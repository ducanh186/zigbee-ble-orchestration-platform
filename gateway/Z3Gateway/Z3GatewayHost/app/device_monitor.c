#include "device_monitor.h"
#include "app_config.h"
#include "app_utils.h"
#include "app_log.h"
#include "app/framework/include/af.h"
#include "app/util/zigbee-framework/zigbee-device-common.h"

#include <string.h>
#include <stdio.h>

// ===== Deferred setup queue =====
// After a device joins, we wait for key exchange, then:
// 1) Send ZDO Bind Request (so Light's reporting plugin knows to send to us)
// 2) Send Configure Reporting (tell Light what/when to report)

#define MAX_PENDING_DEVICES  8
#define BIND_DELAY_MS        5000u    // 5 seconds after join
#define REPORT_DELAY_MS      8000u    // 8 seconds after join (after bind)

typedef enum {
  DEV_STATE_IDLE = 0,
  DEV_STATE_WAIT_BIND,
  DEV_STATE_WAIT_REPORT,
  DEV_STATE_DONE
} DevState_t;

typedef struct {
  bool        active;
  EmberNodeId nodeId;
  EmberEUI64  eui64;
  uint32_t    joinTick;
  DevState_t  state;
} PendingDevice_t;

static PendingDevice_t g_pending[MAX_PENDING_DEVICES] = {0};

void deviceMonitorOnJoin(EmberNodeId nodeId, EmberEUI64 eui64)
{
  // Find a free slot or reuse existing entry for same nodeId
  int freeSlot = -1;
  for (int i = 0; i < MAX_PENDING_DEVICES; i++) {
    if (g_pending[i].active && g_pending[i].nodeId == nodeId) {
      g_pending[i].joinTick = msTick();
      g_pending[i].state = DEV_STATE_WAIT_BIND;
      memcpy(g_pending[i].eui64, eui64, EUI64_SIZE);
      appLogLog("MON", "rejoin_queued", "\"node_id\":\"0x%04X\"", (unsigned)nodeId);
      return;
    }
    if (!g_pending[i].active && freeSlot < 0) {
      freeSlot = i;
    }
  }

  if (freeSlot >= 0) {
    g_pending[freeSlot].active = true;
    g_pending[freeSlot].nodeId = nodeId;
    memcpy(g_pending[freeSlot].eui64, eui64, EUI64_SIZE);
    g_pending[freeSlot].joinTick = msTick();
    g_pending[freeSlot].state = DEV_STATE_WAIT_BIND;
    appLogLog("MON", "join_queued", "\"node_id\":\"0x%04X\",\"delay_ms\":%u",
              (unsigned)nodeId, (unsigned)BIND_DELAY_MS);
  } else {
    appLogLog("MON", "queue_full", "\"node_id\":\"0x%04X\"", (unsigned)nodeId);
  }
}

// Send ZDO Bind Request to the device:
// "Create a binding on YOUR side for cluster -> gateway"
static bool deviceMonitorSendBindRequest(EmberNodeId nodeId,
                                         EmberEUI64 deviceEui64,
                                         uint8_t deviceEp,
                                         EmberAfClusterId clusterId)
{
  // Gateway's own EUI64 - copy to mutable array for emberBindRequest
  EmberEUI64 gatewayEui;
  memcpy(gatewayEui, emberGetEui64(), EUI64_SIZE);

  // ZDO Bind Request: tell the Light to add a binding entry
  // Source = device's EUI64, endpoint, cluster
  // Destination = Gateway's EUI64, endpoint
  EmberStatus st = emberBindRequest(
    nodeId,              // target node to send the ZDO Bind Request to
    deviceEui64,         // source EUI64 in the binding (the device itself)
    deviceEp,            // source endpoint
    clusterId,           // cluster
    UNICAST_BINDING,     // binding type
    gatewayEui,          // destination EUI64 (gateway)
    0,                   // group (unused for unicast)
    COORD_EP_TELEM,      // destination endpoint (gateway's ep)
    EMBER_AF_DEFAULT_APS_OPTIONS
  );

  appLogLog("MON", "bind_req_sent",
    "\"node_id\":\"0x%04X\",\"ep\":%u,\"cluster\":\"0x%04X\","
    "\"zstatus\":\"0x%02X\"",
    (unsigned)nodeId, (unsigned)deviceEp, (unsigned)clusterId, (unsigned)st);

  return (st == EMBER_SUCCESS);
}

