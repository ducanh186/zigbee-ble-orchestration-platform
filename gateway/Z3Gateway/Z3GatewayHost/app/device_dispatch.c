#include "device_dispatch.h"
#include "app_mqtt.h"
#include "app_log.h"
#include "device_registry.h"
#include "light_ctrl.h"
#include "switch_logic.h"
#include "net_mgr.h"

#include <stdio.h>
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

// Handle gateway-scoped commands (no device target).
// Lifecycle: accepted -> queued -> sent -> executed | failed.
// "queued" and "sent" coalesce here -- the open/close are synchronous SDK
// calls, there is no separate queueing step.
static bool dispatchGatewayOp(const sb_command_t *cmd)
{
  // device_id is NULL/empty for gateway ops -- pass NULL to the reply helper
  // so it emits JSON null rather than an empty string.
  const char *devId = (cmd->device_id[0] != '\0') ? cmd->device_id : NULL;

  appMqttPublishCommandReply(cmd->command_id, devId, "accepted", NULL);
  appLogLog("DISPATCH", "accepted_gw",
            "\"command_id\":\"%s\",\"op\":\"%s\"",
            cmd->command_id, cmd->op);

  appMqttPublishCommandReply(cmd->command_id, devId, "queued", NULL);
  appMqttPublishCommandReply(cmd->command_id, devId, "sent", NULL);

  EmberStatus st;
  if (strcmp(cmd->op, "gateway.open_network") == 0) {
    int dur = (cmd->duration_sec > 0) ? cmd->duration_sec : 180;
    st = netMgrOpenForJoin((uint16_t)dur);
  } else if (strcmp(cmd->op, "gateway.close_network") == 0) {
    st = netMgrCloseJoin();
  } else {
    appMqttPublishCommandReply(cmd->command_id, devId,
                               "failed", "unsupported_op");
    appLogLog("DISPATCH", "reject",
              "\"command_id\":\"%s\",\"reason\":\"unsupported_op\",\"op\":\"%s\"",
              cmd->command_id, cmd->op);
    return false;
  }

  if (st == EMBER_SUCCESS) {
    appMqttPublishCommandReply(cmd->command_id, devId, "executed", NULL);
    return true;
  }

  // Map common failures to short, machine-friendly reasons.
  const char *reason;
  char reasonBuf[40];
  if (st == EMBER_NOT_JOINED) {
    reason = "not_formed";
  } else {
    snprintf(reasonBuf, sizeof(reasonBuf), "zstatus:0x%02X", (unsigned)st);
    reason = reasonBuf;
  }
  appMqttPublishCommandReply(cmd->command_id, devId, "failed", reason);
  appLogLog("DISPATCH", "gw_failed",
            "\"command_id\":\"%s\",\"op\":\"%s\",\"zstatus\":\"0x%02X\"",
            cmd->command_id, cmd->op, (unsigned)st);
  return false;
}

bool deviceDispatch(const sb_command_t *cmd)
{
  if (!cmd) return false;

  // Gateway-scoped op? No device involved.
  if (sbCommandIsGatewayOp(cmd->op)) {
    return dispatchGatewayOp(cmd);
  }

  // v1 only supports op="device.command" over the MQTT device path
  if (strcmp(cmd->op, "device.command") != 0) {
    appMqttPublishCommandReply(cmd->command_id, cmd->device_id,
                               "failed", "unsupported_op");
    appLogLog("DISPATCH", "reject",
              "\"command_id\":\"%s\",\"reason\":\"unsupported_op\",\"op\":\"%s\"",
              cmd->command_id, cmd->op);
    return false;
  }

  // Resolve device_type, in priority order (per MQTT_CONTRACT: payload hint only):
  //   1. registry lookup by device_id       -- authoritative
  //   2. payload.device_type                -- optional hint from cloud
  //   3. cluster_id inference (0x0006/0008) -- last-resort heuristic
  // This lets a minimal request { device_id, op, target, timeout_ms } succeed.
  char typeBuf[32] = {0};
  const char *type = NULL;

  device_resolved_t resolved;
  bool haveResolved = deviceRegistryResolve(cmd->device_id, &resolved);
  if (haveResolved && resolved.device_type[0]) {
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
