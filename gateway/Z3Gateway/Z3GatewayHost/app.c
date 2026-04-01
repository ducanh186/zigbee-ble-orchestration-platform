/***************************************************************************//**
 * @file app.c
 * @brief Z3GatewayHost application - ported from Z3Coordinator SoC.
 *
 * This file integrates the Coordinator's application logic (network management,
 * valve control, telemetry, JSON command protocol) into the Z3Gateway host
 * framework running on Linux.
 *
 * Original Z3Gateway sample callbacks (IAS ACE, token dump, etc.) are preserved.
 * Coordinator features are added on top.
 ******************************************************************************/

#include "af.h"
#include "app/framework/util/af-main.h"
#include "app/framework/util/util.h"
#include "app/util/zigbee-framework/zigbee-device-common.h"
#include "zap-cluster-command-parser.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "stack/include/zigbee-security-manager.h"

// CLI registration for custom commands
#include "sl_cli.h"
#include "sl_cli_instances.h"
#include "sl_cli_command.h"
#include "sl_cli_handles.h"

// Forward declarations for CLI command handlers
void cli_json_command(sl_cli_command_arg_t *arguments);

// ===== Coordinator app modules =====
#include "app/app_config.h"
#include "app/app_state.h"
#include "app/app_log.h"
#include "app/app_utils.h"
#include "app/net_mgr.h"
#include "app/valve_ctrl.h"
#include "app/cmd_handler.h"
#include "app/device_monitor.h"

// ===== Original Z3Gateway token dump constants =====
#define MFGSAMP_NUM_EZSP_TOKENS 8
#define MFGSAMP_EZSP_TOKEN_SIZE 8
#define MFGSAMP_NUM_EZSP_MFG_TOKENS 11
#define MFGSAMP_EZSP_TOKEN_MFG_MAXSIZE 92

#if defined(SL_CATALOG_ZIGBEE_TRUST_CENTER_NWK_KEY_UPDATE_UNICAST_PRESENT)    \
  || defined(SL_CATALOG_ZIGBEE_TRUST_CENTER_NWK_KEY_UPDATE_BROADCAST_PRESENT) \
  || defined(SL_CATALOG_ZIGBEE_TEST_HARNESS_Z3_PRESENT)
extern EmberStatus emberAfTrustCenterStartNetworkKeyUpdate(void);
#endif

//----------------------
// ZCL commands handling (original Z3Gateway sample)

static void ias_ace_cluster_arm_command_handler(uint8_t armMode,
                                                uint8_t* armDisarmCode,
                                                uint8_t zoneId)
{
  uint16_t armDisarmCodeLength = emberAfStringLength(armDisarmCode);
  EmberNodeId sender = emberGetSender();
  uint16_t i;

  sl_zigbee_app_debug_print("IAS ACE Arm Received %04X", armMode);
  for (i = 1; i < armDisarmCodeLength; i++) {
    sl_zigbee_app_debug_print("%c", armDisarmCode[i]);
  }
  sl_zigbee_app_debug_println(" %02X", zoneId);

  emberAfFillCommandIasAceClusterArmResponse(armMode);
  emberAfSendCommandUnicast(EMBER_OUTGOING_DIRECT, sender);
}

static void ias_ace_cluster_bypass_command_handler(uint8_t numberOfZones,
                                                   uint8_t* zoneIds,
                                                   uint8_t* armDisarmCode)
{
  EmberNodeId sender = emberGetSender();
  uint8_t i;

  sl_zigbee_app_debug_print("IAS ACE Cluster Bypass for zones ");
  for (i = 0; i < numberOfZones; i++) {
    sl_zigbee_app_debug_print("%d ", zoneIds[i]);
  }
  sl_zigbee_app_debug_println("");

  emberAfFillCommandIasAceClusterBypassResponse(numberOfZones,
                                                zoneIds,
                                                numberOfZones);
  emberAfSendCommandUnicast(EMBER_OUTGOING_DIRECT, sender);
}

