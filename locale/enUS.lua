local addonName = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true, true)
if not L then return end

-- ============================================================================
-- General
-- ============================================================================
L["GENERAL_SETTINGS"] = "General Settings"
L["VERSION_PREFIX"] = "Version: "

L["MAX_ZOOM_FACTOR"] = "Max Camera Distance"
L["MAX_ZOOM_FACTOR_DESC"] = "Set the absolute maximum allowed camera distance (in yards) for the game client."

L["MOVE_VIEW_DISTANCE"] = "Zoom Speed"
L["MOVE_VIEW_DISTANCE_DESC"] = "How fast the camera zooms in and out when using the mouse wheel or hotkeys."

L["ZOOM_TRANSITION"] = "Transition Smoothness"
L["ZOOM_TRANSITION_DESC"] = "Time in seconds to smoothly transition between camera distances (Combat/Mount/Normal). Higher values mean slower, smoother movement."

L["YAW_MOVE_SPEED"] = "Horizontal Rotation Speed"
L["YAW_MOVE_SPEED_DESC"] = "Adjust the speed of horizontal camera rotation (Yaw) when turning with the mouse."

L["PITCH_MOVE_SPEED"] = "Vertical Rotation Speed"
L["PITCH_MOVE_SPEED_DESC"] = "Adjust the speed of vertical camera rotation (Pitch) when looking up or down."

-- UI / Profile
L["WARNING_TEXT"] = "This addon extends the camera distance limit beyond the default UI slider to improve visibility in raids, dungeons, and PvP."

L["RELOAD_BUTTON"] = "Reload UI"
L["RELOAD_BUTTON_DESC"] = "Reloads the user interface to apply critical changes."

L["RESET_BUTTON"] = "Reset Defaults"
L["RESET_BUTTON_DESC"] = "Resets all settings in this profile to their default values."

L["SETTINGS_CHANGED"] = "Camera settings have been updated."
L["SETTINGS_RESET"] = "Profile has been reset to default values."
L["DB_NOT_READY"] = "Database not initialized yet."

-- Minimap
L["SHOW_MINIMAP_BUTTON"] = "Show Minimap Button"
L["SHOW_MINIMAP_BUTTON_DESC"] = "Toggles the minimap icon."

-- Common states
L["ENABLED"] = "|cff00ff00Enabled|r"
L["DISABLED"] = "|cffff0000Disabled|r"

-- ============================================================================
-- Smart Zoom (Combat & Mount)
-- ============================================================================
L["COMBAT_SETTINGS"] = "Smart Zoom System"
L["COMBAT_SETTINGS_WARNING"] = "|cffffd100System Logic:|r Automatically adjusts camera distance based on your state.\n\n|cffffd100Priority:|r |cffff5555Combat|r  >  |cff66ccffMount|r  >  |cffffffffNormal|r"

-- Combat
L["AUTO_ZOOM_COMBAT"] = "Enable Smart Combat Zoom"
L["AUTO_ZOOM_COMBAT_DESC"] = "Automatically zooms out to the configured distance when entering combat. (Highest Priority)"

L["MAX_COMBAT_ZOOM_FACTOR"] = "Combat Distance"
L["MAX_COMBAT_ZOOM_FACTOR_DESC"] = "Target camera distance while you are IN combat."

L["MIN_COMBAT_ZOOM_FACTOR"] = "Normal Distance"
L["MIN_COMBAT_ZOOM_FACTOR_DESC"] = "Target camera distance while OUT of combat and NOT mounted."

-- Zones
L["ZONES_HEADER"] = "Combat Zones"
L["ZONES_DESC"] = "Select zones where the addon will |cff00ff00force max combat zoom|r.\n|cff888888Disable zones to keep camera control more relaxed.|r"

L["ZONE_PARTY"] = "Dungeons"
L["ZONE_RAID"] = "Raids"
L["ZONE_ARENA"] = "Arenas"
L["ZONE_BG"] = "Battlegrounds"
L["ZONE_SCENARIO"] = "Scenarios / Delves"

-- (Missing in your snippet but referenced by options in some setups)
L["ZONE_WORLD"] = "Open World Combat"
L["ZONE_WORLD_DESC"] = "Zooms out for ANY combat in the open world. Warning: may feel aggressive while questing."

