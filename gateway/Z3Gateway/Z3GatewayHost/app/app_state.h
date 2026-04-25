#ifndef APP_STATE_H
#define APP_STATE_H
#pragma once
#include <stdint.h>
#include <stdbool.h>

typedef struct {
  uint8_t  battery;     // 0..100
  bool     joined;
} AppState;

extern AppState g_state;

void appStateInit(void);
void appStateSetBattery(uint8_t battery);
void appStateSetJoined(bool joined);
void appStateNotifyChanged(void);

// telemetry
extern uint8_t    g_batteryPercent;

#endif
