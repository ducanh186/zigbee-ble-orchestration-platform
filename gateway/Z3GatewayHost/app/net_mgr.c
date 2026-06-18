#include "net_mgr.h"
#include "app_config.h"
#include "app_utils.h"
#include "app_log.h"
#include "app_mqtt.h"
#include "device_discovery.h"
#include "device_registry.h"
#include "sec_mgr.h"

#include "app/framework/include/af.h"

#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_PRESENT
#include "network-creator.h"
#endif
#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_SECURITY_PRESENT
#include "network-creator-security.h"
#endif
#include "app/framework/security/af-security.h"  // sli_zigbee_af_install_code_to_key

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

// Boot + periodic rediscovery: 0 = inactive, otherwise msTick deadline at which
// netMgrTick() walks the NCP child AND neighbor tables and queues ZDO discovery
// for any already-joined device the registry does not yet classify. This solves
// the case where a device joined before this gateway instance started: the
// TC-join callback never fired (an already-keyed router rejoins UNSECURED, which
// fires no join callback), so neither device_discovery nor the registry — which
// is RAM-only and rebuilt every boot — got populated, and the device stays
// invisible until it happens to publish a report. A silent router (button
// switch, idle occupancy sensor) may never publish, so it would be reaped
// offline while still joined (LED on). The first sweep defers a few seconds
// after EMBER_NETWORK_UP; we then re-arm periodically because after an NCP reset
// the neighbor table repopulates only as link-status messages arrive (~16 s
// cadence), and because a later silent rejoin must also be re-registered.
static uint32_t g_rediscoverDeadline = 0;
static bool     g_rediscoverDidFirst = false;
#define BOOT_REDISCOVER_DELAY_MS 3000u
#define REDISCOVER_PERIOD_MS     30000u

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

// Run ZDO discovery for one already-joined device the registry has not yet
// classified. Skips devices already classified or with a discovery already in
// flight, so a periodic re-sweep does not restart in-progress discoveries.
static void netMgrRediscoverConsider(EmberNodeId nodeId, const EmberEUI64 euiLe,
                                     const char *src, bool verbose,
                                     uint8_t *kicked, uint8_t *skipped)
{
  if (deviceDiscoveryInProgress(nodeId)) { (*skipped)++; return; }

  char euiStr[17];
  eui64ToStringBigEndian(euiStr, sizeof(euiStr), euiLe);

  device_resolved_t resolved;
  if (deviceRegistryResolve(euiStr, &resolved)
      && resolved.device_type[0]
      && strcmp(resolved.device_type, "unknown") != 0) {
    if (verbose) {
      appLogLog("BOOT", "rediscover_skip",
        "\"eui64\":\"%s\",\"node_id\":\"0x%04X\",\"type\":\"%s\","
        "\"src\":\"%s\",\"reason\":\"already_classified\"",
        euiStr, (unsigned)nodeId, resolved.device_type, src);
    }
    (*skipped)++;
    return;
  }
  appLogLog("BOOT", "rediscover_kick",
    "\"eui64\":\"%s\",\"node_id\":\"0x%04X\",\"src\":\"%s\"",
    euiStr, (unsigned)nodeId, src);
  deviceDiscoveryStart(nodeId, euiLe);
  (*kicked)++;
}

