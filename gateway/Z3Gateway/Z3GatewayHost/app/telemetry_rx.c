#include "app_config.h"
#include "app_state.h"
#include "app_utils.h"
#include "app_log.h"
#include "app_mqtt.h"
#include "device_registry.h"
#include "rule_engine.h"
#include "app/framework/include/af.h"
#include "app_zcl_fallback.h"

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>  // TEMP DEBUG - REMOVE AFTER BUGFIX: getenv

/* TEMP DEBUG - REMOVE AFTER BUGFIX */
static bool telDbg(void) {
  static int cached = -1;
  if (cached < 0) {
    const char *v = getenv("SB_DEBUG_VERBOSE");
    cached = (v && *v && *v != '0') ? 1 : 0;
  }
  return cached != 0;
}
/* Published by light_ctrl.c; 0 if never toggled locally. */
extern uint32_t gLightLastLocalToggleMs;
/* TEMP DEBUG end */

// ===== Cached light level for enriching reported state =====
// Updated when we receive Level Control cluster reports.
static uint8_t s_lastLightLevel = 0;

// ===== This is the correct callback for receiving attribute reports =====
// The ZCL framework calls this BEFORE emberAfPreCommandReceivedCallback.
// Return true to consume the report, false to let the framework handle it.
bool emberAfReportAttributesCallback(EmberAfClusterId clusterId,
                                     uint8_t *buffer,
                                     uint16_t bufLen)
{
  uint16_t i = 0;

  // DEBUG: log every report we receive
  emberAfCorePrintln("@DBG REPORT clusterId=0x%04X bufLen=%u sender=0x%04X",
                     clusterId, bufLen, (unsigned)emberGetSender());

  // --- On/Off Cluster (0x0006) ---
  if (clusterId == ZCL_ON_OFF_CLUSTER_ID) {
    while (i + 3 <= bufLen) {
      uint16_t attrId = u16le(&buffer[i]);
      uint8_t type = buffer[i + 2];
      i += 3;

      // Attribute 0x0000 = On/Off, type Boolean (0x10)
      if (attrId == 0x0000 && type == ZCL_BOOLEAN_ATTRIBUTE_TYPE) {
        if (i + 1 > bufLen) break;
        uint8_t onOff = buffer[i];
        i += 1;

        EmberNodeId sender = emberGetSender();
        emberAfCorePrintln(
          "@DATA {\"device\":\"light\",\"node_id\":\"0x%04X\","
          "\"state\":\"%s\",\"source\":\"report\"}",
          (unsigned)sender,
          onOff ? "on" : "off"
        );

        /* TEMP DEBUG - REMOVE AFTER BUGFIX
         * Snap-back visibility: time since last local toggle dispatch.
         * Expected healthy pattern after a local toggle:
         *   one report ~50-300 ms after toggle with flipped state.
         * Snap-back pattern:
         *   two reports within ~200 ms; second one flips back. */
        if (telDbg()) {
          uint32_t nowMs = msTick();
          uint32_t sinceToggle =
              gLightLastLocalToggleMs ? (nowMs - gLightLastLocalToggleMs) : 0u;
          emberAfCorePrintln("@DBG ONOFF_REPORT node=0x%04X state=%s "
                             "tick_ms=%u since_local_toggle_ms=%u",
                             (unsigned)sender, onOff ? "on" : "off",
                             (unsigned)nowMs, (unsigned)sinceToggle);
        }
        /* TEMP DEBUG end */

        // Publish state change over MQTT (Phase 3.1: include level)
        {
          EmberEUI64 eui;
          if (emberLookupEui64ByNodeId(sender, eui) == EMBER_SUCCESS) {
            char euiStr[20];
            eui64ToStringBigEndian(euiStr, sizeof(euiStr), eui);

            // v1 auto-register: if no device paired yet, register on
            // first attribute report (covers already-joined devices).
            if (!deviceRegistryIsKnown()) {
              deviceRegistryPair(euiStr, sender, 1);
              appLogLog("REG", "auto_paired",
                "\"eui64\":\"%s\",\"node_id\":\"0x%04X\","
                "\"trigger\":\"attr_report\"",
                euiStr, (unsigned)sender);
            }

            appMqttPublishDeviceReportedFull(sender, euiStr, "light",
                                             onOff ? "on" : "off",
                                             s_lastLightLevel);
          } else {
            emberAfCorePrintln("MQTT: skip report, EUI64 unknown for 0x%04X",
                               (unsigned)sender);
          }
        }
      } else {
        break;
      }
    }
    return false;  // let framework continue processing
  }

  // --- Level Control Cluster (0x0008) ---
  // Phase 3.1: track current level so reported state includes it.
  if (clusterId == ZCL_LEVEL_CONTROL_CLUSTER_ID) {
    while (i + 3 <= bufLen) {
      uint16_t attrId = u16le(&buffer[i]);
      uint8_t type = buffer[i + 2];
      i += 3;

      // Attribute 0x0000 = CurrentLevel, type uint8 (0x20)
      if (attrId == 0x0000 && type == ZCL_INT8U_ATTRIBUTE_TYPE) {
        if (i + 1 > bufLen) break;
        s_lastLightLevel = buffer[i];
        i += 1;

        EmberNodeId sender = emberGetSender();
        emberAfCorePrintln("@DATA {\"device\":\"light\",\"node_id\":\"0x%04X\","
                           "\"level\":%u,\"source\":\"report\"}",
                           (unsigned)sender, (unsigned)s_lastLightLevel);

        // Publish full reported state with updated level
        {
          EmberEUI64 eui;
          if (emberLookupEui64ByNodeId(sender, eui) == EMBER_SUCCESS) {
            char euiStr[20];
            eui64ToStringBigEndian(euiStr, sizeof(euiStr), eui);
            // Infer power from level: level>0 means on
            const char *power = (s_lastLightLevel > 0) ? "on" : "off";
            appMqttPublishDeviceReportedFull(sender, euiStr, "light",
                                             power, s_lastLightLevel);
          }
        }
      } else {
        break;
      }
    }
    return false;
  }

  // --- Power Configuration / Battery (0x0001) ---
  if (clusterId == ZCL_POWER_CONFIGURATION_CLUSTER_ID) {
    while (i + 3 <= bufLen) {
      uint16_t attrId = u16le(&buffer[i]);
      uint8_t type = buffer[i + 2];
      i += 3;

      if (attrId == 0x0021 && type == ZCL_INT8U_ATTRIBUTE_TYPE) {
        if (i + 1 > bufLen) break;
        uint8_t half = buffer[i];
        i += 1;
        uint8_t percent = (uint8_t)(half / 2u);
        if (g_batteryPercent != percent) {
          g_batteryPercent = percent;
          appLogData();
        }
      } else {
        break;
      }
    }
    return false;
  }

  return false;
}

