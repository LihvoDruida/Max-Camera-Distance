# Max Camera Distance — Changelog

## v10.4 — Gamepad support, configurable shoulder offset, ActionCam deadlock fix

### Gamepad scope and rules

- Gamepad handling activates **only when Forever's "Enable Gamepad UI (Alpha)" is on** (Gameplay → Gamepad). A connected controller alone is not enough; with the toggle off every gamepad option stays inert and the client keeps its own defaults. The CVar behind that toggle is undocumented (the panel is alpha), so it is **discovered at runtime** — a candidate-name probe, then a scan of `C_Console.GetAllCommands()` for a gamepad CVar that also mentions the UI, with `GamePadEnable` only as a last resort. `/mcd gamepad` reports which name was resolved and whether it fell back.
- **The addon never duplicates a control the game already has.** Blizzard registers panel settings through `Settings.RegisterCVarSetting`, keyed by CVar name, so `Settings.GetSetting(cvar)` is an authoritative "does the game own this?". Any CVar that answers yes is hidden here and left alone. The rule is evaluated at runtime, so the moment the alpha grows its own camera-speed sliders the addon's duplicates disappear by themselves.
- What the addon exposes instead is the gap: camera CVars that exist in the API but have **no control in the Gamepad panel** — `GamePadCursorPushCamera` (camera turn rate when the cursor hits the window edge) and `GamePadTankTurnSpeed`. Off by default, and enabling management captures the live values first so it changes nothing by itself.
- **AFK safe exit now works on a controller.** The anti-trap exit was keyboard-only: the UI is hidden, the exit frame swallows keyboard input, and a gamepad player may have no ESC at all. Gamepad buttons arrive on a separate input path, so `EnableGamePadButton` + `OnGamePadButtonDown` are wired up explicitly. Any button exits, and gamepad input is propagated rather than swallowed.
- `/mcd gamepad cvars` lists every gamepad CVar the client reports, each marked `[game]` or `[addon-only]`.

### Fixed

- **ActionCam could permanently stop working once `CameraKeepCharacterCentered` was switched on.** `CVarGuard` decided whether to block that CVar by reading `test_cameraOverShoulder` back. Keep-centered overrides ActionCam outright (it was added in 9.0.1 for exactly that), and since 11.0.2 `cameraReduceUnexpectedMovement` affects the shoulder CVar as well — so once either was enabled the shoulder value read back as `0`, the guard concluded the shoulder camera was inactive, stopped blocking keep-centered, restored it, and the shoulder camera could never return. The guard now follows the addon's published *intent* (`CVarGuard:SetActionCamIntent`), which does not take part in that feedback loop. This is the most likely cause of "the camera inputs just don't work once I turn the gamepad on".
- `CVarGuard:Refresh()` no longer returns early when its blocking state is unchanged, so a CVar moved underneath it (Blizzard's camera or gamepad panel, a saved-view restore, another addon) is reconciled instead of being ignored until something else flips the state.
- `CVAR_UPDATE` for `CameraKeepCharacterCentered` used to fall through `Functions:OnCVarUpdate` and do nothing at all. It now reaches the guard.

### Added

- **Shoulder offset is configurable.** The base offset was hardcoded to `1.0`; it is now the `actionCamShoulderOffset` setting (range −5…5, negative values move the camera to the other shoulder), with a Reset button.
- The zoom recentring window is configurable too (previously hardcoded at 2.0 and 5.0 yards), can be switched off entirely for a constant offset, and per-model compensation can be disabled to send the raw CVar value.
- **Gamepad support (`GamePad.lua`), scoped to WoW: Forever.** The CVars and the `C_GamePad` namespace exist on Retail and Classic too, so this is a product decision rather than a technical limit — the behaviour has only been reasoned about against Forever. Off Forever the module reports no support, the options tab is hidden, the `GAME_PAD_*` events are never registered, and the profile keys are stripped rather than left dead. Detects the gamepad through `C_GamePad.IsEnabled` / `GetActiveDeviceID` with a `GamePadEnable` CVar fallback, and reacts to `GAME_PAD_ACTIVE_CHANGED`, `GAME_PAD_CONNECTED`, `GAME_PAD_DISCONNECTED` and `GAME_PAD_CONFIGS_CHANGED`.
- Optional management of `GamePadCameraYawSpeed` / `GamePadCameraPitchSpeed`. Every existing camera speed option in this addon writes `cameraYawMoveSpeed` / `cameraPitchMoveSpeed`, which only drive the mouse camera — which is why those sliders appeared to do nothing with a controller. Stored as a **multiplier** of the client's own default rather than an absolute number, because the scale of these CVars is not reliably documented. Off by default; switching it off hands both CVars back to the client.
- Optional suspension of `GamePadFaceMovement` while the shoulder camera is active, restoring the player's own value afterwards. Off by default.
- Diagnostics for the mundane cause of "no camera input": `GamePadCameraStick` set to `0`, or sharing a physical stick with movement or the cursor. Surfaced as a one-shot warning, in the options panel, and in `/mcd status`.
- **The gamepad panel opens itself once.** When a gamepad first becomes active on a character, the addon opens its settings window on a dedicated **Gamepad** tab, because the camera settings that apply to a controller are not the ones the player has been using. It opens only on an inactive → active transition, never in combat, once per character, and there is a visible toggle that both disables and re-arms it.
- `/mcd gamepad` and new `/mcd status` lines covering gamepad state, stick assignment, resolved camera speeds, ActionCam intent and the current shoulder polling rate.

### Changed

- The shoulder `OnUpdate` driver compared *zoom* and then called `UpdateCVar` unconditionally, so any camera jitter past the fade window cost a CVar read every frame for a value that had not changed. It now compares the resulting offset, and backs its polling off from 30 Hz to 10 Hz after a full second of a completely static camera, snapping back the instant the camera moves.
- Shoulder tuning constants are grouped into one table because `Functions.lua` is close to Lua 5.1's 200-locals-per-chunk ceiling.

### Tests

- New `tests/probe_gamepad.lua` (48 assertions), running as a Forever client via `Forever.lua`, covering the offset, the fade window, write suppression, the keep-centered deadlock, gamepad speed mirroring, face-movement restore and stick misconfiguration. Verified against negative controls: reverting either the intent fix or the write-suppression fix makes it fail.
- `tests/probe_lateace3.lua` runs as Retail and now doubles as the negative control for the Forever scope: no support, no profile keys, hidden options tab.
- `tests/wow_stub.lua` gained real shown/hidden frame state and a case-insensitive CVar store with read/write counting.

## v10.3 — Forever ground-effect default reset controls

- Added a per-setting **Reset** button beside `groundEffectDensity`, `groundEffectDist`, and `groundEffectFade` in the Forever Advanced Environment panel.
- Reset buttons read the Forever client's built-in CVar default through the CVar API and immediately synchronize both the live CVar and the addon profile.
- Disabling **Manage Advanced Ground Effects** now restores all three raw ground-effect CVars to their game defaults before releasing addon ownership.
- Kept the reset controls disabled while Advanced Ground Effects management is off, matching the sliders' ownership state.
- Updated all bundled locales and bumped the addon version to v10.3.

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

