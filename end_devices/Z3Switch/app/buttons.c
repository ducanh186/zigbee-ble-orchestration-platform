#include "buttons.h"
#include "app_config.h"
#include "net_mgr.h"

#include "app/framework/include/af.h"
#include "sl_simple_button.h"
#include "sl_simple_button_instances.h"

// Deferred action flags (set in ISR, processed in main loop)
static volatile bool g_pb0Pending = false;
static volatile bool g_pb1Pending = false;

// PB1 software debounce: one physical press was observed to enqueue ~15 toggle
// sends (contact bounce / repeat), flooding the gateway automation. Ignore PB1
// presses that land within this window of the last accepted one.
#define PB1_DEBOUNCE_MS   300u
static uint32_t g_lastPb1Ms = 0;

// ---------------------------------------------------------------------------
void buttonsInit(void)
{
  // Button hardware is initialized by the driver
}

// ---------------------------------------------------------------------------
// Called from ISR — only set flags, no stack calls!
void sl_button_on_change(const sl_button_t *handle)
{
  if (handle == &sl_button_btn0) {
    if (sl_button_get_state(handle) == SL_SIMPLE_BUTTON_PRESSED) {
      g_pb0Pending = true;
    }
  } else if (handle == &sl_button_btn1) {
    if (sl_button_get_state(handle) == SL_SIMPLE_BUTTON_PRESSED) {
      g_pb1Pending = true;
    }
  }
}

// ---------------------------------------------------------------------------
void buttonsTick(void)
{
  // PB0: Leave network and rejoin
  if (g_pb0Pending) {
    g_pb0Pending = false;
    emberAfCorePrintln("BTN: PB0 -> leave and rejoin");
    netMgrRequestLeaveAndRejoin();
  }

  // PB1: send an On/Off Toggle straight to the gateway/coordinator (0x0000).
  // The gateway's PRE_CMD hook turns it into a switch "toggle" event and the
  // cloud automation rule drives the light. No binding is involved — the cloud
  // owns the switch -> light path. (Previously this sent to the binding table,
  // but net_mgr wipes bindings on boot when SWITCH_AUTO_FIND_BIND=0, so the
  // toggle had no target and PB1 did nothing.)
  if (g_pb1Pending) {
    g_pb1Pending = false;

    // Debounce: drop bounce/repeat presses inside the window.
    uint32_t now = halCommonGetInt32uMillisecondTick();
    if (g_lastPb1Ms != 0 && (uint32_t)(now - g_lastPb1Ms) < PB1_DEBOUNCE_MS) {
      return;
    }
    g_lastPb1Ms = now;

    if (emberAfNetworkState() != EMBER_JOINED_NETWORK) {
      emberAfCorePrintln("BTN: PB1 -> not in network");
      return;
    }

    emberAfFillCommandOnOffClusterToggle();
    EmberApsFrame *aps = emberAfGetCommandApsFrame();
    aps->sourceEndpoint      = SWITCH_ENDPOINT;
    aps->destinationEndpoint = GATEWAY_ENDPOINT;
    EmberStatus st = emberAfSendCommandUnicast(EMBER_OUTGOING_DIRECT,
                                               GATEWAY_NODE_ID);
    emberAfCorePrintln("BTN: PB1 -> toggle to gateway 0x%04X st=0x%02X",
                       GATEWAY_NODE_ID, (unsigned)st);
  }
}
