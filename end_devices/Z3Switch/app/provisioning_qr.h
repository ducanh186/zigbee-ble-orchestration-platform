#ifndef PROVISIONING_QR_H
#define PROVISIONING_QR_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Compile-time per-project identity. The build flips these for Z3Switch /
// Z3_Occupancy_Sensor (where device_type becomes "switch" / "motion"). Keeping
// them as macros means the JSON builder stays project-agnostic.
#ifndef PROVISIONING_QR_DEVICE_TYPE
#define PROVISIONING_QR_DEVICE_TYPE "light"
#endif

#ifndef PROVISIONING_QR_MODEL
#define PROVISIONING_QR_MODEL "EFR32MG12_LIGHT_KIT"
#endif

#ifndef PROVISIONING_QR_VERSION
#define PROVISIONING_QR_VERSION 1
#endif

// EUI64 as 16 uppercase hex chars, big-endian (contract §3 form), NUL-terminated.
// Reads the running stack's EUI64; reverses Ember's little-endian byte order
// to match the contract example "A8D417FEFF570B00".
bool provisioning_qr_get_eui64_hex(char *out, size_t out_len);

// Install code as uppercase hex (no separator, includes the 2-byte CRC trailer).
// Until manufacturing-token reading lands (Phase P1b), this returns a clearly
// marked DEMO value. The function is the single isolation point so the
// production replacement can drop in without touching callers.
//
// Contract §7: install code MUST NOT be logged raw. Callers must treat the
// returned buffer as secret material — never pass it to printf-style logging.
bool provisioning_qr_get_install_code_hex(char *out, size_t out_len);

// Build the provisioning JSON exactly as contract §3:
//   {"version":1,"eui64":"...","install_code":"...","device_type":"...","model":"..."}
// Returns the number of characters written (excluding NUL), or -1 on failure.
// On success the buffer is NUL-terminated. Callers should pass a buffer of
// at least 200 bytes to be safe.
int provisioning_qr_build_payload(char *out, size_t out_size);

// True when the install code returned by provisioning_qr_get_install_code_hex
// is a compile-time demo value (i.e. no real MFG token is wired). Used by the
// display layer to render a visible "DEMO" banner so the operator does not
// confuse a not-yet-provisioned kit with a production kit.
bool provisioning_qr_is_demo_install_code(void);

#endif // PROVISIONING_QR_H
