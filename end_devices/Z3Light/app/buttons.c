#include "buttons.h"
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

  // PB1: Manually start find-and-bind target (make Light discoverable)
  if (g_pb1Pending) {
    g_pb1Pending = false;
    emberAfCorePrintln("BTN: PB1 -> start find-and-bind target");
    netMgrStartFindBind();
  }
}
