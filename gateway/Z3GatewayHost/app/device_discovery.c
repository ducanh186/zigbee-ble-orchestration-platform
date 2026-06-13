#include "device_discovery.h"
#include "device_registry.h"
#include "app_mqtt.h"
#include "app_log.h"
#include "app_utils.h"

#include "app/framework/include/af.h"
#include "app/util/zigbee-framework/zigbee-device-common.h"

#include <string.h>
#include <stdio.h>

// ===== Constants =====
// ACTIVE_ENDPOINTS_REQUEST / SIMPLE_DESCRIPTOR_REQUEST come from
// zigbee-device-common.h (which pulls zigbee-device-stack.h).
// ZCL_*_CLUSTER_ID constants come from the generated zcl-id.h via af.h.

#define DD_MAX_DEVICES 8
#define DD_MAX_EPS     8

// Slot states
typedef enum {
  DD_FREE = 0,
  DD_FIND_EPS,        // Active EP request in flight
  DD_FIND_CLUSTERS,   // Simple Descriptor in flight for ep_list[ep_idx]
  DD_DONE             // (not normally observed - slot is freed when done)
} dd_state_t;

typedef struct {
  bool        in_use;
  dd_state_t  state;
  EmberNodeId nodeId;
  EmberEUI64  euiLe;
  char        eui64BeStr[17];

  // Active EP results
  uint8_t  ep_count;
  uint8_t  ep_list[DD_MAX_EPS];
  uint8_t  ep_idx;             // next EP to query

  // Per-device retry book-keeping
  bool retry_active_ep;        // already retried Active-EP once
  bool retry_simple_desc;      // already retried current Simple-Desc once

  // Aggregated cluster info across all endpoints
  bool has_onoff_server;
  bool has_onoff_client;
  bool has_level_server;
  bool has_occupancy_server;
  bool has_temp_server;
  bool has_humidity_server;

  // Best-effort identity hints (last EP that gave us non-zero values)
  uint16_t profileId;
  uint16_t zigbeeDeviceId;     // the device-id field inside Simple Descriptor

  // Endpoint chosen for downstream control unicast (light path).
  // First EP whose Simple Descriptor advertises 0x0006 server.
  uint8_t  control_ep;

  // True if at least one Simple Descriptor came back successfully.
  bool any_simple_desc_ok;
} dd_slot_t;

static dd_slot_t g_slots[DD_MAX_DEVICES];

// ===== Slot management =====

static dd_slot_t *findSlotByNodeId(EmberNodeId nodeId)
{
  for (int i = 0; i < DD_MAX_DEVICES; i++) {
    if (g_slots[i].in_use && g_slots[i].nodeId == nodeId) {
      return &g_slots[i];
    }
  }
  return NULL;
}

static dd_slot_t *allocSlot(void)
{
  for (int i = 0; i < DD_MAX_DEVICES; i++) {
    if (!g_slots[i].in_use) {
      memset(&g_slots[i], 0, sizeof(g_slots[i]));
      g_slots[i].in_use     = true;
      g_slots[i].control_ep = 1;          // safe default until discovered
      return &g_slots[i];
    }
  }
  return NULL;
}

static void releaseSlot(dd_slot_t *s)
{
  if (s) memset(s, 0, sizeof(*s));
}

// ===== Classification =====

// Per the agreed rule, we only commit to "light" when 0x0006 or 0x0008 is
// in the input/server cluster list AND 0x0006 is NOT in the output/client
// list.  Conflicts (server+client) become "unknown" - never silently "light".
// Returns canonical device_type. For sensors, also writes the slot kind via
// *kind_out (1=occupancy [reserved], 2=environment [active], 3=flame is a
// reserved slot — IAS Zone 0x0500 detection deferred until hardware exists).
// Non-sensor types set *kind_out = 0.
static const char *classifyType(const dd_slot_t *s, uint8_t *kind_out)
{
  if (kind_out) *kind_out = 0;
  if (s->has_occupancy_server) {
    if (kind_out) *kind_out = 1;          // occupancy (reserved slot)
    return "sensor";
  }
  if (s->has_temp_server || s->has_humidity_server) {
    if (kind_out) *kind_out = 2;          // environment (DHT11, active)
    return "sensor";
  }
  if (s->has_onoff_client && s->has_onoff_server) {
    return "unknown";   // conflict; let mentor inspect
  }
  if (s->has_onoff_client) {
    return "switch";
  }
  if (s->has_onoff_server || s->has_level_server) {
    return "light";
  }
  return "unknown";
}

