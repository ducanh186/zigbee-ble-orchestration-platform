#include "light_ctrl.h"
#include "app_mqtt.h"
#include "app_log.h"
#include "app_utils.h"
#include "app_config.h"
#include "device_registry.h"

#include <string.h>
#include <stdio.h>

// --- Single in-flight tracker for v1 ---
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
static void publishReply(const char *command_id, const char *device_id,
                         const char *status, const char *reason);

// -------------------------------------------------------------------
// ZCL On/Off send (extracted from former valve_ctrl)
// -------------------------------------------------------------------
static EmberStatus lightSendOnOff(bool wantOn, uint8_t dstEp,
                                  EmberNodeId nodeId)
{
  uint8_t cmdId = wantOn ? ZCL_ON_COMMAND_ID : ZCL_OFF_COMMAND_ID;

  emberAfFillExternalBuffer(
    (uint8_t)(ZCL_CLUSTER_SPECIFIC_COMMAND | ZCL_FRAME_CONTROL_CLIENT_TO_SERVER),
    ZCL_ON_OFF_CLUSTER_ID,
    cmdId,
    "");

  emberAfSetCommandEndpoints(COORD_EP_CONTROL, dstEp);

  EmberApsFrame *aps = emberAfGetCommandApsFrame();
  if (aps) {
#ifdef EMBER_APS_OPTION_ACK_REQUEST
    aps->options |= EMBER_APS_OPTION_ACK_REQUEST;
#endif
#ifdef EMBER_APS_OPTION_RETRY
    aps->options |= EMBER_APS_OPTION_RETRY;
#endif
  }

  return emberAfSendCommandUnicast(EMBER_OUTGOING_DIRECT, nodeId);
}

