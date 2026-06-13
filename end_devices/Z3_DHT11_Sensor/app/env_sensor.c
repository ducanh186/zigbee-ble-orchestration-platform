#include "env_sensor.h"
#include "dht11.h"

#include <stdbool.h>
#include "app/framework/include/af.h"
#include "sl_led.h"
#include "sl_simple_led_instances.h"

/* Two-phase read driven by one event so the 20ms DHT11 start signal never
 * busy-waits: TICK fires -> drive DATA low -> re-arm event +20ms -> clock
 * the 40-bit frame in (bounded ~6ms) -> process -> re-arm for the next
 * cycle. Same event/timer pattern as the Occupancy firmware's PIR poll. */
typedef enum {
  ENV_PHASE_TICK = 0,    /* begin a read: send start signal       */
  ENV_PHASE_SAMPLE,      /* start signal held long enough: sample */
} env_phase_t;

static sl_zigbee_event_t s_envEvent;
static env_phase_t s_phase = ENV_PHASE_TICK;
static uint8_t s_retries = 0;

/* Last good read + last reported values, deci-units. */
static int16_t  s_tempDc = 0;
static uint16_t s_rhDp = 0;
static bool     s_reportedOnce = false;
static int16_t  s_repTempDc = 0;
static uint16_t s_repRhDp = 0;
static uint32_t s_lastReportMs = 0;

/* Manually emit a ZCL Report Attributes (cmd 0x0A) frame. Same fallback as
 * the Occupancy firmware: the `zigbee_reporting` plugin sources are not
 * linked into these binaries, so attribute writes never auto-report and
 * Configure Reporting from the gateway is answered UNSUP_CLUSTER_COMMAND.
 * Unlike Occupancy (which walks bindings the gateway created for 0x0406),
 * the gateway never binds 0x0402/0x0405, so we unicast straight to the
 * coordinator (nodeId 0x0000, endpoint 1). */
static EmberStatus envSendReport(uint16_t clusterId, uint8_t attrType,
                                 uint16_t valueLe)
{
  uint8_t payload[5];
  payload[0] = 0x00; /* attr id 0x0000 (MeasuredValue) LSB */
  payload[1] = 0x00; /* attr id MSB */
  payload[2] = attrType;
  payload[3] = (uint8_t)(valueLe & 0xFFu);
  payload[4] = (uint8_t)((valueLe >> 8) & 0xFFu);

  emberAfFillExternalBuffer(
      (ZCL_GLOBAL_COMMAND | ZCL_FRAME_CONTROL_SERVER_TO_CLIENT),
      clusterId,
      ZCL_REPORT_ATTRIBUTES_COMMAND_ID,
      "b",
      payload,
      sizeof(payload));

  emberAfSetCommandEndpoints(1u, 1u);
  return emberAfSendCommandUnicast(EMBER_OUTGOING_DIRECT, 0x0000u);
}

static void envReport(void)
{
  /* ZCL scaling: MeasuredValue is centi-units on both clusters
   * (0x0402 int16s 0.01C, 0x0405 uint16 0.01%RH): 28.5C -> 2850. */
  int16_t  tempCenti = (int16_t)(s_tempDc * 10);
  uint16_t rhCenti   = (uint16_t)(s_rhDp * 10u);

  EmberAfStatus wt = emberAfWriteServerAttribute(
      1, ZCL_TEMP_MEASUREMENT_CLUSTER_ID,
      ZCL_TEMP_MEASURED_VALUE_ATTRIBUTE_ID,
      (uint8_t *)&tempCenti, ZCL_INT16S_ATTRIBUTE_TYPE);
  EmberAfStatus wh = emberAfWriteServerAttribute(
      1, ZCL_RELATIVE_HUMIDITY_MEASUREMENT_CLUSTER_ID,
      ZCL_RELATIVE_HUMIDITY_MEASURED_VALUE_ATTRIBUTE_ID,
      (uint8_t *)&rhCenti, ZCL_INT16U_ATTRIBUTE_TYPE);
  if (wt != EMBER_ZCL_STATUS_SUCCESS || wh != EMBER_ZCL_STATUS_SUCCESS) {
    sl_zigbee_app_debug_println("ENV: attr write failed t=0x%02X h=0x%02X",
                                wt, wh);
    return;
  }

  EmberStatus st = envSendReport(ZCL_TEMP_MEASUREMENT_CLUSTER_ID,
                                 ZCL_INT16S_ATTRIBUTE_TYPE,
                                 (uint16_t)tempCenti);
  EmberStatus sh = envSendReport(ZCL_RELATIVE_HUMIDITY_MEASUREMENT_CLUSTER_ID,
                                 ZCL_INT16U_ATTRIBUTE_TYPE,
                                 rhCenti);

  sl_zigbee_app_debug_println(
      "Zigbee report sent: temp=%d.%dC humidity=%d.%d%% (tx 0x%02X/0x%02X)",
      s_tempDc / 10, s_tempDc % 10, s_rhDp / 10u, s_rhDp % 10u,
      (unsigned)st, (unsigned)sh);

  if (st == EMBER_SUCCESS && sh == EMBER_SUCCESS) {
    s_reportedOnce = true;
    s_repTempDc = s_tempDc;
    s_repRhDp = s_rhDp;
    s_lastReportMs = halCommonGetInt32uMillisecondTick();
  }
}

