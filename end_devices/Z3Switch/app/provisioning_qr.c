#include "provisioning_qr.h"

#include <stdio.h>
#include <string.h>

#include "app/framework/include/af.h"

// DEMO_QR_ONLY — not valid for secure join. Replaced in Phase P1b by a
// manufacturing-token read. The CRC pair on the end is intentionally a
// recognisable sentinel (0xCAFE) so anyone scanning a kit and grepping for
// "CAFE" knows the kit has not been provisioned with a real install code yet.
static const char k_demo_install_code_hex[] =
    "00112233445566778899AABBCCDDEEFF11220000CAFE";

bool provisioning_qr_get_eui64_hex(char *out, size_t out_len)
{
  if (!out || out_len < 17u) {
    return false;
  }

  EmberEUI64 eui_le;
  emberAfGetEui64(eui_le);

  static const char hex[] = "0123456789ABCDEF";
  for (uint8_t i = 0; i < 8; i++) {
    uint8_t b = eui_le[7u - i];
    out[2u * i]     = hex[(b >> 4) & 0x0Fu];
    out[2u * i + 1] = hex[b & 0x0Fu];
  }
  out[16] = '\0';
  return true;
}

bool provisioning_qr_get_install_code_hex(char *out, size_t out_len)
{
  if (!out || out_len == 0u) {
    return false;
  }

  const size_t need = sizeof(k_demo_install_code_hex);
  if (out_len < need) {
    return false;
  }

  memcpy(out, k_demo_install_code_hex, need);
  return true;
}

bool provisioning_qr_is_demo_install_code(void)
{
  return true;
}

int provisioning_qr_build_payload(char *out, size_t out_size)
{
  if (!out || out_size == 0u) {
    return -1;
  }

  char eui_hex[17];
  if (!provisioning_qr_get_eui64_hex(eui_hex, sizeof(eui_hex))) {
    return -1;
  }

  char ic_hex[64];
  if (!provisioning_qr_get_install_code_hex(ic_hex, sizeof(ic_hex))) {
    return -1;
  }

  int written = snprintf(out, out_size,
      "{\"version\":%d,"
      "\"eui64\":\"%s\","
      "\"install_code\":\"%s\","
      "\"device_type\":\"%s\","
      "\"model\":\"%s\"}",
      (int)PROVISIONING_QR_VERSION,
      eui_hex,
      ic_hex,
      PROVISIONING_QR_DEVICE_TYPE,
      PROVISIONING_QR_MODEL);

  // Wipe the local install-code copy on the way out. Stack memory will be
  // reused for other purposes; do not leave it for a later inspector to find.
  memset(ic_hex, 0, sizeof(ic_hex));

  if (written < 0 || (size_t)written >= out_size) {
    return -1;
  }
  return written;
}
