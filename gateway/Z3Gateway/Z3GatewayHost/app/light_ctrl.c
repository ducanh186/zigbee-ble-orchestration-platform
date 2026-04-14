#include "light_ctrl.h"
#include "app_mqtt.h"
#include "app_log.h"
#include "app_utils.h"
#include "device_registry.h"
#include "valve_ctrl.h"

#include <string.h>
#include <stdio.h>

// --- Single in-flight tracker for v1 (valve_ctrl already serializes its own TX) ---
typedef struct {
  bool     active;
  char     command_id[64];
  char     device_id[64];
  char     correlation_id[64];
  uint32_t deadlineTick;   // msTick() deadline
  bool     wantOn;
} LightTrack_t;

static LightTrack_t s_track = {0};

// --- Forward declarations ---
static void onValveTxComplete(bool ok, uint8_t zstatus, void *user);
static void publishReply(const char *command_id, const char *device_id,
                         const char *status, const char *reason);

// -------------------------------------------------------------------
// Init
// -------------------------------------------------------------------
void lightCtrlInit(void)
{
  valveCtrlSetTxCompleteCb(onValveTxComplete, NULL);
}

// -------------------------------------------------------------------
// Tick: timeout enforcement
// -------------------------------------------------------------------
void lightCtrlTick(void)
{
  if (!s_track.active) return;

  uint32_t now = msTick();
  if ((int32_t)(now - s_track.deadlineTick) >= 0) {
    char cmdId[64];
    char devId[64];
    strncpy(cmdId, s_track.command_id, sizeof(cmdId) - 1);
    cmdId[sizeof(cmdId) - 1] = '\0';
    strncpy(devId, s_track.device_id, sizeof(devId) - 1);
    devId[sizeof(devId) - 1] = '\0';

    s_track.active = false;
    publishReply(cmdId, devId, "timeout", "no tx confirm within timeout_ms");
    appLogLog("LIGHT", "timeout",
              "\"command_id\":\"%s\",\"device_id\":\"%s\"", cmdId, devId);
  }
}

// -------------------------------------------------------------------
// Handle command
// -------------------------------------------------------------------
bool lightCtrlHandleCommand(const sb_command_t *cmd)
{
  if (!cmd) return false;

  // Already-accepted was emitted by the dispatcher. We emit queued/sent/...

  // Validate op: v1 supports on/off only
  bool wantOn = false;
  if (strcmp(cmd->command, "on") == 0) {
    wantOn = true;
  } else if (strcmp(cmd->command, "off") == 0) {
    wantOn = false;
  } else {
    publishReply(cmd->command_id, cmd->device_id, "failed", "unsupported_command");
    appLogLog("LIGHT", "reject", "\"reason\":\"unsupported_command\",\"cmd\":\"%s\"",
              cmd->command);
    return false;
  }

  // Resolve device
  device_resolved_t resolved;
  if (!deviceRegistryResolve(cmd->device_id, &resolved)) {
    publishReply(cmd->command_id, cmd->device_id, "failed", "unknown_device");
    appLogLog("LIGHT", "reject",
              "\"reason\":\"unknown_device\",\"device_id\":\"%s\"", cmd->device_id);
    return false;
  }

  // Only allow one light command in flight at a time (v1).
  if (s_track.active) {
    publishReply(cmd->command_id, cmd->device_id, "failed", "busy");
    appLogLog("LIGHT", "reject", "\"reason\":\"busy\",\"device_id\":\"%s\"",
              cmd->device_id);
    return false;
  }

  // Kick off the send. valveCtrlQueueTx already builds the ZCL On/Off cluster
  // (0x0006) frame, sets endpoints, and calls emberAfSendCommandUnicast.
  // Passing id=0 tells valve_ctrl NOT to emit the legacy numeric @ACK path.
  bool ok = valveCtrlQueueTx(0u, wantOn);
  if (!ok) {
    publishReply(cmd->command_id, cmd->device_id, "failed", "enqueue_failed");
    appLogLog("LIGHT", "enqueue_fail", "\"device_id\":\"%s\"", cmd->device_id);
    return false;
  }

  // Start tracking THIS command_id for the next tx-complete callback.
  memset(&s_track, 0, sizeof(s_track));
  s_track.active = true;
  s_track.wantOn = wantOn;
  strncpy(s_track.command_id, cmd->command_id, sizeof(s_track.command_id) - 1);
  strncpy(s_track.device_id, cmd->device_id, sizeof(s_track.device_id) - 1);
  strncpy(s_track.correlation_id,
          cmd->correlation_id[0] ? cmd->correlation_id : cmd->command_id,
          sizeof(s_track.correlation_id) - 1);
  s_track.deadlineTick = msTick() + cmd->timeout_ms;

  // In the current native path, `valveCtrlQueueTx` returning true means the
  // frame was handed to the stack for unicast. "queued" and "sent" are
  // effectively the same moment; we emit both to satisfy the contract and
  // keep the state machine observable.
  publishReply(cmd->command_id, cmd->device_id, "queued", NULL);
  publishReply(cmd->command_id, cmd->device_id, "sent",   NULL);

  appLogLog("LIGHT", "tx_started",
            "\"command_id\":\"%s\",\"device_id\":\"%s\",\"want\":\"%s\"",
            cmd->command_id, cmd->device_id, wantOn ? "on" : "off");

  return true;
}

