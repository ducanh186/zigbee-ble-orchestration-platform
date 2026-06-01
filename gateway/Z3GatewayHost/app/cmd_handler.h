#ifndef CMD_HANDLER_H
#define CMD_HANDLER_H

// Legacy CLI / stdio path: receives full "@CMD {..json..}" lines.
// Flat schema {"id":N,"op":"..."} with legacy ops (valve_set, mode_set, ...).
// Kept for CLI/debug back-compat; NOT used by the MQTT path.
void cmdHandleLine(const char *line);

// sb/v1 MQTT path: parser -> dispatcher -> device module.
// `topic` must include ".../commands/{command_id}/request".
// `body`  is the raw MQTT payload (sb.v1 envelope JSON).
// Emits command_reply lifecycle messages via app_mqtt.
void cmdHandleMqttPayload(const char *topic, const char *body);

#endif