L["ZONE_WORLD_BOSS"] = "World Bosses / Events"
L["ZONE_WORLD_BOSS_DESC"] = "Zooms out only during boss encounters in the open world (IsEncounterInProgress)."

-- Mount / Travel
L["MOUNT_SETTINGS_HEADER"] = "Mount & Travel Settings"
L["AUTO_MOUNT_ZOOM"] = "Enable Auto Zoom on Mount"
L["AUTO_MOUNT_ZOOM_DESC"] = "Automatically zooms out when mounted or in travel form (Druid/Shaman/Evoker). Active only when NOT in combat."

L["MOUNT_ZOOM_FACTOR"] = "Mount Distance"
L["MOUNT_ZOOM_FACTOR_DESC"] = "Target camera distance while mounted/traveling."

-- Delay
L["DISMOUNT_DELAY"] = "Mount Return Delay"
L["DISMOUNT_DELAY_DESC"] = "Delay before returning to Normal after leaving mount or travel form."

-- Messages used by Functions.lua
L["SMART_ZOOM_MSG"] = "Smart Zoom: state=%s, target=%.1f yards"
L["SMART_ZOOM_DISABLED_MSG"] = "Smart Zoom is disabled. Using manual max distance settings."

-- ============================================================================
-- Advanced
-- ============================================================================
L["ADVANCED_SETTINGS"] = "Advanced Settings"

L["REDUCE_UNEXPECTED_MOVEMENT"] = "Reduce Unexpected Movement"
L["REDUCE_UNEXPECTED_MOVEMENT_DESC"] = "Reduces camera jumps when the camera collides with terrain or objects (Smart Pivot)."

L["INDIRECT_VISIBILITY"] = "Reduced Camera Collision"
L["INDIRECT_VISIBILITY_DESC"] = "Turns on Blizzard's reduced camera collision behavior. This is a global client setting and applies everywhere."
L["INDIRECT_OFFSET"] = "Collision Sensitivity"
L["INDIRECT_OFFSET_DESC"] = "How strongly reduced camera collision should resist pushing the camera forward. Higher values tolerate more obstruction before the camera moves in."
L["COLLISION_HEADER"] = "Camera Collision"
L["COLLISION_DESC"] = "General camera collision behavior. These settings are global and apply everywhere, not per combat context."
L["COLLISION_SUMMARY_TEXT"] = "Reduced Camera Collision: %s\nCollision Sensitivity: %s\nReduce Unexpected Movement: %s\nThese settings are global and apply everywhere."
L["VISUAL_UTILITY_HEADER"] = "Visual Utility"

L["RESAMPLE_ALWAYS_SHARPEN"] = "Always Sharpen (FSR)"
L["RESAMPLE_ALWAYS_SHARPEN_DESC"] = "Forces the game to apply a sharpness filter (FidelityFX), making the image crisper even without upscaling."

L["SOFT_TARGET_INTERACT"] = "Soft Target Interact Icons"
L["SOFT_TARGET_INTERACT_DESC"] = "Displays interaction icons over game objects (mailboxes, herbs, portals, NPCs) for easier targeting."

-- ============================================================================
-- Extra Features
-- ============================================================================
L["EXTRA_FEATURES"] = "Extra Features"

-- Quest Tracker
L["UNTRACK_QUESTS_BUTTON"] = "Untrack All Quests"
L["UNTRACK_QUESTS_DESC"] = "Instantly removes all quests from the objective tracker to reduce clutter."
L["QUEST_TRACKER_EMPTY"] = "Quest tracker is already empty."
L["QUEST_TRACKER_CLEARED"] = "Stopped tracking %d quests."

-- ActionCam
L["ACTION_CAM_HEADER"] = "Action Cam"
L["ACTION_CAM_DESC"] = "Enables Blizzard's hidden ActionCam settings for a modern RPG camera feel."

L["ACTION_CAM_SHOULDER_NAME"] = "Over-Shoulder View"
L["ACTION_CAM_SHOULDER_DESC"] = "Offsets the camera slightly to the side (test_cameraOverShoulder). Includes Smart Offset that recenters when zooming in close."

L["ACTION_CAM_PITCH_NAME"] = "Dynamic Pitch"
L["ACTION_CAM_PITCH_DESC"] = "Adjusts camera angle based on movement (test_cameraDynamicPitch)."

L["CONFLICT_FIX_MSG"] = "ActionCam: Disabled 'Keep Character Centered' to prevent camera jitter."

