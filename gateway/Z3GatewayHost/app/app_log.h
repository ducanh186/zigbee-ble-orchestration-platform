#ifndef APP_LOG_H
#define APP_LOG_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ===== STABLE UART LINE PROTOCOL =====
// All output follows: "@PREFIX <compact JSON>\r\n"
// Prefixes: @INFO, @DATA, @LOG, @ACK

// === INFO: System/network status ===
void appLogInfo(void);

// === DATA: Telemetry ===
void appLogData(void);

// === LOG: Events and debug (structured logging) ===
void appLogLog(const char *tag, const char *event, const char *fmt, ...);

// === ACK: Command acknowledgment ===
void appLogAck(uint32_t id, bool ok, const char *msg);

// Extended ACK with Zigbee status
void appLogAckZb(uint32_t id, bool ok, const char *msg, uint8_t zstatus, const char *stage);

// === Emit @INFO now ===
void appLogEmitHeartbeat(void);

// === UPTIME tracking ===
uint32_t appLogGetUptimeSec(void);

#ifdef __cplusplus
}
#endif

#endif // APP_LOG_H
