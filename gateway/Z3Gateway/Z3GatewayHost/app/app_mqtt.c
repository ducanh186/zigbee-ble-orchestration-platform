/***************************************************************************//**
 * @file app_mqtt.c
 * @brief MQTT client module for Z3GatewayHost (libmosquitto).
 ******************************************************************************/

#define _POSIX_C_SOURCE 200112L  // gmtime_r, gettimeofday

#include "app_mqtt.h"
#include "app_log.h"
#include "cmd_handler.h"

#include <mosquitto.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>
#include <sys/time.h>

#include "af.h"  // emberAfCorePrintln

// ===== Broker connection defaults =====
// Overridable at runtime via environment variables:
//   SB_MQTT_HOST, SB_MQTT_PORT, SB_MQTT_USERNAME, SB_MQTT_PASSWORD
#define MQTT_CLIENT_ID        "z3gw-host"
#define MQTT_HOST_DEFAULT     "98.83.4.87"
#define MQTT_PORT_DEFAULT     1883
#define MQTT_KEEPALIVE        60
#define MQTT_USERNAME_DEFAULT "gateway"
#define MQTT_PASSWORD_DEFAULT "gateway123"

// Reconnect: 1 s initial, 30 s max, exponential backoff
#define MQTT_RECONN_MIN  1
#define MQTT_RECONN_MAX  30

// Runtime broker config (resolved once in appMqttInit from env)
static const char *sMqttHost     = MQTT_HOST_DEFAULT;
static int         sMqttPort     = MQTT_PORT_DEFAULT;
static const char *sMqttUsername = MQTT_USERNAME_DEFAULT;
static const char *sMqttPassword = MQTT_PASSWORD_DEFAULT;

// ===== Topic contract (sb/v1 namespace) =====
#define MQTT_TENANT  "hust"
#define MQTT_SITE    "lab01"
#define MQTT_GW_ID   "gw-ubuntu-01"
#define MQTT_PREFIX  "sb/v1/" MQTT_TENANT "/" MQTT_SITE "/" MQTT_GW_ID

// ===== Inbound command queue =====
#define MQTT_Q_SIZE         8
#define MQTT_Q_TOPIC_MAX    160
#define MQTT_Q_PAYLOAD_MAX  512

typedef struct {
  char topic[MQTT_Q_TOPIC_MAX];
  char payload[MQTT_Q_PAYLOAD_MAX];
  int  qos;
} MqttQEntry_t;

typedef struct {
  MqttQEntry_t    entries[MQTT_Q_SIZE];
  uint8_t         head;   // next write (mosquitto thread)
  uint8_t         tail;   // next read  (main thread)
  pthread_mutex_t lock;
} MqttCmdQueue_t;

static struct mosquitto *sMosq = NULL;
static MqttCmdQueue_t    sCmdQ;
static uint32_t          sMsgId = 0;

//----------------------------------------------------------------------
// Helpers
//----------------------------------------------------------------------

static void iso8601Now(char *buf, size_t len)
{
  struct timeval tv;
  gettimeofday(&tv, NULL);
  struct tm tm;
  gmtime_r(&tv.tv_sec, &tm);
  int n = (int)strftime(buf, len, "%Y-%m-%dT%H:%M:%S", &tm);
  snprintf(buf + n, len - (size_t)n, ".%03dZ", (int)(tv.tv_usec / 1000));
}

// Build a minimal sb.v1 envelope.  Caller supplies the inner payload JSON
// (without outer braces).  Result written to buf.
static int buildEnvelope(char *buf, size_t len, const char *innerPayloadJson)
{
  char ts[32];
  iso8601Now(ts, sizeof(ts));
  uint32_t id = ++sMsgId;

  return snprintf(buf, len,
    "{\"schema\":\"sb.v1\","
     "\"msg_id\":\"%lu\","
     "\"ts\":\"%s\","
     "\"tenant_id\":\"" MQTT_TENANT "\","
     "\"site_id\":\"" MQTT_SITE "\","
     "\"gateway_id\":\"" MQTT_GW_ID "\","
     "\"source\":\"gateway\","
     "\"payload\":{%s}}",
    (unsigned long)id, ts, innerPayloadJson);
}

//----------------------------------------------------------------------
// Command queue (lock-based ring buffer)
//----------------------------------------------------------------------

static void mqttQueueInit(void)
{
  pthread_mutex_init(&sCmdQ.lock, NULL);
  sCmdQ.head = 0;
  sCmdQ.tail = 0;
}

