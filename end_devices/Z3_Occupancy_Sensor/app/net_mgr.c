#include "net_mgr.h"

#include <stdbool.h>

#include "network-steering.h"

#define NETWORK_SEARCH_DELAY_MS 3000u

static sl_zigbee_event_t s_searchEvent;
static bool s_pendingLeave = false;

static void searchHandler(sl_zigbee_event_t *event)
{
  (void)event;

  if (emberAfNetworkState() == EMBER_JOINED_NETWORK) {
    sl_zigbee_app_debug_println("NET: steering skip, already joined");
    return;
  }

  EmberStatus st = emberAfPluginNetworkSteeringStart();
  sl_zigbee_app_debug_println("NET: steering start st=0x%02X", st);
}

void netMgrInit(void)
{
  sl_zigbee_event_init(&s_searchEvent, searchHandler);
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

  sl_zigbee_app_debug_println("NET: PB0 steering requested");
  sl_zigbee_event_set_active(&s_searchEvent);
}

void netMgrOnStackStatus(EmberStatus status)
{
  if (status == EMBER_NETWORK_UP) {
    s_pendingLeave = false;
    sl_zigbee_app_debug_println("NET: joined");
    return;
  }

  if (status == EMBER_NETWORK_DOWN && s_pendingLeave) {
    s_pendingLeave = false;
    sl_zigbee_app_debug_println("NET: left, steering in %u ms",
                                (unsigned)NETWORK_SEARCH_DELAY_MS);
    sl_zigbee_event_set_delay_ms(&s_searchEvent, NETWORK_SEARCH_DELAY_MS);
  }
}