// -------------------------------------------------------------------
// valve_ctrl -> us, on emberAfMessageSentCallback completion.
//
// IMPORTANT semantic note:
//   What we publish here as "executed" is TX-LEVEL success -- i.e. the APS
//   layer reported EMBER_SUCCESS for the unicast On/Off frame (APS ACK from
//   the device's radio stack, with retries already applied by the stack).
//   It is NOT an application-level confirmation that the bulb actually
//   toggled its On/Off attribute. For true end-state verification we would
//   have to follow up with a ZCL Read Attribute on 0x0006/0x0000 (OnOff)
//   or wait for the device's reported attribute update handled in
//   app/telemetry_rx.c (`emberAfReportAttributesCallback`). That
//   application-level confirmation path is NOT wired into the command
//   lifecycle in v1 -- it lives on the telemetry channel only.
// -------------------------------------------------------------------
static void onValveTxComplete(bool ok, uint8_t zstatus, void *user)
{
  (void)user;
  if (!s_track.active) return; // not our TX

  char cmdId[64];
  char devId[64];
  strncpy(cmdId, s_track.command_id, sizeof(cmdId) - 1);
  cmdId[sizeof(cmdId) - 1] = '\0';
  strncpy(devId, s_track.device_id, sizeof(devId) - 1);
  devId[sizeof(devId) - 1] = '\0';

  s_track.active = false;

  if (ok) {
    // "executed" here == APS tx confirm from emberAfMessageSentCallback.
    publishReply(cmdId, devId, "executed", NULL);
    appLogLog("LIGHT", "executed_tx",
              "\"command_id\":\"%s\",\"device_id\":\"%s\",\"zstatus\":\"0x%02X\","
              "\"note\":\"tx_level_only\"",
              cmdId, devId, (unsigned)zstatus);
  } else {
    char reason[48];
    snprintf(reason, sizeof(reason), "tx_failed:0x%02X", (unsigned)zstatus);
    publishReply(cmdId, devId, "failed", reason);
    appLogLog("LIGHT", "failed",
              "\"command_id\":\"%s\",\"device_id\":\"%s\",\"zstatus\":\"0x%02X\"",
              cmdId, devId, (unsigned)zstatus);
  }
}

// -------------------------------------------------------------------
// Reply publisher (thin wrapper so dispatcher + switch_logic can share it)
// -------------------------------------------------------------------
static void publishReply(const char *command_id, const char *device_id,
                         const char *status, const char *reason)
{
  appMqttPublishCommandReply(command_id, device_id, status, reason);
}
