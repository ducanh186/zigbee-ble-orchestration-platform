#ifndef LIGHT_CTRL_H
#define LIGHT_CTRL_H

// Light action module.
//
// Responsibilities:
//   * Validate allowed ops (v1: on, off)
//   * Build and send ZCL On/Off cluster (0x0006) commands via Ember AF
//   * Emit the MQTT command lifecycle:
//         accepted -> queued -> sent -> executed | failed | timeout
//   * Enforce per-command timeout via lightCtrlTick()
//   * Own emberAfMessageSentCallback for On/Off TX completion

#include <stdbool.h>
#include <stdint.h>

#include "sb_command.h"

#ifdef __cplusplus
extern "C" {
#endif

// Init (call once at boot).
void lightCtrlInit(void);

// Periodic tick for timeout enforcement. Call from emberAfMainTickCallback.
void lightCtrlTick(void);

// Handle a parsed command. Publishes lifecycle replies.
// Returns true if the command was accepted into the TX path.
bool lightCtrlHandleCommand(const sb_command_t *cmd);

// Local toggle for gateway-driven automation (Phase 4.2).
// Toggles the registered light's On/Off state.
// Does NOT use command tracking or publish command_reply — this is the
// LOCAL AUTOMATION path, triggered by the rule engine from switch events.
// The resulting state change will naturally appear as a reported state
// update when the light sends its attribute report back.
void lightCtrlLocalToggle(void);

// Phase 3: gateway-driven automation rule execution.
// Send an On / Off / Toggle ZCL frame to the light registered under
// `device_id` (EUI64 hex). `command` must be "on", "off", or "toggle".
// No command_id, no command_reply — same LOCAL AUTOMATION semantics as
// lightCtrlLocalToggle(). Returns true if the frame was handed off to the
// stack successfully (EMBER_SUCCESS); false on any failure (unknown
// device, wrong type, command in-flight, network not joined, send fail).
bool lightCtrlLocalActionByDeviceId(const char *device_id,
                                    const char *command);

#ifdef __cplusplus
}
#endif

#endif // LIGHT_CTRL_H
