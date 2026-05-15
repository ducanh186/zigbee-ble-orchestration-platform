---
name: zigbee-sb-design
description: Use this skill to generate well-branded interfaces and assets for the Zigbee Smart Building mobile app, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. The Light/Dark/Grey theme tokens live in `colors_and_type.css` — import it and switch via `data-theme="light|dark|grey"` on `<html>`.

If working on production code (Flutter), copy assets and use the rules in README.md plus `systemdes.md` (referenced in README) to align your work to the brand. The UI kit in `ui_kits/mobile_app/` shows the target visual fidelity and component breakdown that maps onto the Flutter folder structure.

If the user invokes this skill without other guidance, ask them what they want to build or design (a screen mock? a marketing asset? a Flutter component?), then act as an expert designer who outputs HTML artifacts or production code, depending on the need.

Key files:
- `README.md` — content fundamentals, visual foundations, iconography
- `colors_and_type.css` — all tokens for Light / Dark / Grey themes
- `assets/` — logo placeholder
- `preview/` — per-token preview cards
- `ui_kits/mobile_app/` — interactive screen recreations

Iconography: Lucide via CDN (`https://unpkg.com/lucide@latest`). No emoji. No hand-rolled SVG glyphs.
