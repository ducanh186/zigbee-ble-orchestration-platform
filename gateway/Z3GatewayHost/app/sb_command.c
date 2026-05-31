#include "sb_command.h"
#include "app_utils.h"

#include <string.h>
#include <stdio.h>
#include <ctype.h>

// Extract "{cmd}" out of ".../commands/{cmd}/request".
bool sbCommandExtractIdFromTopic(const char *topic, char *out, uint32_t outSize)
{
  if (!topic || !out || outSize < 2) return false;

  const char *marker = strstr(topic, "/commands/");
  if (!marker) return false;

  const char *start = marker + strlen("/commands/");
  const char *end = strchr(start, '/');
  if (!end) return false;

  uint32_t n = (uint32_t)(end - start);
  if (n == 0 || n + 1 > outSize) return false;

  memcpy(out, start, n);
  out[n] = '\0';
  return true;
}

// Small helper: find a quoted string value for a key that is explicit with ':'.
// e.g. lookKey = "\"command\":" to disambiguate from "command_id".
static bool findQuotedString(const char *json, const char *lookKey,
                             char *out, uint32_t outSize)
{
  if (!json || !lookKey || !out || outSize == 0) return false;

  const char *p = strstr(json, lookKey);
  if (!p) return false;
  p += strlen(lookKey);
  while (*p && isspace((unsigned char)*p)) p++;
  if (*p != '"') return false;
  p++;

  uint32_t i = 0;
  while (*p && *p != '"' && i + 1 < outSize) {
    out[i++] = *p++;
  }
  out[i] = '\0';
  return (*p == '"');
}

// Small helper: find a decimal uint value for a key with ':' anchor.
static bool findUintExact(const char *json, const char *lookKey, uint32_t *out)
{
  if (!json || !lookKey || !out) return false;

  const char *p = strstr(json, lookKey);
  if (!p) return false;
  p += strlen(lookKey);
  while (*p && isspace((unsigned char)*p)) p++;

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

bool sbCommandIsGatewayOp(const char *op)
{
  // Any op prefixed "gateway." is gateway-scoped (no device target).
  return (op != NULL && strncmp(op, "gateway.", 8) == 0);
}

bool sbCommandParse(const char *topic, const char *body, sb_command_t *out)
{
  if (!out) return false;
  memset(out, 0, sizeof(*out));
  out->timeout_ms = 5000u;

  // command_id comes from topic, not body
  if (!sbCommandExtractIdFromTopic(topic, out->command_id, sizeof(out->command_id))) {
    return false;
  }

  if (!body) return false;

  // correlation_id (optional; envelope-level)
  (void)findQuotedString(body, "\"correlation_id\":",
                         out->correlation_id, sizeof(out->correlation_id));

  // op (required regardless of target kind) -- parse first so we can decide
  // whether device_id is mandatory.
  if (!findQuotedString(body, "\"op\":", out->op, sizeof(out->op))) {
    return false;
  }

  // device_id: required for device-targeted ops, optional for gateway ops.
  bool haveDeviceId = findQuotedString(body, "\"device_id\":",
                                       out->device_id, sizeof(out->device_id));
  if (!haveDeviceId && !sbCommandIsGatewayOp(out->op)) {
    return false;
  }

  // device_type (optional)
  (void)findQuotedString(body, "\"device_type\":",
                         out->device_type, sizeof(out->device_type));

  // target.endpoint, target.cluster_id, target.command  (device ops)
  uint32_t ep = 0;
  if (findUintExact(body, "\"endpoint\":", &ep)) {
    out->endpoint = (int)ep;
  }
  (void)findQuotedString(body, "\"cluster_id\":",
                         out->cluster_id, sizeof(out->cluster_id));
  (void)findQuotedString(body, "\"command\":",
                         out->command, sizeof(out->command));

  // target.duration_sec (gateway ops, e.g. open_network)
  uint32_t dsec = 0;
  if (findUintExact(body, "\"duration_sec\":", &dsec)) {
    out->duration_sec = (int)dsec;
  }
  char eui64[18] = {0};
  if (findQuotedString(body, "\"eui64\":", eui64, sizeof(eui64))
      && strlen(eui64) < sizeof(out->eui64)) {
    strncpy(out->eui64, eui64, sizeof(out->eui64) - 1);
  }

  char installCode[38] = {0};
  if (findQuotedString(body, "\"install_code\":",
                       installCode, sizeof(installCode))
      && strlen(installCode) < sizeof(out->install_code)) {
    strncpy(out->install_code, installCode, sizeof(out->install_code) - 1);
  }

  // timeout_ms (optional)
  uint32_t t = 0;
  if (findUintExact(body, "\"timeout_ms\":", &t) && t > 0) {
    out->timeout_ms = t;
  }

  return true;
}