// Called on mosquitto thread.  Returns true if enqueued.
static bool mqttQueuePush(const char *topic, const void *payload,
                          int payloadLen, int qos)
{
  bool ok = false;
  pthread_mutex_lock(&sCmdQ.lock);

  uint8_t next = (sCmdQ.head + 1) % MQTT_Q_SIZE;
  if (next != sCmdQ.tail) {
    MqttQEntry_t *e = &sCmdQ.entries[sCmdQ.head];

    // Copy topic (ensure null-terminated)
    size_t tlen = strlen(topic);
    if (tlen >= MQTT_Q_TOPIC_MAX) tlen = MQTT_Q_TOPIC_MAX - 1;
    memcpy(e->topic, topic, tlen);
    e->topic[tlen] = '\0';

    // Copy payload (may not be null-terminated from mosquitto)
    int plen = payloadLen;
    if (plen >= MQTT_Q_PAYLOAD_MAX) plen = MQTT_Q_PAYLOAD_MAX - 1;
    if (plen > 0) memcpy(e->payload, payload, (size_t)plen);
    e->payload[plen] = '\0';

    e->qos = qos;
    sCmdQ.head = next;
    ok = true;
  }

  pthread_mutex_unlock(&sCmdQ.lock);
  return ok;
}

// Called on main thread.  Returns true if an entry was popped.
static bool mqttQueuePop(MqttQEntry_t *out)
{
  bool ok = false;
  pthread_mutex_lock(&sCmdQ.lock);

  if (sCmdQ.head != sCmdQ.tail) {
    *out = sCmdQ.entries[sCmdQ.tail];
    sCmdQ.tail = (sCmdQ.tail + 1) % MQTT_Q_SIZE;
    ok = true;
  }

  pthread_mutex_unlock(&sCmdQ.lock);
  return ok;
}

// Forward declaration (used by onConnect before definition)
int appMqttPublish(const char *topicSuffix, const char *payload,
                   int qos, bool retain);

//----------------------------------------------------------------------
// Mosquitto callbacks
//----------------------------------------------------------------------

static void onConnect(struct mosquitto *mosq, void *userdata, int rc)
{
  (void)userdata;
  if (rc != 0) {
    emberAfCorePrintln("MQTT: connect failed rc=%d", rc);
    appLogLog("mqtt", "conn_fail", "rc=%d", rc);
    return;
  }

  emberAfCorePrintln("MQTT: connected to %s:%d", sMqttHost, sMqttPort);
  appLogLog("mqtt", "connected", "\"broker\":\"%s\",\"port\":%d", sMqttHost, sMqttPort);

  // Publish gateway/online (counterpart to LWT)
  char env[512];
  buildEnvelope(env, sizeof(env), "\"value\":\"online\"");
  appMqttPublish("gateway/online", env, 1, true);

  // Subscribe to command requests
  int sr = mosquitto_subscribe(mosq, NULL,
               MQTT_PREFIX "/commands/+/request", 1);
  if (sr != MOSQ_ERR_SUCCESS) {
    emberAfCorePrintln("MQTT: subscribe failed: %s", mosquitto_strerror(sr));
    appLogLog("mqtt", "sub_fail", "\"rc\":%d,\"text\":\"%s\"",
              sr, mosquitto_strerror(sr));
  } else {
    emberAfCorePrintln("MQTT: subscribed to " MQTT_PREFIX "/commands/+/request");
    appLogLog("mqtt", "subscribed",
              "\"topic\":\"" MQTT_PREFIX "/commands/+/request\",\"qos\":1");
  }
}

static void onDisconnect(struct mosquitto *mosq, void *userdata, int rc)
{
  (void)mosq;
  (void)userdata;
  if (rc == 0) {
    emberAfCorePrintln("MQTT: clean disconnect");
  } else {
    emberAfCorePrintln("MQTT: unexpected disconnect rc=%d", rc);
    appLogLog("mqtt", "disconnected", "rc=%d", rc);
  }
}

static void onMessage(struct mosquitto *mosq, void *userdata,
                      const struct mosquitto_message *msg)
{
  (void)mosq;
  (void)userdata;
  if (!msg || !msg->topic || !msg->payload) return;

  emberAfCorePrintln("MQTT: rx [%s] (%d bytes)", msg->topic, msg->payloadlen);

  if (!mqttQueuePush(msg->topic, msg->payload, msg->payloadlen, msg->qos)) {
    emberAfCorePrintln("MQTT: cmd queue full, dropped");
  }
}

static void onLog(struct mosquitto *mosq, void *userdata, int level, const char *str)
{
  (void)mosq;
  (void)userdata;
  (void)level;
  emberAfCorePrintln("MQTT-lib: %s", str);
}

