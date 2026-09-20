# Max Camera Distance — Changelog

## v10.10 — Forever CVar range validation fixes

- Fixed repeated Forever console validation spam caused by zero-length smooth zoom transitions writing `cameraZoomSpeed = 0`.
- `LibCamera:SetZoomUsingCVar()` now skips no-op transitions and clamps non-zero temporary zoom speeds to the client-validated `0.002778..50` range.
- Updated Forever gamepad camera speed controls to the live Camelot `1..4` validation range.
- Legacy profiles containing yaw/pitch multipliers below `1` are normalized safely instead of generating rejected CVar writes.
- Effective Forever gamepad yaw/pitch values are clamped again at the final write boundary so future client-default changes cannot escape the valid CVar range.
- Added regression coverage for legacy low gamepad speed values and no-op LibCamera zoom writes.
- Console-log audit also confirmed that current `test_cameraOverShoulder` / `test_cameraDynamicPitch` writes are accepted by Forever; the remaining CharacterCustomize, GroupFinder, HandyNotes and EverythingQuests errors originate outside Max Camera Distance.

## v10.9 — ActionCam ownership, clean restore, and controller bindings

### ActionCam ownership / Forever reliability

- Added explicit ownership tracking for `test_cameraOverShoulder` and `test_cameraDynamicPitch`. MCD now captures the value that existed before it took control and restores that value when the corresponding ActionCam feature is released instead of assuming `0` is always the correct teardown state.
- External shoulder/pitch changes made while MCD owns the camera become the new restoration target. MCD may reassert its active view while enabled, but it hands the player's/latest external value back when disabled.
- Changed blocker ownership to follow only MCD's published ActionCam intent. A pre-existing shoulder value from the player or another addon no longer makes MCD keep `CameraKeepCharacterCentered` / `CameraReduceUnexpectedMovement` forced off after MCD itself has released ActionCam.
- Added `PLAYER_LOGOUT` cleanup for temporary ActionCam state. Normal logout/reload restores owned shoulder/pitch values and temporary Blizzard blocker values while preserving the saved MCD profile so the configured camera is reapplied on the next world entry.
- Added narrowly-scoped Forever suppression for the experimental-camera popup only around MCD's own ActionCam CVar writes. Unlike broad UI event unregistration, this does not permanently disable Blizzard's experimental-CVar warning path.

### Shoulder controls / gamepad usability

- Added **Swap Shoulder** and **Center** actions beside the shoulder offset control on both the Forever Gamepad ActionCam section and the normal Retail/Classic ActionCam section.
- Added `Bindings.xml` entries for toggling the shoulder camera in the current combat context, swapping shoulder side, centering the shoulder camera, and opening camera settings. Blizzard loads this file automatically, so these actions can be assigned through the normal Key Bindings UI, including gamepad buttons where supported.
- Added `/mcd shoulder toggle|swap|center|config` (also available as `/mcd actioncam ...`) as the binding-safe command surface. The toggle changes only the current combat/out-of-combat shoulder state so a split profile is not destroyed.
- Kept the full `-15 .. +15` shoulder range, Smart Fade and model compensation; the simpler Forever shoulder addon used for comparison does not replace these stronger MCD features.

### Regression

- Added regression coverage for preserving a pre-existing shoulder/pitch setup, updating the restoration target after an external ActionCam change, restoring blocker CVars even when an external shoulder remains active, and cleaning temporary ActionCam state on logout without clearing profile preferences.

## v10.8 — Forever ActionCam/gamepad compatibility fix

### Forever ActionCam

- Fixed the Forever-specific ActionCam failure path confirmed by the current beta client: `CameraKeepCharacterCentered = 1` suppresses most ActionCam behaviour. MCD now publishes ActionCam intent, clears the blocking motion-sickness CVars, verifies that they actually committed, and only then applies `test_cameraDynamicPitch` / `test_cameraOverShoulder`.
- Applied the second blocker in the same ordered pipeline: `CameraReduceUnexpectedMovement` must remain disabled while a shoulder offset is requested. `ApplyManagedCVars()` can no longer briefly re-enable it from the normal profile while the ActionCam guard owns the temporary exception.
- Kept the v10.6 CVar reentrancy protection intact. Forever may deliver `CVAR_UPDATE` before a `SetCVar` commit; the ActionCam compatibility sequence never recursively writes the same CVar.
- Added a pre-commit Gamepad UI master-toggle bridge: the event payload is used synchronously so switching **Enable Gamepad UI (Alpha)** off tears ActionCam down immediately even when `GetCVar()` still reports the previous value.
- Expanded the shoulder offset to the full current `test_cameraOverShoulder` range of `-15 .. 15`, matching the live engine range used by DynamicCam instead of silently clamping Forever profiles to `-5 .. 5`.

### Gamepad integration / diagnostics

