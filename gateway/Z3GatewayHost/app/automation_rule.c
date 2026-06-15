/***************************************************************************//**
 * @file automation_rule.c
 * @brief In-memory automation rule table + desired/reported MQTT sync.
 *
 * See docs/AUTOMATION_MQTT_CONTRACT.md. Phase 2: storage + ack only; no
 * matching, no execution. Rule firing will be added in a later phase.
 ******************************************************************************/

#include "automation_rule.h"
#include "app_log.h"
#include "app_mqtt.h"
#include "app_utils.h"     // msTick()
#include "light_ctrl.h"    // lightCtrlLocalActionByDeviceId

#include <ctype.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "af.h"  // emberAfCorePrintln

// ----- Sizes (kept small; gateway is tight on RAM) -----
#define ID_MAX           48
#define NAME_MAX         96
#define DEVICE_ID_MAX    24
#define EVENT_NAME_MAX   24
#define COMMAND_MAX      8
#define OCCUPANCY_MAX    12

typedef enum {
  AUTO_DEV_UNKNOWN = 0,
  AUTO_DEV_SWITCH,
  AUTO_DEV_MOTION,
  AUTO_DEV_LIGHT,
  AUTO_DEV_ENVIRONMENT,
} AutomationDeviceType_t;

typedef enum { AUTO_METRIC_TEMPERATURE = 0, AUTO_METRIC_HUMIDITY } AutomationMetric_t;
typedef enum { AUTO_CMP_GTE = 0, AUTO_CMP_LTE } AutomationComparator_t;

typedef struct {
  AutomationDeviceType_t device_type;
  char device_id[DEVICE_ID_MAX];
  char command[COMMAND_MAX];   // "on" | "off" | "toggle"
} AutomationAction_t;

typedef struct {
  bool                    inUse;
  uint32_t                version;
  bool                    enabled;
  char                    id[ID_MAX];
  char                    name[NAME_MAX];
  // Trigger
  AutomationDeviceType_t  trig_device_type;
  char                    trig_device_id[DEVICE_ID_MAX];
  char                    trig_event[EVENT_NAME_MAX]; // switch_toggle | occupancy_changed
  char                    trig_occupancy[OCCUPANCY_MAX]; // occupied|unoccupied|""
  // Environment threshold trigger (trig_device_type == AUTO_DEV_ENVIRONMENT)
  AutomationMetric_t      trig_metric;       // temperature | humidity
  AutomationComparator_t  trig_comparator;   // gte | lte
  int32_t                 trig_threshold;    // centi-unit
  bool                    cond_met;          // runtime edge-trigger state
  // Actions
  uint8_t                 action_count;
  AutomationAction_t      actions[AUTOMATION_MAX_ACTIONS];
} AutomationRule_t;

static AutomationRule_t s_rules[AUTOMATION_MAX_RULES];

// Per-rule cooldown (anti-bounce). Same idea as rule_engine.c's
// `s_cooldown[]`. Indexed by slot. `lastFireMs` == 0 means never fired.
#define AUTOMATION_COOLDOWN_MS 500u
static uint32_t s_lastFireMs[AUTOMATION_MAX_RULES];

// Monotonically increasing run counter; goes into event `run_id` as
// "run_%08lx" so cloud Event Center can correlate gateway fires with logs.
static uint32_t s_runCounter = 0;

// Phase 3 execution gating.
//
//  * SB_AUTOMATION_EXECUTE  (default = "1")
//      Master enable flag. Set to "0" to keep storing/acking rules but
//      skip action execution entirely — useful for staged rollouts.
//
//  * SB_RULES_SWITCH_TO_LIGHT  (legacy, see rule_engine.c)
//      If "=1" at boot, the legacy hardcoded switch->light wildcard relay
//      is installed. We MUST NOT also fire automation actions on switch
//      events, or the light is toggled twice. Motion automation is
//      unaffected (legacy has no motion path).
//
//  * SB_AUTOMATION_SWITCH_HOOK  (default = "0", i.e. SKIP switch path)
//      The Z3 reference design owns the switch->light path via **Zigbee
//      direct binding** (switch client → light server). If the gateway
//      ALSO fires automation on switch_toggle, the light is toggled twice
//      per press → visible "snap-back" flicker. Default is OFF so the
//      gateway stays out of the way. Operators who have removed the
//      direct binding (e.g. a switch wired to a different light, or
//      switch with no binding at all) can opt in with "=1".
//      Motion path is unaffected.
//
// Resolved once at init and cached so we don't getenv() on every event.
static bool s_executeEnabled    = true;
static bool s_skipSwitchActions = true;   // default = skip (direct binding owns)

