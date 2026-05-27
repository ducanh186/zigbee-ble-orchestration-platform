#include "buttons.h"
#include "app_config.h"
#include "net_mgr.h"

#include "app/framework/include/af.h"
#include "sl_simple_button.h"
#include "sl_simple_button_instances.h"

// Deferred action flags (set in ISR, processed in main loop)
static volatile bool g_pb0Pending = false;
static volatile bool g_pb1Pending = false;

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

  // PB1: Send On/Off toggle to bound Light
  if (g_pb1Pending) {
    g_pb1Pending = false;

    if (emberAfNetworkState() != EMBER_JOINED_NETWORK) {
      emberAfCorePrintln("BTN: PB1 -> not in network");
      return;
    }

    // Debug: check binding table
    uint8_t bindCount = 0;
    for (uint8_t i = 0; i < EMBER_BINDING_TABLE_SIZE; i++) {
      EmberBindingTableEntry entry;
      if (emberGetBinding(i, &entry) == EMBER_SUCCESS
          && entry.type != EMBER_UNUSED_BINDING) {
        bindCount++;
        emberAfCorePrintln("  bind[%d]: type=%d cluster=0x%04X ep=%d->%d node=0x%04X",
                           i, entry.type, entry.clusterId,
                           entry.local, entry.remote, entry.networkIndex);
      }
    }

    if (bindCount == 0) {
#if SWITCH_AUTO_FIND_BIND
      emberAfCorePrintln("BTN: PB1 -> NO BINDINGS! Press PB1 on Light, then run find-bind");
      netMgrStartFindBind();
#else
      // Auto find-bind disabled. In normal operation Find-and-Bind during
      // commissioning leaves the switch -> gateway binding in NVM3; switch
      // presses reach the gateway and cloud automation rule fires the light.
      // If the binding table is empty, the user must re-commission with
      // SWITCH_AUTO_FIND_BIND=1 (see app_config.h).
      emberAfCorePrintln("BTN: PB1 -> no bindings; rebuild with SWITCH_AUTO_FIND_BIND=1 to commission");
#endif
      return;
    }

    emberAfGetCommandApsFrame()->sourceEndpoint = SWITCH_ENDPOINT;
    emberAfFillCommandOnOffClusterToggle();
    EmberStatus st = emberAfSendCommandUnicastToBindings();
    emberAfCorePrintln("BTN: PB1 -> toggle sent st=0x%02X (bindings=%d)", st, bindCount);
  }
}
