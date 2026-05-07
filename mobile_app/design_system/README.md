# Zigbee Smart Building — Design System

A design system for the **Zigbee Smart Building Mobile App**: an Android/Flutter application that controls Zigbee LIGHT nodes through a FastAPI Cloud REST API. The app is part of a larger IoT orchestration platform (`zigbee-ble-orchestration-platform`) that bridges a Z3Gateway/EFR32 NCP radio to the cloud over MQTT.

The mobile app itself is a thin client: **it never speaks MQTT or Zigbee directly** — it only calls REST. The visual language is therefore tuned for **operator-style debug clarity**: device state, command lifecycle, and event logs must be readable at a glance, in light, dark, and grey ambient conditions.

## Sources

- **System design doc** — `systemdes.md` (provided in the project brief). The single source of truth for routes, theme tokens, components, API contract, polling policy, and screen list.
- **Codebase** (read-only, mounted) — `zigbee-ble-orchestration-platform/`
  - Top-level `README.md` describing the platform architecture
  - `cloud/` FastAPI backend exposing `/api/devices`, `/api/commands`, `/api/events`
  - `mobile_app/` is a placeholder — Flutter project not yet scaffolded
  - `docs/` contains MQTT, UART, OTA, and capability matrix docs

> The mobile app folder in the codebase is currently empty (placeholder only). All visual / token decisions in this design system come from the `systemdes.md` brief.

## Products represented

This system covers **one product surface**:

1. **Mobile App (Flutter / Android)** — operator-facing app for monitoring and controlling Zigbee nodes. MVP scope is LIGHT (on/off), with Logs, Devices, Home, and Settings tabs and three theme modes (Light, Dark, Grey).

There is no marketing site, no docs site, and no companion web product in the brief — those are out of scope.

## Index

| File / Folder | Purpose |
|---|---|
| `README.md` | This file. Overview, content fundamentals, visual foundations, iconography. |
| `colors_and_type.css` | All color + typography CSS variables (Light / Dark / Grey themes + semantic type roles). |
| `fonts/` | Webfont files used by the system (currently linked from Google Fonts CDN — see VISUAL FOUNDATIONS). |
| `assets/` | Logos, icons, illustrations referenced by the system. |
| `preview/` | Per-token / per-component preview cards rendered in the Design System tab. |
| `ui_kits/mobile_app/` | Hi-fi Flutter-style component kit + interactive screen mocks (Home, Devices, Light Detail, Logs, Settings). |
| `SKILL.md` | Agent skill manifest for downstream Claude Code use. |

---

## CONTENT FUNDAMENTALS

The brief is bilingual (Vietnamese + English). Operator-facing UI strings should be **Vietnamese-primary, English-allowed for technical terms**, since the codebase, MQTT topics, and command vocabulary are all English. The brief itself models this — error copy is Vietnamese, IDs and statuses (`accepted`, `executed`, `unreachable`, `cmd-01`) stay English.

### Voice & tone

- **Operator voice, not consumer voice.** The user is a technician demoing a smart-building gateway, not a homeowner asking Alexa to turn off the lights. Copy is direct, terse, status-first.
- **No marketing flourish.** No exclamation points, no "Welcome back!", no emoji. The brief explicitly prioritises *low visual noise* and *debug-friendly* — copy follows.
- **Imperative + declarative, not conversational.** "Tap ON/OFF", "Command timeout", "Light unreachable" — never "Looks like your light isn't responding 😔".
- **Show, don't narrate.** State is shown as a badge (`ON`, `OFF`, `UNREACHABLE`), not a sentence. Errors give the fact + a retry, nothing more.

### Casing

- **Status values: UPPERCASE** in chips/badges (`ON`, `OFF`, `UNREACHABLE`, `EXECUTED`). They read as enums, not words.
- **Tab labels / screen titles: Sentence case** (`Devices`, `Light detail`, `Logs`).
- **IDs: lowercase-hyphen as-is** (`light-01`, `cmd-01`, `pir-01`). Never re-cased.
- **Buttons: short, ALL CAPS or Title Case** depending on density — `ON` / `OFF` for primary toggles, `Retry` / `Refresh` for secondary actions.

### Pronouns

- The app does not address the user as "you" or refer to itself as "we". It speaks *about* the system: "Command executed", "Light unreachable", "Cloud offline". This keeps copy translation-stable and removes affective noise.

