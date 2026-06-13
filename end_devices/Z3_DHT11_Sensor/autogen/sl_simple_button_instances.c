#include "sl_simple_button.h"
#include "sl_simple_button_btn0_config.h"

sl_simple_button_context_t simple_btn0_context = {
  .state = 0,
  .history = 0,
  .port = SL_SIMPLE_BUTTON_BTN0_PORT,
  .pin = SL_SIMPLE_BUTTON_BTN0_PIN,
  .mode = SL_SIMPLE_BUTTON_BTN0_MODE,
};

const sl_button_t sl_button_btn0 = {
  .context = &simple_btn0_context,
  .init = sl_simple_button_init,
  .get_state = sl_simple_button_get_state,
  .poll = sl_simple_button_poll_step,
  .enable = sl_simple_button_enable,
  .disable = sl_simple_button_disable,
};

const sl_button_t *sl_simple_button_array[] = {
  &sl_button_btn0,
};

const uint8_t simple_button_count = 1;

void sl_simple_button_init_instances(void)
{
  sl_button_init(&sl_button_btn0);
}

void sl_simple_button_poll_instances(void)
{
  sl_button_poll_step(&sl_button_btn0);
}
