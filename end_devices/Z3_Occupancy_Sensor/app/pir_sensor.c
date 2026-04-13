#include <stdbool.h>
#include "app/pir_sensor.h"
#include "app/framework/include/af.h"
#include "sl_led.h"
#include "sl_simple_led_instances.h"

static bool s_warmedUp = false;
static bool s_lastDetected = false;
static sl_zigbee_event_t s_pollEvent;

/* ---------- Zigbee On/Off command helper ---------- */
static void pirSendOnOffToBindings(bool on)
{
  /* Guard: only send if we are on the network */
  if (emberAfNetworkState() != EMBER_JOINED_NETWORK) {
    sl_zigbee_app_debug_println("PIR: skip Zigbee cmd — not joined");
    return;
  }

  /* Fill the On or Off command frame (cluster 0x0006, client→server) */
  if (on) {
    emberAfFillCommandOnOffClusterOn();
  } else {
    emberAfFillCommandOnOffClusterOff();
  }

  /* Set source endpoint so the binding table can be matched */
  emberAfGetCommandApsFrame()->sourceEndpoint = PIR_ENDPOINT;

  /* Send to all matching bindings (On/Off cluster, endpoint 1) */
  EmberStatus st = emberAfSendCommandUnicastToBindings();
  sl_zigbee_app_debug_println("PIR: Zigbee %s sent st=0x%02X",
                              on ? "ON" : "OFF", st);
}

/* ---------- PIR poll handler ---------- */
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

  /* Only act + log on state change */
  if (detected != s_lastDetected) {
    s_lastDetected = detected;

    /* --- LOCAL PATH: Occupancy attribute + LED0 --- */
    uint8_t occupancyValue = detected ? 1u : 0u;
    emberAfWriteServerAttribute(PIR_ENDPOINT,
                                ZCL_OCCUPANCY_SENSING_CLUSTER_ID,
                                ZCL_OCCUPANCY_ATTRIBUTE_ID,
                                &occupancyValue,
                                ZCL_BITMAP8_ATTRIBUTE_TYPE);

    if (detected) {
      sl_led_turn_on(&sl_led_led0);
      sl_zigbee_app_debug_println("PIR: MOTION DETECTED (pin=%u)", pinState);
    } else {
      sl_led_turn_off(&sl_led_led0);
      sl_zigbee_app_debug_println("PIR: CLEAR (pin=%u)", pinState);
    }

    /* --- ZIGBEE PATH: send On/Off command to bound light(s) --- */
    pirSendOnOffToBindings(detected);
  }

  /* Schedule next poll */
  sl_zigbee_event_set_delay_ms(&s_pollEvent, PIR_POLL_INTERVAL_MS);
}

void pirSensorInit(void)
{
  /* Configure PD8 as digital input, no pull-up/pull-down.
   * GPIO clock is already enabled by sl_system_init(). */
  GPIO_PinModeSet(PIR_PORT, PIR_PIN, gpioModeInput, 0);

  /* Init Zigbee event for polling */
  sl_zigbee_event_init(&s_pollEvent, pirPollHandler);

  /* Start first poll after warm-up delay */
  sl_zigbee_event_set_delay_ms(&s_pollEvent, PIR_WARMUP_MS);

  sl_zigbee_app_debug_println("PIR: init OK (port=D pin=8, detect_level=%d, poll=%ums, warmup=%ums)",
                              PIR_DETECTED_LEVEL,
                              PIR_POLL_INTERVAL_MS,
                              PIR_WARMUP_MS);
}
