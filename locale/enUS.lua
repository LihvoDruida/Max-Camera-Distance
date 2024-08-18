local addonName = "Max_Camera_Distance"
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true, true)

L["GENERAL_SETTINGS"] = "General Settings"
L["MAX_ZOOM_FACTOR"] = "Max Zoom Factor"
L["MAX_ZOOM_FACTOR_DESC"] = "Set the maximum zoom factor."
L["MOVE_VIEW_DISTANCE"] = "Move View Distance"
L["MOVE_VIEW_DISTANCE_DESC"] = "Set the move view distance."
L["YAW_MOVE_SPEED"] = "Yaw Move Speed"
L["YAW_MOVE_SPEED_DESC"] = "Adjust the speed of yaw (horizontal) camera movement."
L["PITCH_MOVE_SPEED"] = "Pitch Move Speed"
L["PITCH_MOVE_SPEED_DESC"] = "Adjust the speed of pitch (vertical) camera movement."

L["ADVANCED_SETTINGS"] = "Advanced Settings"
L["REDUCE_UNEXPECTED_MOVEMENT"] = "Reduce Unexpected Camera Movement"
L["REDUCE_UNEXPECTED_MOVEMENT_DESC"] = "Enable this option to reduce unexpected camera movements during gameplay."
L["RESAMPLE_ALWAYS_SHARPEN"] = "Resample Always Sharpen"
L["RESAMPLE_ALWAYS_SHARPEN_DESC"] = "Run sharpness pass, even if not using AMD FSR Upscale [0,1]"
L["INDIRECT_VISIBILITY"] = "Camera Indirect Visibility"
L["INDIRECT_VISIBILITY_DESC"] =
"Enable or disable camera collision settings that control how the camera interacts with the environment."

L["SETTINGS_CHANGED"] = "Camera settings have been changed."
L["SETTINGS_SET_TO_MAX"] = "Camera settings set to maximum values."
L["SETTINGS_SET_TO_AVERAGE"] = "Camera settings set to average values."
L["SETTINGS_SET_TO_MIN"] = "Camera settings set to minimum values."
L["SETTINGS_SET_TO_DEFAULT"] = "Camera settings set to default values."