// ===== Forward decls =====
static void onServiceDiscovery(const EmberAfServiceDiscoveryResult *result);
static void requestActiveEps(dd_slot_t *s);
static void requestNextSimpleDesc(dd_slot_t *s);
static void completeAndPublish(dd_slot_t *s, const char *metadataNote);

// ===== Public entry =====

void deviceDiscoveryStart(EmberNodeId nodeId, const EmberEUI64 euiLe)
{
  dd_slot_t *s = findSlotByNodeId(nodeId);
  if (s) {
    // Rejoin while a discovery is still in flight - reset and retry.
    appLogLog("DD", "restart",
              "\"node_id\":\"0x%04X\"", (unsigned)nodeId);
    memset(s, 0, sizeof(*s));
    s->in_use     = true;
    s->control_ep = 1;
  } else {
    s = allocSlot();
    if (!s) {
      appLogLog("DD", "slots_full",
                "\"node_id\":\"0x%04X\"", (unsigned)nodeId);
      return;
    }
  }

  s->nodeId = nodeId;
  memcpy(s->euiLe, euiLe, EUI64_SIZE);
  eui64ToStringBigEndian(s->eui64BeStr, sizeof(s->eui64BeStr), euiLe);

  appLogLog("DD", "start",
            "\"node_id\":\"0x%04X\",\"eui64\":\"%s\"",
            (unsigned)nodeId, s->eui64BeStr);

  requestActiveEps(s);
}

bool deviceDiscoveryInProgress(EmberNodeId nodeId)
{
  return findSlotByNodeId(nodeId) != NULL;
}

// ===== ZDO request senders =====

static void requestActiveEps(dd_slot_t *s)
{
  s->state = DD_FIND_EPS;
  EmberStatus st = emberAfFindActiveEndpoints(s->nodeId, onServiceDiscovery);
  if (st != EMBER_SUCCESS) {
    appLogLog("DD", "active_ep_send_fail",
              "\"node_id\":\"0x%04X\",\"zstatus\":\"0x%02X\","
              "\"retry\":%s",
              (unsigned)s->nodeId, (unsigned)st,
              s->retry_active_ep ? "false" : "true");
    if (!s->retry_active_ep) {
      s->retry_active_ep = true;
      // Immediate retry: the SDK is not holding state for us in this branch.
      EmberStatus st2 = emberAfFindActiveEndpoints(s->nodeId, onServiceDiscovery);
      if (st2 == EMBER_SUCCESS) return;
    }
    completeAndPublish(s, "zdo_send_fail");
  }
}

static void requestNextSimpleDesc(dd_slot_t *s)
{
  if (s->ep_idx >= s->ep_count) {
    completeAndPublish(s, s->any_simple_desc_ok ? NULL : "zdo_partial");
    return;
  }

  s->state = DD_FIND_CLUSTERS;
  s->retry_simple_desc = false;
  uint8_t ep = s->ep_list[s->ep_idx];
  EmberStatus st = emberAfFindClustersByDeviceAndEndpoint(
                     s->nodeId, ep, onServiceDiscovery);
  if (st != EMBER_SUCCESS) {
    appLogLog("DD", "simple_desc_send_fail",
              "\"node_id\":\"0x%04X\",\"ep\":%u,\"zstatus\":\"0x%02X\"",
              (unsigned)s->nodeId, (unsigned)ep, (unsigned)st);
    // Skip this EP, try the next one.
    s->ep_idx++;
    requestNextSimpleDesc(s);
  }
}

