#include "net_mgr.h"
#include "app_config.h"
#include "app_utils.h"
#include "app_log.h"
#include "app_mqtt.h"

#include "app/framework/include/af.h"

#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_PRESENT
#include "network-creator.h"
#endif
#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_SECURITY_PRESENT
#include "network-creator-security.h"
#endif

#include <string.h>
#include <stdio.h>

NetCfg_t g_netCfg = {
  .panId = (uint16_t)DEFAULT_PAN_ID,
  .ch = (uint8_t)DEFAULT_CHANNEL,
  .txPowerDbm = (int8_t)DEFAULT_TX_POWER_DBM,
};

static bool     g_pendingForm = false;
static NetCfg_t g_pendingCfg;
static char     g_pendingSrc[8] = "uart";

static bool     g_networkOpen     = false;
static uint32_t g_openTick        = 0;
// Runtime auto-close window: 0 means "use compile-time OPEN_JOIN_MS".
// netMgrOpenForJoin() overrides this per request.
static uint32_t g_openDurationMs  = 0;

static bool startNetworkForm(uint16_t panId, int8_t txPwrDbm, uint8_t ch, const char *src)
{
  if (emberAfNetworkState() != EMBER_NO_NETWORK) {
    appLogLog("NET", "form_skip", "\"reason\":\"already_in_network\",\"src\":\"%s\"", src ? src : "");
    return false;
  }

#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_SECURITY_PRESENT
  (void)emberAfPluginNetworkCreatorSecurityStart(true);
#endif

#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_PRESENT
  EmberStatus st = emberAfPluginNetworkCreatorNetworkForm(true, panId, txPwrDbm, ch);
  appLogLog("NET", "form_start", "\"zstatus\":\"0x%02X\",\"pan_id\":\"0x%04X\",\"ch\":%u,\"pwr\":%d,\"src\":\"%s\"",
    (unsigned)st, (unsigned)panId, (unsigned)ch, (int)txPwrDbm, src ? src : "");
  return (st == EMBER_SUCCESS);
#else
  appLogLog("NET", "form_fail", "\"reason\":\"network_creator_missing\",\"src\":\"%s\"", src ? src : "");
  return false;
#endif
}

bool netMgrRequestForm(NetCfg_t cfg, const char *src, bool force)
{
  EmberNetworkStatus ns = emberAfNetworkState();

  if (ns == EMBER_NO_NETWORK) {
    return startNetworkForm(cfg.panId, cfg.txPowerDbm, cfg.ch, src);
  }

  if (!force) {
    appLogLog("NET", "form_skip", "\"reason\":\"already_in_network\",\"src\":\"%s\"", src ? src : "");
    return false;
  }

  g_pendingForm = true;
  g_pendingCfg = cfg;
  strncpy(g_pendingSrc, (src ? src : "uart"), sizeof(g_pendingSrc) - 1);
  g_pendingSrc[sizeof(g_pendingSrc) - 1] = 0;

  EmberStatus st = emberLeaveNetwork();
  appLogLog("NET", "leave_req", "\"zstatus\":\"0x%02X\",\"src\":\"%s\"", (unsigned)st, src ? src : "");
  return (st == EMBER_SUCCESS);
}

void netMgrTick(void)
{
#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_SECURITY_PRESENT
  uint32_t window = (g_openDurationMs > 0) ? g_openDurationMs : OPEN_JOIN_MS;
  if (g_networkOpen && (msTick() - g_openTick >= window)) {
    EmberStatus st = emberAfPluginNetworkCreatorSecurityCloseNetwork();
    appLogLog("NET", "close_join_auto",
      "\"zstatus\":\"0x%02X\",\"after_ms\":%u", (unsigned)st, (unsigned)window);
    g_networkOpen = false;
    g_openDurationMs = 0;

    // Tell cloud the join window closed (auto, not from a close cmd).
    char extra[64];
    snprintf(extra, sizeof(extra),
             "\"reason\":\"timeout\",\"zstatus\":\"0x%02X\"", (unsigned)st);
    appMqttPublishGatewayEvent("permit_join_closed", extra);
  }
#endif
}

