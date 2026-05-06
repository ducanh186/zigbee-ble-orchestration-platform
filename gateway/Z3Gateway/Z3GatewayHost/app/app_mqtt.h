#ifndef APP_MQTT_H
#define APP_MQTT_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize mosquitto library and create client instance.
// Must be called before appMqttStart().
void appMqttInit(void);

// Connect to broker and start threaded network loop.
void appMqttStart(void);

// Publish a message.  topicSuffix is relative to the sb/v1 prefix,
// e.g. "gateway/online".  Returns MOSQ_ERR_SUCCESS on success.
int appMqttPublish(const char *topicSuffix, const char *payload,
                   int qos, bool retain);

// Drain inbound message queue.  Call from emberAfMainTickCallback().
void appMqttTick(void);

// Publish device reported state (e.g. light on/off).
// nodeId: Zigbee short address (for nwk_addr field)
// eui64Str: hex string like "0b57fffe1234abcd" (used as device_id and topic key)
// deviceType: e.g. "light"
// powerState: e.g. "on" or "off"
// level: brightness level 0-254 (only meaningful for light; pass 0 for non-dimmable)
void appMqttPublishDeviceReported(uint16_t nodeId, const char *eui64Str,
                                  const char *deviceType, const char *powerState);

// Extended reported with level field (Phase 3.1).
void appMqttPublishDeviceReportedFull(uint16_t nodeId, const char *eui64Str,
                                      const char *deviceType, const char *powerState,
                                      uint8_t level);

// Publish a device event (e.g. switch toggle).
// Per MQTT_CONTRACT: devices/{device_type}/{device_id}/event (QoS1, no retain).
// eventName: e.g. "toggle"
void appMqttPublishDeviceEvent(uint16_t nodeId, const char *eui64Str,
                               const char *deviceType, const char *eventName);

// Publish a retained device registry snapshot on
// `devices/{device_type}/{eui64Str}/registry` (QoS 1, retained, per MQTT_CONTRACT).
// Used at pairing time so any subscriber (e.g. cloud) that connects later
// immediately receives the device's identity and inferred capabilities.
// clusters/endpoints are MVP-inferred by device_type; metadata_source is set
// to "gateway_mvp_inferred" so cloud can mark these as provisional.
void appMqttPublishDeviceRegistry(uint16_t nodeId, const char *eui64Str,
                                  const char *deviceType);

// Clear retained registry snapshots for `eui64Str` under EVERY known
// device_type EXCEPT `keepType`.  Implemented by publishing an empty payload
// with retain=1 to each of the OTHER `devices/{type}/{eui64Str}/registry`
// topics, so the broker drops the retained slot.  Called by the discovery
// completion path so a corrected classification is the only retained
// registry the broker holds for a given EUI64.
void appMqttClearRetainedRegistry(const char *eui64Str, const char *keepType);

// Publish a gateway health snapshot on `gateway/health` (QoS 1, retained).
// uptime_ms: monotonic uptime since appMqttInit, known_device_count: from
// device_registry, network_state: short string such as "up"|"down"|"unknown".
void appMqttPublishGatewayHealth(uint64_t uptime_ms, bool mqttConnected,
                                 uint32_t knownDeviceCount,
                                 const char *networkState);

// Publish a gateway-level event on topic `gateway/event` (QoS 1, no retain).
// Per MQTT_CONTRACT: envelope is sb.v1; payload contains {"event":"<name>", ...}.
// `eventName` MUST be non-empty (e.g. "permit_join_opened").
// `extraJson` may be NULL or empty; when non-empty it is appended as raw JSON
// fields (without surrounding braces) -- caller must format it correctly.
void appMqttPublishGatewayEvent(const char *eventName, const char *extraJson);

// Publish a command_reply message on topic commands/{command_id}/reply.
// Payload always contains: command_id, device_id, status, reason (per MQTT_CONTRACT).
// `device_id` may be NULL/empty (e.g. parse_fail before we extracted it);
//             in that case the field is emitted as null.
// `status`    e.g. "accepted" | "queued" | "sent" | "executed" | "failed" | "timeout"
// `reason`    may be NULL; emitted as null JSON when absent.
void appMqttPublishCommandReply(const char *command_id,
                                const char *device_id,
                                const char *status,
                                const char *reason);

#ifdef __cplusplus
}
#endif

#endif // APP_MQTT_H
