#include "net_mgr.h"
#include "app_config.h"

#include "app/framework/include/af.h"
#include "network-steering.h"
#include "find-and-bind-target.h"
#include "sl_led.h"
#include "sl_simple_led_instances.h"

// LED0 = network status,  LED1 = On/Off light (controlled via ZCL)
#define STATUS_LED  (&sl_led_led0)
#define LIGHT_LED   (&sl_led_led1)

// Find-and-bind retry config
#define FIND_BIND_RETRY_MAX      5
#define FIND_BIND_RETRY_MS       15000u   // 15s between retries

// Events
static sl_zigbee_event_t g_ledBlinkEvent;
static sl_zigbee_event_t g_searchEvent;
static sl_zigbee_event_t g_findBindEvent;

static bool g_searching    = false;
static bool g_pendingLeave = false;
static uint8_t g_findBindRetry = 0;

// ---------------------------------------------------------------------------
// Forward declarations
static void ledBlinkHandler(sl_zigbee_event_t *event);
static void searchHandler(sl_zigbee_event_t *event);
static void findBindHandler(sl_zigbee_event_t *event);

// ---------------------------------------------------------------------------
void netMgrInit(void)
{
  sl_zigbee_event_init(&g_ledBlinkEvent, ledBlinkHandler);
  sl_zigbee_event_init(&g_searchEvent,   searchHandler);
  sl_zigbee_event_init(&g_findBindEvent, findBindHandler);

  if (emberAfNetworkState() == EMBER_JOINED_NETWORK) {
    sl_led_turn_on(STATUS_LED);
    // Already joined — start find-and-bind target in case binding was lost
    g_findBindRetry = 0;
    sl_zigbee_event_set_delay_ms(&g_findBindEvent, FIND_BIND_DELAY_MS);
  } else {
    sl_led_turn_off(STATUS_LED);
    g_searching = true;
    sl_zigbee_event_set_active(&g_searchEvent);
    sl_zigbee_event_set_active(&g_ledBlinkEvent);
  }
}

// ---------------------------------------------------------------------------
void netMgrRequestLeaveAndRejoin(void)
{
  if (emberAfNetworkState() == EMBER_JOINED_NETWORK
      || emberAfNetworkState() == EMBER_JOINING_NETWORK) {
    g_pendingLeave = true;
    EmberStatus st = emberLeaveNetwork();
    emberAfCorePrintln("NET: leave requested st=0x%02X", st);
  } else {
    g_searching = true;
    sl_led_turn_off(STATUS_LED);
    sl_zigbee_event_set_delay_ms(&g_searchEvent, NETWORK_SEARCH_DELAY_MS);
    sl_zigbee_event_set_active(&g_ledBlinkEvent);
  }
}

// ---------------------------------------------------------------------------
void netMgrStartFindBind(void)
{
  g_findBindRetry = 0;
  sl_zigbee_event_set_active(&g_findBindEvent);
}

// ---------------------------------------------------------------------------
static void ledBlinkHandler(sl_zigbee_event_t *event)
{
  if (g_searching) {
    sl_led_toggle(STATUS_LED);
    sl_zigbee_event_set_delay_ms(&g_ledBlinkEvent, LED_BLINK_PERIOD_MS);
  }
}

// ---------------------------------------------------------------------------
static void searchHandler(sl_zigbee_event_t *event)
{
  if (emberAfNetworkState() == EMBER_JOINED_NETWORK) {
    g_searching = false;
    return;
  }

  EmberStatus st = emberAfPluginNetworkSteeringStart();
  emberAfCorePrintln("NET: steering start st=0x%02X", st);
}

// ---------------------------------------------------------------------------
static void findBindHandler(sl_zigbee_event_t *event)
{
  if (emberAfNetworkState() != EMBER_JOINED_NETWORK) return;

  EmberStatus st = emberAfPluginFindAndBindTargetStart(LIGHT_ENDPOINT);
  emberAfCorePrintln("NET: find-bind target start st=0x%02X (attempt %d/%d)",
                     st, g_findBindRetry + 1, FIND_BIND_RETRY_MAX);

  // Schedule retry regardless — target mode just needs to be active
  // when the initiator queries
  g_findBindRetry++;
  if (g_findBindRetry < FIND_BIND_RETRY_MAX) {
    sl_zigbee_event_set_delay_ms(&g_findBindEvent, FIND_BIND_RETRY_MS);
  }
}

// ===========================================================================
// Zigbee framework callbacks
// ===========================================================================

void emberAfStackStatusCallback(EmberStatus status)
{
  emberAfCorePrintln("NET: stack status=0x%02X", status);

  if (status == EMBER_NETWORK_UP) {
    g_searching = false;
    sl_zigbee_event_set_inactive(&g_ledBlinkEvent);
    sl_zigbee_event_set_inactive(&g_searchEvent);
    sl_led_turn_on(STATUS_LED);

    // Start find-and-bind target after joining
    g_findBindRetry = 0;
    sl_zigbee_event_set_delay_ms(&g_findBindEvent, FIND_BIND_DELAY_MS);
  } else if (status == EMBER_NETWORK_DOWN) {
    sl_led_turn_off(STATUS_LED);

    if (g_pendingLeave) {
      g_pendingLeave = false;
      g_searching = true;
      sl_zigbee_event_set_delay_ms(&g_searchEvent, NETWORK_SEARCH_DELAY_MS);
      sl_zigbee_event_set_active(&g_ledBlinkEvent);
    }
  }
}

// ---------------------------------------------------------------------------
void emberAfPluginNetworkSteeringCompleteCallback(EmberStatus status,
                                                  uint8_t totalBeacons,
                                                  uint8_t joinAttempts,
                                                  uint8_t finalState)
{
  emberAfCorePrintln("NET: steering complete st=0x%02X", status);

  if (status != EMBER_SUCCESS) {
    sl_zigbee_event_set_delay_ms(&g_searchEvent, NETWORK_RETRY_DELAY_MS);
  }
}

// ===========================================================================
// ZCL On/Off attribute change → control LED1
// ===========================================================================

void emberAfPostAttributeChangeCallback(uint8_t endpoint,
                                        EmberAfClusterId clusterId,
                                        EmberAfAttributeId attributeId,
                                        uint8_t mask,
                                        uint16_t manufacturerCode,
                                        uint8_t type,
                                        uint8_t size,
                                        uint8_t *value)
{
  if (clusterId == ZCL_ON_OFF_CLUSTER_ID
      && attributeId == ZCL_ON_OFF_ATTRIBUTE_ID
      && mask == CLUSTER_MASK_SERVER) {
    bool onOff;
    if (emberAfReadServerAttribute(endpoint,
                                   ZCL_ON_OFF_CLUSTER_ID,
                                   ZCL_ON_OFF_ATTRIBUTE_ID,
                                   (uint8_t *)&onOff,
                                   sizeof(onOff))
        == EMBER_ZCL_STATUS_SUCCESS) {
      if (onOff) {
        sl_led_turn_on(LIGHT_LED);
        emberAfCorePrintln("LIGHT: ON");
      } else {
        sl_led_turn_off(LIGHT_LED);
        emberAfCorePrintln("LIGHT: OFF");
      }
    }
  }
}

void emberAfPluginOnOffClusterServerPostInitCallback(uint8_t endpoint)
{
  emberAfPostAttributeChangeCallback(endpoint,
                                     ZCL_ON_OFF_CLUSTER_ID,
                                     ZCL_ON_OFF_ATTRIBUTE_ID,
                                     CLUSTER_MASK_SERVER,
                                     0, 0, 0, NULL);
}