EmberStatus netMgrOpenForJoin(uint16_t durationSec)
{
#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_SECURITY_PRESENT
  if (emberAfNetworkState() != EMBER_JOINED_NETWORK) {
    appLogLog("NET", "open_skip", "\"reason\":\"not_joined\"");
    return EMBER_NOT_JOINED;
  }

  // Clamp to [1, 180] -- matches OPEN_JOIN_MS=180s and EZSP permit-join byte.
  if (durationSec < 1) durationSec = 1;
  if (durationSec > 180) durationSec = 180;

  EmberStatus st = emberAfPluginNetworkCreatorSecurityOpenNetwork();
  appLogLog("NET", "open_join_cmd",
            "\"zstatus\":\"0x%02X\",\"duration_s\":%u",
            (unsigned)st, (unsigned)durationSec);

  if (st == EMBER_SUCCESS) {
    g_networkOpen     = true;
    g_openTick        = msTick();
    g_openDurationMs  = (uint32_t)durationSec * 1000u;

    char extra[64];
    snprintf(extra, sizeof(extra), "\"duration_sec\":%u",
             (unsigned)durationSec);
    appMqttPublishGatewayEvent("permit_join_opened", extra);
  } else {
    char extra[80];
    snprintf(extra, sizeof(extra),
             "\"reason\":\"open_fail\",\"zstatus\":\"0x%02X\"",
             (unsigned)st);
    appMqttPublishGatewayEvent("permit_join_failed", extra);
  }
  return st;
#else
  appLogLog("NET", "open_skip", "\"reason\":\"plugin_missing\"");
  return EMBER_LIBRARY_NOT_PRESENT;
#endif
}

EmberStatus netMgrCloseJoin(void)
{
#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_SECURITY_PRESENT
  EmberStatus st = emberAfPluginNetworkCreatorSecurityCloseNetwork();
  appLogLog("NET", "close_join_cmd", "\"zstatus\":\"0x%02X\"", (unsigned)st);

  // Always clear local flags even if the broadcast failed -- the request was
  // intentional and the local TC link-key transient set is already cleared
  // by the SDK.
  g_networkOpen    = false;
  g_openDurationMs = 0;

  char extra[80];
  snprintf(extra, sizeof(extra),
           "\"reason\":\"command\",\"zstatus\":\"0x%02X\"", (unsigned)st);
  appMqttPublishGatewayEvent("permit_join_closed", extra);
  return st;
#else
  appLogLog("NET", "close_skip", "\"reason\":\"plugin_missing\"");
  return EMBER_LIBRARY_NOT_PRESENT;
#endif
}

// callback: formed network
void emberAfPluginNetworkCreatorCompleteCallback(const EmberNetworkParameters *network,
                                                bool usedSecondaryChannels)
{
  (void)usedSecondaryChannels;
  appLogLog("NET", "formed", "\"pan_id\":\"0x%04X\",\"ch\":%u", (unsigned)network->panId, (unsigned)network->radioChannel);

#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_SECURITY_PRESENT
  EmberStatus st = emberAfPluginNetworkCreatorSecurityOpenNetwork();
  appLogLog("NET", "open_join_form",
            "\"zstatus\":\"0x%02X\",\"after\":\"form\"", (unsigned)st);
  if (st == EMBER_SUCCESS) {
    g_networkOpen    = true;
    g_openTick       = msTick();
    g_openDurationMs = OPEN_JOIN_MS;

    char extra[64];
    snprintf(extra, sizeof(extra),
             "\"duration_sec\":%u,\"trigger\":\"form\"",
             (unsigned)(OPEN_JOIN_MS / 1000u));
    appMqttPublishGatewayEvent("permit_join_opened", extra);
  }
#endif

  appLogEmitHeartbeat();
}

// callback: stack status
void emberAfStackStatusCallback(EmberStatus status)
{
  appLogLog("NET", "stack_status", "\"zstatus\":\"0x%02X\"", (unsigned)status);

  if (status == EMBER_NETWORK_UP) {
    appLogEmitHeartbeat();
  } else if (status == EMBER_NETWORK_DOWN) {
    appLogEmitHeartbeat();
  }

  if (status == EMBER_NETWORK_DOWN && g_pendingForm) {
    g_pendingForm = false;
    (void)startNetworkForm(g_pendingCfg.panId, g_pendingCfg.txPowerDbm, g_pendingCfg.ch, g_pendingSrc);
  }
}