// Walk the devices the NCP already knows and run ZDO discovery for any this
// gateway instance has not classified yet. Two sources, because a joined device
// is either a CHILD of the coordinator (EZSP child table — sleepy/end devices)
// or a mains-powered ROUTER (neighbor table — every kit in this deployment).
// The original implementation walked only the child table, so after a restart
// the router-only kit set produced scanned:0 and nothing re-registered. NOTE:
// the neighbor table holds only 1-hop routers; a multi-hop router would need a
// ZDO broadcast to rediscover (not implemented — every kit here is 1 hop).
// `verbose` is true for the first boot sweep, false for periodic re-sweeps so
// the steady state stays quiet.
static void netMgrBootRediscover(bool verbose)
{
  uint8_t kicked = 0, skipped = 0, children = 0, neighbors = 0;

#ifdef EMBER_AF_PLUGIN_CHILD_TABLE_SIZE
  const uint8_t maxChild = EMBER_AF_PLUGIN_CHILD_TABLE_SIZE;
#else
  const uint8_t maxChild = 32;  // safe upper bound for EZSP host child table
#endif
  for (uint8_t i = 0; i < maxChild; i++) {
    EmberChildData child;
    if (emberGetChildData(i, &child) != EMBER_SUCCESS) continue;
    children++;
    netMgrRediscoverConsider(child.id, child.eui64, "child", verbose,
                             &kicked, &skipped);
  }

  uint8_t nCount = emberNeighborCount();
  for (uint8_t i = 0; i < nCount; i++) {
    EmberNeighborTableEntry n;
    if (emberGetNeighbor(i, &n) != EMBER_SUCCESS) continue;
    neighbors++;
    netMgrRediscoverConsider(n.shortId, n.longId, "neighbor", verbose,
                             &kicked, &skipped);
  }

  if (verbose || kicked > 0) {
    appLogLog("BOOT", "rediscover_done",
      "\"children\":%u,\"neighbors\":%u,\"kicked\":%u,\"skipped\":%u",
      (unsigned)children, (unsigned)neighbors, (unsigned)kicked, (unsigned)skipped);
  }
}

// Layer-2: on-demand rediscovery by big-endian EUI64 hex (gateway.rediscover_device).
// Returns true if a ZDO discovery was queued, false if the EUI cannot be
// resolved to a known nodeId on this network.
bool netMgrRediscoverByEui(const char *euiStr)
{
  if (!euiStr || !*euiStr) return false;

  EmberEUI64 euiLe;
  if (!parseHexEui64(euiStr, euiLe)) {
    appLogLog("REDISC", "bad_eui", "\"eui64\":\"%s\"", euiStr);
    return false;
  }

#ifdef EMBER_AF_PLUGIN_CHILD_TABLE_SIZE
  const uint8_t maxIdx = EMBER_AF_PLUGIN_CHILD_TABLE_SIZE;
#else
  const uint8_t maxIdx = 32;
#endif
  for (uint8_t i = 0; i < maxIdx; i++) {
    EmberChildData child;
    if (emberGetChildData(i, &child) != EMBER_SUCCESS) continue;
    if (memcmp(child.eui64, euiLe, EUI64_SIZE) == 0) {
      appLogLog("REDISC", "found_in_child_table",
        "\"eui64\":\"%s\",\"node_id\":\"0x%04X\"",
        euiStr, (unsigned)child.id);
      deviceDiscoveryStart(child.id, child.eui64);
      return true;
    }
  }

  // Fallback: stack address lookup (covers router devices not in child table).
  EmberNodeId nodeId = emberLookupNodeIdByEui64(euiLe);
  if (nodeId != EMBER_NULL_NODE_ID) {
    appLogLog("REDISC", "found_in_lookup",
      "\"eui64\":\"%s\",\"node_id\":\"0x%04X\"",
      euiStr, (unsigned)nodeId);
    deviceDiscoveryStart(nodeId, euiLe);
    return true;
  }

  appLogLog("REDISC", "not_found",
    "\"eui64\":\"%s\",\"reason\":\"not_on_network\"", euiStr);
  return false;
}