### Examples (lifted from the brief)

| Surface | Copy |
|---|---|
| Network error banner | `Không kết nối được Cloud API. Kiểm tra server hoặc mạng.` + `[Retry]` |
| Command timeout | `Command timeout. Chưa xác nhận được trạng thái từ gateway.` |
| Unreachable light | `Light unreachable` |
| Parse error (debug) | `Invalid payload received from API.` |
| Log row | `[07:16:03] LIGHT light-01` / `Command executed: off` / `source=gateway \| command_id=cmd-01` |

### Vibe

> **A multimeter, not a smart speaker.** Every screen should look like it could ship next to an oscilloscope.

---

## VISUAL FOUNDATIONS

### Theme modes

Three peer-level themes — not a light/dark pair with a tint. **Grey** is its own mode for log-heavy reading.

| | Light | Dark | Grey |
|---|---|---|---|
| Background | `#F7F8FA` | `#0F1115` | `#E7E9EC` |
| Surface | `#FFFFFF` | `#171A21` | `#F1F2F4` |
| Surface elevated | `#FFFFFF` | `#20242D` | `#FAFBFC` |
| Primary | `#4F7DFF` | `#7AA2FF` | `#4B5563` |
| Success | `#22C55E` | `#34D399` | `#4F7A5E` |
| Warning | `#F59E0B` | `#FBBF24` | `#8E7635` |
| Error | `#EF4444` | `#F87171` | `#9C5A5A` |
| Text primary | `#111827` | `#F9FAFB` | `#111418` |
| Text secondary | `#6B7280` | `#A1A1AA` | `#5C6470` |
| Border | `#E5E7EB` | `#2D3340` | `#C8CCD2` |

The Grey palette is **fully desaturated slate** — no blue or purple cast, no warmth. It's the "calm engineering / debug mode" look: neutral surfaces, low-key semantic tints, high readability for log-heavy reading. Think instrument panel, not dimmed light theme.

### Typography

- **Display / UI:** `Inter` — neutral, high-x-height grotesque, available at all needed weights. Material 3 default-compatible.
- **Monospace (logs, IDs, payloads):** `JetBrains Mono` — designed for code legibility, has a clear `0`/`O` and `l`/`1` distinction critical for device IDs.
- Both fonts are loaded from Google Fonts CDN. **No fonts were provided in the brief** — these are reasonable matches for a Material 3 / debug-oriented surface. If the team has a preferred typeface, swap in `colors_and_type.css`.

Type scale (mobile, 16px base):

| Role | Size | Weight | Line height |
|---|---|---|---|
| Display | 28px | 700 | 1.2 |
| Title | 20px | 600 | 1.3 |
| Body | 15px | 400 | 1.5 |
| Body strong | 15px | 600 | 1.5 |
| Caption | 13px | 500 | 1.4 |
| Mono | 13px | 400 | 1.5 |

### Spacing, radii, elevation

- **Spacing** is on a 4px grid: `4 / 8 / 12 / 16 / 20 / 24 / 32 / 48`.
- **Radii** — cards `20px` (per brief: *Rounded 20px*), buttons `12px`, chips/pills `999px`, inputs `12px`.
- **Elevation** is restrained: `0` (flat surfaces), `1` (cards) = `0 1px 2px rgb(0 0 0 / 0.04), 0 1px 1px rgb(0 0 0 / 0.02)`, `2` (elevated/sheets) = `0 8px 24px rgb(0 0 0 / 0.08)`. Dark mode uses surface tinting, not stronger shadows.
- **Borders** are 1px and the tokenized `--border` color. They appear on cards in Light/Grey, are mostly invisible in Dark (where surface contrast does the work).

### Layout rules

- **Bottom navigation bar** is fixed, 4 tabs (Home, Devices, Logs, Settings), 56px tall, with a top border in `--border`.
- **App bar** is 56px, sentence-case title left, optional refresh action right.
- **Cards** are full-width minus 16px gutters, stacked with 12px gaps.
- **Filter chips** sit in a horizontally-scrollable row above timelines.
- Content never butts against screen edges — minimum 16px horizontal padding.

### Backgrounds & imagery

