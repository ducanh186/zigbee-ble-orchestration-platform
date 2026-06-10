#ifndef DEVICE_MONITOR_H
#define DEVICE_MONITOR_H

#include <stdint.h>
#include <stdbool.h>
#include "app/framework/include/af.h"

// Call from main tick - handles deferred configure-reporting after join
void deviceMonitorTick(void);

// Call when a new device joins the network
void deviceMonitorOnJoin(EmberNodeId nodeId, EmberEUI64 eui64);

// Send Configure Reporting for On/Off cluster to a device now
bool deviceMonitorConfigureReporting(EmberNodeId nodeId, uint8_t dstEp);

// ===== Presence heartbeat =====
// Periodic liveness sweep over registered devices (currently lights only, which
// are mains-powered routers that reliably APS-ACK). Each interval it probes the
// device; APS delivery success/failure drives a reachable flag, published on
// `devices/{type}/{eui}/presence` so the cloud reflects leave/unreachable
// promptly instead of waiting for the offline reaper.
void devicePresenceTick(void);                                  // from main tick
void devicePresenceOnSent(EmberNodeId nodeId, bool delivered);  // from msgSent cb
void devicePresenceOnLeft(const EmberEUI64 eui64);              // from TC LEFT

#endif
