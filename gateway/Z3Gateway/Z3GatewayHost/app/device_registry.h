#ifndef DEVICE_REGISTRY_H
#define DEVICE_REGISTRY_H

// Device registry: maps Zigbee EUI64/device_id -> Zigbee coordinates.
//
// The public device_id for native Zigbee devices is the EUI64 rendered as a
// big-endian hex string.  Legacy single-light behavior is retained by falling
// back to the first known light when a non-EUI logical id is supplied.

#include <stdbool.h>
#include <stdint.h>
#include "app/framework/include/af.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  EmberNodeId nodeId;
  uint8_t     endpoint;
  char        device_type[32]; // light, motion, switch, unknown
  char        eui64[20];       // big-endian hex string, null terminated
  bool        exact_match;     // true when device_id matched a registry EUI64
} device_resolved_t;

// Resolve a logical device_id into Zigbee coordinates.
// Returns true if the device is known and usable; false otherwise.
bool deviceRegistryResolve(const char *device_id, device_resolved_t *out);

// Resolve a device by id and expected type.  device_id="*" returns the first
// known device of expectedType.  expectedType may be NULL to match any type.
bool deviceRegistryResolveByType(const char *device_id, const char *expectedType,
                                 device_resolved_t *out);

// Register the single controllable device.
// Returns false if eui64Str is malformed.
bool deviceRegistryPair(const char *eui64Str, EmberNodeId nodeId,
                        uint8_t dstEp);

// Upsert a device learned from join, reports, or local commissioning.
bool deviceRegistryUpsert(const char *eui64Str, EmberNodeId nodeId,
                          uint8_t endpoint, const char *deviceType);
bool deviceRegistryUpsertLe(const EmberEUI64 euiLe, EmberNodeId nodeId,
                            uint8_t endpoint, const char *deviceType);

// Record a telemetry source and inferred type.  Returns false if the EUI64
// cannot be looked up from nodeId.
bool deviceRegistryLearnReport(EmberNodeId nodeId, uint8_t endpoint,
                               const char *deviceType, char *outEui64,
                               uint32_t outEui64Size);

// Getters for log/info output.
bool        deviceRegistryIsKnown(void);
EmberNodeId deviceRegistryGetNodeId(void);
uint8_t     deviceRegistryGetDstEp(void);
const EmberEUI64 *deviceRegistryGetEuiLe(void);

// Number of populated slots (used by gateway/health publish).
uint32_t    deviceRegistryCount(void);

#ifdef __cplusplus
}
#endif

#endif // DEVICE_REGISTRY_H