// ===== Phase 3.2: Switch event detection =====
// A Zigbee switch (client-side On/Off) sends cluster-specific commands
// (On=0x01, Off=0x00, Toggle=0x02) to the coordinator.  These arrive as
// incoming ZCL commands (not attribute reports).  We detect them here and
// publish switch events to MQTT.
bool emberAfPreCommandReceivedCallback(EmberAfClusterCommand *cmd)
{
  if (cmd == NULL || cmd->apsFrame == NULL) return false;

  // DEBUG: log every incoming ZCL command
  emberAfCorePrintln("@DBG PRE_CMD cluster=0x%04X cmd=0x%02X src=0x%04X dir=%u",
                     cmd->apsFrame->clusterId, cmd->commandId,
                     cmd->source, cmd->direction);

  // Debug: ZCL Default Response from devices
  if (cmd->apsFrame->clusterId == ZCL_ON_OFF_CLUSTER_ID && cmd->commandId == 0x0B) {
    emberAfCorePrintln("@LOG {\"event\":\"zcl_default_rsp\",\"cluster\":\"0x0006\",\"src\":\"0x%04X\"}",
                       cmd->source);
  }

  // --- Phase 3.2: Switch toggle event detection ---
  // A switch device sends On/Off cluster commands (client-to-server).
  // direction=0 means client-to-server (switch sending to us).
  // We treat On(0x01), Off(0x00), Toggle(0x02) all as "toggle" events in v1.
  if (cmd->apsFrame->clusterId == ZCL_ON_OFF_CLUSTER_ID
      && cmd->direction == ZCL_DIRECTION_CLIENT_TO_SERVER
      && (cmd->commandId == ZCL_ON_COMMAND_ID
          || cmd->commandId == ZCL_OFF_COMMAND_ID
          || cmd->commandId == ZCL_TOGGLE_COMMAND_ID)) {

    EmberNodeId sender = cmd->source;

    /* TEMP DEBUG - REMOVE AFTER BUGFIX
     * Detect rapid duplicates from the same switch to test BUG 2 hypothesis
     * (switch RF-retransmits or double-emits when toggled fast). This only
     * observes; the 500 ms rule_engine cooldown is what actually filters. */
    if (telDbg()) {
      static EmberNodeId sLastSrc = 0xFFFF;
      static uint8_t     sLastCmd = 0xFF;
      static uint32_t    sLastMs  = 0;
      static uint8_t     sLastSeq = 0xFF;
      uint32_t nowMs = msTick();
      uint32_t elapsed = (sLastMs == 0) ? 0u : (nowMs - sLastMs);
      uint8_t  seq = cmd->seqNum;
      bool sameFrame = (sender == sLastSrc
                        && cmd->commandId == sLastCmd
                        && seq == sLastSeq);
      if (sLastMs != 0 && elapsed < 200u) {
        emberAfCorePrintln("@DBG SWITCH_FAST src=0x%04X cmd=0x%02X seq=%u "
                           "elapsed_ms=%u same_seq=%d",
                           (unsigned)sender, cmd->commandId, (unsigned)seq,
                           (unsigned)elapsed, sameFrame ? 1 : 0);
      }
      sLastSrc = sender;
      sLastCmd = cmd->commandId;
      sLastMs  = nowMs;
      sLastSeq = seq;
    }
    /* TEMP DEBUG end */

    // Distinguish switch from light: a switch sends On/Off commands TO us
    // (client-side), whereas a light sends attribute REPORTS (handled above).
    // Only process if sender is NOT the registered light device.
    EmberEUI64 eui;
    if (emberLookupEui64ByNodeId(sender, eui) == EMBER_SUCCESS) {
      char euiStr[20];
      eui64ToStringBigEndian(euiStr, sizeof(euiStr), eui);

      emberAfCorePrintln("SWITCH: toggle event from 0x%04X (%s) cmd=0x%02X",
                         (unsigned)sender, euiStr, cmd->commandId);
      appLogLog("SWITCH", "event",
                "\"device_id\":\"%s\",\"event\":\"toggle\",\"zcl_cmd\":\"0x%02X\"",
                euiStr, cmd->commandId);

      // Publish switch event to MQTT (Phase 3.2)
      appMqttPublishDeviceEvent(sender, euiStr, "switch", "toggle");

      // Phase 4: Feed into rule engine for local automation
      ruleEngineOnSwitchEvent(euiStr);
    } else {
      emberAfCorePrintln("SWITCH: toggle event from 0x%04X but EUI64 unknown",
                         (unsigned)sender);
    }
  }

  return false;
}
