#ifndef DEVICE_REGISTRY_H
#define DEVICE_REGISTRY_H

// Device registry: maps logical device_id -> Zigbee coordinates.
//
// v1 supports a single controllable device (paired via `deviceRegistryPair`
// from CLI or future MQTT provisioning path). Future phases will add a
// multi-device lookup table keyed by device_id.

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

// Register the single controllable device.
// Returns false if eui64Str is malformed.
bool deviceRegistryPair(const char *eui64Str, EmberNodeId nodeId,
                        uint8_t dstEp);

// Getters for log/info output.
bool        deviceRegistryIsKnown(void);
EmberNodeId deviceRegistryGetNodeId(void);
uint8_t     deviceRegistryGetDstEp(void);
const EmberEUI64 *deviceRegistryGetEuiLe(void);

#ifdef __cplusplus
}
#endif

#endif // DEVICE_REGISTRY_H