-- AFK
L["AFK_MODE_HEADER"] = "AFK Mode"
L["AFK_MODE_DESC_SAFE"] = "|cff00ff00Safe Mode:|r If the UI is hidden, pressing |cffffd100ESC|r will immediately restore it and exit AFK mode."
L["AFK_MODE_ENABLE"] = "Enable AFK Rotation"
L["AFK_MODE_ENABLE_DESC"] = "Automatically zooms out and rotates the camera while AFK. Hides UI for cinematic effect."

-- Messages used by AFK logic
L["AFK_ENTER_MSG"] = "AFK Mode: enabled (cinematic rotation)."
L["AFK_EXIT_MSG"] = "AFK Mode: disabled (restored UI and camera)."

-- ============================================================================
-- Commands / Help
-- ============================================================================
L["CMD_USAGE"] = "Usage: /mcd config | autozoom | automount"

-- Optional (if used anywhere in other files)
L["ZOOM_SET_MESSAGE"] = "Zoom set to %s (%.1f yards)"

-- ============================================================================
-- Hook / System Messages
-- ============================================================================
L["HOOK_DISABLED_BY_ADDON"] = "|cffff0000Disabled by MaxCameraDistance|r"
L["HOOK_MOUSE_SPEED_DESC"] = "Mouse look speed is controlled separately (Horizontal/Vertical) in the addon settings:"
L["HOOK_MOUSE_SPEED_PATH"] = "/mcd config -> General Settings"

-- ============================================================================
-- Debug
-- ============================================================================
L["DEBUG_SETTINGS"] = "Debug Settings"
L["ENABLE_DEBUG_LOGGING"] = "Enable Logging"
L["ENABLE_DEBUG_LOGGING_DESC"] = "Prints debug information to chat about state changes (Combat/Mount/AFK) and CVar updates."

L["DEBUG_LEVEL"] = "Debug Level"
L["DEBUG_LEVEL_DESC"] = "Select the verbosity of logs."
L["DEBUG_LEVEL_ERROR"] = "Error"
L["DEBUG_LEVEL_WARNING"] = "Warning"
L["DEBUG_LEVEL_INFO"] = "Info"
L["DEBUG_LEVEL_DEBUG"] = "Verbose"

-- Additional localized UI labels
L["COMBAT_HEADER"] = "Combat"
L["ZONE_CATEGORY_PVP"] = "PvP"
L["ZONE_CATEGORY_PVE"] = "PvE"
L["ZONE_ZOOM_FACTOR"] = "Zone Distance"
L["ZONE_ZOOM_FACTOR_DESC"] = "Target camera distance in enabled raid, dungeon, arena, battleground, or scenario zones. Lets you keep a smaller combat distance elsewhere."
L["DELAY_HEADER"] = "Return Hysteresis"
L["ACTION_CAM_SHOULDER_IN_COMBAT_NAME"] = "Over-Shoulder in Combat"
L["ACTION_CAM_SHOULDER_IN_COMBAT_DESC"] = "Enable over-shoulder camera while in combat."
L["ACTION_CAM_SHOULDER_OUT_OF_COMBAT_NAME"] = "Over-Shoulder out of Combat"
L["ACTION_CAM_SHOULDER_OUT_OF_COMBAT_DESC"] = "Enable over-shoulder camera while out of combat."

L["WORLD_COMBAT_ZOOM_FACTOR"] = "Open World Combat Distance"
L["WORLD_COMBAT_ZOOM_FACTOR_DESC"] = "Target camera distance while you are in combat in the open world."
L["PARTY_COMBAT_ZOOM_FACTOR"] = "Party Combat Distance"
L["PARTY_COMBAT_ZOOM_FACTOR_DESC"] = "Target camera distance while you are in combat in a party, dungeon, delve, or similar small-group content."
L["RAID_COMBAT_ZOOM_FACTOR"] = "Raid Combat Distance"
L["RAID_COMBAT_ZOOM_FACTOR_DESC"] = "Target camera distance while you are in combat in a raid or other large-group content."
L["GROUP_COMBAT_ZOOM_FACTOR"] = "Raid / Party Combat Distance"
L["GROUP_COMBAT_ZOOM_FACTOR_DESC"] = "Target camera distance while you are in combat in a party, dungeon, raid, or similar group content."
L["PVP_COMBAT_ZOOM_FACTOR"] = "PvP Combat Distance"
L["PVP_COMBAT_ZOOM_FACTOR_DESC"] = "Target camera distance while you are in combat in PvP content."

