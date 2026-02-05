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
    * *Dynamic Interpolation:* Automatically centers the camera when you zoom in close (for looting/interacting) and shifts to the shoulder as you zoom out.
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

### ⚙️ System Integration & Optimization
* **Zero-Lag Core:** Uses **Event Throttling** to process camera logic only once per frame, ensuring 0% FPS drop even in heavy raid combat.
* **Blizzard Settings Hook:** Intercepts the default UI to disable the "Mouse Look Speed" slider, preventing conflicts with the addon's precision Pitch/Yaw controls.
* **Limit Breaker:** Extends camera distance up to 39 yards (Retail) / 50 yards (Classic).

## 🛠️ Quality of Life
* **Always Sharpen (FSR):** Forces FidelityFX sharpness for a crisper image without upscaling.
* **Soft Target Icons:** Displays interaction icons over NPCs and portals.
* **Quest Cleaner:** One-click button to untrack all quests for instant FPS boost in raids.

## 💻 Commands

* `/mcd config` - Open the configuration panel (GUI).
* `/mcd autozoom` - Toggle Smart Combat Zoom.
* `/mcd automount` - Toggle Smart Mount Zoom.

## ✅ Compatibility

Fully compatible with:
* **Retail:** Midnight (12.x) - *Safe for Raids (Private Aura crash fixed!)*, *Full Skyriding Support*
* **Classic:** Mists of Pandaria Classic
* **Anniversary:** The Burning Crusade (TBC)

## 🐞 Bug Reporting

Found a bug or have a suggestion? Please submit a ticket via our [GitHub Issues](https://github.com/LihvoDruida/Max-Camera-Distance/issues) or leave a comment on [CurseForge](https://www.curseforge.com/wow/addons/max-camera-distance).
