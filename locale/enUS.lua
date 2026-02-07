local addonName = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true, true)

if not L then return end

-- *** General Settings ***
L["GENERAL_SETTINGS"] = "General Settings"
L["VERSION_PREFIX"] = "Version: "

L["MAX_ZOOM_FACTOR"] = "Max Camera Distance"
L["MAX_ZOOM_FACTOR_DESC"] = "Set the absolute maximum allowed camera distance (in yards) for the game client."

L["MOVE_VIEW_DISTANCE"] = "Zoom Speed"
L["MOVE_VIEW_DISTANCE_DESC"] = "Adjusts how fast the camera zooms in and out when using the scroll wheel or hotkeys."

L["ZOOM_TRANSITION"] = "Transition Smoothness"
L["ZOOM_TRANSITION_DESC"] = "Time in seconds to smoothly transition between camera distances (Combat/Mount/Normal). Higher values mean slower, smoother movement."

L["YAW_MOVE_SPEED"] = "Horizontal Rotation Speed"
L["YAW_MOVE_SPEED_DESC"] = "Adjust the speed of the camera's horizontal movement (Yaw) when turning with the mouse."

L["PITCH_MOVE_SPEED"] = "Vertical Rotation Speed"
L["PITCH_MOVE_SPEED_DESC"] = "Adjust the speed of the camera's vertical movement (Pitch) when looking up or down."

-- *** Smart Zoom Settings (Combat & Mount) ***
L["COMBAT_SETTINGS"] = "Smart Zoom System"
L["COMBAT_SETTINGS_WARNING"] = "|cffffd100System Logic:|r Automatically adjusts camera distance based on your state.\n\n|cffffd100Priority:|r |cffff5555Combat|r  >  |cff66ccffMount|r  >  |cffffffffNormal|r"

-- Combat
L["AUTO_ZOOM_COMBAT"] = "Enable Smart Combat Zoom"
L["AUTO_ZOOM_COMBAT_DESC"] = "If enabled, the camera will automatically zoom out to the maximum distance when entering combat. (Highest Priority)"

L["MAX_COMBAT_ZOOM_FACTOR"] = "Combat Distance"
L["MAX_COMBAT_ZOOM_FACTOR_DESC"] = "The target camera distance when you are IN combat."

L["MIN_COMBAT_ZOOM_FACTOR"] = "Normal Distance"
L["MIN_COMBAT_ZOOM_FACTOR_DESC"] = "The target camera distance when you are OUT of combat and NOT mounted (Peace mode)."

L["ZONES_HEADER"] = "Combat Zones"
L["ZONES_DESC"] = "Select zones where the addon will |cff00ff00Force Max Zoom|r upon entering |cffff0000Combat|r.\n|cff888888Uncheck to keep auto control.|r"

L["ZONE_PARTY"] = "Dungeons"
L["ZONE_RAID"] = "Raids"
L["ZONE_ARENA"] = "Arenas"
L["ZONE_BG"] = "Battlegrounds"
L["ZONE_SCENARIO"] = "Scenarios / Delves"
L["ZONE_WORLD_DESC"] = "Zooms out for ANY combat in the open world. Warning: can be annoying while questing."
L["ZONE_WORLD_BOSS"] = "World Bosses / Events"
L["ZONE_WORLD_BOSS_DESC"] = "Zooms out only during boss encounters in the open world (checking IsEncounterInProgress)."

-- Mount
L["MOUNT_SETTINGS_HEADER"] = "Mount & Travel Settings"
L["AUTO_MOUNT_ZOOM"] = "Enable Auto Zoom on Mount"
L["AUTO_MOUNT_ZOOM_DESC"] = "Automatically zoom out when mounted or in travel form (Druid/Shaman/Evoker). Active only when NOT in combat."

L["MOUNT_ZOOM_FACTOR"] = "Mount Distance"
L["MOUNT_ZOOM_FACTOR_DESC"] = "The target camera distance when you are mounted/traveling."

-- Delay
L["DISMOUNT_DELAY"] = "Transition Delay"
L["DISMOUNT_DELAY_DESC"] = "Time to wait (in seconds) after leaving combat or dismounting before zooming back in."

-- *** Advanced Settings ***
L["ADVANCED_SETTINGS"] = "Advanced Settings"

L["REDUCE_UNEXPECTED_MOVEMENT"] = "Reduce Unexpected Movement"
L["REDUCE_UNEXPECTED_MOVEMENT_DESC"] = "Reduces camera jumps when the camera collides with terrain or objects (Smart Pivot)."

