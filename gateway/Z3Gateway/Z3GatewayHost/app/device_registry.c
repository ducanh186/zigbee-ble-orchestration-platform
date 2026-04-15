#include "device_registry.h"
#include "device_monitor.h"
#include "app_utils.h"
#include "app_log.h"

#include <string.h>

// ===== Single-device store (v1) =====
static bool        g_known   = false;
static EmberEUI64  g_euiLe   = {0};
static EmberNodeId g_nodeId  = EMBER_NULL_NODE_ID;
static uint8_t     g_dstEp   = 1;  // default endpoint on light

bool deviceRegistryResolve(const char *device_id, device_resolved_t *out)
{
  if (!out) return false;
  memset(out, 0, sizeof(*out));

  if (!g_known || g_nodeId == EMBER_NULL_NODE_ID) {
    return false;
  }

  out->nodeId   = g_nodeId;
  out->endpoint = g_dstEp;

  // v1 single-role: the paired device is a light.
  // (`device_id` is accepted but not yet used as a key.)
  (void)device_id;
  strncpy(out->device_type, "light", sizeof(out->device_type) - 1);

  return true;
}

bool deviceRegistryPair(const char *eui64Str, EmberNodeId nodeId,
                        uint8_t dstEp)
{
  EmberEUI64 euiLe;
  if (!parseHexEui64(eui64Str, euiLe)) return false;

  g_known  = true;
  memcpy(g_euiLe, euiLe, EUI64_SIZE);
  g_nodeId = nodeId;
  g_dstEp  = dstEp;

  appLogLog("REG", "paired",
    "\"node_id\":\"0x%04X\",\"ep\":%u",
    (unsigned)nodeId, (unsigned)dstEp);
  return true;
}

// ===== Getters =====
bool        deviceRegistryIsKnown(void)    { return g_known; }
EmberNodeId deviceRegistryGetNodeId(void)  { return g_nodeId; }
uint8_t     deviceRegistryGetDstEp(void)   { return g_dstEp; }
const EmberEUI64 *deviceRegistryGetEuiLe(void) { return &g_euiLe; }

// ===== Trust Center join callback =====
// Called by the Ember framework when any device joins the network.
// Responsibilities:
//   1. Log the event
//   2. Queue configure-reporting via device_monitor
//   3. Update node ID if the joining device is the registered one
void emberAfTrustCenterJoinCallback(EmberNodeId newNodeId,
                                    EmberEUI64 newNodeEui64,
                                    EmberNodeId parentOfNewNode,
                                    EmberDeviceUpdate status,
                                    EmberJoinDecision decision)
{
  (void)parentOfNewNode;
  (void)decision;

  appLogLog("NET", "tc_join",
    "\"node_id\":\"0x%04X\",\"status\":%u,\"decision\":%u",
    (unsigned)newNodeId, (unsigned)status, (unsigned)decision
  );

  // Queue Configure Reporting for the new device (On/Off monitoring)
  if (status == EMBER_STANDARD_SECURITY_SECURED_REJOIN
      || status == EMBER_STANDARD_SECURITY_UNSECURED_JOIN) {
    deviceMonitorOnJoin(newNodeId, newNodeEui64);
  }

  if (!g_known) return;

  // If this is our registered device rejoining, update its node ID.
  if (memcmp(newNodeEui64, g_euiLe, EUI64_SIZE) == 0) {
    g_nodeId = newNodeId;
    appLogLog("REG", "nodeid_update",
      "\"node_id\":\"0x%04X\",\"status\":%u",
      (unsigned)newNodeId, (unsigned)status);
  }
}