- Kept Action Camera as the first Forever Gamepad section and moved all three primary toggles onto full-width AceConfig rows so long labels are no longer clipped.
- Added an explicit runtime status line for inactive Alpha UI and for both ActionCam blockers, so a non-working shoulder/pitch setting is diagnosable directly from the panel rather than looking like an inert checkbox.
- Added diagnostics for `GamePadTurnWithCamera`, `GamePadCameraLookMaxPitch/Yaw`, and `CameraFollowGamepadAdjustDelay/EaseIn`. These are intentionally read-only diagnostics: they change controller policy and are not required to make ActionCam work, so MCD does not override them without a verified product requirement.
- Kept optional face-movement relaxation separate from the core ActionCam fix. `GamePadFaceMovementMaxAngle*` can affect how controller movement feels with an offset camera, but it is a control preference, not a prerequisite for shoulder offset.

### Cross-flavor safety / regression

- Retail and Classic keep their existing ActionCam placement and runtime gate; only Forever requires the Gamepad UI Alpha master.
- Added regression coverage for blocker-before-shoulder ordering, full-width Forever controls, the full `-15 .. 15` range, pre-commit Alpha master-off handling, diagnostic gamepad camera CVars, and a Retail negative control proving its ActionCam slider is not gated by Forever Gamepad state.

## v10.7 — Forever camera pipeline, default-first gamepad, and cross-flavor regression

### Forever / Gamepad UX

- Moved the full Action Camera configuration into the dedicated Forever **Gamepad** tab and made it the first section. The old ActionCam block remains in its existing location on Retail/Classic, so this is a Forever-only presentation change rather than a second implementation.
- Ordered the Forever controller camera pipeline explicitly as **ActionCam → gamepad compatibility → camera speed/API-only controls**. ActionCam now publishes shoulder/pitch intent before gamepad face-movement and CVar reconciliation on login, world entry, gamepad events, and the discovered Gamepad UI master-toggle path.
- Kept a single ActionCam engine/profile/CVarGuard behind both layouts; Forever does not maintain a parallel copy that could drift from Retail/Classic behavior.
- Made gamepad controls default-first. Fresh yaw/pitch multipliers remain `1.0x`; API-only values come from the client's built-in CVar defaults; enabling advanced gamepad management seeds built-in defaults before applying them instead of capturing arbitrary live `/console` overrides.
- Updated the audit fixture to the current Forever beta `1.60.1.69913` / Interface `16001`. Client patch numbers are informational only; unsupported/newer APIs remain capability-detected rather than inferred from Retail version numbers.

### API ownership / safety

- Retained the runtime `Settings.GetSetting(cvar)` ownership rule per individual CVar. If Blizzard exposes a control, the addon hides its duplicate and stops both applying and restoring that CVar.
- Kept Gamepad UI CVar discovery behind `VARIABLES_LOADED`, because console enumeration is incomplete during early login.
- Kept the curated API-only approach instead of auto-generating settings for every `GamePad*` CVar. Input bindings, enums and poorly documented ranges are intentionally left to Blizzard until their semantics are verified in-client.
- Preserved the v10.6 CVar reentrancy guards for `CameraKeepCharacterCentered` and `CameraReduceUnexpectedMovement`; the new ActionCam-first ordering does not bypass those write locks.

### Cross-flavor regression

- Added a client-flavor matrix covering Forever (marker and fallback detection), Retail 12.1.5, Classic Era and Mists Classic. Forever stays `IS_FOREVER=true`, `IS_RETAIL=false`, `IS_CLASSIC=false`, while using the modern API family.
- Expanded Forever gamepad regression to verify ActionCam placement/order, ActionCam-before-gamepad execution, `1.0x` speed defaults, built-in defaults for API-only controls, and default seeding when advanced management is enabled.
- Kept the non-Forever late-Ace3 probe as a negative control proving the Gamepad tab remains hidden and Forever-only profile keys do not leak into Retail.

## v10.6 — CVar reentrancy crash fix

### Fixed

- Fixed a live Forever `C stack overflow` triggered by `CameraKeepCharacterCentered`. Forever can emit `CVAR_UPDATE` synchronously from inside `C_CVar.SetCVar` before `GetCVar` reflects the pending value; the old handler forced a full guard refresh, saw the stale value again, and recursively called `SetCVar` until the Lua C stack overflowed.
- Added a per-CVar managed-write lock in `CVarGuard`, so a CVar already being committed cannot recursively write itself.
- Added a refresh-level reentrancy guard as a second line of defense against future event-driven reconciliation loops.
- Internal addon CVar writes are now ignored by the generic `CVAR_UPDATE` reconciliation path in both `Core.lua` and `Functions.lua`.
- `CameraKeepCharacterCentered` and `cameraReduceUnexpectedMovement` CVAR events now forward their event value directly to `CVarGuard:OnExternalCVarSet()` instead of forcing a live-value refresh during the SetCVar call.
- Managed writes now verify the live CVar after `SetCVar` returns before being counted as successfully committed.
- Guarded external CVar preferences are captured from the `CVAR_UPDATE` event value instead of a potentially stale live read.
- Added a deduplicated zero-delay reconcile after blocked external writes so an outer SetCVar that commits after the event cannot leave the conflicting value enabled.

