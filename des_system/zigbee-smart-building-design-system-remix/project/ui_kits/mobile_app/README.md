# Mobile App UI Kit

Hi-fi recreation of the Zigbee Smart Building Android app, built per `systemdes.md`.

## Files

- `index.html` — interactive demo with theme switcher (Light / Dark / Grey). Renders 5 phones side-by-side: Home, Devices, Light detail, Logs, Settings. The Devices screen is interactive (tap a Light row → opens detail in-place); the dedicated Light detail panel shows the command lifecycle live.
- `Phone.jsx` — minimal 360×780 phone bezel with status bar.
- `Components.jsx` — `AppBar`, `BottomNav`, `Badge`, `Card`, `Chip`, `IconBtn`, `SectionTitle`, `Body`.
- `HomeScreen.jsx` — gateway status, counts, quick lights.
- `DevicesScreen.jsx` — search + type chips + device list.
- `LightDetailScreen.jsx` — large ON/OFF pills, command status panel with simulated `accepted → polling → executed` flow, recent events.
- `LogsScreen.jsx` — timeline with type + severity chips, expandable JSON payload.
- `SettingsScreen.jsx` — theme picker, Cloud config rows.
- `Mock.jsx` — sample devices + events; mirrors API contract from `systemdes.md` §6.

## What's intentionally faked

- All API calls. Tapping ON/OFF in the Light detail screen simulates `accepted → polling → executed` with `setTimeout`. No real Cloud or MQTT.
- Command IDs are random.
- Timestamps are static strings, not live clocks.

## How to extend in Flutter

The component decomposition mirrors the folder layout in `systemdes.md` §12:

| JSX here | Flutter target |
|---|---|
| `AppBar` | `Scaffold.appBar` |
| `BottomNav` | `NavigationBar` (Material 3) |
| `Card` | `Card` w/ `ShapeBorder(RoundedRectangleBorder(20))` |
| `Badge` | `Chip` w/ tonal background |
| `Chip` (filter) | `FilterChip` |
| `LightDetailScreen` controls | `light_control/widgets/light_power_control.dart` |
| `LogsScreen` row | `logs/widgets/log_row.dart` |
