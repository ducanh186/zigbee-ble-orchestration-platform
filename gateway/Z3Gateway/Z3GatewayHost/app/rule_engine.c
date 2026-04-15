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

// ===== Public API =====

void ruleEngineInit(void)
{
  memset(s_bindings, 0, sizeof(s_bindings));
  memset(s_cooldown, 0, sizeof(s_cooldown));
  s_bindingCount = 0;

  // ---- V1 default bindings ----
  // These can be overridden by a future config-load mechanism.
  // For now, any switch event triggers toggle on the registered light.
  // We use "*" as a wildcard meaning "any switch".
  strncpy(s_bindings[0].switch_id, "*", sizeof(s_bindings[0].switch_id) - 1);
  strncpy(s_bindings[0].target_light_id, "*", sizeof(s_bindings[0].target_light_id) - 1);
  s_bindingCount = 1;

  appLogLog("RULE", "init", "\"bindings\":%d", s_bindingCount);
  emberAfCorePrintln("RULE: engine init, %d binding(s)", s_bindingCount);
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
      if ((int32_t)(now - cd->lastTriggerTick) < (int32_t)RULE_COOLDOWN_MS) {
        appLogLog("RULE", "cooldown",
                  "\"switch\":\"%s\",\"elapsed_ms\":%u",
                  switchDeviceId, (unsigned)(now - cd->lastTriggerTick));
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
