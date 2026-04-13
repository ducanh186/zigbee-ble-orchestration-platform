#ifndef PIR_SENSOR_H
#define PIR_SENSOR_H

#include "em_gpio.h"

/*--- Hardware mapping: HC-SR501 OUT -> EXP3 = PD8 ---*/
#define PIR_PORT              gpioPortD
#define PIR_PIN               8

/*--- HC-SR501 output polarity ---
 * Most modules: HIGH (3.3V) = motion detected.
 * If your module is inverted, change to 0. */
#define PIR_DETECTED_LEVEL    1

/*--- Timing ---*/
#define PIR_POLL_INTERVAL_MS  200U     /* Read sensor every 200ms */
#define PIR_WARMUP_MS         60000U   /* 60s warm-up after power-on */

/*--- ZCL endpoint used by this sensor ---*/
#define PIR_ENDPOINT              1

/*--- API ---*/
void pirSensorInit(void);

#endif /* PIR_SENSOR_H */