//---------------------------------------------------------------------------
// Small hand-rolled JSON helpers (mirror sb_command.c style; no cJSON dep).
// These are best-effort and treat the envelope as a flat key-value scan.
// They are NOT a general parser — they are good enough for the small,
// well-formed payloads our contract emits.
//---------------------------------------------------------------------------

static const char *findKey(const char *json, const char *keyWithQuotesAndColon)
{
  if (!json || !keyWithQuotesAndColon) return NULL;
  return strstr(json, keyWithQuotesAndColon);
}

// Skip whitespace and an optional opening quote; returns NULL on bad input.
static const char *skipToValueStart(const char *p)
{
  if (!p) return NULL;
  while (*p && isspace((unsigned char)*p)) p++;
  return p;
}

// Extract a quoted string value at p; returns true if extracted.
static bool readQuotedString(const char *p, char *out, uint32_t outSize)
{
  if (!p || !out || outSize == 0) return false;
  p = skipToValueStart(p);
  if (!p || *p != '"') return false;
  p++;
  uint32_t i = 0;
  while (*p && *p != '"' && i + 1 < outSize) {
    out[i++] = *p++;
  }
  out[i] = '\0';
  return (*p == '"');
}

// Find the first '{' / '[' that opens a section after the given key, then
// return a pointer to its first inner char. Sets `endOut` to the matching
// close char (one past last inner char). Returns NULL if not found.
static const char *findSection(const char *json, const char *keyAnchor,
                               char openCh, char closeCh,
                               const char **endOut)
{
  const char *p = findKey(json, keyAnchor);
  if (!p) return NULL;
  p += strlen(keyAnchor);
  p = skipToValueStart(p);
  if (!p || *p != openCh) return NULL;
  const char *inner = p + 1;
  int depth = 1;
  const char *q = inner;
  while (*q && depth > 0) {
    if (*q == openCh) depth++;
    else if (*q == closeCh) {
      depth--;
      if (depth == 0) break;
    }
    q++;
  }
  if (depth != 0) return NULL;
  if (endOut) *endOut = q;
  return inner;
}

static bool findQuotedStringIn(const char *json, const char *keyAnchor,
                               char *out, uint32_t outSize)
{
  if (!out || outSize == 0) return false;
  out[0] = '\0';
  const char *p = findKey(json, keyAnchor);
  if (!p) return false;
  p += strlen(keyAnchor);
  return readQuotedString(p, out, outSize);
}

static bool findUintIn(const char *json, const char *keyAnchor, uint32_t *out)
{
  if (!json || !keyAnchor || !out) return false;
  const char *p = findKey(json, keyAnchor);
  if (!p) return false;
  p += strlen(keyAnchor);
  p = skipToValueStart(p);
  if (!p) return false;
  uint32_t v = 0;
  bool any = false;
  while (*p && isdigit((unsigned char)*p)) {
    any = true;
    v = v * 10u + (uint32_t)(*p - '0');
    p++;
  }
  if (!any) return false;
  *out = v;
  return true;
}

static bool findBoolIn(const char *json, const char *keyAnchor, bool *out)
{
  if (!json || !keyAnchor || !out) return false;
  const char *p = findKey(json, keyAnchor);
  if (!p) return false;
  p += strlen(keyAnchor);
  p = skipToValueStart(p);
  if (!p) return false;
  if (strncmp(p, "true", 4) == 0) { *out = true; return true; }
  if (strncmp(p, "false", 5) == 0) { *out = false; return true; }
  return false;
}

//---------------------------------------------------------------------------
// Device type / command enum mapping
//---------------------------------------------------------------------------

static AutomationDeviceType_t parseDeviceType(const char *s)
{
  if (!s) return AUTO_DEV_UNKNOWN;
  if (strcmp(s, "switch") == 0) return AUTO_DEV_SWITCH;
  if (strcmp(s, "motion") == 0) return AUTO_DEV_MOTION;
  if (strcmp(s, "light")  == 0) return AUTO_DEV_LIGHT;
  if (strcmp(s, "environment") == 0) return AUTO_DEV_ENVIRONMENT;
  return AUTO_DEV_UNKNOWN;
}

static bool isAllowedTriggerEvent(const char *evt, AutomationDeviceType_t dt)
{
  if (!evt) return false;
  if (dt == AUTO_DEV_SWITCH) return strcmp(evt, "switch_toggle") == 0;
  if (dt == AUTO_DEV_MOTION) return strcmp(evt, "occupancy_changed") == 0;
  if (dt == AUTO_DEV_ENVIRONMENT) return strcmp(evt, "threshold_crossed") == 0;
  return false;
}

static bool isAllowedCommand(const char *cmd)
{
  if (!cmd) return false;
  return (strcmp(cmd, "on") == 0
       || strcmp(cmd, "off") == 0
       || strcmp(cmd, "toggle") == 0);
}

