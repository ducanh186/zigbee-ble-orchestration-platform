/***************************************************************************//**
 * @file
 * @brief Simple Led Driver Configuration
 *******************************************************************************
 * # License
 * <b>Copyright 2019 Silicon Laboratories Inc. www.silabs.com</b>
 *******************************************************************************
 *
 * SPDX-License-Identifier: Zlib
 *
 ******************************************************************************/

#ifndef SL_SIMPLE_LED_LED1_CONFIG_H
#define SL_SIMPLE_LED_LED1_CONFIG_H

// <<< Use Configuration Wizard in Context Menu >>>

// <h> Simple LED configuration
// <o SL_SIMPLE_LED_LED1_POLARITY>
// <SL_SIMPLE_LED_POLARITY_ACTIVE_LOW=> Active low
// <SL_SIMPLE_LED_POLARITY_ACTIVE_HIGH=> Active high
// <i> Default: SL_SIMPLE_LED_POLARITY_ACTIVE_HIGH
#define SL_SIMPLE_LED_LED1_POLARITY SL_SIMPLE_LED_POLARITY_ACTIVE_HIGH
// </h> end led configuration

// <<< end of configuration section >>>

// <<< sl:start pin_tool >>>

// <gpio> SL_SIMPLE_LED_LED1
// $[GPIO_SL_SIMPLE_LED_LED1]
#ifndef SL_SIMPLE_LED_LED1_PORT
#define SL_SIMPLE_LED_LED1_PORT                  gpioPortF
#endif
#ifndef SL_SIMPLE_LED_LED1_PIN
#define SL_SIMPLE_LED_LED1_PIN                   5
#endif
// [GPIO_SL_SIMPLE_LED_LED1]$

// <<< sl:end pin_tool >>>

#endif // SL_SIMPLE_LED_LED1_CONFIG_H
