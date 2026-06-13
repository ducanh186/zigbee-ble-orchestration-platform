#include "net_mgr.h"

#include <stdbool.h>

#include "app/framework/include/af.h"
#include "network-steering.h"
#include "sl_led.h"
#include "sl_simple_led_instances.h"

// LED0 = network status (off=detached, blink=searching/joining, solid=joined).
// LED1 is owned by env_sensor.c (DHT11 read-OK feedback) — do not touch it here.
#define STATUS_LED              (&sl_led_led0)
#define LED_BLINK_PERIOD_MS     500u
#define NETWORK_SEARCH_DELAY_MS 3000u
#define NETWORK_RETRY_DELAY_MS  10000u

static sl_zigbee_event_t s_searchEvent;
static sl_zigbee_event_t s_ledBlinkEvent;

static bool s_searching    = false;
static bool s_pendingLeave = false;

static void searchHandler(sl_zigbee_event_t *event)
{
  (void)event;

  if (emberAfNetworkState() == EMBER_JOINED_NETWORK) {
    s_searching = false;
    sl_zigbee_event_set_inactive(&s_ledBlinkEvent);
    sl_led_turn_on(STATUS_LED);
    return;
  }

  EmberStatus st = emberAfPluginNetworkSteeringStart();
  sl_zigbee_app_debug_println("NET: steering start st=0x%02X", st);

  if (st != EMBER_SUCCESS) {
    sl_zigbee_event_set_delay_ms(&s_searchEvent, NETWORK_RETRY_DELAY_MS);
  }
}

static void ledBlinkHandler(sl_zigbee_event_t *event)
{
  (void)event;
  if (s_searching) {
    sl_led_toggle(STATUS_LED);
    sl_zigbee_event_set_delay_ms(&s_ledBlinkEvent, LED_BLINK_PERIOD_MS);
  }
}

static void beginSearching(uint32_t firstDelayMs)
{
  s_searching = true;
  sl_led_turn_off(STATUS_LED);
  sl_zigbee_event_set_delay_ms(&s_searchEvent, firstDelayMs);
  sl_zigbee_event_set_active(&s_ledBlinkEvent);
}

void netMgrInit(void)
{
  sl_zigbee_event_init(&s_searchEvent,   searchHandler);
  sl_zigbee_event_init(&s_ledBlinkEvent, ledBlinkHandler);

  if (emberAfNetworkState() == EMBER_JOINED_NETWORK) {
    // Already commissioned from NVM3: skip steering, just light the LED.
    s_searching = false;
    sl_led_turn_on(STATUS_LED);
  } else {
    // Cold boot without a network: auto-search like the Switch firmware so
    // the user does not need to press PB0 just to commission.
    beginSearching(NETWORK_SEARCH_DELAY_MS);
  }
}

void netMgrRequestLeaveAndRejoin(void)
{
  EmberNetworkStatus state = emberAfNetworkState();

  if (state == EMBER_JOINED_NETWORK || state == EMBER_JOINING_NETWORK) {
    s_pendingLeave = true;
    EmberStatus st = emberLeaveNetwork();
    sl_zigbee_app_debug_println("NET: PB0 leave requested st=0x%02X", st);
    return;
  }

  // Not on a network — kick a fresh search now.
  sl_zigbee_app_debug_println("NET: PB0 steering requested");
  beginSearching(0);
}

void netMgrOnStackStatus(EmberStatus status)
{
  if (status == EMBER_NETWORK_UP) {
    s_pendingLeave = false;
    s_searching    = false;
    sl_zigbee_event_set_inactive(&s_ledBlinkEvent);
    sl_led_turn_on(STATUS_LED);
    sl_zigbee_app_debug_println("NET: joined");
    return;
  }

  if (status == EMBER_NETWORK_DOWN) {
    sl_led_turn_off(STATUS_LED);
    if (s_pendingLeave) {
      s_pendingLeave = false;
      sl_zigbee_app_debug_println("NET: left, steering in %u ms",
                                  (unsigned)NETWORK_SEARCH_DELAY_MS);
      beginSearching(NETWORK_SEARCH_DELAY_MS);
    }
  }
}
