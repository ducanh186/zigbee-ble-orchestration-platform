#include "buttons.h"
#include "net_mgr.h"

#include <stdbool.h>

#include "sl_simple_button.h"
#include "sl_simple_button_instances.h"

static volatile bool s_pb0Pending = false;

void buttonsInit(void)
{
}

void sl_button_on_change(const sl_button_t *handle)
{
  if (handle == &sl_button_btn0
      && sl_button_get_state(handle) == SL_SIMPLE_BUTTON_PRESSED) {
    s_pb0Pending = true;
  }
}

void buttonsTick(void)
{
  if (!s_pb0Pending) {
    return;
  }

  s_pb0Pending = false;
  netMgrRequestLeaveAndRejoin();
}
