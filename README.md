# Max Camera Distance

[![CurseForge](https://img.shields.io/badge/Download-CurseForge-orange?style=for-the-badge&logo=curseforge)](https://www.curseforge.com/wow/addons/max-camera-distance)
[![Latest Version](https://img.shields.io/github/v/tag/LihvoDruida/Max-Camera-Distance?style=for-the-badge&label=Version&color=blue)](https://github.com/LihvoDruida/Max-Camera-Distance/releases)

**Max Camera Distance** is the ultimate camera utility for World of Warcraft. It unlocks the hidden potential of the game engine, combining tactical advantages with cinematic immersion.

Unlike simple scripts, this addon features a **reactive engine** that adapts to your gameplay state (Combat, Skyriding, AFK) and manages hidden Blizzard CVar settings to prevent motion sickness and camera jitter.

## 🎥 Preview

| ActionCam Mode | Smart Zoom |
| :---: | :---: |
| [![Video 1](https://img.youtube.com/vi/9HRe4jD02z4/0.jpg)](https://www.youtube.com/watch?v=9HRe4jD02z4) | [![Video 2](https://img.youtube.com/vi/qP_kdOdMhIk/0.jpg)](https://www.youtube.com/watch?v=qP_kdOdMhIk) |

## 🚀 Key Features

### 🎬 Cinematic ActionCam (New!)
Transform your WoW experience with modern RPG camera mechanics:
* **Smart Shoulder Offset:** Moves the camera over your character's shoulder for an immersive view.
    * *Adjustable Intensity:* Set exactly how far off-centre the camera sits (−5 to +5). Negative values move it to the other shoulder.
    * *Dynamic Interpolation:* Automatically centers the camera when you zoom in close (for looting/interacting) and shifts to the shoulder as you zoom out. Both edges of that window are configurable, and it can be switched off for a constant offset.
    * *Model Compensation:* Blizzard scales the offset by your model's width, so the same value looks different on a Tauren, a Gnome or a mount. Compensation is on by default and can be disabled to use the raw CVar value.
* **Dynamic Pitch:** Subtly adjusts the camera angle based on your character's movement.
* **Jitter Protection:** Automatically disables the conflicting *"Keep Character Centered"* setting to ensure smooth motion.

### 🧠 Smart Zoom System
The addon intelligently changes your camera distance based on priority:
1.  ⚔️ **Combat Mode:** Zooms out to the absolute max for raid/dungeon awareness.
2.  🐉 **Mount & Travel:** Detects **Skyriding (Dragonriding)**, standard flying, and travel forms (Druid/Shaman/Evoker) to adjust FOV.
3.  🌿 **Normal Mode:** Returns to a closer, immersive distance when exploring.

### 💤 Intelligent AFK Mode
Turn your screen into a screensaver when you step away:
* **Cinematic Rotation:** Automatically hides the UI and slowly rotates the camera around your character.
* **Safe Exit (Anti-Trap):** Pressing **ESC** while the UI is hidden immediately restores the interface and exits AFK mode. No more getting stuck!
* **Settings Protection:** Prevents the Settings Panel from becoming transparent during AFK.

### 🎮 Gamepad Support *(WoW: Forever only)*
Activates only when **Gameplay → Gamepad (Alpha) → Enable Gamepad UI** is switched on. A connected controller alone changes nothing; with the toggle off the addon returns its gamepad-owned CVars to client defaults and stays inert.

The Forever Gamepad tab is now ordered as a camera pipeline rather than a collection of unrelated switches:
1. **Action Camera first** — shoulder offset, dynamic pitch, smart fade and model compensation use the same shared ActionCam engine/CVarGuard as the rest of the addon. On Forever these controls live here instead of being duplicated under Additional Features.
2. **Gamepad compatibility second** — optional face-movement conflict handling is evaluated only after ActionCam has published its intended shoulder/pitch state.
3. **Controller camera speed and API-only controls last** — the addon only offers a CVar when it exists on the client and Blizzard has not already registered its own Settings control for it.

Gamepad values are **default-first**: fresh profiles use the client's built-in CVar defaults, yaw/pitch start at **1.0×**, and enabling the API-only override seeds its controls from `GetCVarDefault` before applying anything. A stray `/console` experiment is never adopted as the addon's default baseline.

* **No duplicate Blizzard controls:** ownership is checked at runtime through the Settings registry. If Blizzard adds its own control for a CVar in a later Forever build, Max Camera Distance hides its copy and stops writing/restoring that CVar.
* **Guided Setup:** the dedicated **Gamepad** tab can open once when Forever's Gamepad UI becomes active. It never auto-opens in combat or while dead/ghost and can be disabled/re-armed.
* **Gamepad Camera Speed:** `GamePadCameraYawSpeed` / `GamePadCameraPitchSpeed` are stored as multipliers of the client's built-in defaults and are shown only while Blizzard does not expose its own controls.
* **API-only Camera CVars:** currently curated to `GamePadCursorPushCamera` and `GamePadTankTurnSpeed`; both start from client defaults and are hidden automatically if the game takes ownership later.
* **AFK Safe Exit on Controller:** any gamepad button exits cinematic AFK mode, not just keyboard ESC.
* **ActionCam Compatibility:** the addon tracks ActionCam *intent* rather than reading the overridden shoulder CVar back. On Forever it clears `CameraKeepCharacterCentered` first and, for shoulder offset, `CameraReduceUnexpectedMovement` second; only after both blockers are confirmed clear does it apply Dynamic Pitch / `test_cameraOverShoulder`. The original motion-sickness values are restored when ActionCam no longer needs the exception.
* **Full shoulder range:** Forever and the shared ActionCam engine expose the current `test_cameraOverShoulder` range from **-15 to +15**, with negative values moving the view to the opposite shoulder.
* **Controller-policy diagnostics:** `/mcd gamepad` reports `GamePadTurnWithCamera`, camera-look limits and gamepad follow timing so controller-specific snapping/follow behaviour can be diagnosed without automatically overriding player preferences.
* **Face-Movement Conflict:** prefers `GamePadFaceMovementMaxAngle` / `GamePadFaceMovementMaxAngleCombat` when available, with the legacy binary CVar only as a capability-detected fallback.
* **Stick Diagnostics:** warns when no stick is assigned to camera input, or when camera input collides with movement/cursor assignment.

### ⚙️ System Integration & Optimization
* **Event-Driven Core:** Uses throttling, debouncing, short-lived state caches and lazy status checks so camera work runs only when relevant instead of polling every subsystem continuously.
* **Blizzard Settings Hook:** Intercepts the default UI to disable the "Mouse Look Speed" slider, preventing conflicts with the addon's precision Pitch/Yaw controls.
* **Limit Breaker:** Extends camera distance up to 39 yards (Retail) / 50 yards (Classic).

## 🛠️ Quality of Life
* **Always Sharpen (FSR):** Forces FidelityFX sharpness for a crisper image without upscaling.
* **Soft Target Icons:** Displays interaction icons over NPCs and portals.
* **Quest Cleaner:** One-click button to untrack all quests for a cleaner objective tracker during raids, screenshots or streaming.

## 💻 Commands

* `/mcd config` - Open the configuration panel (GUI).
* `/mcd autozoom` - Toggle Smart Combat Zoom.
* `/mcd automount` - Toggle Smart Mount Zoom.
* `/mcd status` - Print full runtime diagnostics.
* `/mcd gamepad` - Print gamepad state, stick assignment and camera speeds.

## ✅ Compatibility

Supported client families use separate manifests and capability checks:
* **Retail:** Midnight 12.x, including current live/PTR interface generations supported by the TOC.
* **World of Warcraft: Forever:** dedicated Camelot/Forever flavor (`16001`) with Forever-only ordered ActionCam/gamepad settings, fog and advanced ground-effect controls. Forever remains a separate product identity while individual modern APIs are capability-detected.
* **Classic:** Classic Era / Anniversary, Burning Crusade Anniversary, Mists of Pandaria Classic, and the additional Classic manifests shipped with the addon.

Features that do not exist on a client are hidden or disabled through capability checks rather than assumed to be available.

## 🐞 Bug Reporting

Found a bug or have a suggestion? Please submit a ticket via our [GitHub Issues](https://github.com/LihvoDruida/Max-Camera-Distance/issues) or leave a comment on [CurseForge](https://www.curseforge.com/wow/addons/max-camera-distance).

## Credits

- **LibCamera** by mpstark, bundled under the MIT License (see `libs/LibCamera/LICENSE.md`).
- **Reactive Zoom** (`ReactiveZoom.lua`) is a port of the mouse-wheel zoom algorithm from
  [DynamicCam](https://github.com/Mpstark/DynamicCam) by mpstark and LudiusMaximus, MIT Licensed.
  The accelerating-increment algorithm is theirs; the profile plumbing, activity-aware cap
  handling and cross-flavour guards are specific to this addon.
