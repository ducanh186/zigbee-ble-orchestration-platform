#include <stdbool.h>
#include "app/pir_sensor.h"
#include "app/framework/include/af.h"
#include "sl_led.h"
#include "sl_simple_led_instances.h"

static bool s_warmedUp = false;
static bool s_lastDetected = false;
static uint16_t s_pollCount = 0;
static sl_zigbee_event_t s_pollEvent;

/* Heartbeat cadence: print one tick log every HEARTBEAT_EVERY polls.
 * With PIR_POLL_INTERVAL_MS=200 and value 25, that is ~5 seconds. */
#define PIR_HEARTBEAT_EVERY  25u

/* Manually emit a ZCL Report Attributes (cmd 0x0A) frame for Occupancy
 * attribute 0x0000 on cluster 0x0406, sent to every binding-table entry
 * that targets {our_ep=1, cluster=0x0406}.
 *
 * Why this is needed: the Silicon Labs `zigbee_reporting` plugin is listed
 * in the .slcp but its sources are NOT actually compiled into this binary
 * (verified at link time — `emberAfPluginReportingConfigureReportedAttribute`
 * is undefined). The Configure-Reporting handler that should have lived
 * inside that plugin therefore does not exist, which is also why the
 * gateway's Configure-Reporting frame comes back with ZCL Default Response
 * status 0x81 (UNSUP_CLUSTER_COMMAND). Without the plugin, attribute
 * writes do not auto-generate a Report Attributes frame.
 *
 * The fallback path here builds the same Report Attributes frame the plugin
 * would have built, and ships it via `emberAfSendCommandUnicastToBindings`
 * which walks the local binding table the gateway already populated through
 * its ZDO Bind Request.
 */
static void pirSendOccupancyReport(bool detected)
{
  uint8_t payload[4];
  payload[0] = (uint8_t)(ZCL_OCCUPANCY_ATTRIBUTE_ID & 0xFFu);        /* attr id LSB */
  payload[1] = (uint8_t)((ZCL_OCCUPANCY_ATTRIBUTE_ID >> 8) & 0xFFu); /* attr id MSB */
  payload[2] = ZCL_BITMAP8_ATTRIBUTE_TYPE;                            /* 0x18 */
  payload[3] = detected ? 0x01u : 0x00u;                              /* value */

  emberAfFillExternalBuffer(
      (ZCL_GLOBAL_COMMAND | ZCL_FRAME_CONTROL_SERVER_TO_CLIENT),
      ZCL_OCCUPANCY_SENSING_CLUSTER_ID,
      ZCL_REPORT_ATTRIBUTES_COMMAND_ID,
      "b",
      payload,
      sizeof(payload));

  emberAfSetCommandEndpoints(1u, 1u);
  EmberStatus tx_st = emberAfSendCommandUnicastToBindings();
  sl_zigbee_app_debug_println(
      "PIR: report tx cluster=0x0406 attr=0x0000 val=0x%02X tx_status=0x%02X",
      payload[3], (unsigned)tx_st);
}

static void pirWriteOccupancyAttribute(bool detected)
{
  uint8_t occupancy = detected ? 0x01u : 0x00u;
  EmberAfStatus st = emberAfWriteServerAttribute(1,
                                                 ZCL_OCCUPANCY_SENSING_CLUSTER_ID,
                                                 ZCL_OCCUPANCY_ATTRIBUTE_ID,
                                                 &occupancy,
                                                 ZCL_BITMAP8_ATTRIBUTE_TYPE);
  sl_zigbee_app_debug_println("PIR: occupancy attr=0x%02X write_status=0x%02X",
                              occupancy, st);

  /* Manual report emit — see comment on pirSendOccupancyReport.
   * Sent only on successful write so we don't blast invalid state. */
  if (st == EMBER_ZCL_STATUS_SUCCESS) {
    pirSendOccupancyReport(detected);
  }
}

static void pirPollHandler(sl_zigbee_event_t *event)
{
  (void)event;

  /* First fire after warm-up period */
  if (!s_warmedUp) {
    s_warmedUp = true;
    sl_zigbee_app_debug_println("PIR: warm-up done, polling started");
  }

  /* Read HC-SR501 OUT on PD8 */
  unsigned int pinState = GPIO_PinInGet(PIR_PORT, PIR_PIN);
  bool detected = (pinState == PIR_DETECTED_LEVEL);

  /* Heartbeat so we can tell "polling is alive but pin never changes" apart
   * from "polling stopped" without having to wait for motion. */
  s_pollCount++;
  if ((s_pollCount % PIR_HEARTBEAT_EVERY) == 0u) {
    sl_zigbee_app_debug_println("PIR: tick pin=%u last=%u",
                                pinState, (unsigned)s_lastDetected);
  }

  /* Only act + log on state change */
  if (detected != s_lastDetected) {
    s_lastDetected = detected;
    pirWriteOccupancyAttribute(detected);
    if (detected) {
      sl_led_turn_on(&sl_led_led1);
      sl_zigbee_app_debug_println("PIR: MOTION DETECTED (pin=%u)", pinState);
    } else {
      sl_led_turn_off(&sl_led_led1);
      sl_zigbee_app_debug_println("PIR: CLEAR (pin=%u)", pinState);
    }
  }

  /* Schedule next poll */
  sl_zigbee_event_set_delay_ms(&s_pollEvent, PIR_POLL_INTERVAL_MS);
}

void pirSensorInit(void)
{
  /* Configure PD8 as digital input with internal pull-down.
   * GPIO clock is already enabled by sl_system_init().
   * Pull-down keeps the line at a known LOW (= unoccupied) if the HC-SR501
   * OUT wire is missing or briefly disconnected, so the change-detector does
   * not get triggered by floating-input noise. The HC-SR501 push-pull output
   * easily overrides the ~50kΩ pull-down when wired. */
  GPIO_PinModeSet(PIR_PORT, PIR_PIN, gpioModeInputPull, 0);
  pirWriteOccupancyAttribute(false);

  /* Init Zigbee event for polling */
  sl_zigbee_event_init(&s_pollEvent, pirPollHandler);

  /* Start first poll after warm-up delay */
  sl_zigbee_event_set_delay_ms(&s_pollEvent, PIR_WARMUP_MS);

  sl_zigbee_app_debug_println("PIR: init OK (port=D pin=8, detect_level=%d, poll=%ums, warmup=%ums)",
                              PIR_DETECTED_LEVEL,
                              PIR_POLL_INTERVAL_MS,
                              PIR_WARMUP_MS);
}
