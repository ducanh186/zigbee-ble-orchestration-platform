#include "device_dispatch.h"
#include "app_mqtt.h"
#include "app_log.h"
#include "device_registry.h"
#include "light_ctrl.h"
#include "switch_logic.h"

#include <string.h>
#include <strings.h>  // strcasecmp

static bool sameType(const char *a, const char *b)
{
  return (a && b && strcasecmp(a, b) == 0);
}

// Infer device_type from cluster_id string when the caller did not set it.
// Only conservative inferences - no guesses.
static const char* inferTypeFromCluster(const char *cluster_id)
{
  if (!cluster_id || !*cluster_id) return NULL;
  // On/Off (0x0006) and Level Control (0x0008) -> light
  if (strcasecmp(cluster_id, "0x0006") == 0
      || strcasecmp(cluster_id, "0x0008") == 0) {
    return "light";
  }
  return NULL;
}

bool deviceDispatch(const sb_command_t *cmd)
{
  if (!cmd) return false;

  // v1 only supports op="device.command" over the MQTT path
  if (strcmp(cmd->op, "device.command") != 0) {
    appMqttPublishCommandReply(cmd->command_id, cmd->device_id,
                               "failed", "unsupported_op");
    appLogLog("DISPATCH", "reject",
              "\"command_id\":\"%s\",\"reason\":\"unsupported_op\",\"op\":\"%s\"",
              cmd->command_id, cmd->op);
    return false;
  }

  // Resolve device_type, in priority order:
  //   1. exact registry lookup by EUI64     -- authoritative
  //   2. payload.device_type                -- optional hint from cloud
  //   3. cluster_id inference (0x0006/0008) -- last-resort heuristic
  // Non-exact registry fallback is intentionally not used for type selection:
  // it exists only so legacy logical ids like "light-01" can still resolve to
  // the first known light after the command has been routed.
  // This lets a minimal request { device_id, op, target, timeout_ms } succeed.
  char typeBuf[32] = {0};
  const char *type = NULL;

  device_resolved_t resolved;
  bool haveResolved = deviceRegistryResolve(cmd->device_id, &resolved);
  if (haveResolved && resolved.exact_match
      && resolved.device_type[0]
      && !sameType(resolved.device_type, "unknown")) {
    strncpy(typeBuf, resolved.device_type, sizeof(typeBuf) - 1);
    type = typeBuf;
  } else if (cmd->device_type[0]) {
    type = cmd->device_type;
  } else {
    type = inferTypeFromCluster(cmd->cluster_id);
  }

  // Emit 'accepted' now that we know the payload is well-formed enough to route.
  appMqttPublishCommandReply(cmd->command_id, cmd->device_id, "accepted", NULL);
  appLogLog("DISPATCH", "accepted",
            "\"command_id\":\"%s\",\"device_id\":\"%s\",\"type\":\"%s\","
            "\"cluster\":\"%s\",\"cmd\":\"%s\"",
            cmd->command_id, cmd->device_id,
            type ? type : "", cmd->cluster_id, cmd->command);

  if (sameType(type, "light")) {
    return lightCtrlHandleCommand(cmd);
  }
  if (sameType(type, "switch")) {
    return switchLogicHandleCommand(cmd);
  }

  // Unknown / unsupported device_type
  appMqttPublishCommandReply(cmd->command_id, cmd->device_id,
                             "failed", "unsupported_device_type");
  appLogLog("DISPATCH", "reject",
            "\"command_id\":\"%s\",\"reason\":\"unsupported_device_type\","
            "\"type\":\"%s\"",
            cmd->command_id, type ? type : "(none)");
  return false;
}