static uint32_t zcl_ias_ace_cluster_server_command_handler(sl_service_opcode_t opcode,
                                                           sl_service_function_context_t *context)
{
  (void)opcode;
  EmberAfClusterCommand *cmd = (EmberAfClusterCommand *)context->data;

  switch (cmd->commandId) {
    case ZCL_ARM_COMMAND_ID:
    {
      sl_zcl_ias_ace_cluster_arm_command_t cmd_data;
      if (zcl_decode_ias_ace_cluster_arm_command(cmd, &cmd_data)
          != EMBER_ZCL_STATUS_SUCCESS) {
        return EMBER_ZCL_STATUS_UNSUP_COMMAND;
      }
      ias_ace_cluster_arm_command_handler(cmd_data.armMode,
                                          cmd_data.armDisarmCode,
                                          cmd_data.zoneId);
      return EMBER_ZCL_STATUS_SUCCESS;
    }
    case ZCL_BYPASS_COMMAND_ID:
    {
      sl_zcl_ias_ace_cluster_bypass_command_t cmd_data;
      if (zcl_decode_ias_ace_cluster_bypass_command(cmd, &cmd_data)
          != EMBER_ZCL_STATUS_SUCCESS) {
        return EMBER_ZCL_STATUS_UNSUP_COMMAND;
      }
      ias_ace_cluster_bypass_command_handler(cmd_data.numberOfZones,
                                             cmd_data.zoneIds,
                                             cmd_data.armDisarmCode);
      return EMBER_ZCL_STATUS_SUCCESS;
    }
  }
  return EMBER_ZCL_STATUS_UNSUP_COMMAND;
}

//----------------------
// Main init: original Z3Gateway + Coordinator logic

void emberAfMainInitCallback(void)
{
  // Original Z3Gateway: subscribe to IAS ACE
  sl_zigbee_subscribe_to_zcl_commands(ZCL_IAS_ACE_CLUSTER_ID,
                                      0xFFFF,
                                      ZCL_DIRECTION_CLIENT_TO_SERVER,
                                      zcl_ias_ace_cluster_server_command_handler);

  // === Coordinator init ===
  // On EZSP host, TC link key policy is managed via ezspSetPolicy.
  // The Z3Gateway network-creator-security plugin handles this automatically.
  emberAfCorePrintln("APP: TCLK policy managed by network-creator-security plugin");

  appStateInit();
  appStateNotifyChanged();

  // Register "json" CLI command at runtime
  {
    static const sl_cli_command_info_t json_cmd_info =
      SL_CLI_COMMAND(cli_json_command,
                     "Process JSON command (Dashboard protocol)",
                     "JSON payload" SL_CLI_UNIT_SEPARATOR,
                     { SL_CLI_ARG_STRING, SL_CLI_ARG_END });

    static const sl_cli_command_entry_t coord_cmd_table[] = {
      { "json", &json_cmd_info, false },
      { NULL, NULL, false }
    };

    static sl_cli_command_group_t coord_cmd_group = {
      { NULL },
      false,
      coord_cmd_table
    };

    sl_cli_command_add_command_group(sl_cli_example_handle, &coord_cmd_group);
    emberAfCorePrintln("Dashboard command registered: json");
  }

  emberAfCorePrintln("Coordinator init (host mode)");
  // NOTE: Do NOT call emberAfNetworkState(), appLogInfo(), or appLogData() here.
  // EZSP is not connected yet at this point. These will be called after
  // the stack comes up via emberAfStackStatusCallback.
}

//----------------------
// Main tick: network manager (replaces buttonsTick on SoC)

void emberAfMainTickCallback(void)
{
  netMgrTick();
  deviceMonitorTick();
}

//----------------------
// Original Z3Gateway CLI commands

#ifdef SL_CATALOG_CLI_PRESENT

static const char * ezspMfgTokenNames[] =
{
  "EZSP_MFG_CUSTOM_VERSION...",
  "EZSP_MFG_STRING...........",
  "EZSP_MFG_BOARD_NAME.......",
  "EZSP_MFG_MANUF_ID.........",
  "EZSP_MFG_PHY_CONFIG.......",
  "EZSP_MFG_BOOTLOAD_AES_KEY.",
  "EZSP_MFG_ASH_CONFIG.......",
  "EZSP_MFG_EZSP_STORAGE.....",
  "EZSP_STACK_CAL_DATA.......",
  "EZSP_MFG_CBKE_DATA........",
  "EZSP_MFG_INSTALLATION_CODE"
};

