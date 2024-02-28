local Locals = LibStub("AceLocale-3.0"):NewLocale("Max_Camera_Distance", "deDE")
if not Locals then return end

L = Locals or {}
L["MAX_ZOOM_FACTOR"] = "Maximaler Zoomfaktor"
L["MAX_ZOOM_FACTOR_DESC"] = "Stellt den maximalen Zoomfaktor ein."
L["MOVE_VIDEO_DISTANCE"] = "Sichtweite verschieben"
L["MOVE_VIDEO_DISTANCE_DESC"] = "Stellt die Sichtweite zum Verschieben ein."
--[[Translation missing --]]
L["REDUCE_UNEXPECTED_MOVEMENT"] = "Reduce Unexpected Camera Movement"
--[[Translation missing --]]
L["REDUCE_UNEXPECTED_MOVEMENT_DESC"] = "Enable this option to reduce unexpected camera movements during gameplay."
--[[Translation missing --]]
L["RESAMPLE_ALWAYS_SHARPEN"] = "Resample Always Sharpen"
--[[Translation missing --]]
L["RESAMPLE_ALWAYS_SHARPEN_DESC"] = "Run sharpness pass, even if not using AMD FSR Upscale [0,1]"
L["SETTINGS_CHANGED"] = "Die Kameraeinstellungen wurden geändert."
L["SETTINGS_SET_TO_AVERAGE"] = "Kameraeinstellungen auf Durchschnittswerte setzten."
L["SETTINGS_SET_TO_DEFAULT"] = "Kameraeinstellungen auf Standardwerte setzten."
L["SETTINGS_SET_TO_MAX"] = "Kameraeinstellungen auf Maximalwerte setzten."
L["SETTINGS_SET_TO_MIN"] = "Kameraeinstellungen auf Minimalwerte setzten."