static bool deviceMonitorConfigureReportingForCluster(EmberNodeId nodeId,
                                                      uint8_t dstEp,
                                                      EmberAfClusterId clusterId,
                                                      EmberAfAttributeId attrId,
                                                      uint8_t dataType)
{
  uint8_t payload[8];
  payload[0] = 0x00; // direction: server reports to client
  payload[1] = (uint8_t)(attrId & 0xFFu);
  payload[2] = (uint8_t)((attrId >> 8) & 0xFFu);
  payload[3] = dataType;
  payload[4] = 0x01;
  payload[5] = 0x00; // min reporting interval: 1 second
  payload[6] = 0x2C;
  payload[7] = 0x01; // max reporting interval: 300 seconds

  emberAfFillExternalBuffer(
    (ZCL_GLOBAL_COMMAND | ZCL_FRAME_CONTROL_CLIENT_TO_SERVER),
    clusterId,
    ZCL_CONFIGURE_REPORTING_COMMAND_ID,
    "b",
    payload,
    sizeof(payload)
  );

  emberAfSetCommandEndpoints(COORD_EP_TELEM, dstEp);

  EmberStatus st = emberAfSendCommandUnicast(EMBER_OUTGOING_DIRECT, nodeId);

  appLogLog("MON", "cfg_report_sent",
    "\"node_id\":\"0x%04X\",\"ep\":%u,\"cluster\":\"0x%04X\","
    "\"attr\":\"0x%04X\",\"zstatus\":\"0x%02X\"",
    (unsigned)nodeId, (unsigned)dstEp, (unsigned)clusterId,
    (unsigned)attrId, (unsigned)st);

  return (st == EMBER_SUCCESS);
}

bool deviceMonitorConfigureReporting(EmberNodeId nodeId, uint8_t dstEp)
{
  return deviceMonitorConfigureReportingForCluster(nodeId, dstEp,
                                                   ZCL_ON_OFF_CLUSTER_ID,
                                                   ZCL_ON_OFF_ATTRIBUTE_ID,
                                                   ZCL_BOOLEAN_ATTRIBUTE_TYPE);
}

void deviceMonitorTick(void)
{
  uint32_t now = msTick();

  for (int i = 0; i < MAX_PENDING_DEVICES; i++) {
    if (!g_pending[i].active) continue;

    uint32_t elapsed = now - g_pending[i].joinTick;

    switch (g_pending[i].state) {
      case DEV_STATE_WAIT_BIND:
        if (elapsed >= BIND_DELAY_MS) {
          // Step 1: Send ZDO Bind Requests for known report-producing clusters.
          deviceMonitorSendBindRequest(g_pending[i].nodeId, g_pending[i].eui64,
                                       1, ZCL_ON_OFF_CLUSTER_ID);
          deviceMonitorSendBindRequest(g_pending[i].nodeId, g_pending[i].eui64,
                                       1, ZCL_OCCUPANCY_SENSING_CLUSTER_ID);
          g_pending[i].state = DEV_STATE_WAIT_REPORT;
        }
        break;

      case DEV_STATE_WAIT_REPORT:
        if (elapsed >= REPORT_DELAY_MS) {
          // Step 2: Send Configure Reporting for light On/Off and PIR occupancy.
          deviceMonitorConfigureReporting(g_pending[i].nodeId, 1);
          deviceMonitorConfigureReportingForCluster(g_pending[i].nodeId, 1,
                                                    ZCL_OCCUPANCY_SENSING_CLUSTER_ID,
                                                    ZCL_OCCUPANCY_ATTRIBUTE_ID,
                                                    ZCL_BITMAP8_ATTRIBUTE_TYPE);
          g_pending[i].state = DEV_STATE_DONE;
          g_pending[i].active = false;
        }
        break;

      default:
        g_pending[i].active = false;
        break;
    }
  }
}
