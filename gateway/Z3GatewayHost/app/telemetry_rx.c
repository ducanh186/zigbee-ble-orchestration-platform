#include "app_config.h"
#include "app_state.h"
#include "app_utils.h"
#include "app_log.h"
#include "app_mqtt.h"
#include "device_registry.h"
#include "device_discovery.h"
#include "rule_engine.h"
#include "automation_rule.h"
#include "app/framework/include/af.h"
#include "app_zcl_fallback.h"

#include <stdint.h>
#include <stdbool.h>
#include <limits.h>

// ===== Cached light level for enriching reported state =====
// Updated when we receive Level Control cluster reports.
static uint8_t s_lastLightLevel = 0;

// ===== Per-node environment cache =====
// Temperature (0x0402) and humidity (0x0405) arrive in separate reports; we
// cache the latest of each per sender so the published reported state can
// carry both fields. INT32_MIN = not yet observed (-> JSON null).
#define ENV_CACHE_MAX 4
static struct {
  EmberNodeId nodeId;
  bool        valid;
  int32_t     tempCenti;
  int32_t     humCenti;
} s_envCache[ENV_CACHE_MAX];

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
          EmberEUI64 eui;
          if (emberLookupEui64ByNodeId(sender, eui) == EMBER_SUCCESS) {
            char euiStr[20];
            eui64ToStringBigEndian(euiStr, sizeof(euiStr), eui);

            // Telemetry-driven fallback registration: if THIS EUI is not
            // yet in the registry, only auto-register if:
            //   1. ZDO discovery is NOT in progress (let discovery classify)
            //   2. This nodeId is not already registered under a different
            //      EUI64 (avoids duplicate entries for the same device)
            device_resolved_t resolved;
            if (!deviceRegistryResolve(euiStr, &resolved)) {
              if (deviceDiscoveryInProgress(sender)) {
                appLogLog("REG", "auto_skip_discovery",
                  "\"eui64\":\"%s\",\"node_id\":\"0x%04X\","
                  "\"reason\":\"zdo_discovery_active\"",
                  euiStr, (unsigned)sender);
              } else if (deviceRegistryResolveByNodeId(sender, &resolved)) {
                appLogLog("REG", "auto_skip_dup_node",
                  "\"eui64\":\"%s\",\"node_id\":\"0x%04X\","
                  "\"reason\":\"node_already_registered\","
                  "\"existing_type\":\"%s\"",
                  euiStr, (unsigned)sender, resolved.device_type);
              } else {
                deviceRegistryUpsert(euiStr, sender, 1, "light");
                appMqttClearRetainedRegistry(euiStr, "light");
                appMqttPublishDeviceRegistry(sender, euiStr, "light", 0);
                appLogLog("REG", "auto_paired",
                  "\"eui64\":\"%s\",\"node_id\":\"0x%04X\","
                  "\"trigger\":\"attr_report\",\"type\":\"light\"",
                  euiStr, (unsigned)sender);
              }
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

  // --- Occupancy Sensing Cluster (0x0406) — Phase 3 ---
  // PIR motion sensors report attribute 0x0000 (Occupancy) as a bitmap8,
  // where bit 0 = occupied. We emit a contract-compliant
  // `occupancy_changed` event when the value transitions, then feed the
  // change into the cloud-pushed automation rule table.
  //
  // Per-device de-dup is kept simple: a small static `last_occupancy_by_node`
  // array tracks the last value we saw per sender nodeId so unchanged
  // re-reports don't spam events. This is not a full state machine — just
  // enough to avoid duplicate trigger firings on every periodic report.
  if (clusterId == ZCL_OCCUPANCY_SENSING_CLUSTER_ID) {
    #define MOTION_DEDUP_MAX 4
    static struct {
      EmberNodeId nodeId;
      bool        valid;
      bool        occupied;
    } s_motionDedup[MOTION_DEDUP_MAX];

    while (i + 3 <= bufLen) {
      uint16_t attrId = u16le(&buffer[i]);
      uint8_t type = buffer[i + 2];
      i += 3;

      // Attribute 0x0000 = Occupancy, bitmap8 (0x18).
      if (attrId == 0x0000 && type == ZCL_BITMAP8_ATTRIBUTE_TYPE) {
        if (i + 1 > bufLen) break;
        uint8_t bits = buffer[i];
        i += 1;
        bool occupied = (bits & 0x01) != 0;

        EmberNodeId sender = emberGetSender();

        // Dedup against last value for this node.
        int slot = -1;
        int firstFree = -1;
        for (int s = 0; s < MOTION_DEDUP_MAX; s++) {
          if (s_motionDedup[s].valid && s_motionDedup[s].nodeId == sender) {
            slot = s; break;
          }
          if (firstFree < 0 && !s_motionDedup[s].valid) firstFree = s;
        }
        bool changed = true;
        if (slot >= 0) {
          changed = (s_motionDedup[slot].occupied != occupied);
        } else if (firstFree >= 0) {
          slot = firstFree;
        } else {
          // table full; treat as changed (best-effort, no eviction)
          slot = 0;
        }
        s_motionDedup[slot].nodeId   = sender;
        s_motionDedup[slot].valid    = true;
        s_motionDedup[slot].occupied = occupied;

        if (!changed) break;

        char euiStr[20];
        bool haveEui = false;
        EmberEUI64 eui;
        if (emberLookupEui64ByNodeId(sender, eui) == EMBER_SUCCESS) {
          eui64ToStringBigEndian(euiStr, sizeof(euiStr), eui);
          haveEui = true;
        } else if (deviceRegistryGetEuiBeStrByNodeId(sender, euiStr,
                                                    sizeof(euiStr))) {
          // NCP address table did not have an entry for `sender`, but the
          // device_registry remembers EUI64↔nodeId from ZDO discovery. Use
          // that so motion reports are still routed to the rule engine.
          appLogLog("MOTION", "eui_via_registry",
                    "\"node_id\":\"0x%04X\",\"eui64\":\"%s\"",
                    (unsigned)sender, euiStr);
          haveEui = true;
        }
        if (haveEui) {
          const char *occStr = occupied ? "occupied" : "unoccupied";
          emberAfCorePrintln("MOTION: %s from 0x%04X (%s)",
                             occStr, (unsigned)sender, euiStr);
          appLogLog("MOTION", "event",
                    "\"device_id\":\"%s\",\"occupancy\":\"%s\"",
                    euiStr, occStr);

          appMqttPublishMotionOccupancyEvent(sender, euiStr, occStr);

          // Retained reported state so the dashboard reflects current
          // occupancy via DeviceState (event-only would never populate it).
          appMqttPublishMotionReported(sender, euiStr, occStr);

          // Phase 3 automation hook.
          automationRuleOnMotionOccupancyChanged(euiStr, occStr);
        }
      } else {
        break;
      }
    }
    return false;
  }

  // --- Temperature Measurement (0x0402) / Relative Humidity (0x0405) ---
  // DHT11 environment sensor reports MeasuredValue 0x0000 in centi-units
  // (0x0402 int16s 0.01C, 0x0405 uint16 0.01%RH). We log it and feed it into
  // the automation engine (environment threshold rules). No telemetry MQTT
  // publish yet — that is Cloud/App work (see docs/handoffs/).
  if (clusterId == ZCL_TEMP_MEASUREMENT_CLUSTER_ID
      || clusterId == ZCL_RELATIVE_HUMIDITY_MEASUREMENT_CLUSTER_ID) {
    bool isTemp = (clusterId == ZCL_TEMP_MEASUREMENT_CLUSTER_ID);
    uint8_t wantType = isTemp ? ZCL_INT16S_ATTRIBUTE_TYPE
                              : ZCL_INT16U_ATTRIBUTE_TYPE;

    while (i + 3 <= bufLen) {
      uint16_t attrId = u16le(&buffer[i]);
      uint8_t type = buffer[i + 2];
      i += 3;

      if (attrId == 0x0000 && type == wantType) {
        if (i + 2 > bufLen) break;
        int32_t centi = isTemp ? (int32_t)(int16_t)u16le(&buffer[i])
                               : (int32_t)u16le(&buffer[i]);
        i += 2;

        EmberNodeId sender = emberGetSender();
        char euiStr[20] = "unknown";
        EmberEUI64 eui;
        if (emberLookupEui64ByNodeId(sender, eui) == EMBER_SUCCESS) {
          eui64ToStringBigEndian(euiStr, sizeof(euiStr), eui);
        } else {
          (void)deviceRegistryGetEuiBeStrByNodeId(sender, euiStr,
                                                  sizeof(euiStr));
        }

        int32_t whole = centi / 100;
        int32_t frac = centi % 100;
        if (frac < 0) frac = -frac;
        if (isTemp) {
          emberAfCorePrintln("ENV: temp=%d.%02dC from 0x%04X (%s)",
                             (int)whole, (int)frac, (unsigned)sender, euiStr);
          appLogLog("ENV", "report",
                    "\"device_id\":\"%s\",\"node_id\":\"0x%04X\","
                    "\"temperature_c_x100\":%d",
                    euiStr, (unsigned)sender, (int)centi);
        } else {
          emberAfCorePrintln("ENV: humidity=%d.%02d%% from 0x%04X (%s)",
                             (int)whole, (int)frac, (unsigned)sender, euiStr);
          appLogLog("ENV", "report",
                    "\"device_id\":\"%s\",\"node_id\":\"0x%04X\","
                    "\"humidity_pct_x100\":%d",
                    euiStr, (unsigned)sender, (int)centi);
        }

        // Feed into the automation engine (environment threshold rules).
        automationRuleOnEnvironmentReport(euiStr,
                                          isTemp ? "temperature" : "humidity",
                                          centi);

        // Cache the latest temp+humidity per node and publish a combined
        // retained reported state so the dashboard can show live values.
        {
          int slot = -1, freeSlot = -1;
          for (int s = 0; s < ENV_CACHE_MAX; s++) {
            if (s_envCache[s].valid && s_envCache[s].nodeId == sender) { slot = s; break; }
            if (freeSlot < 0 && !s_envCache[s].valid) freeSlot = s;
          }
          if (slot < 0) {
            slot = (freeSlot >= 0) ? freeSlot : 0;
            s_envCache[slot].valid     = true;
            s_envCache[slot].nodeId    = sender;
            s_envCache[slot].tempCenti = INT32_MIN;
            s_envCache[slot].humCenti  = INT32_MIN;
          }
          if (isTemp) s_envCache[slot].tempCenti = centi;
          else        s_envCache[slot].humCenti  = centi;

          appMqttPublishEnvironmentReported(sender, euiStr,
                                            s_envCache[slot].tempCenti,
                                            s_envCache[slot].humCenti);
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

      emberAfCorePrintln("SWITCH: toggle event from 0x%04X (%s) cmd=0x%02X",
                         (unsigned)sender, euiStr, cmd->commandId);
      appLogLog("SWITCH", "event",
                "\"device_id\":\"%s\",\"event\":\"toggle\",\"zcl_cmd\":\"0x%02X\"",
                euiStr, cmd->commandId);

      // Publish switch event to MQTT (Phase 3.2)
      appMqttPublishDeviceEvent(sender, euiStr, "switch", "toggle");

      // Phase 4: Feed into LEGACY rule engine (gated by
      // SB_RULES_SWITCH_TO_LIGHT; default = OFF).
      ruleEngineOnSwitchEvent(euiStr);

      // Phase 3: Feed into cloud-pushed automation table. If legacy is
      // enabled, automationRuleOnSwitchToggle internally skips action
      // execution to avoid double-toggling the light.
      automationRuleOnSwitchToggle(euiStr);
    } else {
      emberAfCorePrintln("SWITCH: toggle event from 0x%04X but EUI64 unknown",
                         (unsigned)sender);
    }
  }

  return false;
}
