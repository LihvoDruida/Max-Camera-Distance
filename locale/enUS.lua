local L = LibStub("AceLocale-3.0"):NewLocale("Max_Camera_Distance", "enUS", true)
if not L then return end

L["SETTINGS_SET_TO_MAX"] = "Camera settings set to maximum values."
L["SETTINGS_SET_TO_AVERAGE"] = "Camera settings set to average values."
L["SETTINGS_SET_TO_MIN"] = "Camera settings set to minimum values."
L["SETTINGS_SET_TO_DEFAULT"] = "Camera settings set to default values."
L["SETTINGS_CHANGED"] = "Camera settings have been changed."
L["MAX_ZOOM_FACTOR"] = "Max Zoom Factor"
L["MAX_ZOOM_FACTOR_DESC"] = "Set the maximum zoom factor."
L["MOVE_VIDEO_DISTANCE"] = "Move View Distance"
L["MOVE_VIDEO_DISTANCE_DESC"] = "Set the move view distance."
L["REDUCE_UNEXPECTED_MOVEMENT"] = "Reduce Unexpected Camera Movement"
L["REDUCE_UNEXPECTED_MOVEMENT_DESC"] = "Enable this option to reduce unexpected camera movements during gameplay."
L["RESAMPLE_ALWAYS_SHARPEN"] = "Resample Always Sharpen"
L["RESAMPLE_ALWAYS_SHARPEN_DESC"] = "Run sharpness pass, even if not using AMD FSR Upscale [0,1]"
