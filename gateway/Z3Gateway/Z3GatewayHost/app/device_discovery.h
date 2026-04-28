#ifndef DEVICE_DISCOVERY_H
#define DEVICE_DISCOVERY_H

// ZDO-driven device classification.
//
// Flow:
//   TC join -> deviceDiscoveryStart()
//      -> emberAfFindActiveEndpoints()
//      -> emberAfFindClustersByDeviceAndEndpoint() per endpoint
//      -> classify by cluster role + profile/device id
//      -> deviceRegistryUpsert(eui, nodeId, controlEp, type)
//      -> appMqttClearRetainedRegistry(eui, type) for the OTHER types
//      -> appMqttPublishDeviceRegistry(nodeId, eui, type)
//
// Classification rule (per chuphu2004 spec, no defaulting to "light"):
//   * 0x0406 in inClusterList                        -> motion
//   * 0x0006 in outClusterList ONLY                  -> switch
//   * 0x0006 in inClusterList ONLY, or 0x0008 in inClusterList -> light
//   * 0x0006 in BOTH in and out                      -> unknown (conflict)
//   * Active EP timeout / no useful clusters         -> unknown
//
// Timeout: each ZDO request relies on the SDK's built-in unicast timeout
// (~1.5 s in 4.5.0). On first failure (timeout or non-success status), this
// module retries the same request once. On second failure it gives up,
// publishes registry as "unknown" with metadata_source="zdo_timeout" or
// "zdo_partial", and lets the runtime telemetry path (telemetry_rx.c)
// re-classify any subsequent ZCL traffic on its own.

#include <stdbool.h>
#include <stdint.h>
#include "app/framework/include/af.h"

#ifdef __cplusplus
extern "C" {
#endif

// Start ZDO discovery for a freshly-joined device.
// `euiLe` is the little-endian EUI64 as supplied by the TC join callback.
// Idempotent: repeated calls for the same nodeId reuse the same slot
// (used during rejoin storms).
void deviceDiscoveryStart(EmberNodeId nodeId, const EmberEUI64 euiLe);

// Optional: lookup whether a discovery is currently in flight for a node.
bool deviceDiscoveryInProgress(EmberNodeId nodeId);

#ifdef __cplusplus
}
#endif

#endif // DEVICE_DISCOVERY_H
