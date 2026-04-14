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
void appMqttPublishDeviceReported(uint16_t nodeId, const char *eui64Str,
                                  const char *deviceType, const char *powerState);

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
