#ifndef DEVICE_DISPATCH_H
#define DEVICE_DISPATCH_H

// Dispatch layer: routes a parsed sb_command_t to the correct device module.
//
// Routing rules (v1):
//   * device_type="light"  -> light_ctrl
//   * device_type="switch" -> switch_logic (always rejects - per capability matrix)
//   * absent device_type -> inferred from cluster_id (0x0006/0x0008 -> light)
//   * anything else -> fail with "failed:unsupported_device_type"
//
// Responsibilities:
//   * emit "accepted" reply BEFORE routing (once we know the op is parseable)
//   * emit "failed" reply if we cannot route at all
//   * leave further lifecycle (queued/sent/executed/...) to the device module

#include <stdbool.h>
#include "sb_command.h"

#ifdef __cplusplus
extern "C" {
#endif

// Route and handle. Returns true if the command was accepted into a device
// module (the actual outcome still comes as a command_reply later).
bool deviceDispatch(const sb_command_t *cmd);

#ifdef __cplusplus
}
#endif

#endif // DEVICE_DISPATCH_H