static bool parseMetric(const char *s, AutomationMetric_t *out)
{
  if (!s) return false;
  if (strcmp(s, "temperature") == 0) { *out = AUTO_METRIC_TEMPERATURE; return true; }
  if (strcmp(s, "humidity")    == 0) { *out = AUTO_METRIC_HUMIDITY;    return true; }
  return false;
}

static bool parseComparator(const char *s, AutomationComparator_t *out)
{
  if (!s) return false;
  if (strcmp(s, "gte") == 0) { *out = AUTO_CMP_GTE; return true; }
  if (strcmp(s, "lte") == 0) { *out = AUTO_CMP_LTE; return true; }
  return false;
}

// Cloud contract metric names (docs/handoffs/gateway-environment-sensor-contract.md):
// "temperature_c" / "humidity_percent". (Distinct from the telemetry-side
// "temperature"/"humidity" strings parseMetric handles.)
static bool parseEnvMetric(const char *s, AutomationMetric_t *out)
{
  if (!s) return false;
  if (strcmp(s, "temperature_c") == 0)    { *out = AUTO_METRIC_TEMPERATURE; return true; }
  if (strcmp(s, "humidity_percent") == 0) { *out = AUTO_METRIC_HUMIDITY;    return true; }
  return false;
}

// Parse a JSON number in whole units (optional '-', integer part, optional
// 1-2 decimal digits) at the key anchor and return it scaled to centi-units
// to match the ZCL MeasuredValue scale: 30 -> 3000, 28.5 -> 2850,
// -5.25 -> -525. Extra fractional digits beyond 2 are ignored.
static bool findCentiIn(const char *json, const char *keyAnchor, int32_t *out)
{
  if (!json || !keyAnchor || !out) return false;
  const char *p = findKey(json, keyAnchor);
  if (!p) return false;
  p += strlen(keyAnchor);
  p = skipToValueStart(p);
  if (!p) return false;

  bool neg = false;
  if (*p == '-') { neg = true; p++; }

  bool any = false;
  int32_t whole = 0;
  while (*p && isdigit((unsigned char)*p)) {
    any = true;
    whole = whole * 10 + (int32_t)(*p - '0');
    p++;
  }

  int32_t centiFrac = 0;
  if (*p == '.') {
    p++;
    int digits = 0;
    while (digits < 2 && *p && isdigit((unsigned char)*p)) {
      centiFrac = centiFrac * 10 + (int32_t)(*p - '0');
      p++;
      digits++;
    }
    if (digits == 1) centiFrac *= 10;   // ".5" -> 50 centi
    while (*p && isdigit((unsigned char)*p)) p++;  // ignore extra precision
  }

  if (!any) return false;
  int32_t val = whole * 100 + centiFrac;
  *out = neg ? -val : val;
  return true;
}

//---------------------------------------------------------------------------
// Topic helpers
//---------------------------------------------------------------------------

// Extract automation_id from topic ".../automations/{id}/desired".
// Writes null-terminated string into `out`. Returns true on success.
static bool extractAutomationIdFromTopic(const char *topic,
                                         char *out, uint32_t outSize)
{
  if (!topic || !out || outSize < 2) return false;
  const char *marker = strstr(topic, "/automations/");
  if (!marker) return false;
  const char *start = marker + strlen("/automations/");
  const char *end = strchr(start, '/');
  if (!end) return false;
  uint32_t n = (uint32_t)(end - start);
  if (n == 0 || n + 1 > outSize) return false;
  memcpy(out, start, n);
  out[n] = '\0';
  return true;
}

//---------------------------------------------------------------------------
// Table operations
//---------------------------------------------------------------------------

static int findSlotById(const char *id)
{
  for (int i = 0; i < AUTOMATION_MAX_RULES; i++) {
    if (s_rules[i].inUse && strcmp(s_rules[i].id, id) == 0) return i;
  }
  return -1;
}

static int findFreeSlot(void)
{
  for (int i = 0; i < AUTOMATION_MAX_RULES; i++) {
    if (!s_rules[i].inUse) return i;
  }
  return -1;
}

static int countInUse(void)
{
  int n = 0;
  for (int i = 0; i < AUTOMATION_MAX_RULES; i++) {
    if (s_rules[i].inUse) n++;
  }
  return n;
}

//---------------------------------------------------------------------------
// Reporting helpers
//---------------------------------------------------------------------------

static void publishReported(const char *automation_id,
                            uint32_t version,
                            const char *sync_status,
                            const char *last_error)
{
  if (!automation_id || !*automation_id || !sync_status) return;
  appMqttPublishAutomationReported(automation_id, version,
                                   sync_status, last_error);
}

//---------------------------------------------------------------------------
// Parse `actions` array entries
//---------------------------------------------------------------------------

