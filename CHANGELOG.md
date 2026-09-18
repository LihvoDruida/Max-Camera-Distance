## [9.4] - 2026-09-18

- Added WoW: Forever-only volumetric fog controls under Extra Features.
- Added `volumeFog` and `volumeFogInterior` as 0/1 toggles and `volumeFogLevel` as a 0-3 selector.
- Fog defaults are read from the Forever client via the CVar default API, with safe metadata fallbacks, so a new/reset profile matches the game's own defaults.
- Added CVAR_UPDATE synchronization so changes made through Blizzard graphics settings or `/console` are reflected back into the addon instead of being overwritten.
- Added Forever fog values to `/mcd status` diagnostics.

## [9.3] - 2026-09-18

- Added first-class World of Warcraft: Forever / Camelot support for beta 1.60.1 (Interface 16001).
- Added a dedicated `Max_Camera_Distance_Camelot.toc` and load-time Forever marker so Forever is not misdetected as Classic Era or Retail.
- Split product identity from API-family detection with `IS_FOREVER` and `USES_MODERN_API`.
- Forever now uses the modern camera/CVar API path while keeping Retail-only gameplay contexts such as Mythic+ separate.
- Added Forever-aware runtime diagnostics to `/mcd status`.
- Hid Retail-only Skyriding/Dragonriding race controls on Forever.

## [9.2] - 2026-09-01

### 🐛 Bug Fixes

- Make Ace3 initialization resilient to load order


### 📦 Other Changes

- Run release gate through bash

