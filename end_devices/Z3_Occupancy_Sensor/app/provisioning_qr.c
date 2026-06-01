#include "provisioning_qr.h"

#include <stdio.h>
#include <string.h>

#include "app/framework/include/af.h"

// Fallback only — used when the kit has NO real install code programmed into
// its MFG_INSTALLATION_CODE token (token flag bit0 == 1, uninitialized). The
// trailing 0xCAFE sentinel lets anyone scanning such a kit and grepping for
// "CAFE" know it has not been provisioned yet. A provisioned kit shows its
// real 18-byte install code (read from the token below), NOT this.
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

// Read the 18-byte install code (16-byte value + 2-byte CRC) from the
// MFG_INSTALLATION_CODE manufacturing token and emit it as uppercase hex.
// `value[16]` is immediately followed by `crc` (uint16_t, little-endian) in
// tokTypeMfgInstallationCode, so 18 contiguous bytes from .value == the
// on-the-wire install code the gateway stages (data + CRC, CRC low-byte
// first). Matches Simplicity Commander tokendump / `pjoin-secure` exactly.
bool provisioning_qr_get_install_code_hex(char *out, size_t out_len)
{
  // 18 bytes -> 36 hex chars + NUL = 37; demo fallback needs 45.
  if (!out || out_len < sizeof(k_demo_install_code_hex)) {
    return false;
  }

  tokTypeMfgInstallationCode tok;
  halCommonGetMfgToken(&tok, TOKEN_MFG_INSTALLATION_CODE);

  // flags bit0 == 1 -> token uninitialized: kit not provisioned. Render the
  // demo sentinel so the QR still draws, recognisable by the trailing CAFE.
  if (tok.flags & 0x0001u) {
    memcpy(out, k_demo_install_code_hex, sizeof(k_demo_install_code_hex));
    return true;
  }

  static const char hex[] = "0123456789ABCDEF";
  const uint8_t *ic = (const uint8_t *)tok.value;   // value[16] + crc[2] contiguous
  for (uint8_t i = 0; i < 18u; i++) {
    out[2u * i]     = hex[(ic[i] >> 4) & 0x0Fu];
    out[2u * i + 1] = hex[ic[i] & 0x0Fu];
  }
  out[36] = '\0';

  // Do not leave the secret on the stack.
  memset(&tok, 0, sizeof(tok));
  return true;
}

bool provisioning_qr_is_demo_install_code(void)
{
  tokTypeMfgInstallationCode tok;
  halCommonGetMfgToken(&tok, TOKEN_MFG_INSTALLATION_CODE);
  bool is_demo = (tok.flags & 0x0001u) != 0u;   // uninitialized token == demo
  memset(&tok, 0, sizeof(tok));
  return is_demo;
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
