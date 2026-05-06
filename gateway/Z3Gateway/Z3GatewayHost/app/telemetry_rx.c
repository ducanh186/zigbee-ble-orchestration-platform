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
#include <string.h>

// ===== Cached light level for enriching reported state =====
// Updated when we receive Level Control cluster reports.
static uint8_t s_lastLightLevel = 0;

// ===== Cached motion state for publishing change events only =====
#define MOTION_STATE_CACHE_MAX 16

typedef struct {
  bool active;
  char eui64[20];
  bool occupied;
} MotionStateCache_t;

static MotionStateCache_t s_motionStates[MOTION_STATE_CACHE_MAX];

static bool motionStateChanged(const char *eui64Str, bool occupied)
{
  if (!eui64Str || !eui64Str[0]) return false;

  int freeIdx = -1;
  for (int i = 0; i < MOTION_STATE_CACHE_MAX; i++) {
    if (!s_motionStates[i].active) {
      if (freeIdx < 0) freeIdx = i;
      continue;
    }

    if (strcmp(s_motionStates[i].eui64, eui64Str) == 0) {
      if (s_motionStates[i].occupied == occupied) return false;
      s_motionStates[i].occupied = occupied;
      return true;
    }
  }

  int idx = (freeIdx >= 0) ? freeIdx : 0;
  s_motionStates[idx].active = true;
  strncpy(s_motionStates[idx].eui64, eui64Str,
          sizeof(s_motionStates[idx].eui64) - 1);
  s_motionStates[idx].eui64[sizeof(s_motionStates[idx].eui64) - 1] = '\0';
  s_motionStates[idx].occupied = occupied;
  return true;
}

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

        // Publish state change over MQTT (Phase 3.1: include level)
        {
          char euiStr[20];
          if (deviceRegistryLearnReport(sender, 1, "light",
                                        euiStr, sizeof(euiStr))) {
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
          char euiStr[20];
          if (deviceRegistryLearnReport(sender, 1, "light",
                                        euiStr, sizeof(euiStr))) {
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

  // --- Occupancy Sensing Cluster (0x0406) ---
  if (clusterId == ZCL_OCCUPANCY_SENSING_CLUSTER_ID) {
    while (i + 3 <= bufLen) {
      uint16_t attrId = u16le(&buffer[i]);
      uint8_t type = buffer[i + 2];
      i += 3;

      // Attribute 0x0000 = Occupancy, type bitmap8 (0x18).
      if (attrId == ZCL_OCCUPANCY_ATTRIBUTE_ID
          && type == ZCL_BITMAP8_ATTRIBUTE_TYPE) {
        if (i + 1 > bufLen) break;
        uint8_t raw = buffer[i];
        i += 1;

        bool occupied = ((raw & 0x01u) != 0u);
        EmberNodeId sender = emberGetSender();
        const char *occupancy = occupied ? "occupied" : "unoccupied";

        char euiStr[20];
        if (deviceRegistryLearnReport(sender, 1, "motion",
                                      euiStr, sizeof(euiStr))) {
          emberAfCorePrintln(
            "@DATA {\"device\":\"motion\",\"node_id\":\"0x%04X\","
            "\"occupancy\":\"%s\",\"raw\":\"0x%02X\",\"source\":\"report\"}",
            (unsigned)sender, occupancy, (unsigned)raw);
          appLogLog("MOTION", "report_parsed",
                    "\"device_id\":\"%s\",\"node_id\":\"0x%04X\","
                    "\"occupancy\":\"%s\",\"raw\":\"0x%02X\"",
                    euiStr, (unsigned)sender, occupancy, (unsigned)raw);

          appMqttPublishMotionReported(sender, euiStr, occupancy, false, 0);
          if (motionStateChanged(euiStr, occupied)) {
            appMqttPublishMotionEvent(sender, euiStr, occupancy, raw);
          }
          ruleEngineOnMotionReport(euiStr, occupied);
        } else {
          emberAfCorePrintln("MQTT: skip motion report, EUI64 unknown for 0x%04X",
                             (unsigned)sender);
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

    // Distinguish switch from light: a switch sends On/Off commands TO us
    // (client-side), whereas a light sends attribute REPORTS (handled above).
    // Only process if sender is NOT the registered light device.
    EmberEUI64 eui;
    if (emberLookupEui64ByNodeId(sender, eui) == EMBER_SUCCESS) {
      char euiStr[20];
      eui64ToStringBigEndian(euiStr, sizeof(euiStr), eui);
      deviceRegistryUpsertLe(eui, sender, 1, "switch");

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
