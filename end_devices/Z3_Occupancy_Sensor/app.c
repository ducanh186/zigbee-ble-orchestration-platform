/***************************************************************************//**
 * @file app.c
 * @brief Callbacks implementation and application specific code.
 *******************************************************************************
 * # License
 * <b>Copyright 2021 Silicon Laboratories Inc. www.silabs.com</b>
 *******************************************************************************
 *
 * The licensor of this software is Silicon Laboratories Inc. Your use of this
 * software is governed by the terms of Silicon Labs Master Software License
 * Agreement (MSLA) available at
 * www.silabs.com/about-us/legal/master-software-license-agreement. This
 * software is distributed to you in Source Code format and is governed by the
 * sections of the MSLA applicable to Source Code.
 *
 ******************************************************************************/

#include "app/framework/include/af.h"
#include "find-and-bind-initiator.h"
#include "app/pir_sensor.h"

/* ---------- Find & Bind Initiator ---------- */
#define FIND_BIND_DELAY_MS      3000u    /* delay after join before F&B */
#define FIND_BIND_RETRY_MAX     5
#define FIND_BIND_RETRY_MS      15000u   /* 15s between retries */

static sl_zigbee_event_t s_findBindEvent;
static bool     s_bindingDone  = false;
static uint8_t  s_findBindRetry = 0;

static void findBindHandler(sl_zigbee_event_t *event)
{
  (void)event;
  if (emberAfNetworkState() != EMBER_JOINED_NETWORK) return;
  if (s_bindingDone) return;

  EmberStatus st = emberAfPluginFindAndBindInitiatorStart(PIR_ENDPOINT);
  sl_zigbee_app_debug_println("F&B: initiator start st=0x%02X (attempt %d/%d)",
                              st, s_findBindRetry + 1, FIND_BIND_RETRY_MAX);
}

/* Called by the Find & Bind plugin when initiator process completes */
void emberAfPluginFindAndBindInitiatorCompleteCallback(EmberStatus status)
{
  sl_zigbee_app_debug_println("F&B: initiator complete st=0x%02X (attempt %d)",
                              status, s_findBindRetry + 1);

  if (status == EMBER_SUCCESS) {
    s_bindingDone = true;
    sl_zigbee_app_debug_println("F&B: BINDING OK — PIR motion will now control light");
  } else {
    s_findBindRetry++;
    if (s_findBindRetry < FIND_BIND_RETRY_MAX) {
      sl_zigbee_app_debug_println("F&B: retry in %u ms", FIND_BIND_RETRY_MS);
      sl_zigbee_event_set_delay_ms(&s_findBindEvent, FIND_BIND_RETRY_MS);
    } else {
      sl_zigbee_app_debug_println("F&B: gave up after %d attempts — use CLI: "
                                  "plugin find_and_bind initiator 1",
                                  FIND_BIND_RETRY_MAX);
    }
  }
}

/* ---------- Network callbacks ---------- */

void emberAfPluginNetworkSteeringCompleteCallback(EmberStatus status,
                                                  uint8_t totalBeacons,
                                                  uint8_t joinAttempts,
                                                  uint8_t finalState)
{
  sl_zigbee_app_debug_println("%s network %s: 0x%02X", "Join", "complete", status);
}

void emberAfStackStatusCallback(EmberStatus status)
{
  sl_zigbee_app_debug_println("NET: stack status=0x%02X", status);

  if (status == EMBER_NETWORK_UP) {
    /* Set sensor type = PIR (0x00) and sensor type bitmap = PIR (0x01) */
    uint8_t sensorType = EMBER_ZCL_OCCUPANCY_SENSOR_TYPE_PIR;
    uint8_t sensorTypeBitmap = 0x01u;
    emberAfWriteServerAttribute(PIR_ENDPOINT,
                                ZCL_OCCUPANCY_SENSING_CLUSTER_ID,
                                ZCL_OCCUPANCY_SENSOR_TYPE_ATTRIBUTE_ID,
                                &sensorType,
                                ZCL_ENUM8_ATTRIBUTE_TYPE);
    emberAfWriteServerAttribute(PIR_ENDPOINT,
                                ZCL_OCCUPANCY_SENSING_CLUSTER_ID,
                                ZCL_OCCUPANCY_SENSOR_TYPE_BITMAP_ATTRIBUTE_ID,
                                &sensorTypeBitmap,
                                ZCL_BITMAP8_ATTRIBUTE_TYPE);

    /* Kick off Find & Bind initiator to auto-bind to lights */
    s_findBindRetry = 0;
    s_bindingDone = false;
    sl_zigbee_event_set_delay_ms(&s_findBindEvent, FIND_BIND_DELAY_MS);
  }
}

/** @brief Must be called from app_init() in main.c */
void appFindBindInit(void)
{
  sl_zigbee_event_init(&s_findBindEvent, findBindHandler);

  /* If already on network at boot (e.g. after reset), try F&B */
  if (emberAfNetworkState() == EMBER_JOINED_NETWORK) {
    s_findBindRetry = 0;
    s_bindingDone = false;
    sl_zigbee_event_set_delay_ms(&s_findBindEvent, FIND_BIND_DELAY_MS);
  }
}

/** @brief Application framework equivalent of ::emberRadioNeedsCalibratingHandler */
void emberAfRadioNeedsCalibratingCallback(void)
{
  sl_mac_calibrate_current_channel();
}