L["PROFILES"] = "Profiles"

L["PROFILES_MISSING_LIB_DESC"] = "AceDBOptions-3.0 was not found, so advanced profile controls are unavailable."


L["ZONE_CONTEXT_HEADER"] = "Context Rules"
L["ZONE_CONTEXT_DESC"] = "These toggles decide whether party, raid, battleground, arena, and scenario combat should use their own preset or fall back to the open-world combat distance."
L["ZONE_PARTY_DESC"] = "Use the Party Combat Distance in dungeon and party content. Disable it to fall back to the Open World Combat Distance instead."
L["ZONE_RAID_DESC"] = "Use the Raid Combat Distance in raid content. Disable it to fall back to the Open World Combat Distance instead."
L["ZONE_ARENA_DESC"] = "Use the PvP Combat Distance in arenas. Disable it to fall back to the Open World Combat Distance instead."
L["ZONE_BG_DESC"] = "Use the PvP Combat Distance in battlegrounds. Disable it to fall back to the Open World Combat Distance instead."
L["ZONE_SCENARIO_DESC"] = "Use the Party Combat Distance in scenarios and delves. Disable it to fall back to the Open World Combat Distance instead."

L["STATUS_HEADER"] = "Live Status"
L["STATUS_DESC"] = "Shows the current resolved zoom decision and why it was chosen."
L["STATUS_UNAVAILABLE"] = "Live status is unavailable right now."
L["STATUS_ZOOM_STATE"] = "Zoom State"
L["STATUS_CONTEXT"] = "Resolved Context"
L["STATUS_RAW_CONTEXT"] = "Raw Context"
L["STATUS_ZONE_SOURCE"] = "Zone Source"
L["STATUS_TARGET_DISTANCE"] = "Target Distance"
L["STATUS_COLLISION_ENABLED"] = "Reduced Camera Collision"
L["STATUS_COLLISION_OFFSET"] = "Collision Sensitivity"
L["STATUS_SMART_PIVOT"] = "Reduce Unexpected Movement"
L["STATUS_WORLD_FALLBACK"] = "Using World Fallback"
L["STATUS_REASON_FLAGS"] = "Reason Flags"
L["STATUS_ZONE_FLAGS"] = "Zone Flags"
L["STATUS_YES"] = "Yes"
L["STATUS_NO"] = "No"
L["STATUS_STATE_NONE"] = "None"
L["STATUS_STATE_MOUNT"] = "Mount"
L["STATUS_STATE_COMBAT"] = "Combat"
L["STATUS_CONTEXT_WORLD"] = "World"
L["STATUS_CONTEXT_PARTY"] = "Party"
L["STATUS_CONTEXT_RAID"] = "Raid"
L["STATUS_CONTEXT_PVP"] = "PvP"
L["STATUS_ZONE_SOURCE_WORLD"] = "World"
L["STATUS_ZONE_SOURCE_PARTY"] = "Party"
L["STATUS_ZONE_SOURCE_RAID"] = "Raid"
L["STATUS_ZONE_SOURCE_ARENA"] = "Arena"
L["STATUS_ZONE_SOURCE_BG"] = "Battleground"
L["STATUS_ZONE_SOURCE_SCENARIO"] = "Scenario / Delve"

L["STATUS_REASON_PLAYER"] = "Player"
L["STATUS_REASON_GROUP"] = "Group"
L["STATUS_REASON_THREAT"] = "Threat"
L["STATUS_REASON_MOUNTED"] = "Mounted"
L["STATUS_REASON_WORLD_BOSS"] = "World Boss"


