#include "device_registry.h"
#include "device_monitor.h"
#include "app_utils.h"
#include "app_log.h"

#include <string.h>

#define DEVICE_REGISTRY_MAX 16

typedef struct {
  bool        active;
  EmberEUI64 euiLe;
  char        eui64[20];
  EmberNodeId nodeId;
  uint8_t     endpoint;
  char        device_type[16];
} DeviceEntry_t;

static DeviceEntry_t s_devices[DEVICE_REGISTRY_MAX];
static const EmberEUI64 s_nullEui = {0};

static const char *normalizeType(const char *deviceType)
{
  if (!deviceType || !deviceType[0]) return "unknown";
  if (strcmp(deviceType, "light") == 0) return "light";
  if (strcmp(deviceType, "motion") == 0) return "motion";
  if (strcmp(deviceType, "switch") == 0) return "switch";
  return "unknown";
}

static bool sameType(const char *a, const char *b)
{
  if (!a || !b) return false;
  return strcmp(a, b) == 0;
}

static int findByEuiLe(const EmberEUI64 euiLe)
{
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (s_devices[i].active
        && memcmp(s_devices[i].euiLe, euiLe, EUI64_SIZE) == 0) {
      return i;
    }
  }
  return -1;
}

static int findByEuiStr(const char *eui64Str)
{
  if (!eui64Str || !eui64Str[0]) return -1;
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (s_devices[i].active && strcmp(s_devices[i].eui64, eui64Str) == 0) {
      return i;
    }
  }
  return -1;
}

static int findByType(const char *deviceType)
{
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (s_devices[i].active && sameType(s_devices[i].device_type, deviceType)) {
      return i;
    }
  }
  return -1;
}

static int findFirstActive(void)
{
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (s_devices[i].active) return i;
  }
  return -1;
}

static int findFreeSlot(void)
{
  for (int i = 0; i < DEVICE_REGISTRY_MAX; i++) {
    if (!s_devices[i].active) return i;
  }
  return -1;
}

static void fillResolved(int idx, bool exact, device_resolved_t *out)
{
  memset(out, 0, sizeof(*out));
  if (idx < 0 || idx >= DEVICE_REGISTRY_MAX || !s_devices[idx].active) return;

  out->nodeId = s_devices[idx].nodeId;
  out->endpoint = s_devices[idx].endpoint;
  out->exact_match = exact;
  strncpy(out->device_type, s_devices[idx].device_type,
          sizeof(out->device_type) - 1);
  strncpy(out->eui64, s_devices[idx].eui64, sizeof(out->eui64) - 1);
}

bool deviceRegistryResolveByType(const char *device_id, const char *expectedType,
                                 device_resolved_t *out)
{
  if (!out) return false;
  memset(out, 0, sizeof(*out));

  const char *type = expectedType ? normalizeType(expectedType) : NULL;

  if (device_id && device_id[0] && strcmp(device_id, "*") != 0) {
    int exact = findByEuiStr(device_id);
    if (exact >= 0) {
      if (!type
          || sameType(s_devices[exact].device_type, type)
          || sameType(s_devices[exact].device_type, "unknown")) {
        fillResolved(exact, true, out);
        return true;
      }
      return false;
    }
  }

  if (type) {
    int byType = findByType(type);
    if (byType >= 0) {
      fillResolved(byType, false, out);
      return true;
    }

    // Backward-compatible demo fallback: before a light report arrives, the
    // only joined device may still be typed as unknown.
    if (sameType(type, "light")) {
      int unknown = findByType("unknown");
      if (unknown >= 0) {
        fillResolved(unknown, false, out);
        return true;
      }
    }
    return false;
  }

  int first = findFirstActive();
  if (first >= 0) {
    fillResolved(first, false, out);
    return true;
  }

  return false;
}

bool deviceRegistryResolve(const char *device_id, device_resolved_t *out)
{
  if (!out) return false;
  memset(out, 0, sizeof(*out));

  if (device_id && device_id[0] && strcmp(device_id, "*") != 0) {
    int exact = findByEuiStr(device_id);
    if (exact >= 0) {
      fillResolved(exact, true, out);
      return true;
    }
  }

  int light = findByType("light");
  if (light >= 0) {
    fillResolved(light, false, out);
    return true;
  }

  int unknown = findByType("unknown");
  if (unknown >= 0) {
    fillResolved(unknown, false, out);
    return true;
  }

  int first = findFirstActive();
  if (first >= 0) {
    fillResolved(first, false, out);
    return true;
  }

  return false;
}

