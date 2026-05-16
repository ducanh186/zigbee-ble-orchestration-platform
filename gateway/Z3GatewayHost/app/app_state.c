#include "app_state.h"
#include <string.h>

AppState g_state;

uint8_t    g_batteryPercent = 0;

void appStateInit(void)
{
  memset(&g_state, 0, sizeof(g_state));
  g_state.battery = 100;
  g_state.joined = false;
}

void appStateSetBattery(uint8_t battery)
{
  if (g_state.battery != battery) {
    g_state.battery = battery;
    appStateNotifyChanged();
  }
}

void appStateSetJoined(bool joined)
{
  if (g_state.joined != joined) {
    g_state.joined = joined;
    appStateNotifyChanged();
  }
}

void appStateNotifyChanged(void)
{
}
