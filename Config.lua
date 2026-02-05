local addonName, ns = ...
ns.Config = {} -- Використовуємо namespace
local Config = ns.Config

-- Імпорт локальних посилань
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Отримання версії
local versionNumber = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Dev"

-- Допоміжна функція для оновлення
-- Зберігає значення в БД і одразу застосовує зміни
local function SetOption(key, value)
    if ns.Database and ns.Database.db then
        ns.Database.db.profile[key] = value
        
        -- Викликаємо оновлення камери (Functions:AdjustCamera)
        if ns.Functions and ns.Functions.AdjustCamera then
            ns.Functions:AdjustCamera()
        end
    end
end

local function GetOption(key)
    if ns.Database and ns.Database.db then
        return ns.Database.db.profile[key]
    end
end

function Config:SetupOptions()
    -- Перевірка на наявність БД
    if not ns.Database or not ns.Database.db then
        print(addonName .. ": Database not initialized, cannot setup options.")
        return
    end
    
    -- Беремо константи з database.lua
    local defaults = ns.Database.DEFAULTS 

    local options = {
        name = "Max Camera Distance",
        type = "group",
        args = {
            -- *** Header Section ***
            header = {
                order = 0,
                type = "description",
                name = function() return "Version: |cFF87CEFA" .. versionNumber .. "|r" end,
                fontSize = "medium",
            },
            
            -- *** Warning / Reload ***
            reloadGroup = {
                order = 1,
                type = "group",
                name = " ",
                inline = true,
                args = {
                    warning = {
                        type = "description",
                        name = L["WARNING_TEXT"],
                        fontSize = "medium",
                        order = 1,
                    },
                    reloadBtn = {
                        order = 2,
                        name = L["RELOAD_BUTTON"],
                        desc = L["RELOAD_BUTTON_DESC"],
                        type = "execute",
                        func = function() C_UI.Reload() end,
                        width = "half",
                    },
                    resetBtn = {
                        order = 3,
                        name = L["RESET_BUTTON"],
                        desc = L["RESET_BUTTON_DESC"],
                        type = "execute",
                        func = function()
                            ns.Database.db:ResetProfile()
                            print("|cff0070deMCD:|r " .. (L["SETTINGS_RESET"] or "Settings reset."))
                        end,
                        width = "half",
                    },
                },
            },

            -- *** General Settings ***
            generalSettings = {
                type = "group",
                name = L["GENERAL_SETTINGS"],
                inline = false,
                order = 2,
                args = {
                    maxZoomFactor = {
                        type = "range",
                        name = L["MAX_ZOOM_FACTOR"] .. " (Yards)",
                        desc = L["MAX_ZOOM_FACTOR_DESC"],
                        min = 1.0,
                        max = defaults.MAX_POSSIBLE_DISTANCE or 39, 
                        step = 1.0,
                        get = function() return GetOption("maxZoomFactor") end,
                        set = function(_, val) SetOption("maxZoomFactor", val) end,
                        order = 1,
                        -- Вимикаємо цей слайдер, якщо увімкнено Combat Zoom, бо він перекриває налаштування
                        disabled = function() return GetOption("autoCombatZoom") end, 
                    },
                    zoomTransition = {
                        type = "range",
                        name = L["ZOOM_TRANSITION"] or "Transition Smoothness",
                        desc = L["ZOOM_TRANSITION_DESC"] or "Time to zoom to target.",
                        min = 0, max = 2.0, step = 0.1,
                        get = function() return GetOption("zoomTransitionTime") end,
                        set = function(_, val) SetOption("zoomTransitionTime", val) end,
                        order = 2,
                    },
                    moveViewDistance = {
                        type = "range",
                        name = L["MOVE_VIEW_DISTANCE"],
                        desc = L["MOVE_VIEW_DISTANCE_DESC"],
                        min = 10000, max = 50000, step = 1000,
                        get = function() return GetOption("moveViewDistance") end,
                        set = function(_, val) SetOption("moveViewDistance", val) end,
                        order = 3,
                    },
                    yawSpeed = {
                        type = "range",
                        name = L["YAW_MOVE_SPEED"],
                        desc = L["YAW_MOVE_SPEED_DESC"],
                        min = 0, max = 360, step = 10,
                        get = function() return GetOption("cameraYawMoveSpeed") end,
                        set = function(_, val) SetOption("cameraYawMoveSpeed", val) end,
                        order = 4,
                    },
                    pitchSpeed = {
                        type = "range",
                        name = L["PITCH_MOVE_SPEED"],
                        desc = L["PITCH_MOVE_SPEED_DESC"],
                        min = 0, max = 360, step = 10,
                        get = function() return GetOption("cameraPitchMoveSpeed") end,
                        set = function(_, val) SetOption("cameraPitchMoveSpeed", val) end,
                        order = 5,
                    },
                },
            },

            -- *** Smart Zoom Settings (Combat & Mount) ***
            smartSettings = {
                type = "group",
                name = L["COMBAT_SETTINGS"], -- "Smart Zoom System"
                inline = false,
                order = 3,
                args = {
                    desc = {
                        type = "description",
                        name = L["COMBAT_SETTINGS_WARNING"],
                        order = 0,
                    },
                    
                    -- === COMBAT SECTION ===
                    combatHeader = {
                        type = "header",
                        name = "Combat",
                        order = 10,
                    },
                    autoCombatZoom = {
                        type = "toggle",
                        name = L["AUTO_ZOOM_COMBAT"],
                        desc = L["AUTO_ZOOM_COMBAT_DESC"],
                        get = function() return GetOption("autoCombatZoom") end,
                        set = function(_, val) SetOption("autoCombatZoom", val) end,
                        order = 11,
                        width = "full",
                    },
                    combatMaxZoom = {
                        type = "range",
                        name = L["MAX_COMBAT_ZOOM_FACTOR"] .. " (Yards)",
                        desc = L["MAX_COMBAT_ZOOM_FACTOR_DESC"],
                        min = 1.0, 
                        max = defaults.MAX_POSSIBLE_DISTANCE or 39,
                        step = 1.0,
                        get = function() return GetOption("maxZoomFactor") end,
                        set = function(_, val) SetOption("maxZoomFactor", val) end,
                        order = 12,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    combatMinZoom = {
                        type = "range",
                        name = L["MIN_COMBAT_ZOOM_FACTOR"] .. " (Yards)",
                        desc = L["MIN_COMBAT_ZOOM_FACTOR_DESC"],
                        min = 1.0, 
                        max = defaults.MAX_POSSIBLE_DISTANCE or 39,
                        step = 1.0,
                        get = function() return GetOption("minZoomFactor") end,
                        set = function(_, val) SetOption("minZoomFactor", val) end,
                        order = 13,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    
                    -- === MOUNT SECTION ===
                    mountHeader = {
                        type = "header",
                        name = L["MOUNT_SETTINGS_HEADER"],
                        order = 20,
                    },
                    autoMountZoom = {
                        type = "toggle",
                        name = L["AUTO_MOUNT_ZOOM"],
                        desc = L["AUTO_MOUNT_ZOOM_DESC"],
                        get = function() return GetOption("autoMountZoom") end,
                        set = function(_, val) SetOption("autoMountZoom", val) end,
                        order = 21,
                        width = "full",
                    },
                    mountZoomFactor = {
                        type = "range",
                        name = L["MOUNT_ZOOM_FACTOR"] .. " (Yards)",
                        desc = L["MOUNT_ZOOM_FACTOR_DESC"],
                        min = 1.0, 
                        max = defaults.MAX_POSSIBLE_DISTANCE or 39,
                        step = 1.0,
                        get = function() return GetOption("mountZoomFactor") end,
                        set = function(_, val) SetOption("mountZoomFactor", val) end,
                        order = 22,
                        disabled = function() return not GetOption("autoMountZoom") end,
                    },

                    -- === DELAY SECTION ===
                    delayHeader = {
                        type = "header",
                        name = "Transition Delay",
                        order = 30,
                    },
                    dismountDelay = {
                        type = "range",
                        name = L["DISMOUNT_DELAY"],
                        desc = L["DISMOUNT_DELAY_DESC"],
                        min = 0, max = 10, step = 0.5,
                        get = function() return GetOption("dismountDelay") end,
                        set = function(_, val) SetOption("dismountDelay", val) end,
                        order = 31,
                        disabled = function() return not (GetOption("autoCombatZoom") or GetOption("autoMountZoom")) end,
                    },
                },
            },

            -- *** Advanced ***
            advancedSettings = {
                type = "group",
                name = L["ADVANCED_SETTINGS"],
                order = 4,
                args = {
                    reduceMovement = {
                        type = "toggle",
                        name = L["REDUCE_UNEXPECTED_MOVEMENT"],
                        desc = L["REDUCE_UNEXPECTED_MOVEMENT_DESC"],
                        get = function() return GetOption("reduceUnexpectedMovement") end,
                        set = function(_, val) SetOption("reduceUnexpectedMovement", val) end,
                        order = 1,
                    },
                    indirectVis = {
                        type = "toggle",
                        name = L["INDIRECT_VISIBILITY"],
                        desc = L["INDIRECT_VISIBILITY_DESC"],
                        get = function() return GetOption("cameraIndirectVisibility") end,
                        set = function(_, val) SetOption("cameraIndirectVisibility", val) end,
                        order = 2,
                    },
                    resampleAlwaysSharpen = {
                        type = "toggle",
                        name = L["RESAMPLE_ALWAYS_SHARPEN"],
                        desc = L["RESAMPLE_ALWAYS_SHARPEN_DESC"],
                        get = function() return GetOption("resampleAlwaysSharpen") end,
                        set = function(_, val) SetOption("resampleAlwaysSharpen", val) end,
                        order = 3,
                    },
                    softTargetInteract = {
                        type = "toggle",
                        name = L["SOFT_TARGET_INTERACT"],
                        desc = L["SOFT_TARGET_INTERACT_DESC"],
                        get = function() return GetOption("softTargetInteract") end,
                        set = function(_, val) SetOption("softTargetInteract", val) end,
                        order = 4,
                    },
                },
            },
            extraFeatures = {
                type = "group",
                name = L["EXTRA_FEATURES"],
                order = 5,
                args = {
                    clearTrackerBtn = {
                        type = "execute",
                        name = L["UNTRACK_QUESTS_BUTTON"],
                        desc = L["UNTRACK_QUESTS_DESC"],
                        func = function() ns.Functions:ClearAllQuestTracking() end,
                        order = 0.5,
                        width = "full",
                    },
                    actionCamHeader = {
                        type = "header",
                        name = "Action Cam",
                        order = 1,
                    },
                    descActionCam = {
                        type = "description",
                        name = "Cinematic camera effects provided by Blizzard's hidden settings.",
                        order = 2,
                    },
                    enableShoulder = {
                        type = "toggle",
                        name = "Over Shoulder View",
                        desc = "Offsets the camera slightly to the side (test_cameraOverShoulder).",
                        get = function() return GetOption("actionCamShoulder") end,
                        set = function(_, val) SetOption("actionCamShoulder", val) end,
                        order = 3,
                    },
                    enableDynamicPitch = {
                        type = "toggle",
                        name = "Dynamic Pitch",
                        desc = "Adjusts camera angle based on movement (test_cameraDynamicPitch).",
                        get = function() return GetOption("actionCamPitch") end,
                        set = function(_, val) SetOption("actionCamPitch", val) end,
                        order = 4,
                    },
                    afkHeader = {
                        type = "header",
                        name = "AFK Mode",
                        order = 10,
                    },
                    enableAFK = {
                        type = "toggle",
                        name = "Enable AFK Rotation",
                        desc = "Automatically zooms out and rotates the camera when you go AFK.",
                        get = function() return GetOption("afkMode") end,
                        set = function(_, val) SetOption("afkMode", val) end,
                        order = 11,
                    },
                }
            },

            -- *** Debug ***
            debugSettings = {
                type = "group",
                name = L["DEBUG_SETTINGS"],
                order = 6,
                args = {
                    enableDebug = {
                        type = "toggle",
                        name = L["ENABLE_DEBUG_LOGGING"],
                        desc = L["ENABLE_DEBUG_LOGGING_DESC"],
                        get = function() return GetOption("enableDebugLogging") end,
                        set = function(_, val) SetOption("enableDebugLogging", val) end,
                        order = 1,
                    },
                    debugLevels = {
                        type = "multiselect",
                        name = L["DEBUG_LEVEL"],
                        desc = L["DEBUG_LEVEL_DESC"],
                        values = {
                            ["error"] = L["DEBUG_LEVEL_ERROR"],
                            ["warning"] = L["DEBUG_LEVEL_WARNING"],
                            ["info"] = L["DEBUG_LEVEL_INFO"],
                            ["debug"] = L["DEBUG_LEVEL_DEBUG"]
                        },
                        get = function(_, key)
                            local db = ns.Database.db.profile
                            return db.debugLevel and db.debugLevel[key]
                        end,
                        set = function(_, key, val)
                            ns.Database.db.profile.debugLevel[key] = val
                        end,
                        disabled = function() return not GetOption("enableDebugLogging") end,
                        order = 2,
                    }
                }
            }
        }
    }

    -- Реєстрація опцій
    AceConfig:RegisterOptionsTable(addonName, options)
    
    -- Додавання в налаштування Blizzard
    AceConfigDialog:AddToBlizOptions(addonName, "Max Camera Distance")
end