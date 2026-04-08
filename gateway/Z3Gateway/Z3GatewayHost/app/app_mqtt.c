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
#include <pthread.h>
#include <time.h>
#include <sys/time.h>

#include "af.h"  // emberAfCorePrintln

// ===== Broker connection =====
#define MQTT_CLIENT_ID   "z3gw-host"
#define MQTT_HOST        "localhost"
#define MQTT_PORT        1883
#define MQTT_KEEPALIVE   60

// Reconnect: 1 s initial, 30 s max, exponential backoff
#define MQTT_RECONN_MIN  1
#define MQTT_RECONN_MAX  30

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

  emberAfCorePrintln("MQTT: connected to %s:%d", MQTT_HOST, MQTT_PORT);
  appLogLog("mqtt", "connected", "broker=%s:%d", MQTT_HOST, MQTT_PORT);

  // Publish gateway/online (counterpart to LWT)
  char env[512];
  buildEnvelope(env, sizeof(env), "\"value\":\"online\"");
  appMqttPublish("gateway/online", env, 1, true);

  // Subscribe to command requests
  int sr = mosquitto_subscribe(mosq, NULL,
               MQTT_PREFIX "/commands/+/request", 1);
  if (sr != MOSQ_ERR_SUCCESS) {
    emberAfCorePrintln("MQTT: subscribe failed: %s", mosquitto_strerror(sr));
  } else {
    emberAfCorePrintln("MQTT: subscribed to " MQTT_PREFIX "/commands/+/request");
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
  // Route mosquitto internal logs through framework debug output
  emberAfCorePrintln("MQTT-lib: %s", str);
}

//----------------------------------------------------------------------
// Public API
//----------------------------------------------------------------------

void appMqttInit(void)
{
  int ret;

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

  ret = mosquitto_connect_async(sMosq, MQTT_HOST, MQTT_PORT, MQTT_KEEPALIVE);
  if (ret != MOSQ_ERR_SUCCESS) {
    emberAfCorePrintln("MQTT: connect_async failed: %s", mosquitto_strerror(ret));
    return;
  }

  ret = mosquitto_loop_start(sMosq);
  if (ret != MOSQ_ERR_SUCCESS) {
    emberAfCorePrintln("MQTT: loop_start failed: %s", mosquitto_strerror(ret));
    return;
  }

  emberAfCorePrintln("MQTT: connecting to %s:%d ...", MQTT_HOST, MQTT_PORT);
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

    // Route payload to cmdHandleLine.
    // For bring-up the payload is sent as bare {"id":N,"op":"..."}.
    // Prepend "@CMD " to match cmdHandleLine's expected format.
    char cmdBuf[MQTT_Q_PAYLOAD_MAX + 8];
    snprintf(cmdBuf, sizeof(cmdBuf), "@CMD %s", entry.payload);
    cmdHandleLine(cmdBuf);
  }
}

void appMqttPublishDeviceReported(uint16_t nodeId, const char *eui64Str,
                                  const char *deviceType, const char *powerState)
{
  if (!sMosq) return;

  // Build inner payload JSON
  char inner[256];
  snprintf(inner, sizeof(inner),
    "\"device_id\":\"%s\","
    "\"device_type\":\"%s\","
    "\"eui64\":\"%s\","
    "\"nwk_addr\":\"0x%04X\","
    "\"state\":{\"power\":\"%s\",\"reachable\":true}",
    eui64Str, deviceType, eui64Str, (unsigned)nodeId, powerState);

  // Wrap in sb.v1 envelope
  char envelope[512];
  buildEnvelope(envelope, sizeof(envelope), inner);

  // Topic: devices/{eui64}/reported
  char topicSuffix[80];
  snprintf(topicSuffix, sizeof(topicSuffix), "devices/%s/reported", eui64Str);

  appMqttPublish(topicSuffix, envelope, 1, true);
}
