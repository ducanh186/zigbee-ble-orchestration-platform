#include "app_log.h"
#include "app_config.h"
#include "app_state.h"
#include "app_utils.h"
#include "net_mgr.h"
#include "device_registry.h"

#include "app/framework/include/af.h"

#include <string.h>
#include <stdio.h>
#include <stdarg.h>

// ===== UPTIME TRACKING =====
static uint32_t s_bootTick = 0;
static bool s_initialized = false;

static void ensureInit(void)
{
  if (!s_initialized) {
    s_bootTick = msTick();
    s_initialized = true;
  }
}

uint32_t appLogGetUptimeSec(void)
{
  ensureInit();
  return (msTick() - s_bootTick) / 1000u;
}

void appLogEmitHeartbeat(void)
{
  ensureInit();
  appLogInfo();
}

void appLogData(void)
{
  emberAfCorePrintln(
    "@DATA {\"battery\":%u,"
    "\"device_known\":%s,\"device_node_id\":\"0x%04X\"}",
    g_batteryPercent,
    deviceRegistryIsKnown() ? "true" : "false",
    (uint16_t)deviceRegistryGetNodeId()
  );
}

void appLogAck(uint32_t id, bool ok, const char *msg)
{
  if (!msg) msg = "";
  emberAfCorePrintln(
    "@ACK {\"id\":%lu,\"ok\":%s,\"msg\":\"%s\"}",
    (unsigned long)id,
    ok ? "true" : "false",
    msg
  );
}

void appLogAckZb(uint32_t id, bool ok, const char *msg, uint8_t zstatus, const char *stage)
{
  if (!msg) msg = "";
  if (!stage) stage = "";
  emberAfCorePrintln(
    "@ACK {\"id\":%lu,\"ok\":%s,\"msg\":\"%s\",\"zstatus\":\"0x%02X\",\"stage\":\"%s\"}",
    (unsigned long)id,
    ok ? "true" : "false",
    msg,
    (unsigned)zstatus,
    stage
  );
}

void appLogLog(const char *tag, const char *event, const char *fmt, ...)
{
  char extra[128] = "";
  if (fmt && fmt[0] != '\0') {
    va_list args;
    va_start(args, fmt);
    vsnprintf(extra, sizeof(extra), fmt, args);
    va_end(args);
  }

  if (extra[0] != '\0') {
    emberAfCorePrintln(
      "@LOG {\"tag\":\"%s\",\"event\":\"%s\",%s,\"uptime\":%lu}",
      tag ? tag : "",
      event ? event : "",
      extra,
      (unsigned long)appLogGetUptimeSec()
    );
  } else {
    emberAfCorePrintln(
      "@LOG {\"tag\":\"%s\",\"event\":\"%s\",\"uptime\":%lu}",
      tag ? tag : "",
      event ? event : "",
      (unsigned long)appLogGetUptimeSec()
    );
  }
}

void appLogInfo(void)
{
  ensureInit();
  EmberNetworkStatus st = emberAfNetworkState();
  EmberNodeId nodeId = emberGetNodeId();

  EmberEUI64 eui;
  memcpy(eui, emberGetEui64(), EUI64_SIZE);

  char euiStr[17];
  eui64ToStringBigEndian(euiStr, sizeof(euiStr), eui);

  uint16_t panId = g_netCfg.panId;
  uint8_t ch = g_netCfg.ch;
  int8_t pwr = g_netCfg.txPowerDbm;

  EmberNodeType nodeType;
  EmberNetworkParameters params;
  if (emberAfGetNetworkParameters(&nodeType, &params) == EMBER_SUCCESS) {
    panId = params.panId;
    ch = params.radioChannel;
  }

  char devEuiStr[17] = "0000000000000000";
  if (deviceRegistryIsKnown()) {
    const EmberEUI64 *de = deviceRegistryGetEuiLe();
    if (de) eui64ToStringBigEndian(devEuiStr, sizeof(devEuiStr), *de);
  }

  emberAfCorePrintln(
    "@INFO {\"node_id\":\"0x%04X\",\"eui64\":\"%s\",\"pan_id\":\"0x%04X\",\"ch\":%u,"
    "\"tx_power\":%d,\"net_state\":%d,"
    "\"device_known\":%s,\"device_eui64\":\"%s\","
    "\"device_node_id\":\"0x%04X\",\"uptime\":%lu}",
    nodeId, euiStr, panId, ch, (int)pwr, st,
    deviceRegistryIsKnown() ? "true" : "false",
    devEuiStr,
    (uint16_t)deviceRegistryGetNodeId(),
    (unsigned long)appLogGetUptimeSec()
  );
}
