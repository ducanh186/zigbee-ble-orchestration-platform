#ifndef LIGHT_CTRL_H
#define LIGHT_CTRL_H

// Light action module (Phase 2).
//
// Responsibilities:
//   * Validate allowed ops (v1: on, off)
//   * Invoke the actual Zigbee send path (currently shared with valve_ctrl,
//     which already owns On/Off cluster 0x0006 with APS ACK+retry)
//   * Emit the MQTT command lifecycle:
//         accepted -> queued -> sent -> executed | failed | timeout
//   * Enforce per-command timeout via lightCtrlTick()

#include <stdbool.h>
#include <stdint.h>

#include "sb_command.h"

#ifdef __cplusplus
extern "C" {
#endif

// Register the TX-complete hook with valve_ctrl. Call once at boot.
void lightCtrlInit(void);

// Periodic tick for timeout enforcement. Call from emberAfMainTickCallback.
void lightCtrlTick(void);

// Handle a parsed command. Publishes lifecycle replies.
// Returns true if the command was accepted into the TX path.
bool lightCtrlHandleCommand(const sb_command_t *cmd);

#ifdef __cplusplus
}
#endif

#endif // LIGHT_CTRL_H