L["RESAMPLE_ALWAYS_SHARPEN"] = "Always Sharpen (FSR)"
L["RESAMPLE_ALWAYS_SHARPEN_DESC"] = "Forces the game to apply a sharpness filter (FidelityFX), making the image crisper even without upscaling."

L["INDIRECT_VISIBILITY"] = "Terrain Collision"
L["INDIRECT_VISIBILITY_DESC"] = "Controls how the camera interacts with the environment (reduces clipping through objects)."

L["SOFT_TARGET_INTERACT"] = "Soft Target Interact Icons"
L["SOFT_TARGET_INTERACT_DESC"] = "Displays interaction icons over game objects (mailboxes, herbs, portals, NPCs) for easier targeting."

-- *** Extra Features (ActionCam & AFK) ***
L["EXTRA_FEATURES"] = "Extra Features"

L["UNTRACK_QUESTS_BUTTON"] = "Untrack All Quests"
L["UNTRACK_QUESTS_DESC"] = "Instantly removes all quests from the objective tracker (right side of screen) to reduce clutter and improve FPS."
L["QUEST_TRACKER_EMPTY"] = "Quest tracker is already empty."
L["QUEST_TRACKER_CLEARED"] = "Stopped tracking %d quests."

-- Action Cam
L["ACTION_CAM_HEADER"] = "Action Cam"
L["ACTION_CAM_DESC"] = "Enables Blizzard's hidden ActionCam settings for a modern RPG camera feel."
L["ACTION_CAM_SHOULDER_NAME"] = "Over Shoulder View"
L["ACTION_CAM_SHOULDER_DESC"] = "Offsets the camera slightly to the side (test_cameraOverShoulder). Features 'Smart Offset' which centers the camera when zooming in close."
L["ACTION_CAM_PITCH_NAME"] = "Dynamic Pitch"
L["ACTION_CAM_PITCH_DESC"] = "Adjusts camera angle based on movement (test_cameraDynamicPitch)."

-- AFK Mode
L["AFK_MODE_HEADER"] = "AFK Mode"
L["AFK_MODE_DESC_SAFE"] = "|cff00ff00Safe Mode:|r If the UI is hidden, pressing |cffffd100ESC|r will immediately restore it and exit AFK mode."
L["AFK_MODE_ENABLE"] = "Enable AFK Rotation"
L["AFK_MODE_ENABLE_DESC"] = "Automatically zooms out and rotates the camera when you go AFK. Hides UI for cinematic effect."

-- *** Messages & UI ***
L["SETTINGS_CHANGED"] = "Camera settings have been updated."
L["SETTINGS_RESET"] = "Profile has been reset to default values."
L["DB_NOT_READY"] = "Database not initialized yet."
L["CMD_USAGE"] = "Usage: /mcd config | autozoom | automount"
L["ZOOM_SET_MESSAGE"] = "Zoom set to %s (%.1f yards)"
L["CONFLICT_FIX_MSG"] = "ActionCam: Disabled 'Keep Character Centered' setting to prevent camera jitter."

L["WARNING_TEXT"] = "This addon extends the camera distance limit beyond default UI slider to improve visibility during raids, dungeons, and PvP."

L["RELOAD_BUTTON"] = "Reload UI"
L["RELOAD_BUTTON_DESC"] = "Reloads the user interface to apply critical changes."

L["RESET_BUTTON"] = "Reset Defaults"
L["RESET_BUTTON_DESC"] = "Resets all settings in this profile to their default values."

-- *** Hook / System Messages ***
L["HOOK_DISABLED_BY_ADDON"] = "|cffff0000Disabled by MaxCameraDistance|r"
L["HOOK_MOUSE_SPEED_DESC"] = "Mouse speed is now controlled separately (Horizontal/Vertical) in the addon settings:"
L["HOOK_MOUSE_SPEED_PATH"] = "/mcd config -> General Settings"

-- *** Debug Settings ***
L["DEBUG_SETTINGS"] = "Debug Settings"
L["ENABLE_DEBUG_LOGGING"] = "Enable Logging"
L["ENABLE_DEBUG_LOGGING_DESC"] = "Prints debug information to the chat window about state changes (Combat/Mount) and CVar updates."

L["DEBUG_LEVEL"] = "Debug Level"
L["DEBUG_LEVEL_DESC"] = "Select the verbosity of the logs."
L["DEBUG_LEVEL_ERROR"] = "Error"
L["DEBUG_LEVEL_WARNING"] = "Warning"
L["DEBUG_LEVEL_INFO"] = "Info"
L["DEBUG_LEVEL_DEBUG"] = "Verbose"