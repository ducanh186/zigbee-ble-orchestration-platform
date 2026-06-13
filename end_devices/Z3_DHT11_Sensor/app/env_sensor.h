#ifndef ENV_SENSOR_H
#define ENV_SENSOR_H

/*--- Schedule (per local-DHT11 spec) ---
 * Read the sensor every 5s. Report at least every 60s, earlier when the
 * value moves >= 1.0 C or >= 5 %RH since the last report. */
#define ENV_READ_INTERVAL_MS    5000u
#define ENV_REPORT_INTERVAL_MS  60000u
#define ENV_TEMP_DELTA_DC       10u    /* deci-degC: 1.0 C  */
#define ENV_RH_DELTA_DP         50u    /* deci-%RH:  5.0 %  */

/* Failed reads retry sooner than the 5s cadence, a couple of times. */
#define ENV_RETRY_DELAY_MS      1000u
#define ENV_MAX_RETRIES         2u

/*--- API ---*/
void envSensorInit(void);

#endif /* ENV_SENSOR_H */