static bool envShouldReport(void)
{
  if (!s_reportedOnce) {
    return true;
  }
  uint32_t sinceMs = elapsedTimeInt32u(s_lastReportMs,
                                       halCommonGetInt32uMillisecondTick());
  if (sinceMs >= ENV_REPORT_INTERVAL_MS) {
    return true;
  }
  int16_t dT = s_tempDc - s_repTempDc;
  if (dT < 0) {
    dT = (int16_t)-dT;
  }
  uint16_t dH = (s_rhDp > s_repRhDp) ? (s_rhDp - s_repRhDp)
                                     : (s_repRhDp - s_rhDp);
  return (dT >= (int16_t)ENV_TEMP_DELTA_DC) || (dH >= ENV_RH_DELTA_DP);
}

static void envProcessReading(void)
{
  sl_led_turn_on(&sl_led_led1);
  sl_zigbee_app_debug_println("DHT11 read OK: temp=%d.%dC humidity=%d.%d%%",
                              s_tempDc / 10, s_tempDc % 10,
                              s_rhDp / 10u, s_rhDp % 10u);

  if (emberAfNetworkState() != EMBER_JOINED_NETWORK) {
    sl_zigbee_app_debug_println("ENV: not joined, report skipped");
    return;
  }
  if (envShouldReport()) {
    envReport();
  }
}

static void envEventHandler(sl_zigbee_event_t *event)
{
  (void)event;

  if (s_phase == ENV_PHASE_TICK) {
    dht11_read_begin();
    s_phase = ENV_PHASE_SAMPLE;
    sl_zigbee_event_set_delay_ms(&s_envEvent, DHT11_START_LOW_MS);
    return;
  }

  /* ENV_PHASE_SAMPLE */
  s_phase = ENV_PHASE_TICK;
  int16_t tempDc;
  uint16_t rhDp;
  dht11_status_t st = dht11_read_finish(&tempDc, &rhDp);

  if (st == DHT11_OK) {
    s_retries = 0;
    s_tempDc = tempDc;
    s_rhDp = rhDp;
    envProcessReading();
    sl_zigbee_event_set_delay_ms(&s_envEvent, ENV_READ_INTERVAL_MS);
    return;
  }

  sl_led_turn_off(&sl_led_led1);
  if (st == DHT11_ERR_CHECKSUM) {
    sl_zigbee_app_debug_println("DHT11 checksum error");
  } else {
    sl_zigbee_app_debug_println("DHT11 timeout at stage=%s bit=%u",
                                dht11_stage_name(dht11_last_stage()),
                                (unsigned)dht11_last_bit());
  }

  if (s_retries < ENV_MAX_RETRIES) {
    s_retries++;
    sl_zigbee_app_debug_println("ENV: retry %u/%u in %ums",
                                (unsigned)s_retries,
                                (unsigned)ENV_MAX_RETRIES,
                                (unsigned)ENV_RETRY_DELAY_MS);
    sl_zigbee_event_set_delay_ms(&s_envEvent, ENV_RETRY_DELAY_MS);
  } else {
    s_retries = 0;
    sl_zigbee_event_set_delay_ms(&s_envEvent, ENV_READ_INTERVAL_MS);
  }
}

void envSensorInit(void)
{
  dht11_init();

  sl_zigbee_event_init(&s_envEvent, envEventHandler);

  /* DHT11 needs ~1s after power-up before the first read. */
  s_phase = ENV_PHASE_TICK;
  sl_zigbee_event_set_delay_ms(&s_envEvent, 1500u);

  sl_zigbee_app_debug_println(
      "DHT11 init: selected GPIO = PD%d (EXP3), read=%ums report<=%ums",
      DHT11_PIN, (unsigned)ENV_READ_INTERVAL_MS,
      (unsigned)ENV_REPORT_INTERVAL_MS);
}
