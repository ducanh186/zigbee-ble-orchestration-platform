#ifndef DEVICE_REGISTRY_H
#define DEVICE_REGISTRY_H

// Device registry: maps logical device_id (EUI64 big-endian hex) to Zigbee
// coordinates (nodeId, endpoint, classified device_type).
//
// Multi-device store with a fixed-size slot array.  Devices are inserted by
// `deviceRegistryUpsert` once their type has been classified by ZDO discovery
// (see device_discovery.c).  TC-join itself does not write here directly.

#include <stdbool.h>
#include <stddef.h>
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

// Check if a nodeId is already registered (under any EUI64).
// Returns true and fills out->device_type if found.
bool deviceRegistryResolveByNodeId(EmberNodeId nodeId, device_resolved_t *out);

// Reverse-resolve a Zigbee short address to its EUI64 (big-endian hex string).
// Used as a fallback when emberLookupEui64ByNodeId() returns failure (the NCP
// address table can be empty for a node that the gateway already classified
// via ZDO discovery). Returns true on hit; `out` is NUL-terminated 16-hex EUI.
// `outLen` must be >= 17.
bool deviceRegistryGetEuiBeStrByNodeId(EmberNodeId nodeId, char *out, size_t outLen);

// Iterate the registry by raw slot index in [0, DEVICE_REGISTRY_MAX).
// Fills the out params for a USED slot and returns true; returns false for an
// empty slot or out-of-range index. Used by the presence sweep to probe every
// known device. Any out pointer may be NULL if that field is not needed.
bool deviceRegistryGetByIndex(uint32_t idx, EmberNodeId *nodeIdOut,
                              uint8_t *endpointOut,
                              char *typeOut, size_t typeLen,
                              char *euiOut, size_t euiLen);

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