//----------------------------------------------------------------------
// Public API
//----------------------------------------------------------------------

void appMqttInit(void)
{
  int ret;

  // Resolve broker config from environment (SB_MQTT_* matches cloud convention)
  const char *envHost = getenv("SB_MQTT_HOST");
  if (envHost && envHost[0]) sMqttHost = envHost;

  const char *envPort = getenv("SB_MQTT_PORT");
  if (envPort && envPort[0]) sMqttPort = atoi(envPort);
  if (sMqttPort <= 0) sMqttPort = MQTT_PORT_DEFAULT;

  const char *envUser = getenv("SB_MQTT_USERNAME");
  if (envUser && envUser[0]) sMqttUsername = envUser;

  const char *envPass = getenv("SB_MQTT_PASSWORD");
  if (envPass && envPass[0]) sMqttPassword = envPass;

  emberAfCorePrintln("MQTT: config host=%s port=%d user=%s",
                     sMqttHost, sMqttPort, sMqttUsername);

  ret = mosquitto_lib_init();
  if (ret != MOSQ_ERR_SUCCESS) {
    emberAfCorePrintln("MQTT: lib_init failed: %s", mosquitto_strerror(ret));
    return;
  }

  sMosq = mosquitto_new(MQTT_CLIENT_ID, true, NULL);
  if (!sMosq) {
    emberAfCorePrintln("MQTT: mosquitto_new failed (out of memory)");
    return;
  }

  mosquitto_connect_callback_set(sMosq, onConnect);
  mosquitto_disconnect_callback_set(sMosq, onDisconnect);
  mosquitto_message_callback_set(sMosq, onMessage);
  mosquitto_log_callback_set(sMosq, onLog);
  mosquitto_reconnect_delay_set(sMosq, MQTT_RECONN_MIN, MQTT_RECONN_MAX, true);

  // Authenticate with broker
  mosquitto_username_pw_set(sMosq, sMqttUsername, sMqttPassword);

  // Initialize inbound command queue
  mqttQueueInit();

  // LWT: broker publishes this if we disconnect ungracefully
  char lwt[512];
  buildEnvelope(lwt, sizeof(lwt), "\"value\":\"offline\"");
  mosquitto_will_set(sMosq, MQTT_PREFIX "/gateway/online",
                     (int)strlen(lwt), lwt, 1, true);

  emberAfCorePrintln("MQTT: client initialized (id=%s)", MQTT_CLIENT_ID);
}

void appMqttStart(void)
{
  int ret;

  if (!sMosq) {
    emberAfCorePrintln("MQTT: cannot start, client not initialized");
    return;
  }

  ret = mosquitto_connect_async(sMosq, sMqttHost, sMqttPort, MQTT_KEEPALIVE);
  if (ret != MOSQ_ERR_SUCCESS) {
    emberAfCorePrintln("MQTT: connect_async failed: %s", mosquitto_strerror(ret));
    return;
  }

  ret = mosquitto_loop_start(sMosq);
  if (ret != MOSQ_ERR_SUCCESS) {
    emberAfCorePrintln("MQTT: loop_start failed: %s", mosquitto_strerror(ret));
    return;
  }

  emberAfCorePrintln("MQTT: connecting to %s:%d ...", sMqttHost, sMqttPort);
}

int appMqttPublish(const char *topicSuffix, const char *payload,
                   int qos, bool retain)
{
  if (!sMosq) return MOSQ_ERR_INVAL;

  char fullTopic[192];
  snprintf(fullTopic, sizeof(fullTopic), "%s/%s", MQTT_PREFIX, topicSuffix);

  int rc = mosquitto_publish(sMosq, NULL, fullTopic,
                             (int)strlen(payload), payload, qos, retain);
  if (rc != MOSQ_ERR_SUCCESS) {
    emberAfCorePrintln("MQTT: publish failed: %s", mosquitto_strerror(rc));
  } else {
    emberAfCorePrintln("MQTT: pub [%s] (%d bytes)", fullTopic, (int)strlen(payload));
  }
  return rc;
}

void appMqttTick(void)
{
  MqttQEntry_t entry;

  // Drain up to 4 messages per tick to avoid starving the main loop
  for (int i = 0; i < 4; i++) {
    if (!mqttQueuePop(&entry)) break;

    emberAfCorePrintln("MQTT: processing [%s]", entry.topic);
    appLogLog("mqtt", "rx_process", "topic=%s", entry.topic);

    // Route to the sb/v1 command handler: parser -> dispatcher -> device module.
    // (Legacy `@CMD`-over-stdio remains available via `cmdHandleLine` for CLI.)
    cmdHandleMqttPayload(entry.topic, entry.payload);
  }
}

