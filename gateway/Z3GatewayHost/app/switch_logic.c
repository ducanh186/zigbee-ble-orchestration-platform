#include "switch_logic.h"
#include "app_mqtt.h"
#include "app_log.h"

bool switchLogicHandleCommand(const sb_command_t *cmd)
{
  if (!cmd) return false;

  appMqttPublishCommandReply(cmd->command_id, cmd->device_id,
                             "failed", "unsupported_for_switch");
  appLogLog("SWITCH", "reject",
            "\"command_id\":\"%s\",\"device_id\":\"%s\","
            "\"reason\":\"unsupported_for_switch\"",
            cmd->command_id, cmd->device_id);
  return false;
}