bool deviceRegistryUpsertLe(const EmberEUI64 euiLe, EmberNodeId nodeId,
                            uint8_t endpoint, const char *deviceType)
{
  int idx = findByEuiLe(euiLe);
  if (idx < 0) idx = findFreeSlot();
  if (idx < 0) {
    appLogLog("REG", "table_full", "\"node_id\":\"0x%04X\"", (unsigned)nodeId);
    return false;
  }

  const char *type = normalizeType(deviceType);
  bool wasActive = s_devices[idx].active;
  char oldType[16] = {0};
  if (wasActive) {
    strncpy(oldType, s_devices[idx].device_type, sizeof(oldType) - 1);
  }

  s_devices[idx].active = true;
  memcpy(s_devices[idx].euiLe, euiLe, EUI64_SIZE);
  eui64ToStringBigEndian(s_devices[idx].eui64,
                         sizeof(s_devices[idx].eui64), euiLe);
  s_devices[idx].nodeId = nodeId;
  s_devices[idx].endpoint = endpoint ? endpoint : 1;

  if (!wasActive || sameType(oldType, "unknown") || !sameType(type, "unknown")) {
    strncpy(s_devices[idx].device_type, type,
            sizeof(s_devices[idx].device_type) - 1);
    s_devices[idx].device_type[sizeof(s_devices[idx].device_type) - 1] = '\0';
  }

  appLogLog("REG", wasActive ? "updated" : "added",
    "\"eui64\":\"%s\",\"node_id\":\"0x%04X\",\"ep\":%u,\"type\":\"%s\"",
    s_devices[idx].eui64, (unsigned)nodeId,
    (unsigned)s_devices[idx].endpoint, s_devices[idx].device_type);

  return true;
}

bool deviceRegistryUpsert(const char *eui64Str, EmberNodeId nodeId,
                          uint8_t endpoint, const char *deviceType)
{
  EmberEUI64 euiLe;
  if (!parseHexEui64(eui64Str, euiLe)) return false;
  return deviceRegistryUpsertLe(euiLe, nodeId, endpoint, deviceType);
}

bool deviceRegistryPair(const char *eui64Str, EmberNodeId nodeId,
                        uint8_t dstEp)
{
  bool ok = deviceRegistryUpsert(eui64Str, nodeId, dstEp, "light");
  if (ok) {
    appLogLog("REG", "paired",
      "\"eui64\":\"%s\",\"node_id\":\"0x%04X\",\"ep\":%u,\"type\":\"light\"",
      eui64Str, (unsigned)nodeId, (unsigned)dstEp);
  }
  return ok;
}

bool deviceRegistryLearnReport(EmberNodeId nodeId, uint8_t endpoint,
                               const char *deviceType, char *outEui64,
                               uint32_t outEui64Size)
{
  EmberEUI64 eui;
  if (emberLookupEui64ByNodeId(nodeId, eui) != EMBER_SUCCESS) {
    return false;
  }

  if (outEui64 && outEui64Size > 0) {
    eui64ToStringBigEndian(outEui64, outEui64Size, eui);
  }

  return deviceRegistryUpsertLe(eui, nodeId, endpoint, deviceType);
}

// ===== Getters =====
bool deviceRegistryIsKnown(void)
{
  return findFirstActive() >= 0;
}

EmberNodeId deviceRegistryGetNodeId(void)
{
  int idx = findByType("light");
  if (idx < 0) idx = findFirstActive();
  return idx >= 0 ? s_devices[idx].nodeId : EMBER_NULL_NODE_ID;
}

uint8_t deviceRegistryGetDstEp(void)
{
  int idx = findByType("light");
  if (idx < 0) idx = findFirstActive();
  return idx >= 0 ? s_devices[idx].endpoint : 1;
}

const EmberEUI64 *deviceRegistryGetEuiLe(void)
{
  int idx = findByType("light");
  if (idx < 0) idx = findFirstActive();
  return idx >= 0 ? &s_devices[idx].euiLe : &s_nullEui;
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
// Called by the Ember framework when any device joins the network.
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

  if (status == EMBER_STANDARD_SECURITY_SECURED_REJOIN
      || status == EMBER_STANDARD_SECURITY_UNSECURED_JOIN) {
    deviceRegistryUpsertLe(newNodeEui64, newNodeId, 1, "unknown");
    deviceMonitorOnJoin(newNodeId, newNodeEui64);
  }
}