void appMqttPublishDeviceReported(uint16_t nodeId, const char *eui64Str,
                                  const char *deviceType, const char *powerState)
{
  // Delegate to full version with level=0 for backward compat
  appMqttPublishDeviceReportedFull(nodeId, eui64Str, deviceType, powerState, 0);
}

void appMqttPublishDeviceReportedFull(uint16_t nodeId, const char *eui64Str,
                                      const char *deviceType, const char *powerState,
                                      uint8_t level)
{
  if (!sMosq) return;

  // Build inner payload JSON (Phase 3.1: include level for light)
  char inner[320];
  snprintf(inner, sizeof(inner),
    "\"device_id\":\"%s\","
    "\"device_type\":\"%s\","
    "\"eui64\":\"%s\","
    "\"nwk_addr\":\"0x%04X\","
    "\"state\":{\"power\":\"%s\",\"level\":%u,\"reachable\":true}",
    eui64Str, deviceType, eui64Str, (unsigned)nodeId, powerState,
    (unsigned)level);

  // Wrap in sb.v1 envelope
  char envelope[640];
  buildEnvelope(envelope, sizeof(envelope), inner);

  // Topic: devices/{device_type}/{eui64}/reported
  char topicSuffix[120];
  snprintf(topicSuffix, sizeof(topicSuffix), "devices/%s/%s/reported",
           deviceType, eui64Str);

  appMqttPublish(topicSuffix, envelope, 1, true);
}

void appMqttPublishDeviceEvent(uint16_t nodeId, const char *eui64Str,
                               const char *deviceType, const char *eventName)
{
  if (!sMosq) return;

  // Build inner payload JSON per DEVICE_CAPABILITY_MATRIX switch event
  char inner[256];
  snprintf(inner, sizeof(inner),
    "\"device_id\":\"%s\","
    "\"device_type\":\"%s\","
    "\"event\":\"%s\","
    "\"eui64\":\"%s\","
    "\"nwk_addr\":\"0x%04X\"",
    eui64Str, deviceType, eventName, eui64Str, (unsigned)nodeId);

  // Wrap in sb.v1 envelope
  char envelope[512];
  buildEnvelope(envelope, sizeof(envelope), inner);

  // Topic: devices/{device_type}/{eui64}/event  (QoS 1, no retain per contract)
  char topicSuffix[120];
  snprintf(topicSuffix, sizeof(topicSuffix), "devices/%s/%s/event",
           deviceType, eui64Str);

  appMqttPublish(topicSuffix, envelope, 1, false);
}

void appMqttPublishCommandReply(const char *command_id,
                                const char *device_id,
                                const char *status,
                                const char *reason)
{
  if (!sMosq || !command_id || !*command_id || !status) return;

  // Per MQTT_CONTRACT: correlation_id on reply == command_id.
  // Payload always carries: command_id, device_id, status, reason.
  // Any of device_id/reason may be NULL -> emitted as JSON null.
  char ts[32];
  iso8601Now(ts, sizeof(ts));
  uint32_t id = ++sMsgId;

  // Build device_id field (quoted or null)
  char devField[96];
  if (device_id && *device_id) {
    snprintf(devField, sizeof(devField), "\"%s\"", device_id);
  } else {
    snprintf(devField, sizeof(devField), "null");
  }

  // Build reason field (quoted or null)
  char reasonField[96];
  if (reason && *reason) {
    snprintf(reasonField, sizeof(reasonField), "\"%s\"", reason);
  } else {
    snprintf(reasonField, sizeof(reasonField), "null");
  }

  char envelope[512];
  snprintf(envelope, sizeof(envelope),
    "{\"schema\":\"sb.v1\","
     "\"msg_id\":\"%lu\","
     "\"ts\":\"%s\","
     "\"tenant_id\":\"" MQTT_TENANT "\","
     "\"site_id\":\"" MQTT_SITE "\","
     "\"gateway_id\":\"" MQTT_GW_ID "\","
     "\"source\":\"gateway\","
     "\"correlation_id\":\"%s\","
     "\"payload\":{\"command_id\":\"%s\","
                  "\"device_id\":%s,"
                  "\"status\":\"%s\","
                  "\"reason\":%s}}",
    (unsigned long)id, ts, command_id,
    command_id, devField, status, reasonField);

  char topicSuffix[96];
  snprintf(topicSuffix, sizeof(topicSuffix), "commands/%s/reply", command_id);

  // QoS 1, retain=false (per MQTT_CONTRACT.md)
  appMqttPublish(topicSuffix, envelope, 1, false);
}