// ===== Cluster aggregation =====

static void absorbClusters(dd_slot_t *s, const EmberAfClusterList *cl)
{
  if (!cl) return;

  if (cl->profileId)      s->profileId      = cl->profileId;
  if (cl->deviceId)       s->zigbeeDeviceId = cl->deviceId;

  for (uint8_t i = 0; i < cl->inClusterCount; i++) {
    uint16_t c = cl->inClusterList[i];
    if (c == ZCL_ON_OFF_CLUSTER_ID) {
      s->has_onoff_server = true;
      if (s->control_ep == 0 || s->control_ep == 1) {
        s->control_ep = cl->endpoint;     // pin to first OnOff-server EP
      }
    }
    if (c == ZCL_LEVEL_CONTROL_CLUSTER_ID) s->has_level_server     = true;
    if (c == ZCL_OCCUPANCY_SENSING_CLUSTER_ID) s->has_occupancy_server = true;
    if (c == ZCL_TEMP_MEASUREMENT_CLUSTER_ID) s->has_temp_server = true;
    if (c == ZCL_RELATIVE_HUMIDITY_MEASUREMENT_CLUSTER_ID) s->has_humidity_server = true;
  }
  for (uint8_t i = 0; i < cl->outClusterCount; i++) {
    uint16_t c = cl->outClusterList[i];
    if (c == ZCL_ON_OFF_CLUSTER_ID) s->has_onoff_client = true;
  }

  appLogLog("DD", "ep_clusters",
            "\"node_id\":\"0x%04X\",\"ep\":%u,\"in\":%u,\"out\":%u,"
            "\"profile\":\"0x%04X\",\"device\":\"0x%04X\"",
            (unsigned)s->nodeId, (unsigned)cl->endpoint,
            (unsigned)cl->inClusterCount, (unsigned)cl->outClusterCount,
            (unsigned)cl->profileId, (unsigned)cl->deviceId);
}

// ===== Single service-discovery callback =====

static void onServiceDiscovery(const EmberAfServiceDiscoveryResult *result)
{
  if (!result) return;

  dd_slot_t *s = findSlotByNodeId(result->matchAddress);
  if (!s) {
    // Stray response after slot was freed - ignore.
    return;
  }

  bool haveResponse = emberAfHaveDiscoveryResponseStatus(result->status);

  if (result->zdoRequestClusterId == ACTIVE_ENDPOINTS_REQUEST) {
    if (!haveResponse) {
      if (!s->retry_active_ep) {
        appLogLog("DD", "active_ep_retry",
                  "\"node_id\":\"0x%04X\",\"status\":\"0x%02X\"",
                  (unsigned)s->nodeId, (unsigned)result->status);
        s->retry_active_ep = true;
        requestActiveEps(s);
        return;
      }
      appLogLog("DD", "active_ep_giveup",
                "\"node_id\":\"0x%04X\",\"status\":\"0x%02X\"",
                (unsigned)s->nodeId, (unsigned)result->status);
      completeAndPublish(s, "zdo_timeout");
      return;
    }

    const EmberAfEndpointList *epList =
      (const EmberAfEndpointList *)result->responseData;
    if (!epList || epList->count == 0) {
      appLogLog("DD", "no_active_eps",
                "\"node_id\":\"0x%04X\"", (unsigned)s->nodeId);
      completeAndPublish(s, "zdo_partial");
      return;
    }

    s->ep_count = epList->count > DD_MAX_EPS ? DD_MAX_EPS : epList->count;
    for (uint8_t i = 0; i < s->ep_count; i++) {
      s->ep_list[i] = epList->list[i];
    }
    s->ep_idx = 0;
    appLogLog("DD", "active_eps_ok",
              "\"node_id\":\"0x%04X\",\"count\":%u",
              (unsigned)s->nodeId, (unsigned)s->ep_count);
    requestNextSimpleDesc(s);
    return;
  }

  if (result->zdoRequestClusterId == SIMPLE_DESCRIPTOR_REQUEST) {
    if (!haveResponse) {
      if (!s->retry_simple_desc) {
        s->retry_simple_desc = true;
        appLogLog("DD", "simple_desc_retry",
                  "\"node_id\":\"0x%04X\",\"ep\":%u,\"status\":\"0x%02X\"",
                  (unsigned)s->nodeId,
                  (unsigned)(s->ep_idx < s->ep_count ? s->ep_list[s->ep_idx] : 0),
                  (unsigned)result->status);
        // Re-issue the same EP (don't advance ep_idx).
        s->state = DD_FIND_CLUSTERS;
        EmberStatus st = emberAfFindClustersByDeviceAndEndpoint(
                           s->nodeId, s->ep_list[s->ep_idx], onServiceDiscovery);
        if (st == EMBER_SUCCESS) return;
        // Fall through: skip this EP.
      }
      // Either retried already or re-send failed — skip this EP, advance.
      appLogLog("DD", "simple_desc_skip",
                "\"node_id\":\"0x%04X\",\"ep\":%u,\"status\":\"0x%02X\"",
                (unsigned)s->nodeId,
                (unsigned)(s->ep_idx < s->ep_count ? s->ep_list[s->ep_idx] : 0),
                (unsigned)result->status);
      s->ep_idx++;
      requestNextSimpleDesc(s);
      return;
    }

    const EmberAfClusterList *cl =
      (const EmberAfClusterList *)result->responseData;
    absorbClusters(s, cl);
    s->any_simple_desc_ok = true;

    s->ep_idx++;
    requestNextSimpleDesc(s);
    return;
  }

  // Unknown ZDO cluster - ignore.
}

