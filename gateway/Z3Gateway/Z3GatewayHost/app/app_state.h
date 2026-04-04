#ifndef APP_STATE_H
#define APP_STATE_H
#pragma once
#include <stdint.h>
#include <stdbool.h>

typedef enum { MODE_MANUAL = 0, MODE_AUTO = 1 } app_mode_t;

typedef struct {
  uint16_t flow;        // 0..65535
  uint8_t  battery;     // 0..100
  bool     joined;
  char     valveStr[8]; // "open"/"closed"
} AppState;

extern AppState g_state;

void appStateInit(void);
void appStateSetFlow(uint16_t flow);
void appStateSetBattery(uint8_t battery);
void appStateSetValveStr(const char *s);
void appStateSetJoined(bool joined);
void appStateNotifyChanged(void);

// telemetry
extern uint16_t   g_flow;
extern uint8_t    g_batteryPercent;

// mode
extern app_mode_t g_mode;

#endif
