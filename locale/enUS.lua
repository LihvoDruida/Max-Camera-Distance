local addonName = "Max_Camera_Distance"
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true, true)

if not L then return end

-- *** General Settings ***
L["GENERAL_SETTINGS"] = "General Settings"

L["MAX_ZOOM_FACTOR"] = "Max Camera Distance"
L["MAX_ZOOM_FACTOR_DESC"] = "Set the absolute maximum allowed camera distance (in yards) for the game client."

L["MOVE_VIEW_DISTANCE"] = "Zoom Speed"
L["MOVE_VIEW_DISTANCE_DESC"] = "Adjusts how fast the camera zooms in and out when using the scroll wheel or hotkeys."

L["YAW_MOVE_SPEED"] = "Horizontal Rotation Speed"
L["YAW_MOVE_SPEED_DESC"] = "Adjust the speed of the camera's horizontal movement (Yaw) when turning with the mouse."

L["PITCH_MOVE_SPEED"] = "Vertical Rotation Speed"
L["PITCH_MOVE_SPEED_DESC"] = "Adjust the speed of the camera's vertical movement (Pitch) when looking up or down."

-- *** Smart Zoom Settings (Combat & Mount) ***
L["COMBAT_SETTINGS"] = "Smart Zoom System"
L["COMBAT_SETTINGS_WARNING"] = "|cff0070deThis system automatically adjusts camera distance based on your current state.\nPriority: Combat > Mount > Normal.|r"

-- Combat
L["AUTO_ZOOM_COMBAT"] = "Enable Smart Combat Zoom"
L["AUTO_ZOOM_COMBAT_DESC"] = "If enabled, the camera will automatically zoom out to the maximum distance when entering combat. (Highest Priority)"

L["MAX_COMBAT_ZOOM_FACTOR"] = "Combat Distance"
L["MAX_COMBAT_ZOOM_FACTOR_DESC"] = "The target camera distance when you are IN combat."

L["MIN_COMBAT_ZOOM_FACTOR"] = "Normal Distance"
L["MIN_COMBAT_ZOOM_FACTOR_DESC"] = "The target camera distance when you are OUT of combat and NOT mounted (Peace mode)."

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

-- *** Tools Section ***
L["TOOLS_HEADER"] = "Tools & Utilities"

L["UNTRACK_QUESTS_BUTTON"] = "Untrack All Quests"
L["UNTRACK_QUESTS_DESC"] = "Instantly removes all quests from the objective tracker (right side of screen) to reduce clutter and improve FPS."

-- *** Messages & UI ***
L["SETTINGS_CHANGED"] = "Camera settings have been updated."
L["SETTINGS_RESET"] = "Profile has been reset to default values."
L["DB_NOT_READY"] = "Database not initialized yet."

L["WARNING_TEXT"] = "This addon extends the camera distance limit beyond default UI slider to improve visibility during raids, dungeons, and PvP."

L["RELOAD_BUTTON"] = "Reload UI"
L["RELOAD_BUTTON_DESC"] = "Reloads the user interface to apply critical changes."

L["RESET_BUTTON"] = "Reset Defaults"
L["RESET_BUTTON_DESC"] = "Resets all settings in this profile to their default values."

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