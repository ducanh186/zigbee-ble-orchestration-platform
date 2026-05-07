/***************************************************************************//**
 * @file app_mqtt.c
 * @brief MQTT client module for Z3GatewayHost (libmosquitto).
 ******************************************************************************/

#define _POSIX_C_SOURCE 200112L  // gettimeofday

#include "app_mqtt.h"
#include "app_log.h"
#include "cmd_handler.h"

#include <mosquitto.h>
#include <inttypes.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>
#include <sys/time.h>

#include "af.h"  // emberAfCorePrintln
#include "device_registry.h"  // deviceRegistryCount (health device count)

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

// Phase 5: gateway health tick (publish every 30 s while connected).
#define MQTT_HEALTH_INTERVAL_MS  30000ULL
static bool     sMqttConnected = false;
static uint64_t sAppStartMs    = 0;
static uint64_t sLastHealthMs  = 0;

//----------------------------------------------------------------------
// Helpers
//----------------------------------------------------------------------

// Unix epoch in milliseconds (UTC). Contract: envelope `ts` is an integer
// number of milliseconds (docs/MQTT_CONTRACT.md → "Kiểu của `ts`").
static uint64_t epochMillisNow(void)
{
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return ((uint64_t)tv.tv_sec * 1000u) + ((uint64_t)tv.tv_usec / 1000u);
}