L["PRESET_SETTINGS"] = "Presets"
L["PRESET_SECTION_HEADER"] = "Distance Presets"
L["PRESET_SECTION_DESC"] = "Presets convert high-level choices into real distances. If a preset other than Manual is selected, the matching slider is locked automatically."
L["PRESET_MANUAL_GROUP_HEADER"] = "Manual / Normal"
L["PRESET_COMBAT_GROUP_HEADER"] = "Combat Presets"
L["PRESET_MOUNT_GROUP_HEADER"] = "Mount / Travel"
L["PRESET_MANUAL"] = "Manual"
L["PRESET_CLIENT_DEFAULT"] = "Game Default"
L["PRESET_CLOSE"] = "Close"
L["PRESET_BALANCED"] = "Balanced"
L["PRESET_FAR"] = "Far"
L["PRESET_MAX"] = "Maximum"
L["PRESET_STATUS_UNAVAILABLE"] = "Preset status is unavailable."
L["PRESET_STATUS_MANUAL"] = "Manual control is active. Slider value: %.1f yd."
L["PRESET_STATUS_LOCKED"] = "Preset: %s. Effective distance: %.1f yd. Matching manual control is locked until you switch back to Manual."
L["PRESET_UNKNOWN"] = "Unknown"
L["MANUAL_SECTION_HEADER"] = "Manual Camera Controls"
L["MANUAL_SECTION_DESC"] = "Manual controls stay available only when the matching preset is set to Manual."
L["MANUAL_COMBAT_HEADER"] = "Manual Distances"
L["MANUAL_COMBAT_DESC"] = "These sliders are used only when their matching preset is set to Manual."
L["MANUAL_MAX_PRESET"] = "Manual Max Distance Preset"
L["NORMAL_ZOOM_PRESET"] = "Normal Distance Preset"
L["WORLD_COMBAT_PRESET"] = "Open World Combat Preset"
L["PARTY_COMBAT_PRESET"] = "Party Combat Preset"
L["RAID_COMBAT_PRESET"] = "Raid Combat Preset"
L["PVP_COMBAT_PRESET"] = "PvP Combat Preset"
L["MOUNT_ZOOM_PRESET"] = "Mount Distance Preset"

L["STATUS_DISTANCE_SOURCE"] = "Distance Source"


L["DEBUG_SETTINGS"] = "Status & Debug"
L["DEBUG_LOGGING_HEADER"] = "Chat Logging"
L["DEBUG_LOGGING_DESC"] = "These options control what gets printed to chat. Live Status above is always available even with logging disabled."
L["COMBAT_TRIGGER_HEADER"] = "Combat Triggers"
L["COMBAT_TRIGGER_DESC"] = "Choose which events are allowed to activate combat zoom."
L["COMBAT_TRIGGER_PLAYER"] = "Zoom when I enter combat"
L["COMBAT_TRIGGER_PLAYER_DESC"] = "Triggers combat zoom when your character enters combat."
L["COMBAT_TRIGGER_GROUP"] = "Zoom when party or raid enters combat"
L["COMBAT_TRIGGER_GROUP_DESC"] = "Triggers combat zoom when your party or raid is fighting, even if you are not actively in combat yet."
L["COMBAT_TRIGGER_THREAT"] = "Zoom on threat only"
L["COMBAT_TRIGGER_THREAT_DESC"] = "Triggers combat zoom when you have threat, even if the normal combat flag has not settled yet."
L["STATUS_TRIGGER_RULES"] = "Trigger Rules"
L["STATUS_ACTIVE_TRIGGERS"] = "Active Triggers"


L["DELAY_HEADER_DESC"] = "Combat zoom-out is instant. Returning to Normal is delayed per context to avoid camera flicker."
L["WORLD_COMBAT_RETURN_DELAY"] = "Open World Return Delay"
L["WORLD_COMBAT_RETURN_DELAY_DESC"] = "Delay before returning to Normal after open-world combat ends."
L["PARTY_COMBAT_RETURN_DELAY"] = "Party Return Delay"
L["PARTY_COMBAT_RETURN_DELAY_DESC"] = "Delay before returning to Normal after party or dungeon combat ends."
L["RAID_COMBAT_RETURN_DELAY"] = "Raid Return Delay"
L["RAID_COMBAT_RETURN_DELAY_DESC"] = "Delay before returning to Normal after raid combat ends."
L["STATUS_RETURN_DELAYS"] = "Return Delays"
L["STATUS_PENDING_RETURN"] = "Pending Return"
L["STATUS_PENDING_RETURN_NONE"] = "No delayed return is pending."
L["STATUS_PENDING_RETURN_ACTIVE"] = "%s: %s, %.1fs remaining (total %.1fs)."
L["STATUS_RETURN_KIND_COMBAT"] = "Combat Return"
L["STATUS_RETURN_KIND_MOUNT"] = "Mount Return"