static bool parseActionsArray(const char *body,
                              AutomationRule_t *rule,
                              const char **errOut)
{
  const char *arrEnd = NULL;
  const char *arr = findSection(body, "\"actions\":", '[', ']', &arrEnd);
  if (!arr) {
    if (errOut) *errOut = "invalid_payload";
    return false;
  }
  rule->action_count = 0;
  const char *p = arr;
  while (p < arrEnd) {
    while (p < arrEnd && (*p == ',' || isspace((unsigned char)*p))) p++;
    if (p >= arrEnd) break;
    if (*p != '{') {
      if (errOut) *errOut = "invalid_payload";
      return false;
    }
    // Find matching closing brace for this object
    int depth = 1;
    const char *objStart = p + 1;
    const char *q = objStart;
    while (q < arrEnd && depth > 0) {
      if (*q == '{') depth++;
      else if (*q == '}') {
        depth--;
        if (depth == 0) break;
      }
      q++;
    }
    if (depth != 0) {
      if (errOut) *errOut = "invalid_payload";
      return false;
    }
    // q now points to '}' of this object. We can use a NUL-bounded view via
    // copy, but the existing helpers are NUL-tolerant within objStart...q
    // since they only look for the key anchor and stop at non-numeric/non-
    // quoted chars before any subsequent ',}'. To be safe though, copy the
    // object into a small buffer.
    size_t objLen = (size_t)(q - objStart);
    if (objLen >= 256) {
      if (errOut) *errOut = "invalid_payload";
      return false;
    }
    char objBuf[256];
    memcpy(objBuf, objStart, objLen);
    objBuf[objLen] = '\0';

    if (rule->action_count >= AUTOMATION_MAX_ACTIONS) {
      if (errOut) *errOut = "rule_table_full";
      return false;
    }
    AutomationAction_t *a = &rule->actions[rule->action_count];
    memset(a, 0, sizeof(*a));

    char dtype[16] = {0};
    findQuotedStringIn(objBuf, "\"device_type\":", dtype, sizeof(dtype));
    a->device_type = parseDeviceType(dtype);
    if (a->device_type != AUTO_DEV_LIGHT) {
      if (errOut) *errOut = "unsupported_target";
      return false;
    }
    if (!findQuotedStringIn(objBuf, "\"device_id\":",
                            a->device_id, sizeof(a->device_id))) {
      if (errOut) *errOut = "invalid_payload";
      return false;
    }
    if (!findQuotedStringIn(objBuf, "\"command\":",
                            a->command, sizeof(a->command))) {
      if (errOut) *errOut = "invalid_payload";
      return false;
    }
    if (!isAllowedCommand(a->command)) {
      if (errOut) *errOut = "unsupported_target";
      return false;
    }
    rule->action_count++;
    p = q + 1;
  }
  if (rule->action_count == 0) {
    if (errOut) *errOut = "invalid_payload";
    return false;
  }
  return true;
}

//---------------------------------------------------------------------------
// Main entry — parse desired, mutate table, publish reported
//---------------------------------------------------------------------------

void automationRuleInit(void)
{
  memset(s_rules, 0, sizeof(s_rules));
  memset(s_lastFireMs, 0, sizeof(s_lastFireMs));
  s_runCounter = 0;

  // Resolve gating envs once.
  const char *envExec = getenv("SB_AUTOMATION_EXECUTE");
  s_executeEnabled = !(envExec != NULL && envExec[0] == '0');

  // Switch path is OFF by default to avoid double-toggle vs Zigbee direct
  // binding. Legacy SB_RULES_SWITCH_TO_LIGHT=1 forces skip regardless.
  const char *envLegacy = getenv("SB_RULES_SWITCH_TO_LIGHT");
  bool legacyOn = (envLegacy != NULL && envLegacy[0] == '1');
  const char *envHook = getenv("SB_AUTOMATION_SWITCH_HOOK");
  bool hookOn = (envHook != NULL && envHook[0] == '1');
  s_skipSwitchActions = legacyOn || !hookOn;

  appLogLog("AUTO", "init",
            "\"cap_rules\":%d,\"cap_actions\":%d,"
            "\"execute\":%s,\"skip_switch\":%s,"
            "\"legacy\":%s,\"hook\":%s",
            AUTOMATION_MAX_RULES, AUTOMATION_MAX_ACTIONS,
            s_executeEnabled ? "true" : "false",
            s_skipSwitchActions ? "true" : "false",
            legacyOn ? "true" : "false",
            hookOn ? "true" : "false");
}

//---------------------------------------------------------------------------
// Phase 3: event hooks (matching + execution + event publish)
//---------------------------------------------------------------------------

