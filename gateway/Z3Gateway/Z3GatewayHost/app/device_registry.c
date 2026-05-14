#include "device_registry.h"
#include "device_monitor.h"
#include "device_discovery.h"
#include "app_mqtt.h"
#include "app_utils.h"
#include "app_log.h"

#include <string.h>
#include <strings.h>     // strcasecmp

// ===== Slot store =====
typedef struct {
  bool        used;
  EmberEUI64  euiLe;
  char        eui64BeStr[17];
  EmberNodeId nodeId;
  uint8_t     endpoint;
  char        device_type[16];
} reg_slot_t;

static reg_slot_t g_slots[DEVICE_REGISTRY_MAX];

// ===== Helpers =====
static reg_slot_t *findByEuiStr(const char *eui64Str)
{
  if (!eui64Str) return NULL;
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (g_slots[i].used && strcasecmp(g_slots[i].eui64BeStr, eui64Str) == 0) {
      return &g_slots[i];
    }
  }
  return NULL;
}

static reg_slot_t *findFirstOfType(const char *type)
{
  if (!type) return NULL;
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (g_slots[i].used && strcasecmp(g_slots[i].device_type, type) == 0) {
      return &g_slots[i];
    }
  }
  return NULL;
}

static reg_slot_t *findFirstUsed(void)
{
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (g_slots[i].used) return &g_slots[i];
  }
  return NULL;
}

// ===== Public API =====

bool deviceRegistryUpsert(const char *eui64Str, EmberNodeId nodeId,
                          uint8_t dstEp, const char *device_type)
{
  if (!eui64Str || !device_type) return false;

  EmberEUI64 euiLe;
  if (!parseHexEui64(eui64Str, euiLe)) return false;

  reg_slot_t *s = findByEuiStr(eui64Str);
  bool created = false;
  if (!s) {
    for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
      if (!g_slots[i].used) { s = &g_slots[i]; break; }
    }
    if (!s) {
      appLogLog("REG", "table_full",
                "\"eui64\":\"%s\",\"node_id\":\"0x%04X\"",
                eui64Str, (unsigned)nodeId);
      return false;
    }
    created = true;
  }

  s->used = true;
  memcpy(s->euiLe, euiLe, EUI64_SIZE);
  strncpy(s->eui64BeStr, eui64Str, sizeof(s->eui64BeStr) - 1);
  s->eui64BeStr[sizeof(s->eui64BeStr) - 1] = '\0';
  s->nodeId   = nodeId;
  s->endpoint = dstEp ? dstEp : 1;
  strncpy(s->device_type, device_type, sizeof(s->device_type) - 1);
  s->device_type[sizeof(s->device_type) - 1] = '\0';

  appLogLog("REG", created ? "paired" : "updated",
            "\"eui64\":\"%s\",\"node_id\":\"0x%04X\",\"ep\":%u,\"type\":\"%s\"",
            eui64Str, (unsigned)nodeId, (unsigned)s->endpoint, s->device_type);
  return true;
}

bool deviceRegistryUpdateNodeId(const char *eui64Str, EmberNodeId nodeId)
{
  reg_slot_t *s = findByEuiStr(eui64Str);
  if (!s) return false;
  s->nodeId = nodeId;
  return true;
}

bool deviceRegistryResolve(const char *device_id, device_resolved_t *out)
{
  if (!out || !device_id) return false;
  memset(out, 0, sizeof(*out));

  reg_slot_t *s = NULL;
  if (device_id[0] == '*' && device_id[1] == '\0') {
    s = findFirstOfType("light");
  } else {
    s = findByEuiStr(device_id);
  }
  if (!s) return false;

  out->nodeId   = s->nodeId;
  out->endpoint = s->endpoint;
  strncpy(out->device_type, s->device_type, sizeof(out->device_type) - 1);
  return true;
}

bool deviceRegistryResolveByNodeId(EmberNodeId nodeId, device_resolved_t *out)
{
  if (!out) return false;
  memset(out, 0, sizeof(*out));
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (g_slots[i].used && g_slots[i].nodeId == nodeId) {
      out->nodeId   = g_slots[i].nodeId;
      out->endpoint = g_slots[i].endpoint;
      strncpy(out->device_type, g_slots[i].device_type,
              sizeof(out->device_type) - 1);
      return true;
    }
  }
  return false;
}

uint32_t deviceRegistryCount(void)
{
  uint32_t n = 0;
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (g_slots[i].used) n++;
  }
  return n;
}

// ===== Compat getters (first populated slot) =====
bool deviceRegistryIsKnown(void)
{
  return deviceRegistryCount() > 0;
}

EmberNodeId deviceRegistryGetNodeId(void)
{
  reg_slot_t *s = findFirstUsed();
  return s ? s->nodeId : EMBER_NULL_NODE_ID;
}

uint8_t deviceRegistryGetDstEp(void)
{
  reg_slot_t *s = findFirstUsed();
  return s ? s->endpoint : 1;
}

const EmberEUI64 *deviceRegistryGetEuiLe(void)
{
  static const EmberEUI64 zero = {0};
  reg_slot_t *s = findFirstUsed();
  return s ? (const EmberEUI64 *)&s->euiLe : &zero;
}

uint32_t deviceRegistryCount(void)
{
  uint32_t n = 0;
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (s_devices[i].active) n++;
  }
  return n;
}

// ===== Trust Center join callback =====
// Fired by the Ember framework on every TC join event.
// New flow (post-classification fix):
//   1. Log the TC event.
//   2. Queue device_monitor for bind + configure-report (independent of type).
//   3. On secure/unsecure join, trigger ZDO discovery for the joining node.
//      device_discovery.c will publish the registry + upsert this table once
//      classification completes.
//   4. On secure/unsecure rejoin of an already-known device, refresh nodeId.
//   5. On "device left" we leave the slot intact; a future re-pair will
//      overwrite it.
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

  bool joined = (status == EMBER_STANDARD_SECURITY_SECURED_REJOIN
                 || status == EMBER_STANDARD_SECURITY_UNSECURED_JOIN);

  if (joined) {
    deviceMonitorOnJoin(newNodeId, newNodeEui64);

    // Refresh nodeId for an already-known device (rejoin) before kicking
    // off discovery again.  Discovery itself is idempotent.
    char euiStr[17];
    eui64ToStringBigEndian(euiStr, sizeof(euiStr), newNodeEui64);
    if (deviceRegistryUpdateNodeId(euiStr, newNodeId)) {
      appLogLog("REG", "nodeid_update",
                "\"eui64\":\"%s\",\"node_id\":\"0x%04X\",\"status\":%u",
                euiStr, (unsigned)newNodeId, (unsigned)status);
    }

    // Always (re-)classify on join, so a previously-misclassified device
    // gets corrected.  device_discovery handles slot reuse internally.
    deviceDiscoveryStart(newNodeId, newNodeEui64);
  }
}
