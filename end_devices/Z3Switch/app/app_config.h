#ifndef APP_CONFIG_H
#define APP_CONFIG_H

#define SWITCH_ENDPOINT          1

// Network timing
#define NETWORK_SEARCH_DELAY_MS  3000u    // 3 s delay after leave before searching
#define NETWORK_RETRY_DELAY_MS   10000u   // 10 s retry if not found
#define LED_BLINK_PERIOD_MS      500u     // LED blink rate when searching
#define FIND_BIND_DELAY_MS       3000u    // delay before find-and-bind after join

#endif