void mfgappTokenDump(sl_cli_command_arg_t *arguments)
{
  (void)arguments;
  EmberStatus status;
  uint8_t tokenData[MFGSAMP_EZSP_TOKEN_MFG_MAXSIZE];
  uint8_t index, i, tokenLength;

  sl_zigbee_app_debug_println("(data shown little endian)");
  sl_zigbee_app_debug_println("Tokens:");
  sl_zigbee_app_debug_println("idx  value:");
  for (index = 0; index < MFGSAMP_NUM_EZSP_TOKENS; index++) {
    status = ezspGetToken(index, tokenData);
    sl_zigbee_app_debug_print("[%d]", index);
    if (status == EMBER_SUCCESS) {
      for (i = 0; i < MFGSAMP_EZSP_TOKEN_SIZE; i++) {
        sl_zigbee_app_debug_print(" %02X", tokenData[i]);
      }
      sl_zigbee_app_debug_println("");
    } else {
      sl_zigbee_app_debug_println(" ... error 0x%02X ...", status);
    }
  }

  sl_zigbee_app_debug_println("Manufacturing Tokens:");
  sl_zigbee_app_debug_println("idx  token name                 len   value");
  for (index = 0; index < MFGSAMP_NUM_EZSP_MFG_TOKENS; index++) {
    tokenLength = ezspGetMfgToken(index, tokenData);
    sl_zigbee_app_debug_println("[%x] %s: 0x%x:",
                                index, ezspMfgTokenNames[index], tokenLength);
    for (i = 0; i < tokenLength; i++) {
      if ((i != 0) && ((i % 8) == 0)) {
        sl_zigbee_app_debug_println("");
        sl_zigbee_app_debug_print("                                    :");
      }
      sl_zigbee_app_debug_print(" %02X", tokenData[i]);
    }
    sl_zigbee_app_debug_println("");
  }
  sl_zigbee_app_debug_println("");
}

#if defined(SL_CATALOG_ZIGBEE_TRUST_CENTER_NWK_KEY_UPDATE_UNICAST_PRESENT)    \
  || defined(SL_CATALOG_ZIGBEE_TRUST_CENTER_NWK_KEY_UPDATE_BROADCAST_PRESENT) \
  || defined(SL_CATALOG_ZIGBEE_TEST_HARNESS_Z3_PRESENT)
void changeNwkKeyCommand(sl_cli_command_arg_t *arguments)
{
  (void)arguments;
  EmberStatus status = emberAfTrustCenterStartNetworkKeyUpdate();
  if (status != EMBER_SUCCESS) {
    sl_zigbee_app_debug_println("Change Key Error %x", status);
  } else {
    sl_zigbee_app_debug_println("Change Key Success");
  }
}
#endif

static void dcPrintKey(uint8_t label, uint8_t *key)
{
  uint8_t i;
  sl_zigbee_app_debug_println("key %x: ", label);
  for (i = 0; i < EMBER_ENCRYPTION_KEY_SIZE; i++) {
    sl_zigbee_app_debug_print("%02X", key[i]);
  }
  sl_zigbee_app_debug_println("");
}

void printNextKeyCommand(sl_cli_command_arg_t *arguments)
{
  (void)arguments;
  sl_status_t status;
  sl_zb_sec_man_context_t context;
  sl_zb_sec_man_key_t plaintext_key;

  sl_zb_sec_man_init_context(&context);
  context.core_key_type = SL_ZB_SEC_MAN_KEY_TYPE_NETWORK;
  context.key_index = 1;
  status = sl_zb_sec_man_export_key(&context, &plaintext_key);

  if (status != SL_STATUS_OK) {
    sl_zigbee_app_debug_println("Error getting key");
  } else {
    dcPrintKey(1, plaintext_key.key);
  }
}

void versionCommand(sl_cli_command_arg_t *arguments)
{
  (void)arguments;
  sl_zigbee_app_debug_print("Version:  0.1 Alpha\n");
  sl_zigbee_app_debug_println(" %s", __DATE__);
  sl_zigbee_app_debug_println(" %s", __TIME__);
  sl_zigbee_app_debug_println("");
}

void setTxPowerCommand(sl_cli_command_arg_t *arguments)
{
  int8_t dBm = sl_cli_get_argument_int8(arguments, 0);
  emberSetRadioPower(dBm);
}

// ===== Coordinator CLI commands (replaces hardware buttons) =====

// "json" command: json {"id":1,"op":"info"}
void cli_json_command(sl_cli_command_arg_t *arguments)
{
  char *json_arg = sl_cli_get_argument_string(arguments, 0);
  if (!json_arg || json_arg[0] == '\0') {
    emberAfCorePrintln("Usage: json {\"id\":N,\"op\":\"...\"}");
    return;
  }

  static char cmdBuf[256];
  int n = snprintf(cmdBuf, sizeof(cmdBuf), "@CMD %s", json_arg);
  if (n < 0 || (size_t)n >= sizeof(cmdBuf)) {
    emberAfCorePrintln("json: command too long");
    return;
  }

  cmdHandleLine(cmdBuf);
}

#endif // SL_CATALOG_CLI_PRESENT

#ifdef SL_CATALOG_ZIGBEE_AF_SUPPORT_PRESENT
bool emberAfGetEndpointInfoCallback(int8u endpoint,
                                    int8u* returnNetworkIndex,
                                    EmberAfEndpointInfoStruct* returnEndpointInfo)
{
  if (endpoint == 242) {
    *returnNetworkIndex = 0;
    returnEndpointInfo->profileId = 0xA1E0;
    return true;
  }
  return false;
}
#endif
