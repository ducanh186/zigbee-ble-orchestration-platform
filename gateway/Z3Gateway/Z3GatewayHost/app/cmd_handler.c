#include "cmd_handler.h"
#include "app_config.h"
#include "app_state.h"
#include "app_utils.h"
#include "app_log.h"
#include "net_mgr.h"
#include "app_mqtt.h"
#include "sb_command.h"
#include "device_dispatch.h"
#include "device_registry.h"
#include "device_discovery.h"

#include <string.h>
#include <stdio.h>

// ===== COMMAND DEBOUNCE =====
#define CMD_DEBOUNCE_MS       500
#define CMD_DEDUP_WINDOW_MS   2000

static uint32_t s_lastCmdId = 0xFFFFFFFF;
static uint32_t s_lastCmdTick = 0;

static bool isDuplicateCmd(uint32_t id)
{
  uint32_t now = msTick();

  if (id == s_lastCmdId && (now - s_lastCmdTick) < CMD_DEDUP_WINDOW_MS) {
    appLogLog("CMD", "duplicate", "\"id\":%lu,\"ignored\":true", (unsigned long)id);
    return true;
  }

  s_lastCmdId = id;
  s_lastCmdTick = now;
  return false;
}

void cmdHandleLine(const char *line)
{
  if (!line) return;

  const char *p = line;
  if (strncmp(p, "@CMD", 4) != 0) return;
  p += 4;
  p = skipSpaces(p);

  uint32_t id = 0;
  (void)parseUintField(p, "\"id\"", &id);

  if (isDuplicateCmd(id)) {
    return;
  }

  char op[28] = {0};
  if (!parseStringField(p, "\"op\"", op, sizeof(op))) {
    appLogAck(id, false, "missing op");
    return;
  }

  if (strcmp(op, "info") == 0) {
    appLogInfo();
    appLogAck(id, true, "info");
    return;
  }

  // --- Device pairing (register target light for MQTT commands) ---
  if (strcmp(op, "device_pair") == 0) {
    char euiStr[40] = {0};
    uint32_t nodeId = 0;
    uint32_t dstEp = 1;

    if (!parseStringField(p, "\"eui64\"", euiStr, sizeof(euiStr))) {
      appLogAck(id, false, "missing eui64");
      return;
    }
    if (!parseU32FieldAny(p, "\"node_id\"", &nodeId)) {
      appLogAck(id, false, "missing node_id");
      return;
    }
    (void)parseUintField(p, "\"dst_ep\"", &dstEp);

    // Manual pair from CLI: store as "unknown" and let ZDO discovery
    // classify properly.  No type guess here.
    bool ok = deviceRegistryUpsert(euiStr, (EmberNodeId)nodeId,
                                   (uint8_t)dstEp, "unknown");
    if (ok) {
      // Convert ASCII eui to little-endian for discovery API.
      EmberEUI64 euiLe;
      if (parseHexEui64(euiStr, euiLe)) {
        deviceDiscoveryStart((EmberNodeId)nodeId, euiLe);
      }
    }
    appLogAck(id, ok, ok ? "device_pair set" : "bad eui64");
    if (ok) appLogInfo();
    return;
  }

  // --- Network management ---
  if (strcmp(op, "net_cfg_set") == 0) {
    uint32_t pan = g_netCfg.panId, ch = g_netCfg.ch, pwr = (uint32_t)g_netCfg.txPowerDbm;
    (void)parseU32FieldAny(p, "\"pan_id\"", &pan);
    (void)parseU32FieldAny(p, "\"ch\"", &ch);
    (void)parseU32FieldAny(p, "\"tx_power\"", &pwr);

    if (ch < 11 || ch > 26) { appLogAck(id, false, "bad channel"); return; }

    g_netCfg.panId = (uint16_t)pan;
    g_netCfg.ch = (uint8_t)ch;
    g_netCfg.txPowerDbm = (int8_t)pwr;

    appLogAck(id, true, "net cfg updated");
    return;
  }

  if (strcmp(op, "net_form") == 0) {
    uint32_t pan = g_netCfg.panId, ch = g_netCfg.ch, pwr = (uint32_t)g_netCfg.txPowerDbm, force = 0;
    (void)parseU32FieldAny(p, "\"pan_id\"", &pan);
    (void)parseU32FieldAny(p, "\"ch\"", &ch);
    (void)parseU32FieldAny(p, "\"tx_power\"", &pwr);
    (void)parseUintField(p, "\"force\"", &force);

    if (ch < 11 || ch > 26) { appLogAck(id, false, "bad channel"); return; }

    NetCfg_t cfg = { (uint16_t)pan, (uint8_t)ch, (int8_t)pwr };
    bool ok = netMgrRequestForm(cfg, "cli", (force != 0));
    appLogAck(id, ok, ok ? "net_form accepted" : "net_form rejected");
    return;
  }

  appLogAck(id, false, "unknown op");
}

// ===== sb/v1 MQTT entry: parser -> dispatcher =====
// This is the production path. It is intentionally thin: all device-specific
// logic lives in the dispatcher and the per-device modules.
void cmdHandleMqttPayload(const char *topic, const char *body)
{
  if (!topic || !body) return;

  sb_command_t cmd;
  if (!sbCommandParse(topic, body, &cmd)) {
    // If we at least have a command_id, try to tell the cloud.
    // device_id is unknown here (parse failed) -> pass NULL -> emitted as null.
    char fallbackId[64] = {0};
    if (sbCommandExtractIdFromTopic(topic, fallbackId, sizeof(fallbackId))) {
      appMqttPublishCommandReply(fallbackId, NULL, "failed", "bad_payload");
    }
    appLogLog("CMD", "parse_fail", "\"topic\":\"%s\"", topic);
    return;
  }

  appLogLog("CMD", "parsed",
    "\"command_id\":\"%s\",\"device_id\":\"%s\",\"op\":\"%s\",\"cmd\":\"%s\"",
    cmd.command_id, cmd.device_id, cmd.op, cmd.command);

  (void)deviceDispatch(&cmd);
}
