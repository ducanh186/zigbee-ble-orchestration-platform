/***************************************************************************//**
 * @file rule_engine.c
 * @brief Minimal gateway-driven local automation (Phase 4).
 *
 * V1: config-driven switch -> light toggle bindings.
 *
 * Anti-loop strategy (Phase 4.3):
 *   This module's sole trigger is ruleEngineOnSwitchEvent(), called from
 *   telemetry_rx.c when a switch ZCL command is received.  It is NEVER
 *   called from light reported state changes, breaking the potential loop:
 *     switch event -> rule -> light command -> light reported -> (stop)
 *
 * Pipeline separation (Phase 4.2):
 *   Cloud command path:  MQTT request -> cmd_handler -> device_dispatch -> lightCtrlHandleCommand
 *   Local automation:    ZCL switch cmd -> telemetry_rx -> ruleEngineOnSwitchEvent -> lightCtrlLocalToggle
 *   Both converge at the ZCL send layer (emberAfSendCommandUnicast) but
 *   lightCtrlLocalToggle does NOT use command tracking or publish command_reply.
 ******************************************************************************/

#include "rule_engine.h"
#include "light_ctrl.h"
#include "device_registry.h"
#include "app_log.h"
#include "app_mqtt.h"
#include "app_utils.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "af.h"

// ===== Binding configuration (Phase 4.1) =====
// V1: compiled-in bindings.  Each entry maps a switch device_id (eui64)
// to a target light device_id.  Action is always "toggle".
// Future: load from JSON file or MQTT desired state.

#define MAX_BINDINGS 8

typedef struct {
  char switch_id[24];     // switch eui64 string
  char target_light_id[24]; // target light eui64 string (device_id)
  // action is always "toggle" in v1
} SwitchBinding_t;

static SwitchBinding_t s_bindings[MAX_BINDINGS];
static int s_bindingCount = 0;

// ===== Anti-loop state (Phase 4.3) =====
// Simple cooldown: ignore rapid re-triggers from the same switch within
// a short window.  This guards against RF retransmits / duplicate ZCL
// commands from the same button press.
#define RULE_COOLDOWN_MS 500

typedef struct {
  char switch_id[24];
  uint32_t lastTriggerTick;
} CooldownEntry_t;

static CooldownEntry_t s_cooldown[MAX_BINDINGS];

// ===== Motion -> light rule (disabled by default) =====
#define MOTION_ID_MAX 24
#define MOTION_DEFAULT_OFF_DELAY_MS 30000u

static bool s_motionEnabled = false;
static char s_motionSensorId[MOTION_ID_MAX] = "*";
static char s_motionLightId[MOTION_ID_MAX] = "*";
static uint32_t s_motionOffDelayMs = MOTION_DEFAULT_OFF_DELAY_MS;
static bool s_motionOffPending = false;
static uint32_t s_motionOffDeadline = 0;

static void copyRuleId(char *dst, size_t dstSize, const char *src)
{
  if (!dst || dstSize == 0) return;
  if (!src || !src[0]) src = "*";
  strncpy(dst, src, dstSize - 1);
  dst[dstSize - 1] = '\0';
}

static uint32_t parseDelayMs(const char *value)
{
  if (!value || !value[0]) return MOTION_DEFAULT_OFF_DELAY_MS;
  char *end = NULL;
  unsigned long parsed = strtoul(value, &end, 10);
  if (end == value || (end && *end != '\0') || parsed == 0ul) {
    return MOTION_DEFAULT_OFF_DELAY_MS;
  }
  if (parsed > 0xFFFFFFFFul) return MOTION_DEFAULT_OFF_DELAY_MS;
  return (uint32_t)parsed;
}

static bool ruleIdMatches(const char *configuredId, const char *actualId)
{
  if (!configuredId || !configuredId[0] || strcmp(configuredId, "*") == 0) {
    return true;
  }
  return actualId && strcmp(configuredId, actualId) == 0;
}

// ===== Public API =====

void ruleEngineInit(void)
{
  memset(s_bindings, 0, sizeof(s_bindings));
  memset(s_cooldown, 0, sizeof(s_cooldown));
  s_bindingCount = 0;

  // Switch -> light binding is AUTHORITATIVELY handled by Zigbee direct
  // binding (switch client -> light server, configured at commissioning).
  // The gateway must only OBSERVE switch events and publish them upstream;
  // it must NOT relay the toggle in parallel, otherwise the gateway's
  // ZCL Toggle races the direct-bind Toggle and state flips back ("snap
  // back" BUG 2).
  //
  // We keep the rule engine skeleton so future non-binding automations
  // (e.g. motion -> light) can be added here without re-plumbing
  // telemetry_rx -> rule_engine wiring.
  //
  // Opt-in override (for deployments WITHOUT direct binding):
  //   SB_RULES_SWITCH_TO_LIGHT=1  -> install the wildcard switch -> light
  //                                 binding (legacy Phase-4 behavior).
  const char *env = getenv("SB_RULES_SWITCH_TO_LIGHT");
  bool relay = (env && *env && *env != '0');
  if (relay) {
    strncpy(s_bindings[0].switch_id, "*", sizeof(s_bindings[0].switch_id) - 1);
    strncpy(s_bindings[0].target_light_id, "*", sizeof(s_bindings[0].target_light_id) - 1);
    s_bindingCount = 1;
  }

  appLogLog("RULE", "init",
            "\"bindings\":%d,\"switch_to_light_relay\":%s",
            s_bindingCount, relay ? "true" : "false");
  emberAfCorePrintln("RULE: engine init, %d binding(s), switch->light relay %s",
                     s_bindingCount, relay ? "ENABLED" : "disabled (direct binding)");

  const char *motionEnv = getenv("SB_RULES_MOTION_TO_LIGHT");
  s_motionEnabled = (motionEnv && strcmp(motionEnv, "1") == 0);
  copyRuleId(s_motionSensorId, sizeof(s_motionSensorId),
             getenv("SB_RULES_MOTION_SENSOR_ID"));
  copyRuleId(s_motionLightId, sizeof(s_motionLightId),
             getenv("SB_RULES_MOTION_LIGHT_ID"));
  s_motionOffDelayMs = parseDelayMs(getenv("SB_RULES_MOTION_OFF_DELAY_MS"));
  s_motionOffPending = false;
  s_motionOffDeadline = 0;

  appLogLog("RULE", "motion_init",
            "\"enabled\":%s,\"sensor\":\"%s\",\"light\":\"%s\","
            "\"off_delay_ms\":%u",
            s_motionEnabled ? "true" : "false",
            s_motionSensorId, s_motionLightId,
            (unsigned)s_motionOffDelayMs);
  emberAfCorePrintln("RULE: motion->light %s sensor=%s light=%s off_delay_ms=%u",
                     s_motionEnabled ? "ENABLED" : "disabled",
                     s_motionSensorId, s_motionLightId,
                     (unsigned)s_motionOffDelayMs);
}

