#include "app_config.h"
#include "app_state.h"
#include "app_utils.h"
#include "app_log.h"
#include "valve_ctrl.h"
#include "app/framework/include/af.h"
#include "app_zcl_fallback.h"

#include <stdint.h>
#include <stdbool.h>

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
      } else {
        break;
      }
    }
    return false;  // let framework continue processing
  }

  // --- Flow Measurement (0x0404) ---
  if (clusterId == ZCL_FLOW_MEASUREMENT_CLUSTER_ID) {
    while (i + 3 <= bufLen) {
      uint16_t attrId = u16le(&buffer[i]);
      uint8_t type = buffer[i + 2];
      i += 3;

      if (attrId == 0x0000 && type == ZCL_INT16U_ATTRIBUTE_TYPE) {
        if (i + 2 > bufLen) break;
        uint16_t v = u16le(&buffer[i]);
        i += 2;
        if (g_flow != v) {
          g_flow = v;
          valveCtrlAutoControl();
          appLogData();
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

// Keep PreCommandReceived for non-report messages (like ZCL Default Response)
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

  return false;
}
