# Max Camera Distance — Changelog

## v10.2 — Forever advanced ground effects

- Added Forever-only raw controls for `groundEffectDensity`, `groundEffectDist`, and `groundEffectFade` under Extra Features.
- Added an opt-in Advanced Ground Effects override (off by default); first enable captures current live CVar values before taking ownership, preventing first-use graphics jumps or hardware-preset regressions.
- Read each setting's built-in default from the Forever client and use documented modern-client values only as early-load fallbacks.
- Exposed density 16-256, distance 32-600, and fade 0-600 with integer-only UI controls and runtime clamps.
- Added CVAR_UPDATE mirroring so Blizzard graphics changes update the profile instead of causing the addon to fight the client.
- Kept `graphicsGroundClutter`, `graphicsEnvironmentDetail`, and `graphicsViewDistance` out of the addon because they are standard graphics UI preset CVars; modern clients document those sliders as 0-9 rather than the obsolete value 10.
- Added the new Forever environment CVars to `/mcd status`, managed-CVar normalization, and runtime diagnostics.

## v10.1 — TOC generator/CI synchronization

- Updated the Mainline TOC source-of-truth to include Retail PTR 12.1.5 (`Interface 120105`) alongside 12.0.7 and 12.1.0.
- Added World of Warcraft: Forever / Camelot (`Interface 16001`) to `tools/generate_tocs.py` so CI owns and verifies the Forever TOC instead of treating it as an unmanaged special case.
- Added Camelot-specific metadata/file injection so `Forever.lua` remains loaded only by `Max_Camera_Distance_Camelot.toc`.
- Made every generated TOC inherit the release version and shared metadata from `Max_Camera_Distance.toc`, preventing per-flavour version drift.
- Bumped the addon version beyond the existing `v10.0` repository tag so the next release does not collide with an already published tag.

## v9.5 — Runtime/API audit and performance hardening

- Fixed 12.1 Secret Value handling so potentially-secret results are screened with `issecretvalue()` before any nil comparison, boolean evaluation, numeric conversion or table-key use.
- Fixed threat, vehicle GUID, aura spell ID, AFK and unit-state paths that could still touch Secret Values after a successful API call.
- Made CVarGuard restores transactional: saved user values survive blocked/failed writes and retry after combat instead of being discarded.
- Removed per-update closure allocations from the Smart Zoom/ActionCam dispatcher and keep error throttling independently per subsystem.
- Fixed the no-lib `LibStub` fallback so it exposes the upstream v2 `minor/libs/minors` surface and cannot crash when bundled `LibStub.lua` loads on a clean client.
- Removed unused global FrameXML compatibility monkey-patches to reduce taint/conflict surface on 12.1+.
- Added CVar presence caching and metadata-aware write guards for locked/read-only/secure CVars.
- Reactive Zoom now has zero idle `OnUpdate` cost; its watchdog wakes only while a zoom is actually in flight.
- Reactive Zoom samples `GetFramerate()` on wheel input instead of maintaining a permanent frame-time tracker.
- Reworked LibCamera scheduling to reuse its update snapshot, eliminate per-tick table garbage and avoid redundant timing calls.
- Cached camera zoom/yaw/pitch normalization speeds per LibCamera operation instead of reading CVars every animation tick.
- Made combat, threat, mount and travel signals lazy so profiles only pay for the state they actually use.
- Reused the central active-mount cache in shoulder compensation instead of independently rescanning the full mount journal.
- Reduced group-combat scan cost by prebuilding unit tokens, removing redundant `UnitExists` calls and extending the tiny reuse window to 250 ms.
- Player `UNIT_AURA` preserves group-combat cache and queues Smart Zoom only when aura-derived mount/race features are enabled.
- Removed `UNIT_SPELLCAST_SUCCEEDED` shoulder refresh spam; dedicated aura/model/mount/shapeshift/vehicle events cover the actual state changes.
- Replaced recursive three-pass shoulder refresh bursts with one immediate and one trailing debounced refresh.
- Made shoulder compensation invalidation idempotent and switched its tracker to the event-provided `elapsed` value instead of `GetTime()` every frame.
- Updated `cameraIndirectOffset` fallback/default presentation to follow the current client default (`6.0` on current 12.1 metadata) instead of the stale 11.0-era `1.5`.
- Added Retail PTR 12.1.5 (`Interface 120105`) to the mainline TOC while retaining 12.1.0 compatibility.

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