// Append a per-action JSON object (without surrounding braces of array) to
// `out` at offset `*off`. Returns false if the buffer would overflow.
static bool appendActionJson(char *out, size_t cap, size_t *off,
                             bool first,
                             const AutomationAction_t *a,
                             const char *status,
                             const char *reason)
{
  if (!out || !off) return false;
  const char *sep = first ? "" : ",";
  const char *reasonField = (reason && *reason) ? reason : NULL;
  char reasonBuf[64];
  if (reasonField) {
    snprintf(reasonBuf, sizeof(reasonBuf), "\"%s\"", reasonField);
  } else {
    snprintf(reasonBuf, sizeof(reasonBuf), "null");
  }
  int n = snprintf(out + *off, cap - *off,
    "%s{\"device_id\":\"%s\","
       "\"command\":\"%s\","
       "\"status\":\"%s\","
       "\"reason\":%s,"
       "\"command_id\":null}",
    sep, a->device_id, a->command, status, reasonBuf);
  if (n < 0 || (size_t)n >= cap - *off) return false;
  *off += (size_t)n;
  return true;
}

// Fire a single matched rule: execute its actions, build the event
// payload, publish to `automations/{id}/event`. Updates s_lastFireMs[slot].
static void fireRule(int slot,
                     const char *trigger_event,
                     const char *trigger_device_id,
                     const char *occupancy_or_null,
                     const char *metric_or_null,
                     int32_t value_centi)
{
  AutomationRule_t *r = &s_rules[slot];
  uint32_t now = msTick();
  s_lastFireMs[slot] = now ? now : 1u;   // never store 0 — would re-trigger
  uint32_t runIx = ++s_runCounter;

  char run_id[24];
  snprintf(run_id, sizeof(run_id), "run_%08lx", (unsigned long)runIx);

  // Actions section
  char actionsBuf[480];
  size_t aoff = 0;
  actionsBuf[0] = '\0';
  int okCount = 0;
  int failCount = 0;

  for (uint8_t i = 0; i < r->action_count; i++) {
    AutomationAction_t *a = &r->actions[i];
    bool ok = false;
    const char *failReason = NULL;
    if (!s_executeEnabled) {
      ok = false;
      failReason = "execute_disabled";
    } else if (a->device_type != AUTO_DEV_LIGHT) {
      ok = false;
      failReason = "unsupported_target";
    } else {
      ok = lightCtrlLocalActionByDeviceId(a->device_id, a->command);
      if (!ok) {
        // light_ctrl already logged the specific reason; report a
        // short stable string in the event for Cloud's Event Center.
        failReason = "send_failed";
      }
    }
    if (ok) okCount++; else failCount++;
    if (!appendActionJson(actionsBuf, sizeof(actionsBuf), &aoff,
                          (i == 0), a,
                          ok ? "executed" : "failed",
                          ok ? NULL : failReason)) {
      appLogLog("AUTO", "event_actions_overflow", "\"id\":\"%s\"", r->id);
      break;
    }
  }

  // Aggregate status
  const char *aggStatus = "executed";
  const char *aggError  = NULL;
  if (okCount == 0 && failCount > 0) {
    aggStatus = "failed";
    aggError  = "all_actions_failed";
  } else if (failCount > 0) {
    aggStatus = "failed";
    aggError  = "partial_failure";
  }
  if (!s_executeEnabled) {
    aggStatus = "skipped";
    aggError  = "execute_disabled";
  }

  // Trigger section
  char triggerBuf[160];
  if (metric_or_null && *metric_or_null) {
    snprintf(triggerBuf, sizeof(triggerBuf),
      "\"device_id\":\"%s\",\"event\":\"%s\",\"metric\":\"%s\",\"value\":%ld",
      trigger_device_id, trigger_event, metric_or_null, (long)value_centi);
  } else if (occupancy_or_null && *occupancy_or_null) {
    snprintf(triggerBuf, sizeof(triggerBuf),
      "\"device_id\":\"%s\",\"event\":\"%s\",\"occupancy\":\"%s\"",
      trigger_device_id, trigger_event, occupancy_or_null);
  } else {
    snprintf(triggerBuf, sizeof(triggerBuf),
      "\"device_id\":\"%s\",\"event\":\"%s\"",
      trigger_device_id, trigger_event);
  }

  // Inner payload (no outer braces — appMqttPublishAutomationEvent wraps).
  char inner[800];
  char errField[80];
  if (aggError) {
    snprintf(errField, sizeof(errField), "\"%s\"", aggError);
  } else {
    snprintf(errField, sizeof(errField), "null");
  }
  int n = snprintf(inner, sizeof(inner),
    "\"automation_id\":\"%s\","
    "\"event\":\"rule_fired\","
    "\"run_id\":\"%s\","
    "\"version\":%lu,"
    "\"trigger\":{%s},"
    "\"actions\":[%s],"
    "\"status\":\"%s\","
    "\"last_error\":%s",
    r->id, run_id, (unsigned long)r->version,
    triggerBuf, actionsBuf, aggStatus, errField);
  if (n < 0 || (size_t)n >= sizeof(inner)) {
    appLogLog("AUTO", "event_payload_overflow", "\"id\":\"%s\"", r->id);
    return;
  }

  appLogLog("AUTO", "fired",
    "\"id\":\"%s\",\"run_id\":\"%s\","
    "\"trigger\":\"%s\",\"status\":\"%s\","
    "\"actions_ok\":%d,\"actions_fail\":%d",
    r->id, run_id, trigger_event, aggStatus, okCount, failCount);

  appMqttPublishAutomationEvent(r->id, inner);
}

