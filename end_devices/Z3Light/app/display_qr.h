#ifndef DISPLAY_QR_H
#define DISPLAY_QR_H

#include <stdbool.h>

// One-shot init for the WSTK Sharp Memory LCD (LS013B7DH03, 128x128 mono).
// Brings up DMD + GLIB and clears the framebuffer. Safe to call exactly once
// from emberAfMainInitCallback after the stack has finished its own init.
// Returns true on success.
bool display_qr_init(const char *title);

// Renders View 1 (device info: title, EUI64-tail, firmware) followed by
// View 2 (provisioning QR + caption). Both views are drawn into the same
// framebuffer and pushed to the panel with a single DMD_updateDisplay().
// Pulls the EUI64 via the provisioning_qr module — caller does not pass it.
//
// payload_for_qr: the exact contract-§3 JSON string to encode in the QR.
//                 Must not be NULL.
//
// On a QR encoder failure (e.g. payload too large for V7-M), the call falls
// back to a text-only screen with an "QR ENCODE FAILED" banner so the kit
// does not silently show a stale or absent QR.
bool display_qr_render_provisioning(const char *payload_for_qr);

#endif // DISPLAY_QR_H
