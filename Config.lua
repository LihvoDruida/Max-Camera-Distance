Config = {}

local addonName = "Max_Camera_Distance"
local settingName = "Max Camera Distance"
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Функція для створення налаштувань
function Config:SetupOptions()
    local options = {
        name = addonName,
        type = "group",
        args = {
            generalSettings = {
                type = "group",
                name = L["GENERAL_SETTINGS"],
                inline = true,
                order = 1,
                args = {
                    maxZoomFactor = {
                        type = "range",
                        name = L["MAX_ZOOM_FACTOR"],
                        desc = L["MAX_ZOOM_FACTOR_DESC"],
                        min = 1.0,
                        max = 2.6,
                        step = 0.1,
                        get = function() return MKD.db.profile.maxZoomFactor end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("maxZoomFactor", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 1,
                    },
                    moveViewDistance = {
                        type = "range",
                        name = L["MOVE_VIEW_DISTANCE"],
                        desc = L["MOVE_VIEW_DISTANCE_DESC"],
                        min = 10000,
                        max = 50000,
                        step = 1000,
                        get = function() return MKD.db.profile.moveViewDistance end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("moveViewDistance", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 2,
                    },
                    cameraYawMoveSpeed = {
                        type = "range",
                        name = L["YAW_MOVE_SPEED"],
                        desc = L["YAW_MOVE_SPEED_DESC"],
                        min = 10,
                        max = 500,
                        step = 10,
                        get = function() return MKD.db.profile.cameraYawMoveSpeed end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("cameraYawMoveSpeed", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 3,
                    },
                    cameraPitchMoveSpeed = {
                        type = "range",
                        name = L["PITCH_MOVE_SPEED"],
                        desc = L["PITCH_MOVE_SPEED_DESC"],
                        min = 10,
                        max = 500,
                        step = 10,
                        get = function() return MKD.db.profile.cameraPitchMoveSpeed end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("cameraPitchMoveSpeed", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 4,
                    },
                },
            },
            advancedSettings = {
                type = "group",
                name = L["ADVANCED_SETTINGS"],
                inline = true,
                order = 2,
                args = {
                    reduceUnexpectedMovement = {
                        type = "toggle",
                        name = L["REDUCE_UNEXPECTED_MOVEMENT"],
                        desc = L["REDUCE_UNEXPECTED_MOVEMENT_DESC"],
                        get = function() return MKD.db.profile.reduceUnexpectedMovement end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("reduceUnexpectedMovement", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 1,
                    },
                    resampleAlwaysSharpen = {
                        type = "toggle",
                        name = L["RESAMPLE_ALWAYS_SHARPEN"],
                        desc = L["RESAMPLE_ALWAYS_SHARPEN_DESC"],
                        get = function() return MKD.db.profile.resampleAlwaysSharpen end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("resampleAlwaysSharpen", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 2,
                    },
                    cameraIndirectVisibility = {
                        type = "toggle",
                        name = L["INDIRECT_VISIBILITY"],
                        desc = L["INDIRECT_VISIBILITY_DESC"],
                        get = function() return MKD.db.profile.cameraIndirectVisibility end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("cameraIndirectVisibility", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 3,
                    },
                },
            },
        },
    }

    -- Реєстрація опцій в AceConfig і додавання їх в налаштування Blizzard
    AceConfig:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName, settingName)
end
