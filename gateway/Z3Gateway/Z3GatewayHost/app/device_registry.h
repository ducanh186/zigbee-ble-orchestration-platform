#ifndef DEVICE_REGISTRY_H
#define DEVICE_REGISTRY_H

// Minimal device registry for Phase 2 (single-light bring-up).
//
// This is intentionally tiny: it resolves a logical `device_id` string to the
// Zigbee coordinates we actually need (`EmberNodeId` + destination endpoint)
// and infers the `device_type` when the caller did not provide one.
//
// For v1 we have exactly one controllable light (the one paired via
// `valveCtrlPair` over CLI/MQTT). Future phases will replace the body of
// `deviceRegistryResolve` with a real lookup table keyed by `device_id`.

#include <stdbool.h>
#include <stdint.h>
#include "app/framework/include/af.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  EmberNodeId nodeId;
  uint8_t     endpoint;
  char        device_type[32]; // inferred, e.g. "light"
} device_resolved_t;

// Resolve a logical device_id into Zigbee coordinates.
// Returns true if the device is known and usable; false otherwise.
bool deviceRegistryResolve(const char *device_id, device_resolved_t *out);

#ifdef __cplusplus
}
#endif

#endif // DEVICE_REGISTRY_H
