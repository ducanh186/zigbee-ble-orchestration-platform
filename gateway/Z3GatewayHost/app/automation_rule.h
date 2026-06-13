/***************************************************************************//**
 * @file automation_rule.h
 * @brief In-memory automation rule table driven by cloud MQTT desired sync.
 *
 * Contract: docs/AUTOMATION_MQTT_CONTRACT.md.
 *
 * This module ONLY stores and acks rules pushed from cloud via
 * `automations/{automation_id}/desired`. Rule execution (matching switch /
 * motion events to actions, sending ZCL frames) is intentionally out of scope
 * for Phase 2 and will be added in a later phase. The legacy hardcoded
 * `rule_engine.c` (env-gated switch->light relay) is unrelated and stays.
 ******************************************************************************/

#ifndef APP_AUTOMATION_RULE_H
#define APP_AUTOMATION_RULE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// MVP caps (contract §11).
#define AUTOMATION_MAX_RULES   16
#define AUTOMATION_MAX_ACTIONS 4

// Initialize the in-memory table. Idempotent; safe to call multiple times.
void automationRuleInit(void);

// Handle a desired MQTT payload routed in by app_mqtt's tick dispatcher.
// `topic` is the full topic string; `body` is the raw JSON envelope.
// On success or failure, publishes an `automations/{id}/reported` envelope
// (synced / failed / deleted). Never crashes on malformed input.
void automationRuleHandleMqttPayload(const char *topic, const char *body);

// Phase 3: switch toggle event hook.
// Call after the switch event has been ingested (telemetry_rx.c). Iterates
// the in-memory rule table; for every enabled rule whose trigger matches
// (device_type="switch", device_id=switch_device_id, event="switch_toggle"),
// executes the rule's actions via light_ctrl and publishes a single
// `automations/{id}/event` per matched rule.
//
// Cooldown: per-rule, default 500 ms — matches the legacy rule_engine.c
// pattern. Repeated triggers from the same switch within the cooldown are
// dropped silently (logged at TRACE level).
//
// Duplicate-action gate: switch automation is OFF by default to avoid
// double-toggle vs the Zigbee direct binding (switch firmware → light)
// that owns the local switch path in the Z3 reference design.
// To enable Phase 3 switch automation, set SB_AUTOMATION_SWITCH_HOOK=1
// at boot. Legacy SB_RULES_SWITCH_TO_LIGHT=1 also forces skip regardless.
void automationRuleOnSwitchToggle(const char *switch_device_id);

// Phase 3: motion occupancy_changed event hook.
// `occupancy` must be "occupied" or "unoccupied". Iterates the in-memory
// rule table; for every enabled rule whose trigger matches
// (device_type="motion", device_id=motion_device_id,
//  event="occupancy_changed", trigger.state.occupancy == occupancy),
// executes the rule's actions and publishes a single
// `automations/{id}/event` per matched rule.
void automationRuleOnMotionOccupancyChanged(const char *motion_device_id,
                                            const char *occupancy);

// Phase 5: environment threshold trigger hook.
// Called from telemetry_rx.c on each DHT11 measured-value report. `metric`
// is "temperature" or "humidity"; `value_centi` is the ZCL MeasuredValue in
// centi-units (2850 = 28.50C, 6500 = 65.00%RH). Iterates the rule table; for
// every enabled environment rule matching device_id+metric, fires
// (edge-triggered: only on the transition into "threshold met") when the
// value crosses the threshold per comparator.
void automationRuleOnEnvironmentReport(const char *device_id,
                                       const char *metric,
                                       int32_t value_centi);

#ifdef __cplusplus
}
#endif

#endif // APP_AUTOMATION_RULE_H
