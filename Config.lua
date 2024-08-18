Config = {}

local addon = "Max_Camera_Distance"

local settingName = "Max Camera Distance"
local L = LibStub("AceLocale-3.0"):GetLocale(addon)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Function to create addon options
function Config:SetupOptions()
    -- Defining the options table
    local options = {
        name = settingName,
        type = "group",
        args = {
            generalSettings = {
                type = "group",
                name = L["GENERAL_SETTINGS"], -- Ensure this resolves to a string
                inline = true,
                order = 1,
                args = {
                    maxZoomFactor = {
                        type = "range",
                        name = L["MAX_ZOOM_FACTOR"],      -- Ensure this resolves to a string
                        desc = L["MAX_ZOOM_FACTOR_DESC"], -- Ensure this resolves to a string
                        min = 1.0,
                        max = Database.MAX_ZOOM_FACTOR,
                        step = 0.1,
                        get = function() return Database.db.profile.maxZoomFactor end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("maxZoomFactor", value, L["SETTINGS_CHANGED"]) -- Ensure L["SETTINGS_CHANGED"] resolves to a string
                        end,
                        order = 1,
                    },
                    moveViewDistance = {
                        type = "range",
                        name = L["MOVE_VIEW_DISTANCE"],      -- Ensure this resolves to a string
                        desc = L["MOVE_VIEW_DISTANCE_DESC"], -- Ensure this resolves to a string
                        min = 10000,
                        max = 50000,
                        step = 1000,
                        get = function() return Database.db.profile.moveViewDistance end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("moveViewDistance", value, L["SETTINGS_CHANGED"]) -- Ensure L["SETTINGS_CHANGED"] resolves to a string
                        end,
                        order = 2,
                    },
                    cameraYawMoveSpeed = {
                        type = "range",
                        name = L["YAW_MOVE_SPEED"],      -- Ensure this resolves to a string
                        desc = L["YAW_MOVE_SPEED_DESC"], -- Ensure this resolves to a string
                        min = Database.MIN_PITCH_YAW_MOVE_SPEED,
                        max = Database.MAX_PITCH_YAW_MOVE_SPEED,
                        step = 1,
                        get = function() return Database.db.profile.cameraYawMoveSpeed end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("cameraYawMoveSpeed", value, L["SETTINGS_CHANGED"]) -- Ensure L["SETTINGS_CHANGED"] resolves to a string
                        end,
                        order = 3,
                    },
                    cameraPitchMoveSpeed = {
                        type = "range",
                        name = L["PITCH_MOVE_SPEED"],      -- Ensure this resolves to a string
                        desc = L["PITCH_MOVE_SPEED_DESC"], -- Ensure this resolves to a string
                        min = Database.MIN_PITCH_YAW_MOVE_SPEED,
                        max = Database.MAX_PITCH_YAW_MOVE_SPEED,
                        step = 1,
                        get = function() return Database.db.profile.cameraPitchMoveSpeed end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("cameraPitchMoveSpeed", value, L["SETTINGS_CHANGED"]) -- Ensure L["SETTINGS_CHANGED"] resolves to a string
                        end,
                        order = 4,
                    },
                },
            },
            advancedSettings = {
                type = "group",
                name = L["ADVANCED_SETTINGS"], -- Ensure this resolves to a string
                inline = true,
                order = 2,
                args = {
                    reduceUnexpectedMovement = {
                        type = "toggle",
                        name = L["REDUCE_UNEXPECTED_MOVEMENT"],      -- Ensure this resolves to a string
                        desc = L["REDUCE_UNEXPECTED_MOVEMENT_DESC"], -- Ensure this resolves to a string
                        get = function() return Database.db.profile.reduceUnexpectedMovement end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("reduceUnexpectedMovement", value, L["SETTINGS_CHANGED"]) -- Ensure L["SETTINGS_CHANGED"] resolves to a string
                        end,
                        order = 1,
                    },
                    resampleAlwaysSharpen = {
                        type = "toggle",
                        name = L["RESAMPLE_ALWAYS_SHARPEN"],      -- Ensure this resolves to a string
                        desc = L["RESAMPLE_ALWAYS_SHARPEN_DESC"], -- Ensure this resolves to a string
                        get = function() return Database.db.profile.resampleAlwaysSharpen end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("resampleAlwaysSharpen", value, L["SETTINGS_CHANGED"]) -- Ensure L["SETTINGS_CHANGED"] resolves to a string
                        end,
                        order = 2,
                    },
                    cameraIndirectVisibility = {
                        type = "toggle",
                        name = L["INDIRECT_VISIBILITY"],      -- Ensure this resolves to a string
                        desc = L["INDIRECT_VISIBILITY_DESC"], -- Ensure this resolves to a string
                        get = function() return Database.db.profile.cameraIndirectVisibility end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("cameraIndirectVisibility", value, L["SETTINGS_CHANGED"]) -- Ensure L["SETTINGS_CHANGED"] resolves to a string
                        end,
                        order = 3,
                    },
                },
            },
        },
    }

    -- Register options with AceConfig
    AceConfig:RegisterOptionsTable(addon, options)

    -- Add options to Blizzard settings
    AceConfigDialog:AddToBlizOptions(addon, settingName)
end