void netMgrTick(void)
{
  // SCRUM-55 staging-table TTL sweep. Cheap (4-slot scan); safe to run
  // unconditionally regardless of plugin presence.
  secMgrTick();

#ifdef SL_CATALOG_ZIGBEE_NETWORK_CREATOR_SECURITY_PRESENT
  // Boot rediscovery fires ~3 s after EMBER_NETWORK_UP, then re-arms on a period
  // so late-populating neighbor entries (after the NCP reset) and silent rejoins
  // still get registered. First sweep is verbose; re-sweeps are quiet.
  if (g_rediscoverDeadline != 0
      && (int32_t)(msTick() - g_rediscoverDeadline) >= 0) {
    netMgrBootRediscover(!g_rediscoverDidFirst);
    g_rediscoverDidFirst = true;
    g_rediscoverDeadline = msTick() + REDISCOVER_PERIOD_MS;
  }

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

EmberStatus netMgrOpenForJoinSecure(const EmberEUI64 eui_le,
                                    const uint8_t *ic_bytes,
                                    uint8_t ic_len,
                                    uint16_t durationSec)
{
  // 2 s grace beyond permit-join window to cover slow associate + key derive.
  uint32_t ttl_ms = (uint32_t)durationSec * 1000u + 2000u;
  if (!secMgrStage(eui_le, ic_bytes, ic_len, ttl_ms)) {
    appLogLog("NET", "open_secure_fail",
              "\"reason\":\"stage_rejected\",\"ic_len\":%u",
              (unsigned)ic_len);
    return EMBER_BAD_ARGUMENT;
  }

  // SDK 4.5.0 does NOT invoke emberAfPluginNetworkCreatorSecurityGetInstallCodeCallback
  // on a plain emberPermitJoining (verified: the callback has no caller anywhere in the
  // SDK/autogen), so the TC never gets a transient link key for the joining EUI and the
  // install-code join is denied as "unsecured". Instead derive the APS link key from the
  // install code (AES-MMO host helper) and open the network with that EUI+key pair, which
  // imports the transient key on the NCP. Only this EUI may then join, using the IC key.
  EmberKeyData key;
  EmberStatus dk = sli_zigbee_af_install_code_to_key((uint8_t *)ic_bytes, ic_len, &key);
  if (dk != EMBER_SUCCESS) {
    secMgrForget(eui_le);
    appLogLog("NET", "open_secure_fail",
              "\"reason\":\"derive\",\"zstatus\":\"0x%02X\"", (unsigned)dk);
    return dk;
  }

  // Opens permit-join for the plugin's NETWORK_OPEN_TIME_S and imports the transient
  // key via sl_zb_sec_man_import_transient_key. durationSec drives our own bookkeeping
  // / staging TTL only.
  EmberStatus st = emberAfPluginNetworkCreatorSecurityOpenNetworkWithKeyPair((uint8_t *)eui_le, key);
  memset(&key, 0, sizeof(key));   // never leave the derived link key on the stack
  if (st == EMBER_SUCCESS) {
    g_networkOpen    = true;
    g_openTick       = msTick();
    g_openDurationMs = (uint32_t)durationSec * 1000u;

    char extra[64];
    snprintf(extra, sizeof(extra),
             "\"duration_sec\":%u,\"trigger\":\"pjoin-secure\"",
             (unsigned)durationSec);
    appMqttPublishGatewayEvent("permit_join_opened", extra);
  } else {
    secMgrForget(eui_le);   // could not open -> drop the staged secret
  }
  appLogLog("NET", "open_secure_cmd",
            "\"zstatus\":\"0x%02X\",\"duration_s\":%u",
            (unsigned)st, (unsigned)durationSec);
  return st;
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
    // SCRUM-55: set TC key request policy = DENY now that EZSP is connected.
    // Calling ezspSetPolicy at emberAfMainInitCallback time returns
    // EZSP_NOT_CONNECTED (0x28); NETWORK_UP guarantees the host-NCP link.
    secMgrOnStackUp();
    // Arm boot-time rediscovery once per session. netMgrTick fires it after
    // BOOT_REDISCOVER_DELAY_MS so the EZSP child-table cache has time to
    // repopulate after stack-up.
    if (g_rediscoverDeadline == 0) {
      g_rediscoverDeadline = msTick() + BOOT_REDISCOVER_DELAY_MS;
      appLogLog("BOOT", "rediscover_armed",
                "\"delay_ms\":%u", (unsigned)BOOT_REDISCOVER_DELAY_MS);
    }
  } else if (status == EMBER_NETWORK_DOWN) {
    appLogEmitHeartbeat();
  }

  if (status == EMBER_NETWORK_DOWN && g_pendingForm) {
    g_pendingForm = false;
    (void)startNetworkForm(g_pendingCfg.panId, g_pendingCfg.txPowerDbm, g_pendingCfg.ch, g_pendingSrc);
  }
}
