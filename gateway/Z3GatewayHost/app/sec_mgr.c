#include "sec_mgr.h"

#include "app/framework/include/af.h"
#include "app_log.h"
#include "app_utils.h"

#include <string.h>

// EZSP policy IDs we set. Per gecko_sdk/protocol/zigbee/app/util/ezsp/ezsp-enum.h:
//   EZSP_TC_KEY_REQUEST_POLICY     = 0x05
//   EZSP_DENY_TC_KEY_REQUESTS      = 0x50
// (matches Jira spec "EmberAllowTrustCenterLinkKeyRequestPolicy = DENIED_BY_DEFAULT".)
#define EZSP_TC_KEY_REQUEST_POLICY_ID  0x05u
#define EZSP_DENY_TC_KEY_REQUESTS_VAL  0x50u

#define SEC_MGR_MAX_SLOTS 4

typedef struct {
  bool      used;
  uint8_t   eui_le[EUI64_SIZE];
  uint8_t   ic[SEC_MGR_IC_MAX_LEN];
  uint8_t   ic_len;
  uint32_t  ttl_deadline_ms;
} sec_slot_t;

static sec_slot_t g_slots[SEC_MGR_MAX_SLOTS];

// ---------- helpers ----------

static sec_slot_t *findSlotByEui(const uint8_t eui_le[EUI64_SIZE])
{
  for (uint8_t i = 0; i < SEC_MGR_MAX_SLOTS; i++) {
    if (g_slots[i].used && memcmp(g_slots[i].eui_le, eui_le, EUI64_SIZE) == 0) {
      return &g_slots[i];
    }
  }
  return NULL;
}

static sec_slot_t *findFreeSlot(void)
{
  for (uint8_t i = 0; i < SEC_MGR_MAX_SLOTS; i++) {
    if (!g_slots[i].used) return &g_slots[i];
  }
  return NULL;
}

static bool isValidIcLen(uint8_t n)
{
  return (n == 8 || n == 10 || n == 14 || n == 18);
}

static void wipeSlot(sec_slot_t *s)
{
  // Defensive memset — slot may have held secret IC bytes.
  memset(s, 0, sizeof(*s));
}

// ---------- public ----------

static bool g_policySet = false;

void secMgrInit(void)
{
  memset(g_slots, 0, sizeof(g_slots));
  g_policySet = false;
  emberAfCorePrintln("secMgr: staging[%u] ready (TC policy deferred to NETWORK_UP)",
                     (unsigned)SEC_MGR_MAX_SLOTS);
}

void secMgrOnStackUp(void)
{
  if (g_policySet) return;  // idempotent — only first NETWORK_UP per boot
  EzspStatus ezsp_status = ezspSetPolicy(EZSP_TC_KEY_REQUEST_POLICY_ID,
                                         EZSP_DENY_TC_KEY_REQUESTS_VAL);
  if (ezsp_status == EZSP_SUCCESS) {
    g_policySet = true;
    emberAfCorePrintln("secMgr: TC policy=DENY (set on NETWORK_UP)");
  } else {
    emberAfCorePrintln("secMgr: WARN set TC policy failed, ezsp=0x%02X",
                       (unsigned)ezsp_status);
  }
}

void secMgrTick(void)
{
  uint32_t now = msTick();
  for (uint8_t i = 0; i < SEC_MGR_MAX_SLOTS; i++) {
    if (g_slots[i].used) {
      // Signed compare so msTick rollover doesn't immediately expire valid entries.
      if ((int32_t)(now - g_slots[i].ttl_deadline_ms) >= 0) {
        char eui_str[17];
        eui64ToStringBigEndian(eui_str, sizeof(eui_str), g_slots[i].eui_le);
        appLogLog("secMgr", "expired", "\"eui64\":\"%s\",\"slot\":%u",
                  eui_str, (unsigned)i);
        wipeSlot(&g_slots[i]);
      }
    }
  }
}

bool secMgrStage(const EmberEUI64 eui_le,
                 const uint8_t *ic_bytes,
                 uint8_t ic_len,
                 uint32_t ttl_ms)
{
  if (!eui_le || !ic_bytes) return false;
  if (!isValidIcLen(ic_len)) return false;

  sec_slot_t *s = findSlotByEui(eui_le);
  if (!s) s = findFreeSlot();
  if (!s) {
    appLogLog("secMgr", "stage_fail", "\"reason\":\"slots_full\"");
    return false;
  }

  s->used = true;
  memcpy(s->eui_le, eui_le, EUI64_SIZE);
  memcpy(s->ic, ic_bytes, ic_len);
  if (ic_len < SEC_MGR_IC_MAX_LEN) {
    memset(s->ic + ic_len, 0, SEC_MGR_IC_MAX_LEN - ic_len);
  }
  s->ic_len = ic_len;
  s->ttl_deadline_ms = msTick() + ttl_ms;

  // Log eui only — NEVER log IC bytes (contract §7).
  char eui_str[17];
  eui64ToStringBigEndian(eui_str, sizeof(eui_str), s->eui_le);
  appLogLog("secMgr", "staged",
            "\"eui64\":\"%s\",\"ttl_ms\":%u,\"ic_len\":%u",
            eui_str, (unsigned)ttl_ms, (unsigned)s->ic_len);
  return true;
}

void secMgrForget(const EmberEUI64 eui_le)
{
  if (!eui_le) return;
  sec_slot_t *s = findSlotByEui(eui_le);
  if (!s) return;

  char eui_str[17];
  eui64ToStringBigEndian(eui_str, sizeof(eui_str), s->eui_le);
  wipeSlot(s);
  appLogLog("secMgr", "forget", "\"eui64\":\"%s\"", eui_str);
}

// ---------- TC plugin callback ----------
//
// When EMBER_AF_PLUGIN_NETWORK_CREATOR_SECURITY_BDB_JOIN_USES_INSTALL_CODE_KEY=1
// the network-creator-security plugin calls this during BDB join to fetch the
// install code for a joining EUI. We look up the staging table.
//
// Return EMBER_SUCCESS + populate installCode/Length on hit → stack derives
// the TC link key via AES-MMO and proceeds with the secure join.
// Return EMBER_NOT_FOUND on miss → stack denies the join.

EmberStatus emberAfPluginNetworkCreatorSecurityGetInstallCodeCallback(
    EmberEUI64 newNodeEui64,
    uint8_t   *installCode,
    uint8_t   *installCodeLength)
{
  if (!installCode || !installCodeLength) return EMBER_BAD_ARGUMENT;
  *installCodeLength = 0;

  sec_slot_t *s = findSlotByEui(newNodeEui64);
  char eui_str[17];
  eui64ToStringBigEndian(eui_str, sizeof(eui_str), newNodeEui64);

  if (!s) {
    appLogLog("secMgr", "ic_lookup",
              "\"eui64\":\"%s\",\"hit\":false", eui_str);
    return EMBER_NOT_FOUND;
  }

  memcpy(installCode, s->ic, s->ic_len);
  *installCodeLength = s->ic_len;

  // Hit log — metadata only, no IC bytes.
  appLogLog("secMgr", "ic_lookup",
            "\"eui64\":\"%s\",\"hit\":true,\"ic_len\":%u",
            eui_str, (unsigned)s->ic_len);
  return EMBER_SUCCESS;
}
