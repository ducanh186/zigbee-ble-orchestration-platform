#ifndef SWITCH_LOGIC_H
#define SWITCH_LOGIC_H

// Switch device module (Phase 2 stub).
//
// Per the v1 capability matrix (docs/DEVICE_CAPABILITY_MATRIX.md), a `switch`
// device does NOT accept command_request from cloud. This module exists so
// the dispatcher can route `device_type=switch` to a type-aware rejecter
// rather than a generic "unknown device_type" error.
//
// When future phases need switch event parsing / binding management, they go
// here.

#include <stdbool.h>
#include "sb_command.h"

#ifdef __cplusplus
extern "C" {
#endif

// Always emits a `failed` command_reply with reason="unsupported_for_switch".
// Returns false (command not accepted).
bool switchLogicHandleCommand(const sb_command_t *cmd);

#ifdef __cplusplus
}
#endif

#endif // SWITCH_LOGIC_H