// Check cooldown for slot. Returns true if the rule MAY fire (cooldown
// has elapsed). Cooldown is per-rule.
static bool cooldownOk(int slot)
{
  uint32_t last = s_lastFireMs[slot];
  if (last == 0) return true;
  uint32_t now = msTick();
  uint32_t elapsed = now - last;
  return ((int32_t)elapsed >= (int32_t)AUTOMATION_COOLDOWN_MS);
}

void automationRuleOnSwitchToggle(const char *switch_device_id)
{
  if (!switch_device_id || !*switch_device_id) return;

  if (s_skipSwitchActions) {
    // Legacy SB_RULES_SWITCH_TO_LIGHT=1 is in charge of switch path;
    // staying out of the way avoids double-toggle.
    appLogLog("AUTO", "switch_skip_legacy",
              "\"device_id\":\"%s\"", switch_device_id);
    return;
  }

  for (int i = 0; i < AUTOMATION_MAX_RULES; i++) {
    AutomationRule_t *r = &s_rules[i];
    if (!r->inUse || !r->enabled) continue;
    if (r->trig_device_type != AUTO_DEV_SWITCH) continue;
    if (strcmp(r->trig_event, "switch_toggle") != 0) continue;
    if (strcmp(r->trig_device_id, switch_device_id) != 0) continue;
    if (!cooldownOk(i)) {
      appLogLog("AUTO", "cooldown",
                "\"id\":\"%s\",\"trigger\":\"switch_toggle\"", r->id);
      continue;
    }
    fireRule(i, "switch_toggle", switch_device_id, NULL, NULL, 0);
  }
}

void automationRuleOnMotionOccupancyChanged(const char *motion_device_id,
                                            const char *occupancy)
{
  if (!motion_device_id || !*motion_device_id
   || !occupancy || !*occupancy) return;

  for (int i = 0; i < AUTOMATION_MAX_RULES; i++) {
    AutomationRule_t *r = &s_rules[i];
    if (!r->inUse || !r->enabled) continue;
    if (r->trig_device_type != AUTO_DEV_MOTION) continue;
    if (strcmp(r->trig_event, "occupancy_changed") != 0) continue;
    if (strcmp(r->trig_device_id, motion_device_id) != 0) continue;
    if (strcmp(r->trig_occupancy, occupancy) != 0) continue;
    if (!cooldownOk(i)) {
      appLogLog("AUTO", "cooldown",
                "\"id\":\"%s\",\"trigger\":\"occupancy_changed\"", r->id);
      continue;
    }
    fireRule(i, "occupancy_changed", motion_device_id, occupancy, NULL, 0);
  }
}

void automationRuleOnEnvironmentReport(const char *device_id,
                                       const char *metric,
                                       int32_t value_centi)
{
  if (!device_id || !*device_id || !metric || !*metric) return;

  AutomationMetric_t m;
  if (!parseMetric(metric, &m)) return;

  for (int i = 0; i < AUTOMATION_MAX_RULES; i++) {
    AutomationRule_t *r = &s_rules[i];
    if (!r->inUse || !r->enabled) continue;
    if (r->trig_device_type != AUTO_DEV_ENVIRONMENT) continue;
    if (strcmp(r->trig_event, "threshold_crossed") != 0) continue;
    if (strcmp(r->trig_device_id, device_id) != 0) continue;
    if (r->trig_metric != m) continue;

    bool met = (r->trig_comparator == AUTO_CMP_GTE)
                 ? (value_centi >= r->trig_threshold)
                 : (value_centi <= r->trig_threshold);
    bool wasMet = r->cond_met;
    r->cond_met = met;                 // always track latest (edge detect)

    if (!met || wasMet) continue;      // fire only on transition into "met"

    if (!cooldownOk(i)) {
      appLogLog("AUTO", "cooldown",
                "\"id\":\"%s\",\"trigger\":\"threshold_crossed\"", r->id);
      continue;
    }
    fireRule(i, "threshold_crossed", device_id, NULL, metric, value_centi);
  }
}

