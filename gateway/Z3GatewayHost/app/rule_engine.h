#ifndef RULE_ENGINE_H
#define RULE_ENGINE_H

// Minimal rule engine for gateway-driven local automation (Phase 4).
//
// V1 scope:
//   * Config-driven switch-to-light bindings
//   * switch event -> rule lookup -> light toggle
//   * Anti-loop: only triggers from switch events, never from reported state
//
// Design:
//   * Bindings are compiled-in for v1 (future: load from file/MQTT)
//   * Rule dispatch calls lightCtrlLocalToggle() directly (no command tracking)
//   * Cloud sees: switch event + light reported (after toggle)

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize rule engine bindings.
// Call once from emberAfMainInitCallback().
void ruleEngineInit(void);

// Called when a switch event is detected.
// switchDeviceId: the eui64 string of the switch that fired.
// This is the ONLY entry point for rule dispatch (anti-loop: Phase 4.3).
// It will NOT be called from light reported state changes.
void ruleEngineOnSwitchEvent(const char *switchDeviceId);

#ifdef __cplusplus
}
#endif

#endif // RULE_ENGINE_H
