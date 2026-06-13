#ifndef DHT11_H
#define DHT11_H

#include <stdint.h>
#include <stdbool.h>
#include "em_gpio.h"

/*--- Hardware mapping: DHT11 DATA -> EXP3 = PD8 ---
 * Same physical EXP-header pin the PIR OUT used on this board config, so it
 * is known-free (no UART/LED/button/LCD/PTI conflict on BRD4162A).
 * DATA is open-drain with a pull-up to 3V3 (external 4.7k-10k recommended;
 * the MCU-internal pull-up is enabled too). Never driven high by the MCU,
 * never exposed to 5V. */
#define DHT11_PORT            gpioPortD
#define DHT11_PIN             8

/*--- Protocol timing bounds (all waits are hard-bounded, never infinite) ---*/
#define DHT11_START_LOW_MS    20u   /* host start signal, >=18ms per datasheet */
#define DHT11_RESP_TIMEOUT_US 200u  /* sensor 80us low + 80us high response    */
#define DHT11_BIT_TIMEOUT_US  150u  /* per bit phase: 50us low, 26-70us high   */
#define DHT11_ONE_THRESH_US   50u   /* high phase > 50us => bit is 1           */

typedef enum {
  DHT11_OK = 0,
  DHT11_ERR_TIMEOUT,       /* sensor missing / stuck line; see dht11_last_stage */
  DHT11_ERR_CHECKSUM,      /* 40 bits read but checksum mismatch                */
} dht11_status_t;

/* Stage names for "DHT11 timeout at stage=..." logs. */
typedef enum {
  DHT11_STAGE_NONE = 0,
  DHT11_STAGE_RELEASE,     /* line did not rise after host released it  */
  DHT11_STAGE_RESP_LOW,    /* sensor never pulled the 80us response low */
  DHT11_STAGE_RESP_HIGH,   /* sensor never released the response high   */
  DHT11_STAGE_BIT_LOW,     /* bit N: 50us low phase missing             */
  DHT11_STAGE_BIT_HIGH,    /* bit N: data high phase missing            */
} dht11_stage_t;

/* One-time init: pin to idle (input + pull-up) and DWT cycle counter on. */
void dht11_init(void);

/* Phase 1 of a read: drive DATA low (open-drain) for the start signal.
 * Caller must wait >= DHT11_START_LOW_MS (via an event/timer, not a busy
 * loop) and then call dht11_read_finish(). */
void dht11_read_begin(void);

/* Phase 2: release the line, clock in the 40-bit frame, validate checksum.
 * Blocking for at most ~6ms (hard DWT timeouts on every wait), runs inside
 * a critical section so radio IRQs cannot stretch a bit measurement.
 * On DHT11_OK fills:
 *   *temp_dc = temperature in deci-degC (e.g. 285 = 28.5 C)
 *   *rh_dp   = relative humidity in deci-%RH (e.g. 650 = 65.0 %)
 * On error the outputs are untouched; dht11_last_stage()/dht11_last_bit()
 * tell where it died. The pin is always returned to idle pull-up. */
dht11_status_t dht11_read_finish(int16_t *temp_dc, uint16_t *rh_dp);

dht11_stage_t dht11_last_stage(void);
uint8_t       dht11_last_bit(void);
const char   *dht11_stage_name(dht11_stage_t stage);

#endif /* DHT11_H */
