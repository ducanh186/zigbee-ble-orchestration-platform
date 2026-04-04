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

#endif
