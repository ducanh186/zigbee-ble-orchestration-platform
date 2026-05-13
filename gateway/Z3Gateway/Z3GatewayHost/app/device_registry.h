#ifndef DEVICE_REGISTRY_H
#define DEVICE_REGISTRY_H

// Device registry: maps logical device_id (EUI64 big-endian hex) to Zigbee
// coordinates (nodeId, endpoint, classified device_type).
//
// Multi-device store with a fixed-size slot array.  Devices are inserted by
// `deviceRegistryUpsert` once their type has been classified by ZDO discovery
// (see device_discovery.c).  TC-join itself does not write here directly.

#include <stdbool.h>
#include <stdint.h>
#include "app/framework/include/af.h"

#ifdef __cplusplus
extern "C" {
#endif

#define DEVICE_REGISTRY_MAX 8

typedef struct {
  EmberNodeId nodeId;
  uint8_t     endpoint;
  char        device_type[16]; // "light"|"switch"|"motion"|"unknown"
} device_resolved_t;

// Resolve a logical device_id into Zigbee coordinates.
//   device_id == "*"            -> first slot whose type is "light"
//   device_id == EUI64 hex (BE) -> exact match (case-insensitive)
// Returns true if a usable entry was found.
bool deviceRegistryResolve(const char *device_id, device_resolved_t *out);

// Insert or replace an entry keyed by EUI64 (big-endian hex).
// Returns false if the table is full or eui64Str is malformed.
bool deviceRegistryUpsert(const char *eui64Str, EmberNodeId nodeId,
                          uint8_t dstEp, const char *device_type);

// Update the nodeId for an existing entry (rejoin path).  Returns false if
// the EUI64 is unknown.
bool deviceRegistryUpdateNodeId(const char *eui64Str, EmberNodeId nodeId);

// Number of populated slots.
uint32_t deviceRegistryCount(void);

// Compatibility getters (return data of the FIRST populated slot).  These
// stay for app_log.c / health publishing where a single representative
// device_id is fine.
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