- **No background imagery, no gradients, no textures.** Surfaces are flat tokenized colors. The brief is explicit about *low visual noise*.
- **No decorative illustrations.** EmptyState uses a single thin-line icon plus terse copy plus a Retry button — nothing more.

### Animation

- **Functional, not expressive.** All transitions ≤ 200ms.
- Standard easing: `cubic-bezier(0.2, 0, 0, 1)` (Material standard) for entries, `cubic-bezier(0.4, 0, 1, 1)` for exits.
- **Pending command spinners** are a 1px ring rotating at 800ms — readable, not flashy.
- **No bounce, no overshoot, no hero animations.** Screen transitions are the platform default (Android shared-axis or fade-through).

### States

- **Hover (web preview / desktop):** background tint shifts by ~4% luminance toward the primary. Most touch surfaces don't show hover on Android.
- **Press:** 4% darken for filled buttons, 8% tint background for ghost buttons. No scale transforms.
- **Disabled:** 40% opacity on text + icon, surface unchanged.
- **Focus ring:** 2px outline in `--primary`, offset 2px. Visible only via keyboard.

### Cards

A card is: `--surface` background, 1px `--border` outline (Light/Grey only), `20px` radius, `16px` interior padding, `elevation-1` shadow, `12px` gap to neighbour cards.

### Status badges

Pill-shaped (`999px` radius), `4px 10px` padding, mono font, `12px` size. Tinted background at ~12% opacity over the semantic color, with the semantic color as the text.

### Transparency & blur

Used sparingly. The only blurred surface is the bottom-sheet scrim (`backdrop-filter: blur(8px)` over `rgb(0 0 0 / 0.4)`). No frosted-glass cards, no translucent nav.

### Imagery

There is no photographic imagery in this product. If a placeholder is ever needed (e.g. an empty Devices list), use a single thin-line icon at `--text-secondary` over the page background. **No emoji.**

---

## ICONOGRAPHY

The brief specifies a per-node-type icon mapping but does **not** ship icon assets. Approach:

- **HTML prototype:** [Lucide](https://lucide.dev/) — thin-line, geometric, loaded from `https://unpkg.com/lucide@latest` (CDN).
- **Flutter implementation:** **built-in `Icons.*` (Material) only** for MVP. Do not add `lucide_icons` to `pubspec.yaml` unless a needed glyph has no Material equivalent — none of the icons in this product do.
- **Sizing:** `20px` in chips/badges, `24px` in nav, `28px` in card headers, `64px` in EmptyState.
- **Color:** inherits `currentColor`. Never tinted decoratively — a node-type icon is `--text-secondary`, a status icon takes its semantic color.

| Concept | Lucide (HTML) | Material (Flutter) |
|---|---|---|
| light | `lightbulb` | `Icons.lightbulb_outline` / `Icons.lightbulb` |
| motion | `radar` | `Icons.sensors` |
| switch | `toggle-left` | `Icons.toggle_off` |
| lock | `lock` | `Icons.lock_outline` |
| gateway | `router` | `Icons.router` |
| unknown | `circle-help` | `Icons.help_outline` |
| log / activity | `terminal` | `Icons.receipt_long` / `Icons.terminal` |
| home / dashboard | `house` | `Icons.dashboard_outlined` |
| settings | `settings` | `Icons.settings_outlined` |
| online / reachable | `wifi` | `Icons.wifi` / `Icons.check_circle` |
| offline / unreachable | `wifi-off` | `Icons.wifi_off` / `Icons.error_outline` |
| command pending | `loader-circle` | `Icons.hourglass_empty` |
| command success | `circle-check` | `Icons.check_circle_outline` |
| command failed | `circle-x` | `Icons.error_outline` |
| error / warning | `triangle-alert` | `Icons.warning_amber_outlined` |
| refresh | `refresh-cw` | `Icons.refresh` |
| filter | `sliders-horizontal` | `Icons.tune` |
| search | `search` | `Icons.search` |

**No emoji. No unicode glyphs as icons.** Status is communicated by the icon + the semantic color, never by a colored circle alone (accessibility).

### Logo

The platform does not have a published logo. `assets/logo.svg` ships a placeholder wordmark — **SB Zigbee** set in Inter 600 with a small lightbulb glyph — for use in Splash and About screens. The placeholder is intentionally generic so design work can proceed; replace when a real mark is available.