// -------------------------------------------------------------------
// Init (no-op now; hook registration was valve-specific)
// -------------------------------------------------------------------
void lightCtrlInit(void)
{
  // Nothing to register — emberAfMessageSentCallback lives in this
  // file and the framework calls it directly.
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

  // Check network
  if (emberAfNetworkState() != EMBER_JOINED_NETWORK) {
    publishReply(cmd->command_id, cmd->device_id, "failed", "not_joined");
    appLogLog("LIGHT", "reject", "\"reason\":\"not_joined\"");
    return false;
  }

  // Send ZCL On/Off
  EmberStatus st = lightSendOnOff(wantOn, resolved.endpoint, resolved.nodeId);
  if (st != EMBER_SUCCESS) {
    char reason[48];
    snprintf(reason, sizeof(reason), "send_fail:0x%02X", (unsigned)st);
    publishReply(cmd->command_id, cmd->device_id, "failed", reason);
    appLogLog("LIGHT", "send_fail", "\"device_id\":\"%s\",\"zstatus\":\"0x%02X\"",
              cmd->device_id, (unsigned)st);
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

  // In the native path, the frame was handed to the stack for unicast.
  // "queued" and "sent" are effectively the same moment; we emit both
  // to satisfy the contract and keep the state machine observable.
  publishReply(cmd->command_id, cmd->device_id, "queued", NULL);
  publishReply(cmd->command_id, cmd->device_id, "sent",   NULL);

  appLogLog("LIGHT", "tx_started",
            "\"command_id\":\"%s\",\"device_id\":\"%s\",\"want\":\"%s\"",
            cmd->command_id, cmd->device_id, wantOn ? "on" : "off");

  return true;
}

// -------------------------------------------------------------------
// emberAfMessageSentCallback — TX completion from the Ember stack.
//
// IMPORTANT semantic note:
//   What we publish here as "executed" is TX-LEVEL success — i.e. the
//   APS layer reported EMBER_SUCCESS for the unicast On/Off frame (APS
//   ACK from the device's radio stack, with retries already applied).
//   It is NOT an application-level confirmation that the bulb actually
//   toggled its On/Off attribute. For true end-state verification we
//   would need a ZCL Read Attribute on 0x0006/0x0000. That path is NOT
//   wired into the command lifecycle in v1 — it lives on the telemetry
//   channel only (telemetry_rx.c, reported state).
// -------------------------------------------------------------------
bool emberAfMessageSentCallback(EmberOutgoingMessageType type,
                               uint16_t indexOrDestination,
                               EmberApsFrame *apsFrame,
                               uint16_t messageLength,
                               uint8_t *messageContents,
                               EmberStatus status)
{
  (void)type;
  (void)indexOrDestination;
  (void)messageLength;
  (void)messageContents;

  if (!apsFrame) return false;

  if (apsFrame->clusterId == ZCL_ON_OFF_CLUSTER_ID
      && apsFrame->sourceEndpoint == COORD_EP_CONTROL) {
    if (!s_track.active) return false;

    bool txOk = (status == EMBER_SUCCESS);

    char cmdId[64];
    char devId[64];
    strncpy(cmdId, s_track.command_id, sizeof(cmdId) - 1);
    cmdId[sizeof(cmdId) - 1] = '\0';
    strncpy(devId, s_track.device_id, sizeof(devId) - 1);
    devId[sizeof(devId) - 1] = '\0';

    s_track.active = false;

    if (txOk) {
      publishReply(cmdId, devId, "executed", NULL);
      appLogLog("LIGHT", "executed_tx",
                "\"command_id\":\"%s\",\"device_id\":\"%s\",\"zstatus\":\"0x%02X\","
                "\"note\":\"tx_level_only\"",
                cmdId, devId, (unsigned)status);
    } else {
      char reason[48];
      snprintf(reason, sizeof(reason), "tx_failed:0x%02X", (unsigned)status);
      publishReply(cmdId, devId, "failed", reason);
      appLogLog("LIGHT", "failed",
                "\"command_id\":\"%s\",\"device_id\":\"%s\",\"zstatus\":\"0x%02X\"",
                cmdId, devId, (unsigned)status);
    }
  }

  return false;
}

// -------------------------------------------------------------------
// Phase 4.2: Local toggle for gateway-driven automation
// -------------------------------------------------------------------
// This is the LOCAL AUTOMATION path.  It sends a ZCL Toggle command
// to the registered light WITHOUT creating a command_id, WITHOUT
// tracking the TX result, and WITHOUT publishing command_reply.
//
// The light's resulting state change will arrive as an attribute report
// -> telemetry_rx.c -> MQTT reported -> cloud sees new state.
//
// Anti-loop guarantee: this function does NOT call ruleEngineOnSwitchEvent
// or any rule dispatch. It is a leaf action.
// -------------------------------------------------------------------

static EmberStatus lightSendToggle(uint8_t dstEp, EmberNodeId nodeId)
{
  emberAfFillExternalBuffer(
    (uint8_t)(ZCL_CLUSTER_SPECIFIC_COMMAND | ZCL_FRAME_CONTROL_CLIENT_TO_SERVER),
    ZCL_ON_OFF_CLUSTER_ID,
    ZCL_TOGGLE_COMMAND_ID,
    "");

  emberAfSetCommandEndpoints(COORD_EP_CONTROL, dstEp);

  EmberApsFrame *aps = emberAfGetCommandApsFrame();
  if (aps) {
#ifdef EMBER_APS_OPTION_ACK_REQUEST
    aps->options |= EMBER_APS_OPTION_ACK_REQUEST;
#endif
#ifdef EMBER_APS_OPTION_RETRY
    aps->options |= EMBER_APS_OPTION_RETRY;
#endif
  }

  return emberAfSendCommandUnicast(EMBER_OUTGOING_DIRECT, nodeId);
}

void lightCtrlLocalToggle(void)
{
  // Resolve the registered (paired) device
  device_resolved_t resolved;
  if (!deviceRegistryResolveByType("*", "light", &resolved)) {
    appLogLog("LIGHT", "local_toggle_skip", "\"reason\":\"no_light_found\"");
    return;
  }

  // Don't interfere with an active cloud command
  if (s_track.active) {
    appLogLog("LIGHT", "local_toggle_skip", "\"reason\":\"command_in_flight\"");
    return;
  }

  // Check network
  if (emberAfNetworkState() != EMBER_JOINED_NETWORK) {
    appLogLog("LIGHT", "local_toggle_skip", "\"reason\":\"not_joined\"");
    return;
  }

  EmberStatus st = lightSendToggle(resolved.endpoint, resolved.nodeId);
  if (st != EMBER_SUCCESS) {
    appLogLog("LIGHT", "local_toggle_fail",
              "\"zstatus\":\"0x%02X\"", (unsigned)st);
  } else {
    appLogLog("LIGHT", "local_toggle_sent",
              "\"node_id\":\"0x%04X\",\"ep\":%u",
              (unsigned)resolved.nodeId, (unsigned)resolved.endpoint);
  }
}

static bool lightCtrlLocalSetPower(const char *device_id, bool wantOn)
{
  const char *target = (device_id && device_id[0]) ? device_id : "*";

  device_resolved_t resolved;
  if (!deviceRegistryResolveByType(target, "light", &resolved)) {
    appLogLog("LIGHT", "local_set_skip",
              "\"target\":\"%s\",\"action\":\"%s\",\"reason\":\"no_light_found\"",
              target, wantOn ? "on" : "off");
    return false;
  }

  // Don't interfere with an active cloud command.
  if (s_track.active) {
    appLogLog("LIGHT", "local_set_skip",
              "\"target\":\"%s\",\"action\":\"%s\",\"reason\":\"command_in_flight\"",
              target, wantOn ? "on" : "off");
    return false;
  }

  if (emberAfNetworkState() != EMBER_JOINED_NETWORK) {
    appLogLog("LIGHT", "local_set_skip",
              "\"target\":\"%s\",\"action\":\"%s\",\"reason\":\"not_joined\"",
              target, wantOn ? "on" : "off");
    return false;
  }

  EmberStatus st = lightSendOnOff(wantOn, resolved.endpoint, resolved.nodeId);
  if (st != EMBER_SUCCESS) {
    appLogLog("LIGHT", "local_set_fail",
              "\"target\":\"%s\",\"action\":\"%s\",\"node_id\":\"0x%04X\","
              "\"ep\":%u,\"zstatus\":\"0x%02X\"",
              target, wantOn ? "on" : "off", (unsigned)resolved.nodeId,
              (unsigned)resolved.endpoint, (unsigned)st);
    return false;
  }

  appLogLog("LIGHT", "local_set_sent",
            "\"target\":\"%s\",\"device_id\":\"%s\",\"action\":\"%s\","
            "\"node_id\":\"0x%04X\",\"ep\":%u",
            target, resolved.eui64, wantOn ? "on" : "off",
            (unsigned)resolved.nodeId, (unsigned)resolved.endpoint);
  return true;
}

bool lightCtrlSetOn(const char *device_id)
{
  return lightCtrlLocalSetPower(device_id, true);
}

bool lightCtrlSetOff(const char *device_id)
{
  return lightCtrlLocalSetPower(device_id, false);
}

// -------------------------------------------------------------------
// Reply publisher (thin wrapper)
// -------------------------------------------------------------------
static void publishReply(const char *command_id, const char *device_id,
                         const char *status, const char *reason)
{
  appMqttPublishCommandReply(command_id, device_id, status, reason);
}
