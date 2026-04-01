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
// "Create a binding on YOUR side (Light) for On/Off cluster -> gateway"
static bool deviceMonitorSendBindRequest(EmberNodeId nodeId, EmberEUI64 deviceEui64, uint8_t deviceEp)
{
  // Gateway's own EUI64 - copy to mutable array for emberBindRequest
  EmberEUI64 gatewayEui;
  memcpy(gatewayEui, emberGetEui64(), EUI64_SIZE);

  // ZDO Bind Request: tell the Light to add a binding entry
  // Source = Light's EUI64, endpoint, cluster
  // Destination = Gateway's EUI64, endpoint
  EmberStatus st = emberBindRequest(
    nodeId,              // target node to send the ZDO Bind Request to
    deviceEui64,         // source EUI64 in the binding (the Light itself)
    deviceEp,            // source endpoint (Light's ep)
    ZCL_ON_OFF_CLUSTER_ID, // cluster
    UNICAST_BINDING,     // binding type
    gatewayEui,          // destination EUI64 (gateway)
    0,                   // group (unused for unicast)
    COORD_EP_TELEM,      // destination endpoint (gateway's ep)
    EMBER_AF_DEFAULT_APS_OPTIONS
  );

  appLogLog("MON", "bind_req_sent",
    "\"node_id\":\"0x%04X\",\"ep\":%u,\"cluster\":\"0x0006\",\"zstatus\":\"0x%02X\"",
    (unsigned)nodeId, (unsigned)deviceEp, (unsigned)st);

  return (st == EMBER_SUCCESS);
}

bool deviceMonitorConfigureReporting(EmberNodeId nodeId, uint8_t dstEp)
{
  uint8_t payload[] = {
    0x00,       // direction: 0x00 = server reports to client
    0x00, 0x00, // attribute ID: 0x0000 (On/Off) little-endian
    0x10,       // data type: ZCL_BOOLEAN_ATTRIBUTE_TYPE
    0x01, 0x00, // min reporting interval: 1 second (little-endian)
    0x2C, 0x01, // max reporting interval: 300 seconds (little-endian) = 5 min
    // no reportable change field for boolean type
  };

  emberAfFillExternalBuffer(
    (ZCL_GLOBAL_COMMAND | ZCL_FRAME_CONTROL_CLIENT_TO_SERVER),
    ZCL_ON_OFF_CLUSTER_ID,
    ZCL_CONFIGURE_REPORTING_COMMAND_ID,
    "b",
    payload,
    sizeof(payload)
  );

  emberAfSetCommandEndpoints(COORD_EP_TELEM, dstEp);

  EmberStatus st = emberAfSendCommandUnicast(EMBER_OUTGOING_DIRECT, nodeId);

  appLogLog("MON", "cfg_report_sent",
    "\"node_id\":\"0x%04X\",\"ep\":%u,\"cluster\":\"0x0006\",\"zstatus\":\"0x%02X\"",
    (unsigned)nodeId, (unsigned)dstEp, (unsigned)st);

  return (st == EMBER_SUCCESS);
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
          // Step 1: Send ZDO Bind Request
          deviceMonitorSendBindRequest(g_pending[i].nodeId, g_pending[i].eui64, 1);
          g_pending[i].state = DEV_STATE_WAIT_REPORT;
        }
        break;

      case DEV_STATE_WAIT_REPORT:
        if (elapsed >= REPORT_DELAY_MS) {
          // Step 2: Send Configure Reporting
          deviceMonitorConfigureReporting(g_pending[i].nodeId, 1);
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
