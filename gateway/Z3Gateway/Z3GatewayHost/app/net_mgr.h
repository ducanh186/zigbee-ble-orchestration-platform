#ifndef NET_MGR_H
#define NET_MGR_H

#include <stdint.h>
#include <stdbool.h>
#include "stack/include/ember-types.h"  // EmberStatus

typedef struct {
  uint16_t panId;
  uint8_t  ch;
  int8_t   txPowerDbm;
} NetCfg_t;

extern NetCfg_t g_netCfg;

bool netMgrRequestForm(NetCfg_t cfg, const char *src, bool force);
void netMgrTick(void);

// Open the network for joining via the network-creator-security plugin
// (broadcasts permit-join + transient ZigBeeAlliance09 link key).
//
// `durationSec` clamps to [1, 180] s.  Replaces any previously-armed close
// deadline, so calling Open while already open simply extends.
//
// Returns the EmberStatus from the underlying SDK call.
//   EMBER_SUCCESS              -> network is now open; auto-close armed
//   EMBER_NOT_JOINED / other   -> not opened; caller should reply "failed"
EmberStatus netMgrOpenForJoin(uint16_t durationSec);

// Close the network for joining (broadcast permit-join with duration=0).
// Cancels any auto-close timer.  Returns SDK status.
EmberStatus netMgrCloseJoin(void);

#endif