void automationRuleHandleMqttPayload(const char *topic, const char *body)
{
  if (!topic || !body) return;

  char automation_id[ID_MAX] = {0};
  if (!extractAutomationIdFromTopic(topic, automation_id, sizeof(automation_id))) {
    // Topic doesn't carry an id; log and drop.
    appLogLog("AUTO", "drop_no_id", "\"topic\":\"%s\"", topic);
    return;
  }

  // Read `op`. Empty payload would be the retained-clear case (we don't use
  // it for delete in v1 — see contract §10 — but be lenient).
  char op[16] = {0};
  bool haveOp = findQuotedStringIn(body, "\"op\":", op, sizeof(op));
  bool isDelete = false;
  bool deletedFlag = false;
  (void)findBoolIn(body, "\"deleted\":", &deletedFlag);
  if (deletedFlag || (haveOp && strcmp(op, "delete") == 0)) {
    isDelete = true;
  }
  if (!isDelete && (!haveOp || strcmp(op, "upsert") != 0)) {
    publishReported(automation_id, 0, "failed", "unsupported_op");
    appLogLog("AUTO", "bad_op", "\"id\":\"%s\",\"op\":\"%s\"", automation_id, op);
    return;
  }

  // Version is required (contract §4.3 / §7).
  uint32_t versionU = 0;
  bool haveVersion = findUintIn(body, "\"version\":", &versionU);

  int slot = findSlotById(automation_id);

  if (isDelete) {
    if (slot >= 0) {
      s_rules[slot].inUse = false;
      memset(&s_rules[slot], 0, sizeof(s_rules[slot]));
    }
    appLogLog("AUTO", "delete", "\"id\":\"%s\",\"version\":%lu",
              automation_id, (unsigned long)(haveVersion ? versionU : 0));
    publishReported(automation_id, haveVersion ? versionU : 0,
                    "deleted", NULL);
    return;
  }

  // ----- upsert path -----
  if (!haveVersion) {
    publishReported(automation_id, 0, "failed", "invalid_payload");
    appLogLog("AUTO", "no_version", "\"id\":\"%s\"", automation_id);
    return;
  }

  if (slot >= 0 && s_rules[slot].version >= versionU) {
    // Stale or equal: idempotent ack with synced, do NOT reapply.
    appLogLog("AUTO", "stale", "\"id\":\"%s\",\"db_v\":%lu,\"in_v\":%lu",
              automation_id,
              (unsigned long)s_rules[slot].version,
              (unsigned long)versionU);
    publishReported(automation_id, s_rules[slot].version, "synced", NULL);
    return;
  }

  // Parse the rest of the payload into a scratch struct, then commit on success.
  AutomationRule_t parsed;
  memset(&parsed, 0, sizeof(parsed));
  parsed.version = versionU;
  strncpy(parsed.id, automation_id, sizeof(parsed.id) - 1);

  // name
  findQuotedStringIn(body, "\"name\":", parsed.name, sizeof(parsed.name));

  // enabled
  bool enabledFlag = true;
  if (findBoolIn(body, "\"enabled\":", &enabledFlag)) {
    parsed.enabled = enabledFlag;
  } else {
    parsed.enabled = true;
  }

  // trigger
  const char *trigEnd = NULL;
  const char *trig = findSection(body, "\"trigger\":", '{', '}', &trigEnd);
  if (!trig) {
    publishReported(automation_id, versionU, "failed", "invalid_payload");
    appLogLog("AUTO", "no_trigger", "\"id\":\"%s\"", automation_id);
    return;
  }
  // Copy trigger subobject into a buffer for safe key search
  size_t trigLen = (size_t)(trigEnd - trig);
  if (trigLen >= 256) {
    publishReported(automation_id, versionU, "failed", "invalid_payload");
    return;
  }
  char trigBuf[256];
  memcpy(trigBuf, trig, trigLen);
  trigBuf[trigLen] = '\0';

  char trig_dtype[16] = {0};
  findQuotedStringIn(trigBuf, "\"device_type\":", trig_dtype, sizeof(trig_dtype));
  parsed.trig_device_type = parseDeviceType(trig_dtype);
  // device-model-v2: the cloud unified occupancy (sensor kind 1) and
  // environment (sensor kind 2) under a single trigger device_type="sensor".
  // The gateway's matching model still distinguishes environment vs motion, so
  // map "sensor" back by the trigger discriminator: a "sensor_threshold" type
  // means environment; otherwise (an event-based trigger) it means motion.
  if (parsed.trig_device_type == AUTO_DEV_UNKNOWN
      && strcmp(trig_dtype, "sensor") == 0) {
    char v2TypeStr[24] = {0};
    if (findQuotedStringIn(trigBuf, "\"type\":", v2TypeStr, sizeof(v2TypeStr))
        && strcmp(v2TypeStr, "sensor_threshold") == 0) {
      parsed.trig_device_type = AUTO_DEV_ENVIRONMENT;
    } else {
      parsed.trig_device_type = AUTO_DEV_MOTION;
    }
  }
  if (parsed.trig_device_type != AUTO_DEV_SWITCH
   && parsed.trig_device_type != AUTO_DEV_MOTION
   && parsed.trig_device_type != AUTO_DEV_ENVIRONMENT) {
    publishReported(automation_id, versionU, "failed", "unsupported_trigger");
    return;
  }
  if (!findQuotedStringIn(trigBuf, "\"device_id\":",
                          parsed.trig_device_id,
                          sizeof(parsed.trig_device_id))) {
    publishReported(automation_id, versionU, "failed", "invalid_payload");
    return;
  }
  // Switch/motion carry an "event" field; environment carries a "type"
  // field instead (parsed in the environment block below).
  if (parsed.trig_device_type != AUTO_DEV_ENVIRONMENT) {
    if (!findQuotedStringIn(trigBuf, "\"event\":",
                            parsed.trig_event, sizeof(parsed.trig_event))) {
      publishReported(automation_id, versionU, "failed", "invalid_payload");
      return;
    }
    if (!isAllowedTriggerEvent(parsed.trig_event, parsed.trig_device_type)) {
      publishReported(automation_id, versionU, "failed", "unsupported_trigger");
      return;
    }
  }
  // Optional state.occupancy for motion
  if (parsed.trig_device_type == AUTO_DEV_MOTION) {
    findQuotedStringIn(trigBuf, "\"occupancy\":",
                       parsed.trig_occupancy, sizeof(parsed.trig_occupancy));
    if (strcmp(parsed.trig_occupancy, "occupied") != 0
     && strcmp(parsed.trig_occupancy, "unoccupied") != 0) {
      publishReported(automation_id, versionU, "failed", "unsupported_trigger");
      return;
    }
  }

  // Environment threshold trigger — cloud contract
  // (docs/handoffs/gateway-environment-sensor-contract.md):
  //   "type":"sensor_threshold",
  //   "metric":"temperature_c"|"humidity_percent",
  //   "operator":"gte"|"lte",
  //   "threshold":<number, whole units e.g. 30 or 28.5>
  // Stored as centi-units to match the ZCL MeasuredValue scale the runtime
  // hook compares against. trig_event is set to "threshold_crossed"
  // internally so the matching hook + event echo stay uniform.
  if (parsed.trig_device_type == AUTO_DEV_ENVIRONMENT) {
    char typeStr[24] = {0};
    char metricStr[20] = {0};
    char opStr[8] = {0};
    if (!findQuotedStringIn(trigBuf, "\"type\":", typeStr, sizeof(typeStr))
     || strcmp(typeStr, "sensor_threshold") != 0) {
      publishReported(automation_id, versionU, "failed", "unsupported_trigger");
      return;
    }
    if (!findQuotedStringIn(trigBuf, "\"metric\":", metricStr, sizeof(metricStr))
     || !parseEnvMetric(metricStr, &parsed.trig_metric)) {
      publishReported(automation_id, versionU, "failed", "unsupported_trigger");
      return;
    }
    if (!findQuotedStringIn(trigBuf, "\"operator\":", opStr, sizeof(opStr))
     || !parseComparator(opStr, &parsed.trig_comparator)) {
      publishReported(automation_id, versionU, "failed", "unsupported_trigger");
      return;
    }
    if (!findCentiIn(trigBuf, "\"threshold\":", &parsed.trig_threshold)) {
      publishReported(automation_id, versionU, "failed", "invalid_payload");
      return;
    }
    strncpy(parsed.trig_event, "threshold_crossed",
            sizeof(parsed.trig_event) - 1);
    parsed.cond_met = false;   // first crossing should fire
  }

  // actions
  const char *actErr = NULL;
  if (!parseActionsArray(body, &parsed, &actErr)) {
    publishReported(automation_id, versionU, "failed",
                    actErr ? actErr : "invalid_payload");
    return;
  }

  // Commit into table
  if (slot < 0) {
    if (countInUse() >= AUTOMATION_MAX_RULES) {
      publishReported(automation_id, versionU, "failed", "rule_table_full");
      appLogLog("AUTO", "full", "\"id\":\"%s\"", automation_id);
      return;
    }
    slot = findFreeSlot();
  }
  parsed.inUse = true;
  s_rules[slot] = parsed;

  appLogLog("AUTO", "upsert",
            "\"id\":\"%s\",\"version\":%lu,\"enabled\":%s,\"actions\":%u",
            parsed.id, (unsigned long)parsed.version,
            parsed.enabled ? "true" : "false",
            (unsigned)parsed.action_count);
  publishReported(automation_id, versionU, "synced", NULL);
}
