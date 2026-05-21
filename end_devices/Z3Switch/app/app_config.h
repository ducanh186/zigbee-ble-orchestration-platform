#ifndef APP_CONFIG_H
#define APP_CONFIG_H

#define SWITCH_ENDPOINT          1

// Network timing
#define NETWORK_SEARCH_DELAY_MS  3000u    // 3 s delay after leave before searching
#define NETWORK_RETRY_DELAY_MS   10000u   // 10 s retry if not found
#define LED_BLINK_PERIOD_MS      500u     // LED blink rate when searching
#define FIND_BIND_DELAY_MS       3000u    // delay before find-and-bind after join

// Auto Find-and-Bind to a server (typically a light) at boot / after join,
// and on PB1 when the binding table is empty.
//
// In production the switch -> light path is owned by cloud automation rules
// (`SB_AUTOMATION_SWITCH_HOOK=1` on the gateway). The local Zigbee direct
// binding is intentionally removed so the dashboard rule is authoritative.
// If Find-and-Bind keeps re-creating that binding every reboot the dashboard
// rule gets double-toggled by direct binding => undefined UX.
//
// 0 = off (default). Switch only emits On/Off commands to existing bindings.
// 1 = on. Use only for first-time commissioning; flash, bind a light by
//     pressing PB1 on the light to enter Identify, then reflash with =0.
#ifndef SWITCH_AUTO_FIND_BIND
#define SWITCH_AUTO_FIND_BIND    0
#endif

#endif
