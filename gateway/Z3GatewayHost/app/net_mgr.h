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

// Stage an install code for a specific EUI64 (via sec_mgr) and open the
// network for joining.  Only that EUI can derive the correct TC link key,
// so the join is bound to the intended device.  TTL of the staged IC is
// `durationSec*1000 + 2000` (2 s grace past permit-join window).
//
// SCRUM-55 security baseline + SCRUM-69 §8.1 contract.
//
// Returns the EmberStatus from netMgrOpenForJoin, or EMBER_BAD_ARGUMENT if
// the IC length is invalid (must be 8/10/14/18 bytes incl 2-byte CRC) or
// the staging table is full.
EmberStatus netMgrOpenForJoinSecure(const EmberEUI64 eui_le,
                                    const uint8_t *ic_bytes,
                                    uint8_t ic_len,
                                    uint16_t durationSec);

// On-demand rediscovery (gateway.rediscover_device). Looks up `euiStr`
// (big-endian hex, 16 chars) in the EZSP child table or the stack address
// cache, then kicks ZDO Simple Descriptor classification via
// deviceDiscoveryStart(). Returns false if the device cannot be located on
// this network (caller should reply command status="failed").
bool netMgrRediscoverByEui(const char *euiStr);

#endif
