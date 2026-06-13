#include "display_qr.h"
#include "provisioning_qr.h"
#include "qrcodegen.h"

#include <stdio.h>
#include <string.h>

#include "app/framework/include/af.h"
#include "dmd.h"
#include "glib.h"
#include "sl_board_control.h"

// LS013B7DH03 panel geometry. Hard-coded — these are physical constants of
// the WSTK display, not configurable.
#define DISPLAY_W 128
#define DISPLAY_H 128

// Layout: 16 px header band at top, 16 px footer band at bottom, QR in
// between. With QR Version 7 (45 modules) at scale=2 = 90 px, that leaves
// 128 - 90 = 38 px split header/footer.
#define HEADER_H  16
#define FOOTER_Y  (DISPLAY_H - 8)

// QR sizing — V8 with ECC level LOW. The contract-shape payload runs ~154 B
// (kit-dependent within ±2 B). Per ISO/IEC 18004:2015 Table 7, byte-mode
// capacity is V7-M = 122 B (too small), V8-M = 152 B (still 2 B short for
// our 154 B payload), V8-L = 192 B (fits with comfortable headroom). ECC-L
// gives 7% damage recovery — adequate for a static, well-lit, on-screen QR
// scanned at ~10 cm by a modern phone camera. Keep min == max so the
// encoder emits exactly version 8 and the on-screen size is deterministic.
#define QR_MIN_VERSION 8
#define QR_MAX_VERSION 8
#define QR_MODULE_SCALE 2
#define QR_ECC_LEVEL qrcodegen_Ecc_LOW

static GLIB_Context_t s_ctx;
static bool s_initialized = false;
static char s_title[24] = {0};

static void clear_and_set_font(void)
{
  GLIB_clear(&s_ctx);
  GLIB_setFont(&s_ctx, (GLIB_Font_t *)&GLIB_FontNarrow6x8);
}

static void draw_text_line(uint8_t line, const char *str)
{
  if (!str) return;
  GLIB_drawStringOnLine(&s_ctx, str, line, GLIB_ALIGN_CENTER, 0, 0, true);
}

static void draw_eui_tail(uint8_t line)
{
  char eui_hex[17];
  if (!provisioning_qr_get_eui64_hex(eui_hex, sizeof(eui_hex))) {
    draw_text_line(line, "EUI: ????");
    return;
  }
  // Tail-only display: full 16 hex chars don't fit nicely in a 21-char row,
  // and the operator only needs the last 4 to disambiguate kits.
  char tail[10];
  snprintf(tail, sizeof(tail), "...%.4s", &eui_hex[12]);
  draw_text_line(line, tail);
}

bool display_qr_init(const char *title)
{
  if (s_initialized) {
    return true;
  }

  // BRD4162A drives the Sharp Memory LCD enable pin (PD15) via the
  // board_control component. The autogen template only auto-calls this when
  // SL_BOARD_ENABLE_DISPLAY = 1 — which we set via slcp configuration — but
  // we also call it here defensively. Without this the SPI writes succeed
  // but the panel ignores them and the previously-flashed image persists.
  (void)sl_board_enable_display();

  if (DMD_init(NULL) != DMD_OK) {
    return false;
  }
  if (GLIB_contextInit(&s_ctx) != GLIB_OK) {
    return false;
  }

  s_ctx.backgroundColor = White;
  s_ctx.foregroundColor = Black;

  GLIB_setFont(&s_ctx, (GLIB_Font_t *)&GLIB_FontNarrow6x8);
  GLIB_clear(&s_ctx);

  if (title) {
    strncpy(s_title, title, sizeof(s_title) - 1u);
    s_title[sizeof(s_title) - 1u] = '\0';
  }

  // Boot splash — drawn once. Replaced by the provisioning view as soon as
  // display_qr_render_provisioning() runs.
  draw_text_line(0, s_title[0] ? s_title : "DEVICE BOOT");
  draw_text_line(2, "init...");
  DMD_updateDisplay();

  s_initialized = true;
  return true;
}

static bool render_qr_matrix(const char *text, int origin_x, int origin_y)
{
  static uint8_t qr_buf [qrcodegen_BUFFER_LEN_FOR_VERSION(QR_MAX_VERSION)];
  static uint8_t tmp_buf[qrcodegen_BUFFER_LEN_FOR_VERSION(QR_MAX_VERSION)];

  bool ok = qrcodegen_encodeText(text, tmp_buf, qr_buf,
                                 QR_ECC_LEVEL,
                                 QR_MIN_VERSION, QR_MAX_VERSION,
                                 qrcodegen_Mask_AUTO,
                                 /* boostEcl = */ false);
  int size = ok ? qrcodegen_getSize(qr_buf) : 0;
  // Diagnostic — metadata only, no payload bytes. Helps catch capacity
  // regressions if the payload grows. Contract §7 forbids logging
  // install_code; this log only emits ok flag + matrix dimension.
  emberAfCorePrintln("[QR] encode_ok=%d size=%d", (int)ok, size);
  if (!ok) {
    return false;
  }
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (qrcodegen_getModule(qr_buf, x, y)) {
        // Each QR module = QR_MODULE_SCALE x QR_MODULE_SCALE black square.
        GLIB_Rectangle_t rect = {
          .xMin = origin_x + x * QR_MODULE_SCALE,
          .yMin = origin_y + y * QR_MODULE_SCALE,
          .xMax = origin_x + x * QR_MODULE_SCALE + (QR_MODULE_SCALE - 1),
          .yMax = origin_y + y * QR_MODULE_SCALE + (QR_MODULE_SCALE - 1),
        };
        GLIB_drawRectFilled(&s_ctx, &rect);
      }
    }
  }
  return true;
}

bool display_qr_render_provisioning(const char *payload_for_qr)
{
  if (!s_initialized) {
    return false;
  }
  if (!payload_for_qr) {
    return false;
  }

  clear_and_set_font();

  // Header band (lines 0-1, 16 px).
  draw_text_line(0, s_title[0] ? s_title : "DEVICE");
  draw_eui_tail(1);

  // Center the QR horizontally. V8 = 49 modules, scale 2 = 98 px → x_origin
  // = (128 - 98)/2 = 15. Vertically place under the 16 px header.
  const int qr_pixels = 49 * QR_MODULE_SCALE;
  const int origin_x = (DISPLAY_W - qr_pixels) / 2;
  const int origin_y = HEADER_H + 4;

  bool encoded = render_qr_matrix(payload_for_qr, origin_x, origin_y);

  // Footer band — single line. Use "DEMO" prefix when install_code is the
  // compile-time placeholder so the operator can never confuse a not-yet-
  // provisioned kit with a production-provisioned kit.
  // Footer at line 15 must fit within 128 px width. With the 6x8 narrow
  // font, max ~21 chars before the glib text clipper drops the whole
  // string. Keep both variants <= 18 chars.
  const char *footer_ok = provisioning_qr_is_demo_install_code()
      ? "DEMO Scan to bind"
      : "Scan to provision";
  const char *footer = encoded ? footer_ok : "QR ENCODE FAILED";
  GLIB_drawStringOnLine(&s_ctx, footer, 15, GLIB_ALIGN_CENTER, 0, 0, true);

  DMD_updateDisplay();
  return encoded;
}