// Build a minimal sb.v1 envelope.  Caller supplies the inner payload JSON
// (without outer braces).  Result written to buf.
static int buildEnvelope(char *buf, size_t len, const char *innerPayloadJson)
{
  uint64_t ts = epochMillisNow();
  uint32_t id = ++sMsgId;

  return snprintf(buf, len,
    "{\"schema\":\"sb.v1\","
     "\"msg_id\":\"%lu\","
     "\"ts\":%" PRIu64 ","
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

  sMqttConnected = true;
  // Force health tick to fire on the first opportunity after (re)connect so
  // cloud sees a fresh snapshot rather than waiting up to the full interval.
  sLastHealthMs = 0;

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
  sMqttConnected = false;
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

  sAppStartMs   = epochMillisNow();
  sLastHealthMs = 0;

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

  // Phase 5: periodic gateway/health publish (30 s, only while connected).
  if (sMqttConnected) {
    uint64_t now = epochMillisNow();
    if (now - sLastHealthMs >= MQTT_HEALTH_INTERVAL_MS) {
      uint32_t devCount = deviceRegistryCount();
      appMqttPublishGatewayHealth(now - sAppStartMs, true, devCount, "unknown");
      sLastHealthMs = now;
    }
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

void appMqttPublishMotionReported(uint16_t nodeId, const char *eui64Str,
                                  const char *occupancy,
                                  bool hasBattery, uint8_t batteryPercent)
{
  if (!sMosq || !eui64Str || !occupancy) return;

  char stateExtra[40] = "";
  if (hasBattery) {
    if (batteryPercent > 100u) batteryPercent = 100u;
    snprintf(stateExtra, sizeof(stateExtra), ",\"battery\":%u",
             (unsigned)batteryPercent);
  }

  char inner[360];
  snprintf(inner, sizeof(inner),
    "\"device_id\":\"%s\","
    "\"device_type\":\"motion\","
    "\"eui64\":\"%s\","
    "\"nwk_addr\":\"0x%04X\","
    "\"state\":{\"occupancy\":\"%s\",\"reachable\":true%s}",
    eui64Str, eui64Str, (unsigned)nodeId, occupancy, stateExtra);

  char envelope[700];
  buildEnvelope(envelope, sizeof(envelope), inner);

  char topicSuffix[120];
  snprintf(topicSuffix, sizeof(topicSuffix), "devices/motion/%s/reported",
           eui64Str);

  appMqttPublish(topicSuffix, envelope, 1, true);
  appLogLog("MQTT", "motion_reported",
            "\"device_id\":\"%s\",\"occupancy\":\"%s\"",
            eui64Str, occupancy);
}

void appMqttPublishMotionEvent(uint16_t nodeId, const char *eui64Str,
                               const char *occupancy, uint8_t raw)
{
  if (!sMosq || !eui64Str || !occupancy) return;

  char inner[360];
  snprintf(inner, sizeof(inner),
    "\"device_id\":\"%s\","
    "\"device_type\":\"motion\","
    "\"event\":\"occupancy_changed\","
    "\"occupancy\":\"%s\","
    "\"eui64\":\"%s\","
    "\"nwk_addr\":\"0x%04X\","
    "\"raw\":\"0x%02X\"",
    eui64Str, occupancy, eui64Str, (unsigned)nodeId, (unsigned)raw);

  char envelope[700];
  buildEnvelope(envelope, sizeof(envelope), inner);

  char topicSuffix[120];
  snprintf(topicSuffix, sizeof(topicSuffix), "devices/motion/%s/event",
           eui64Str);

  appMqttPublish(topicSuffix, envelope, 1, false);
  appLogLog("MQTT", "motion_event",
            "\"device_id\":\"%s\",\"occupancy\":\"%s\",\"raw\":\"0x%02X\"",
            eui64Str, occupancy, (unsigned)raw);
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

  // Topic: devices/{device_type}/{eui64}/event  (QoS 1, no retain)
  appMqttPublish(topicSuffix, envelope, 1, false);
}

// Phase 4: return a JSON-array-literal of inferred cluster IDs per device type.
// Caller must not free. Unknown types return "[]".
static const char *inferredClustersJson(const char *deviceType)
{
  if (!deviceType) return "[]";
  if (strcmp(deviceType, "light")  == 0) return "[\"0x0006\",\"0x0008\"]";
  if (strcmp(deviceType, "switch") == 0) return "[\"0x0006\",\"0x0001\"]";
  if (strcmp(deviceType, "motion") == 0) return "[\"0x0406\"]";
  if (strcmp(deviceType, "lock")   == 0) return "[\"0x0101\"]";
  return "[]";
}

void appMqttPublishDeviceRegistry(uint16_t nodeId, const char *eui64Str,
                                  const char *deviceType)
{
  if (!sMosq || !eui64Str || !deviceType) return;

  uint64_t joinedAt = epochMillisNow();

  // Inner payload per Phase 4 MVP contract.
  char inner[640];
  snprintf(inner, sizeof(inner),
    "\"device_id\":\"%s\","
    "\"device_type\":\"%s\","
    "\"eui64\":\"%s\","
    "\"nwk_addr\":\"0x%04X\","
    "\"endpoint\":1,"
    "\"endpoints\":[1],"
    "\"clusters\":%s,"
    "\"manufacturer\":null,"
    "\"model\":null,"
    "\"joined_at\":%" PRIu64 ","
    "\"metadata_source\":\"gateway_mvp_inferred\"",
    eui64Str, deviceType, eui64Str, (unsigned)nodeId,
    inferredClustersJson(deviceType),
    joinedAt);

  char envelope[896];
  buildEnvelope(envelope, sizeof(envelope), inner);

  // Topic: devices/{device_type}/{eui64}/registry (QoS 1, retained per contract)
  char topicSuffix[120];
  snprintf(topicSuffix, sizeof(topicSuffix), "devices/%s/%s/registry",
           deviceType, eui64Str);

  appMqttPublish(topicSuffix, envelope, 1, true);
}

void appMqttClearRetainedRegistry(const char *eui64Str, const char *keepType)
{
  if (!sMosq || !eui64Str) return;

  // Keep this list aligned with inferredClustersJson() - any device_type
  // the gateway can ever publish must appear here so we never leak a stale
  // retained slot.
  static const char *types[] = {"light", "switch", "motion", "unknown"};
  for (size_t i = 0; i < sizeof(types) / sizeof(types[0]); i++) {
    if (keepType && strcmp(keepType, types[i]) == 0) continue;

    char fullTopic[192];
    snprintf(fullTopic, sizeof(fullTopic),
             "%s/devices/%s/%s/registry", MQTT_PREFIX, types[i], eui64Str);

    // Empty (zero-length) payload + retain=1 -> broker drops the retained
    // value for this topic.  See MQTT 3.1.1 / 5 spec section on retained
    // messages.
    int rc = mosquitto_publish(sMosq, NULL, fullTopic, 0, NULL, 1, true);
    if (rc != MOSQ_ERR_SUCCESS) {
      emberAfCorePrintln("MQTT: clear-retained failed for %s: %s",
                         fullTopic, mosquitto_strerror(rc));
    } else {
      emberAfCorePrintln("MQTT: cleared retained [%s]", fullTopic);
    }
  }
}

void appMqttPublishGatewayHealth(uint64_t uptime_ms, bool mqttConnected,
                                 uint32_t knownDeviceCount,
                                 const char *networkState)
{
  if (!sMosq) return;

  const char *ns = networkState ? networkState : "unknown";

  char inner[256];
  snprintf(inner, sizeof(inner),
    "\"uptime_ms\":%" PRIu64 ","
    "\"mqtt_connected\":%s,"
    "\"known_device_count\":%u,"
    "\"network_state\":\"%s\"",
    uptime_ms,
    mqttConnected ? "true" : "false",
    (unsigned)knownDeviceCount, ns);

  char envelope[512];
  buildEnvelope(envelope, sizeof(envelope), inner);

  // QoS 1, retained per MQTT_CONTRACT.
  appMqttPublish("gateway/health", envelope, 1, true);
}

void appMqttPublishGatewayEvent(const char *eventName, const char *extraJson)
{
  if (!sMosq || !eventName || !*eventName) return;

  char inner[320];
  if (extraJson && *extraJson) {
    snprintf(inner, sizeof(inner),
             "\"event\":\"%s\",%s", eventName, extraJson);
  } else {
    snprintf(inner, sizeof(inner), "\"event\":\"%s\"", eventName);
  }

  char envelope[512];
  buildEnvelope(envelope, sizeof(envelope), inner);

  // QoS 1, retain=false (per MQTT_CONTRACT.md events row).
  appMqttPublish("gateway/event", envelope, 1, false);
}

void appMqttPublishCommandReply(const char *command_id,
                                const char *device_id,
                                const char *status,
                                const char *reason)
{
  if (!sMosq || !command_id || !*command_id || !status) return;

  // Per MQTT_CONTRACT: correlation_id on reply is "cmd_" + command_id.
  // Payload always carries raw command_id, device_id, status, reason.
  // Any of device_id/reason may be NULL -> emitted as JSON null.
  uint64_t ts = epochMillisNow();
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
     "\"ts\":%" PRIu64 ","
     "\"tenant_id\":\"" MQTT_TENANT "\","
     "\"site_id\":\"" MQTT_SITE "\","
     "\"gateway_id\":\"" MQTT_GW_ID "\","
     "\"source\":\"gateway\","
     "\"correlation_id\":\"cmd_%s\","
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
