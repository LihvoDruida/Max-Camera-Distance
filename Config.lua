Config = {}

local addon = "Max_Camera_Distance"
local settingName = "Max Camera Distance"
local L = LibStub("AceLocale-3.0"):GetLocale(addon)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

local versionNumber = C_AddOns.GetAddOnMetadata(addon, "Version")

-- Function to create addon options
function Config:SetupOptions()
    -- Define the options table
    local options = {
        name = settingName,
        type = "group",
        args = {
            version = {
                order = 0.2,
                type = "description",
                name = function()
                    return "Version: |cFF87CEFA" .. versionNumber .. "|r"
                end,
                fontSize = "small",
                width = 0.9
            },
            information = {
                order = 1,
                type = "group",
                name = " ",
                inline = true,
                args = {
                    warning = {
                        type = "description",
                        name = L["WARNING_TEXT"],
                        fontSize = "medium",
                        order = 0,
                        width = "full"
                    },
                    spacer0 = {
                        type = "description",
                        name = " ",
                        order = 0.5, -- Position this to add spacing
                        width = "full",
                    },
                    resetInterface = {
                        order = 1,
                        name = L["RELOAD_BUTTON"],
                        desc = L["RELOAD_BUTTON_DESC"],
                        type = "execute",
                        func = function() ReloadUI() end,
                    },
                    resetButton = {
                        type = "execute",
                        name = L["RESET_BUTTON"],
                        desc = L["RESET_BUTTON_DESC"],
                        func = function()
                            -- Reset the profile to default settings
                            Database.db:ResetProfile()
                            -- Optionally notify the user
                            print(L["SETTINGS_RESET"])
                        end,
                        order = 2, -- Position this at the top
                    },
                },
            },
            generalSettings = {
                type = "group",
                name = L["GENERAL_SETTINGS"],
                inline = true,
                order = 2,
                args = {
                    maxZoomFactor = {
                        type = "range",
                        name = L["MAX_ZOOM_FACTOR"],
                        desc = L["MAX_ZOOM_FACTOR_DESC"],
                        min = 1.0,
                        max = Database.MAX_ZOOM_FACTOR,
                        step = 0.1,
                        get = function() return Database.db.profile.maxZoomFactor end,
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
                        get = function() return Database.db.profile.moveViewDistance end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("moveViewDistance", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 2,
                    },
                    cameraYawMoveSpeed = {
                        type = "range",
                        name = L["YAW_MOVE_SPEED"],
                        desc = L["YAW_MOVE_SPEED_DESC"],
                        min = Database.MIN_PITCH_YAW_MOVE_SPEED,
                        max = Database.MAX_PITCH_YAW_MOVE_SPEED,
                        step = 1,
                        get = function() return Database.db.profile.cameraYawMoveSpeed end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("cameraYawMoveSpeed", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 3,
                    },
                    cameraPitchMoveSpeed = {
                        type = "range",
                        name = L["PITCH_MOVE_SPEED"],
                        desc = L["PITCH_MOVE_SPEED_DESC"],
                        min = Database.MIN_PITCH_YAW_MOVE_SPEED,
                        max = Database.MAX_PITCH_YAW_MOVE_SPEED,
                        step = 1,
                        get = function() return Database.db.profile.cameraPitchMoveSpeed end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("cameraPitchMoveSpeed", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 4,
                    },
                },
            },
            autoSettings = {
                type = "group",
                name = L["AUTO_SETTINGS"],
                inline = true,
                order = 3,
                args = {
                    dismountDelay = {
                        type = "range",
                        name = L["DISMOUNT_DELAY"],
                        desc = L["DISMOUNT_DELAY_DESC"],
                        min = 3,
                        max = 10,
                        step = 1,
                        get = function() return Database.db.profile.dismountDelay end,
                        set = function(_, value)
                            Database.db.profile.dismountDelay = value
                        end,
                        order = 0,
                    },
                    autoMountZoom = {
                        type = "toggle",
                        name = L["AUTO_ZOOM_MOUNT"],
                        desc = L["AUTO_ZOOM_MOUNT_DESC"],
                        get = function() return Database.db.profile.autoMountZoom end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("autoMountZoom", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 1,
                    },
                    autoCombatZoom = {
                        type = "toggle",
                        name = L["AUTO_ZOOM_COMBAT"],
                        desc = L["AUTO_ZOOM_COMBAT_DESC"],
                        get = function() return Database.db.profile.autoCombatZoom end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("autoCombatZoom", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 2,
                    },
                },
            },
            advancedSettings = {
                type = "group",
                name = L["ADVANCED_SETTINGS"],
                inline = true,
                order = 4,
                args = {
                    reduceUnexpectedMovement = {
                        type = "toggle",
                        name = L["REDUCE_UNEXPECTED_MOVEMENT"],
                        desc = L["REDUCE_UNEXPECTED_MOVEMENT_DESC"],
                        get = function() return Database.db.profile.reduceUnexpectedMovement end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("reduceUnexpectedMovement", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 1,
                    },
                    resampleAlwaysSharpen = {
                        type = "toggle",
                        name = L["RESAMPLE_ALWAYS_SHARPEN"],
                        desc = L["RESAMPLE_ALWAYS_SHARPEN_DESC"],
                        get = function() return Database.db.profile.resampleAlwaysSharpen end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("resampleAlwaysSharpen", value, L["SETTINGS_CHANGED"])
                        end,
                        order = 2,
                    },
                    cameraIndirectVisibility = {
                        type = "toggle",
                        name = L["INDIRECT_VISIBILITY"],
                        desc = L["INDIRECT_VISIBILITY_DESC"],
                        get = function() return Database.db.profile.cameraIndirectVisibility end,
                        set = function(_, value)
                            Functions:ChangeCameraSetting("cameraIndirectVisibility", value, L["SETTINGS_CHANGED"])
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
