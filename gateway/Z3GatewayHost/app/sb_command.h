#ifndef SB_COMMAND_H
#define SB_COMMAND_H

// Parser layer for sb/v1 MQTT command payloads.
//
// This module knows ONLY the wire schema:
//   topic:   sb/v1/{tenant}/{site}/{gateway}/commands/{command_id}/request
//   body:    sb.v1 envelope with payload = { device_id, op, target: {...}, ... }
//
// It produces a normalized struct; it does NOT know about Zigbee.

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  // Identity from topic
  char command_id[64];      // extracted from .../commands/{command_id}/request

  // Correlation / tracing (optional, from envelope)
  char correlation_id[64];  // empty if absent (falls back to command_id downstream)

  // Target device
  char device_id[64];       // required: payload.device_id
  char device_type[32];     // optional: payload.device_type ("light"/"switch"/"motion")

  // Op and target
  char op[32];              // e.g. "device.command", "gateway.open_network"
  int  endpoint;            // payload.target.endpoint (0 if absent)
  char cluster_id[16];      // payload.target.cluster_id (string form, e.g. "0x0006")
  char command[32];         // payload.target.command (e.g. "on", "off")

  // device.set_room only: payload.target.room_id (cloud room id string)
  char room_id[40];

  // Gateway-targeted ops only
  // (parsed from payload.target.duration_sec; 0 means absent)
  int  duration_sec;
  char eui64[17];          // payload.target.eui64 for gateway.prepare_join
  char install_code[37];   // payload.target.install_code hex incl 2-byte CRC

  // Optional
  uint32_t timeout_ms;      // default 5000 if absent
} sb_command_t;

// Helper: returns true when the op targets the gateway itself
// (e.g. "gateway.open_network", "gateway.close_network").  Such ops do not
// require a device_id in the payload.
bool sbCommandIsGatewayOp(const char *op);

// Extract {command_id} out of a topic like ".../commands/{cmd}/request".
// Returns true on success.
bool sbCommandExtractIdFromTopic(const char *topic, char *out, uint32_t outSize);

// Parse a sb/v1 envelope body + topic into sb_command_t.
// Returns true on success. On failure, out->command_id is still populated if possible
// so the caller can emit a "failed" reply.
bool sbCommandParse(const char *topic, const char *body, sb_command_t *out);

#ifdef __cplusplus
}
#endif

#endif // SB_COMMAND_H