// ===== Completion =====

static void completeAndPublish(dd_slot_t *s, const char *metadataNote)
{
  uint8_t sensor_kind = 0;
  const char *type = classifyType(s, &sensor_kind);

  // Detect "conflict" specifically so we can log it loudly.
  if (s->has_onoff_server && s->has_onoff_client) {
    appLogLog("DD", "device_type_conflict",
              "\"node_id\":\"0x%04X\",\"eui64\":\"%s\","
              "\"profile\":\"0x%04X\",\"device\":\"0x%04X\"",
              (unsigned)s->nodeId, s->eui64BeStr,
              (unsigned)s->profileId, (unsigned)s->zigbeeDeviceId);
  }

  appLogLog("DD", "classify",
            "\"node_id\":\"0x%04X\",\"eui64\":\"%s\",\"type\":\"%s\","
            "\"in_onoff\":%s,\"out_onoff\":%s,\"in_level\":%s,\"in_occ\":%s,"
            "\"control_ep\":%u,\"profile\":\"0x%04X\",\"device\":\"0x%04X\","
            "\"note\":\"%s\"",
            (unsigned)s->nodeId, s->eui64BeStr, type,
            s->has_onoff_server ? "true" : "false",
            s->has_onoff_client ? "true" : "false",
            s->has_level_server ? "true" : "false",
            s->has_occupancy_server ? "true" : "false",
            (unsigned)s->control_ep,
            (unsigned)s->profileId, (unsigned)s->zigbeeDeviceId,
            metadataNote ? metadataNote : "ok");

  // Persist to registry FIRST so any concurrent ZCL traffic resolves
  // the right type.
  deviceRegistryUpsert(s->eui64BeStr, s->nodeId, s->control_ep, type);
  // Always write the kind (0 for non-sensors) so a slot re-classified from
  // sensor -> light/switch does not keep a stale sensor_kind.
  deviceRegistrySetSensorKind(s->eui64BeStr, sensor_kind);

  // Clear stale retained registry slots on broker before publishing the
  // authoritative one (avoids cloud restoring a wrong device_type after
  // a future restart).
  appMqttClearRetainedRegistry(s->eui64BeStr, type);

  // Publish authoritative registry.
  appMqttPublishDeviceRegistry(s->nodeId, s->eui64BeStr, type, sensor_kind);

  releaseSlot(s);
}
