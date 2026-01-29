local addonName = "Max_Camera_Distance"
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true, true)

if not L then return end

-- *** General Settings ***
L["GENERAL_SETTINGS"] = "General Settings"

L["MAX_ZOOM_FACTOR"] = "Max Camera Distance"
L["MAX_ZOOM_FACTOR_DESC"] = "Set the maximum allowed camera distance (in yards)."

L["MOVE_VIEW_DISTANCE"] = "Zoom Speed"
L["MOVE_VIEW_DISTANCE_DESC"] = "Adjusts how fast the camera zooms in and out."

L["YAW_MOVE_SPEED"] = "Horizontal Rotation Speed"
L["YAW_MOVE_SPEED_DESC"] = "Adjust the speed of the camera's horizontal movement (Yaw)."

L["PITCH_MOVE_SPEED"] = "Vertical Rotation Speed"
L["PITCH_MOVE_SPEED_DESC"] = "Adjust the speed of the camera's vertical movement (Pitch)."

-- *** Combat Settings ***
L["COMBAT_SETTINGS"] = "Smart Combat Zoom"
L["COMBAT_SETTINGS_WARNING"] = "|cff0070deThis section allows the camera to automatically change distance depending on whether you are in combat or not.|r"

L["AUTO_ZOOM_COMBAT"] = "Enable Smart Combat Zoom"
L["AUTO_ZOOM_COMBAT_DESC"] = "If enabled, the camera will automatically zoom out when entering combat and zoom in when leaving combat."

L["MAX_COMBAT_ZOOM_FACTOR"] = "Combat Distance"
L["MAX_COMBAT_ZOOM_FACTOR_DESC"] = "The target camera distance when you are IN combat."

L["MIN_COMBAT_ZOOM_FACTOR"] = "Non-Combat Distance"
L["MIN_COMBAT_ZOOM_FACTOR_DESC"] = "The target camera distance when you are OUT of combat (Peace mode)."

L["DISMOUNT_DELAY"] = "Exit Combat Delay"
L["DISMOUNT_DELAY_DESC"] = "Time to wait (in seconds) after leaving combat before restoring the Non-Combat camera distance."

-- *** Advanced Settings ***
L["ADVANCED_SETTINGS"] = "Advanced Settings"

L["REDUCE_UNEXPECTED_MOVEMENT"] = "Reduce Unexpected Movement"
L["REDUCE_UNEXPECTED_MOVEMENT_DESC"] = "Reduces camera jumps when the camera collides with terrain or objects."

L["RESAMPLE_ALWAYS_SHARPEN"] = "Always Sharpen"
L["RESAMPLE_ALWAYS_SHARPEN_DESC"] = "Forces the game to apply a sharpness filter, even if AMD FSR Upscale is disabled."

L["INDIRECT_VISIBILITY"] = "Terrain Collision"
L["INDIRECT_VISIBILITY_DESC"] = "Controls how the camera interacts with the environment (reduces clipping through objects)."

-- *** Messages & UI ***
L["SETTINGS_CHANGED"] = "Camera settings have been updated."
L["SETTINGS_SET_TO_MAX"] = "Camera settings set to maximum."
L["SETTINGS_SET_TO_AVERAGE"] = "Camera settings set to average."
L["SETTINGS_SET_TO_MIN"] = "Camera settings set to minimum."
L["SETTINGS_SET_TO_DEFAULT"] = "Camera settings reset to defaults."
L["SETTINGS_RESET"] = "Profile has been reset to default values."

L["WARNING_TEXT"] = "This addon extends the camera distance limit to improve visibility during raids, dungeons, and PvP."

L["RELOAD_BUTTON"] = "Reload UI"
L["RELOAD_BUTTON_DESC"] = "Reloads the user interface to apply critical changes."

L["RESET_BUTTON"] = "Reset Defaults"
L["RESET_BUTTON_DESC"] = "Resets all settings in this profile to their default values."

-- *** Debug Settings ***
L["DEBUG_SETTINGS"] = "Debug Settings"
L["ENABLE_DEBUG_LOGGING"] = "Enable Logging"
L["ENABLE_DEBUG_LOGGING_DESC"] = "Prints debug information to the chat window."

L["DEBUG_LEVEL"] = "Debug Level"
L["DEBUG_LEVEL_DESC"] = "Select the verbosity of the logs."
L["DEBUG_LEVEL_ERROR"] = "Error"
L["DEBUG_LEVEL_WARNING"] = "Warning"
L["DEBUG_LEVEL_INFO"] = "Info"
L["DEBUG_LEVEL_DEBUG"] = "Verbose"