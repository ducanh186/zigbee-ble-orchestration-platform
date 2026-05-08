#ifndef SL_SIMPLE_BUTTON_BTN0_CONFIG_H
#define SL_SIMPLE_BUTTON_BTN0_CONFIG_H

#include "em_gpio.h"
#include "sl_simple_button.h"

#define SL_SIMPLE_BUTTON_BTN0_MODE  SL_SIMPLE_BUTTON_MODE_INTERRUPT

#ifndef SL_SIMPLE_BUTTON_BTN0_PORT
#define SL_SIMPLE_BUTTON_BTN0_PORT  gpioPortF
#endif

#ifndef SL_SIMPLE_BUTTON_BTN0_PIN
#define SL_SIMPLE_BUTTON_BTN0_PIN   6
#endif

#endif