### Regression coverage

- Added a stub mode that deliberately fires `CVAR_UPDATE` before the simulated CVar write commits, matching the ordering observed in the Forever crash report.
- Added regression assertions proving the synchronous event cannot recurse, still commits `CameraKeepCharacterCentered = 0`, and does not cause runaway writes.

## v10.5 — Forever API audit, gamepad hardening, and character-state diagnostics

### Forever / API compatibility

- Audited the current Forever Beta line against build `1.60.1.69893` / Interface `16001`. Forever remains a distinct product flavor while using the modern API family exposed by that client; APIs that are not guaranteed on Forever are capability-detected at runtime rather than inferred from Retail patch numbers.
- Fixed early CVar capability discovery on clients without `C_CVar.AreCVarsLoaded`: negative capability results are no longer cached before `VARIABLES_LOADED`.
- Fixed the Gamepad UI (Alpha) toggle discovery race. `C_Console.GetAllCommands()` is now scanned only after `VARIABLES_LOADED`, because Blizzard documents the command list as incomplete earlier in login.
- Improved runtime discovery of the undocumented Forever Gamepad UI toggle: candidates must be real CVars, boolean-like, and are ranked deterministically instead of accepting the first name containing `gamepad` + `ui`.
- Fixed `CVAR_UPDATE` routing for a dynamically discovered Gamepad UI CVar, which cannot exist in the module's static watch list.

### Gamepad

- Corrected camera-speed fallback defaults to the documented `GamePadCameraYawSpeed = 1` and `GamePadCameraPitchSpeed = 1`; the client's own `GetCVarDefault` result still has priority. A user's current override is no longer mistaken for a default baseline.
- Added current `GamePadFaceMovementMaxAngle` / `GamePadFaceMovementMaxAngleCombat` handling (`0` / `180` defaults) and retained `GamePadFaceMovement` only as a legacy fallback.
- Fixed a Settings-ownership bypass: if Blizzard exposes the modern face-movement controls, the addon no longer modifies the legacy binary CVar behind the game's UI.
- Made Blizzard Settings ownership per-CVar/per-axis. If the game owns only yaw, the addon can still manage pitch without touching yaw.
- Applied the same Settings-ownership rule to restore paths, not just writes: a CVar that becomes game-owned later in the session is immediately left alone.
- Removed redundant restore writes by comparing live values with client defaults before calling `SetCVar`.
- When the Forever Gamepad UI master switch is disabled, addon-owned gamepad values are reconciled to client defaults once and are not repeatedly rewritten.
- Improved gamepad runtime diagnostics with input-active state, active device ID, CVar-enumeration readiness, and the resolved Alpha UI toggle.
- Prevented the automatic Gamepad settings panel from opening while the player is dead/ghost in addition to the existing combat guard.

### Character-state detection

- Split physical mount state from travel-form state. Druid/Shaman-style travel forms are no longer reported as a physical mount or sent through mount-journal-only resolution.
- Added explicit `travelActive` state for logic that intentionally treats mounts and travel forms together.
- Expanded diagnostics with vehicle, taxi, flying, falling, swimming, submerged, AFK, dead, and ghost states.
- Added feature-detected gliding diagnostics through `C_PlayerInfo.GetGlidingInfo` when that API exists; it is not assumed to exist on Forever.
- Added both pre/post vehicle transition events (`UNIT_ENTERING/ENTERED_VEHICLE`, `UNIT_EXITING/EXITED_VEHICLE`) and invalidated mount/runtime caches at each relevant player transition.
- AFK cinematic entry now rejects vehicle state and treats travel forms as mounted when the "skip mounted" safeguard is enabled.
- Removed a small shapeshift-status table allocation from a frequently used form lookup path.

### Regression coverage

- Expanded the Forever gamepad probe to cover the `VARIABLES_LOADED` discovery race, a runtime-only Alpha UI CVar, partial Blizzard Settings ownership, modern face-movement ownership, no-write restore semantics, Gamepad master-off reconciliation, physical mount vs travel form, and feature-detected gliding.
- Kept the Retail late-Ace3 probe as a negative control proving that Forever-only profile keys/UI remain absent off the Camelot flavor.
- Added explicit dead/ghost regression coverage for both Gamepad panel auto-open suppression and character-state diagnostics.
- Hardened `check_all.sh` so a missing `lua5.1`/`luac5.1` toolchain fails the relevant gate instead of allowing the global-leak stage to pass silently.
- Excluded accidental `luac.out` compiler artifacts from both Git and packaged releases.

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

