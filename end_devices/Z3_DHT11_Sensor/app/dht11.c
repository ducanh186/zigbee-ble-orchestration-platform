#include "dht11.h"

#include <stddef.h>
#include "em_core.h"
#include "em_device.h"
#include "em_cmu.h"

static dht11_stage_t s_lastStage = DHT11_STAGE_NONE;
static uint8_t       s_lastBit   = 0;
static uint32_t      s_cyclesPerUs = 38; /* refreshed in dht11_init() */

/* DWT cycle counter gives us sub-microsecond timing that keeps working
 * inside a critical section (no IRQs needed), which a sleeptimer tick
 * (30.5us at 32768Hz) cannot do for 26-70us pulse discrimination. */
static inline uint32_t nowCycles(void)
{
  return DWT->CYCCNT;
}

static inline uint32_t usToCycles(uint32_t us)
{
  return us * s_cyclesPerUs;
}

/* Wait until DATA reads `level`. Returns true and writes the elapsed time
 * if it happened within `timeout_us`, false on timeout. Hard-bounded:
 * this is the only wait primitive in the driver, so no path can hang. */
static bool waitLevel(unsigned int level, uint32_t timeout_us, uint32_t *elapsed_us)
{
  uint32_t start = nowCycles();
  uint32_t limit = usToCycles(timeout_us);

  while (GPIO_PinInGet(DHT11_PORT, DHT11_PIN) != level) {
    if ((nowCycles() - start) > limit) {
      return false;
    }
  }
  if (elapsed_us != NULL) {
    *elapsed_us = (nowCycles() - start) / s_cyclesPerUs;
  }
  return true;
}

static void pinIdle(void)
{
  /* Input with internal pull-up: the bus idles high at 3V3. */
  GPIO_PinModeSet(DHT11_PORT, DHT11_PIN, gpioModeInputPull, 1);
}

void dht11_init(void)
{
  /* GPIO clock is already enabled by sl_system_init(). */
  pinIdle();

  /* Enable the DWT cycle counter (free on Cortex-M4, survives sleep modes
   * we use; EM1+ is never entered while a read is in flight because the
   * read runs to completion inside one event handler). */
  CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;
  DWT->CYCCNT = 0;
  DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;

  uint32_t hz = CMU_ClockFreqGet(cmuClock_CORE);
  s_cyclesPerUs = (hz >= 1000000u) ? (hz / 1000000u) : 1u;
}

void dht11_read_begin(void)
{
  /* Open-drain (wired-AND) driving 0: we only ever pull the line down,
   * the pull-up to 3V3 raises it. The MCU never sources high level. */
  GPIO_PinModeSet(DHT11_PORT, DHT11_PIN, gpioModeWiredAnd, 0);
}

dht11_status_t dht11_read_finish(int16_t *temp_dc, uint16_t *rh_dp)
{
  uint8_t data[5] = { 0 };
  dht11_status_t status = DHT11_OK;

  s_lastStage = DHT11_STAGE_NONE;
  s_lastBit = 0;

  CORE_DECLARE_IRQ_STATE;
  CORE_ENTER_CRITICAL();

  /* Release the bus; pull-up raises it, then the sensor answers with
   * 80us low + 80us high before streaming 40 bits. */
  pinIdle();

  if (!waitLevel(1, DHT11_RESP_TIMEOUT_US, NULL)) {
    s_lastStage = DHT11_STAGE_RELEASE;
    status = DHT11_ERR_TIMEOUT;
  } else if (!waitLevel(0, DHT11_RESP_TIMEOUT_US, NULL)) {
    s_lastStage = DHT11_STAGE_RESP_LOW;
    status = DHT11_ERR_TIMEOUT;
  } else if (!waitLevel(1, DHT11_RESP_TIMEOUT_US, NULL)) {
    s_lastStage = DHT11_STAGE_RESP_HIGH;
    status = DHT11_ERR_TIMEOUT;
  } else {
    for (uint8_t bit = 0; bit < 40u && status == DHT11_OK; bit++) {
      uint32_t highUs = 0;

      /* 50us low preamble of every bit. */
      if (!waitLevel(0, DHT11_BIT_TIMEOUT_US, NULL)) {
        s_lastStage = DHT11_STAGE_BIT_LOW;
        s_lastBit = bit;
        status = DHT11_ERR_TIMEOUT;
        break;
      }
      /* Data phase: 26-28us high = 0, ~70us high = 1. Measure by waiting
       * for the next falling edge (start of the following bit's low). */
      if (!waitLevel(1, DHT11_BIT_TIMEOUT_US, NULL)) {
        s_lastStage = DHT11_STAGE_BIT_HIGH;
        s_lastBit = bit;
        status = DHT11_ERR_TIMEOUT;
        break;
      }
      if (!waitLevel(0, DHT11_BIT_TIMEOUT_US, &highUs)) {
        /* Last bit's trailing edge: the sensor releases the bus high after
         * bit 39, so a missing final falling edge still gives us the
         * high-time via the timeout path only for bit < 39. */
        if (bit == 39u) {
          highUs = DHT11_BIT_TIMEOUT_US;
        } else {
          s_lastStage = DHT11_STAGE_BIT_LOW;
          s_lastBit = bit;
          status = DHT11_ERR_TIMEOUT;
          break;
        }
      }

      if (highUs > DHT11_ONE_THRESH_US) {
        data[bit / 8u] |= (uint8_t)(0x80u >> (bit % 8u));
      }
    }
  }

  CORE_EXIT_CRITICAL();
  pinIdle();

  if (status != DHT11_OK) {
    return status;
  }

  if (((uint8_t)(data[0] + data[1] + data[2] + data[3])) != data[4]) {
    return DHT11_ERR_CHECKSUM;
  }

  /* DHT11 frame: [0]=RH int, [1]=RH decimal (0-9), [2]=T int, [3]=T decimal.
   * Clamp the decimal bytes — genuine DHT11s send 0, some clones send
   * tenths; anything >9 is garbage we refuse to scale. */
  uint8_t rhDec = (data[1] <= 9u) ? data[1] : 0u;
  uint8_t tDec  = (data[3] <= 9u) ? data[3] : 0u;

  *rh_dp   = (uint16_t)(data[0] * 10u + rhDec);
  *temp_dc = (int16_t)(data[2] * 10 + tDec);
  return DHT11_OK;
}

dht11_stage_t dht11_last_stage(void)
{
  return s_lastStage;
}

uint8_t dht11_last_bit(void)
{
  return s_lastBit;
}

const char *dht11_stage_name(dht11_stage_t stage)
{
  switch (stage) {
    case DHT11_STAGE_RELEASE:   return "release";
    case DHT11_STAGE_RESP_LOW:  return "resp_low";
    case DHT11_STAGE_RESP_HIGH: return "resp_high";
    case DHT11_STAGE_BIT_LOW:   return "bit_low";
    case DHT11_STAGE_BIT_HIGH:  return "bit_high";
    default:                    return "none";
  }
}