void ruleEngineTick(void)
{
  if (!s_motionEnabled || !s_motionOffPending) return;

  uint32_t now = msTick();
  if ((int32_t)(now - s_motionOffDeadline) < 0) return;

  s_motionOffPending = false;
  appLogLog("RULE", "motion_off_action",
            "\"light\":\"%s\",\"reason\":\"delay_expired\"",
            s_motionLightId);

  bool sent = lightCtrlSetOff(s_motionLightId);
  appLogLog("RULE", sent ? "motion_off_sent" : "motion_off_skipped",
            "\"light\":\"%s\"", s_motionLightId);
}

void ruleEngineOnSwitchEvent(const char *switchDeviceId)
{
  if (!switchDeviceId || !switchDeviceId[0]) return;

  uint32_t now = msTick();

  for (int i = 0; i < s_bindingCount; i++) {
    SwitchBinding_t *b = &s_bindings[i];

    // Match: exact switch_id or wildcard "*"
    bool match = (strcmp(b->switch_id, "*") == 0)
              || (strcmp(b->switch_id, switchDeviceId) == 0);
    if (!match) continue;

    // Anti-loop cooldown check (Phase 4.3)
    CooldownEntry_t *cd = &s_cooldown[i];
    if (cd->switch_id[0] && strcmp(cd->switch_id, switchDeviceId) == 0) {
      uint32_t elapsed = now - cd->lastTriggerTick;
      if ((int32_t)elapsed < (int32_t)RULE_COOLDOWN_MS) {
        appLogLog("RULE", "cooldown",
                  "\"switch\":\"%s\",\"elapsed_ms\":%u",
                  switchDeviceId, (unsigned)elapsed);
        return;
      }
    }

    // Update cooldown
    strncpy(cd->switch_id, switchDeviceId, sizeof(cd->switch_id) - 1);
    cd->switch_id[sizeof(cd->switch_id) - 1] = '\0';
    cd->lastTriggerTick = now;

    // Resolve target light
    // If target is "*", toggle the registered (paired) device.
    const char *targetId = b->target_light_id;

    appLogLog("RULE", "trigger",
              "\"switch\":\"%s\",\"target\":\"%s\",\"action\":\"toggle\"",
              switchDeviceId, targetId);
    emberAfCorePrintln("RULE: switch %s -> toggle light %s",
                       switchDeviceId, targetId);

    // Phase 4.2: Use lightCtrlLocalToggle (no command tracking, no command_reply).
    // This is the LOCAL AUTOMATION path, separate from the cloud command path.
    lightCtrlLocalToggle();
  }
}

void ruleEngineOnMotionReport(const char *sensorDeviceId, bool occupied)
{
  if (!sensorDeviceId || !sensorDeviceId[0]) return;

  const char *occupancy = occupied ? "occupied" : "unoccupied";
  appLogLog("RULE", "motion_report",
            "\"enabled\":%s,\"sensor\":\"%s\",\"occupancy\":\"%s\"",
            s_motionEnabled ? "true" : "false", sensorDeviceId, occupancy);

  if (!s_motionEnabled) return;

  if (!ruleIdMatches(s_motionSensorId, sensorDeviceId)) {
    appLogLog("RULE", "motion_skip",
              "\"sensor\":\"%s\",\"configured_sensor\":\"%s\","
              "\"reason\":\"sensor_no_match\"",
              sensorDeviceId, s_motionSensorId);
    return;
  }

  if (occupied) {
    if (s_motionOffPending) {
      s_motionOffPending = false;
      appLogLog("RULE", "motion_off_timer_canceled",
                "\"sensor\":\"%s\",\"reason\":\"reoccupied\"",
                sensorDeviceId);
    }

    bool sent = lightCtrlSetOn(s_motionLightId);
    appLogLog("RULE", sent ? "motion_on_sent" : "motion_on_skipped",
              "\"sensor\":\"%s\",\"light\":\"%s\"",
              sensorDeviceId, s_motionLightId);
    return;
  }

  s_motionOffPending = true;
  s_motionOffDeadline = msTick() + s_motionOffDelayMs;
  appLogLog("RULE", "motion_off_timer_scheduled",
            "\"sensor\":\"%s\",\"light\":\"%s\",\"delay_ms\":%u",
            sensorDeviceId, s_motionLightId, (unsigned)s_motionOffDelayMs);
}
