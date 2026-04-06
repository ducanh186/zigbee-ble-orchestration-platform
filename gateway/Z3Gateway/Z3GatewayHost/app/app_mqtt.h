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

#ifdef __cplusplus
}
#endif

#endif // APP_MQTT_H
