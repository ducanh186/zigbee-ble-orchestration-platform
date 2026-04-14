#include "device_registry.h"
#include "valve_ctrl.h"

#include <string.h>

// v1: the single controllable device is the one paired via valveCtrl.
// We intentionally do NOT key by device_id string yet - there is no table -
// but we still log the requested id so callers see it in traces.
bool deviceRegistryResolve(const char *device_id, device_resolved_t *out)
{
  if (!out) return false;
  memset(out, 0, sizeof(*out));

  if (!valveCtrlIsKnown()) {
    return false;
  }

  EmberNodeId nodeId = valveCtrlGetNodeId();
  if (nodeId == EMBER_NULL_NODE_ID) {
    return false;
  }

  out->nodeId   = nodeId;
  out->endpoint = valveCtrlGetDstEp();

  // v1 single-role: the paired device is a light.
  // (`device_id` is accepted but not yet used as a key.)
  (void)device_id;
  strncpy(out->device_type, "light", sizeof(out->device_type) - 1);

  return true;
}
