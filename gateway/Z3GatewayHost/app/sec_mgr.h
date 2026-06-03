#ifndef SEC_MGR_H
#define SEC_MGR_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "stack/include/ember-types.h"  // EmberEUI64

// Install code byte length includes the 2-byte CRC suffix.
// Valid Zigbee BDB lengths (contract §7): 8, 10, 14, 18.
#define SEC_MGR_IC_MAX_LEN 18

// Boot-time init. Zeroes the staging table; safe to call before the EZSP
// host-NCP link is up. EZSP policy is deferred to secMgrOnStackUp() (called
// after EMBER_NETWORK_UP fires) because ezspSetPolicy needs the NCP
// connected — running it from emberAfMainInitCallback returns
// EZSP_NOT_CONNECTED (0x28).
void secMgrInit(void);

// Late init — called from emberAfStackStatusCallback when EMBER_NETWORK_UP.
// Sets the EZSP TC key request policy to DENY so post-join APS link-key
// requests using the well-known key are ignored. Idempotent — safe to call
// on every NETWORK_UP transition; only logs on success/state change.
void secMgrOnStackUp(void);

// Periodic tick. Sweeps expired staging entries (zero-wipes IC bytes).
// Call from netMgrTick().
void secMgrTick(void);

// Stage an install code for a specific EUI64. TTL is duration in milliseconds
// (caller adds grace). Replaces existing entry for the same EUI if any.
// Returns true on success; false if args invalid or all slots full.
//
// IC validity: length 8/10/14/18 incl 2-byte CRC. Caller is responsible
// for format; CRC validity is checked by the Ember stack during key derive.
bool secMgrStage(const EmberEUI64 eui_le,
                 const uint8_t *ic_bytes,
                 uint8_t ic_len,
                 uint32_t ttl_ms);

// Forget the staged entry for an EUI64 (e.g. after the device joined).
// Zero-wipes the IC bytes. Safe no-op if no slot held.
void secMgrForget(const EmberEUI64 eui_le);

// Returns true if the EUI64 currently has a non-expired staged install code.
// Used by the Trust Center join callback to decide whether a join event was
// driven by SCRUM-81 prepare_join (publish provisioning_joined) or unrelated.
bool secMgrHasStaged(const EmberEUI64 eui_le);

#endif // SEC_MGR_H
