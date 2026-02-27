local addonName, ns = ...
ns.Config = ns.Config or {}
local Config = ns.Config

-- Libs
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- =====================================================================
-- VERSION / CLIENT DETECTION
-- =====================================================================
local build = select(4, GetBuildInfo()) or 0

-- Provided targets:
-- Retail: 120000, 120001
-- Classic Era: 20505
-- Cata Classic: 50502
local IS_RETAIL  = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) or (build >= 120000)
local IS_CATA    = (build >= 50000 and build < 60000) -- 50502
local IS_ERA     = (build > 0 and build < 30000)      -- 20505-ish

-- Cached globals / APIs
local type = type
local print = print
local tostring = tostring
local pcall = pcall
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs

local ReloadUI = ReloadUI
local C_UI = C_UI
local C_AddOns = C_AddOns
local GetAddOnMetadata = GetAddOnMetadata
local C_CVar = C_CVar
local GetCVar = GetCVar

-- =====================================================================
-- CVAR FEATURE DETECTION (works cross-version)
-- =====================================================================
local function HasCVar(name)
    -- Prefer C_CVar in modern clients
    if C_CVar and C_CVar.GetCVar then
        local ok, val = pcall(C_CVar.GetCVar, name)
        return ok and val ~= nil
    end
    -- Fallback for older clients
    if type(GetCVar) == "function" then
        local ok, val = pcall(GetCVar, name)
        return ok and val ~= nil
    end
    return false
end

local function SupportsFSRSharpen()
    return IS_RETAIL and HasCVar("resampleAlwaysSharpen")
end

local function SupportsSoftTargetIcons()
    -- SoftTargetIconGameObject is Retail-ish
    return IS_RETAIL and HasCVar("SoftTargetIconGameObject")
end

local function SupportsActionCam()
    -- test_camera* CVars exist on Retail; sometimes present on some Classic branches,
    -- but safest is to show only if at least one exists.
    return HasCVar("test_cameraOverShoulder") or HasCVar("test_cameraDynamicPitch")
end

local function SupportsScenarioZone()
    -- "scenario" instanceType is reliably Retail (Delves, Scenarios)
    return IS_RETAIL
end

-- =====================================================================
-- ADDON VERSION
-- =====================================================================
local function GetAddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, "Version") or "Dev"
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(addonName, "Version") or "Dev"
    end
    return "Dev"
end

local versionNumber = GetAddonVersion()

-- =====================================================================
-- SAFE HELPERS
-- =====================================================================
local function SafeReload()
    if C_UI and C_UI.Reload then
        C_UI.Reload()
    elseif ReloadUI then
        ReloadUI()
    end
end

local function GetDB()
    return (ns.Database and ns.Database.db and ns.Database.db.profile) or nil
end

local function ApplyNow()
    if ns.Functions and ns.Functions.AdjustCamera then
        ns.Functions:AdjustCamera(true)
    end
end

local function EnsureDebugLevelTable(db)
    if not db.debugLevel then
        db.debugLevel = { error = true, warning = true, info = true, debug = false }
    end
end

local function SetOption(key, value)
    local db = GetDB()
    if not db then return end

    db[key] = value

    if key == "enableDebugLogging" or key == "debugLevel" then
        EnsureDebugLevelTable(db)
    end

    ApplyNow()
end

local function GetOption(key)
    local db = GetDB()
    if not db then return nil end
    return db[key]
end

-- =====================================================================
-- OPTIONS
-- =====================================================================
function Config:SetupOptions()
    if not ns.Database or not ns.Database.db then return end
    local defaults = ns.Database.DEFAULTS

    -- Make sure distance matches the current client
    local maxDistance = defaults.MAX_POSSIBLE_DISTANCE or (IS_RETAIL and 39 or 50)
    local isClassic = not IS_RETAIL
    local hasQuestWatch = (C_QuestLog and C_QuestLog.GetNumQuestWatches) and true or false

    local options = {
        name = "Max Camera Distance",
        type = "group",
        args = {
            header = {
                order = 0,
                type = "description",
                name = function()
                    return (L["VERSION_PREFIX"] or "Version: ")
                        .. "|cFF87CEFA" .. versionNumber .. "|r"
                        .. (IS_RETAIL and " |cff00ff00(Retail)|r" or " |cffffd100(Classic)|r")
                end,
                fontSize = "medium",
            },

            -- Reload / Reset / Minimap
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
                        order = 1
                    },
                    reloadBtn = {
                        order = 2,
                        name = L["RELOAD_BUTTON"],
                        desc = L["RELOAD_BUTTON_DESC"],
                        type = "execute",
                        func = SafeReload,
                        width = "normal"
                    },
                    resetBtn = {
                        order = 3,
                        name = L["RESET_BUTTON"],
                        desc = L["RESET_BUTTON_DESC"],
                        type = "execute",
                        func = function()
                            ns.Database.db:ResetProfile()
                            print("|cff0070deMCD:|r " .. (L["SETTINGS_RESET"] or "Settings reset."))
                            ApplyNow()
                        end,
                        width = "normal"
                    },
                    minimapButton = {
                        type = "toggle",
                        name = L["SHOW_MINIMAP_BUTTON"] or "Show Minimap Button",
                        desc = L["SHOW_MINIMAP_BUTTON_DESC"] or "Toggles the minimap icon.",
                        order = 4,
                        width = "normal",
                        get = function()
                            local db = GetDB()
                            if not db then return true end
                            if db.minimap then
                                return not db.minimap.hide
                            end
                            return true
                        end,
                        set = function(_, val)
                            local db = GetDB()
                            if not db then return end

                            db.minimap = db.minimap or { hide = false }
                            db.minimap.hide = not val

                            local iconLib = LibStub("LibDBIcon-1.0", true)
                            if iconLib then
                                if val then iconLib:Show(addonName) else iconLib:Hide(addonName) end
                            end
                        end,
                    },
                },
            },

            -- General
            generalSettings = {
                type = "group",
                name = L["GENERAL_SETTINGS"],
                inline = false,
                order = 2,
                args = {
                    maxZoomFactor = {
                        type = "range",
                        name = (L["MAX_ZOOM_FACTOR"] or "Max Zoom") .. " (Yards)",
                        desc = L["MAX_ZOOM_FACTOR_DESC"],
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("maxZoomFactor") end,
                        set = function(_, val) SetOption("maxZoomFactor", val) end,
                        order = 1,
                        disabled = function() return GetOption("autoCombatZoom") end,
                    },
                    zoomTransition = {
                        type = "range",
                        name = L["ZOOM_TRANSITION"],
                        desc = L["ZOOM_TRANSITION_DESC"],
                        min = 0,
                        max = 2.0,
                        step = 0.1,
                        get = function() return GetOption("zoomTransitionTime") end,
                        set = function(_, val) SetOption("zoomTransitionTime", val) end,
                        order = 2,
                    },
                    moveViewDistance = {
                        type = "range",
                        name = L["MOVE_VIEW_DISTANCE"],
                        desc = L["MOVE_VIEW_DISTANCE_DESC"],
                        -- cameraDistanceMoveSpeed is a small value (usually ~20)
                        min = 1,
                        max = 50,
                        step = 1,
                        get = function() return GetOption("moveViewDistance") end,
                        set = function(_, val) SetOption("moveViewDistance", val) end,
                        order = 3,
                    },
                    yawSpeed = {
                        type = "range",
                        name = L["YAW_MOVE_SPEED"],
                        desc = L["YAW_MOVE_SPEED_DESC"],
                        min = 0,
                        max = 360,
                        step = 10,
                        get = function() return GetOption("cameraYawMoveSpeed") end,
                        set = function(_, val) SetOption("cameraYawMoveSpeed", val) end,
                        order = 4,
                    },
                    pitchSpeed = {
                        type = "range",
                        name = L["PITCH_MOVE_SPEED"],
                        desc = L["PITCH_MOVE_SPEED_DESC"],
                        min = 0,
                        max = 360,
                        step = 10,
                        get = function() return GetOption("cameraPitchMoveSpeed") end,
                        set = function(_, val) SetOption("cameraPitchMoveSpeed", val) end,
                        order = 5,
                    },
                },
            },

            -- Smart Zoom
            smartSettings = {
                type = "group",
                name = L["COMBAT_SETTINGS"],
                inline = false,
                order = 3,
                args = {
                    desc = { type = "description", name = L["COMBAT_SETTINGS_WARNING"], order = 0 },

                    combatHeader = { type = "header", name = "Combat", order = 10 },

                    autoCombatZoom = {
                        type = "toggle",
                        name = L["AUTO_ZOOM_COMBAT"],
                        desc = L["AUTO_ZOOM_COMBAT_DESC"],
                        get = function() return GetOption("autoCombatZoom") end,
                        set = function(_, val) SetOption("autoCombatZoom", val) end,
                        order = 11,
                        width = "full",
                    },

                    zonesGroup = {
                        type = "group",
                        name = L["ZONES_HEADER"],
                        inline = true,
                        order = 11.5,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                        args = {
                            zonesDescription = { type = "description", name = L["ZONES_DESC"], order = 0, fontSize = "medium" },

                            br1 = { type = "header", name = "PVP", order = 0.1, width = "full" },

                            zoneArena = { type = "toggle", name = L["ZONE_ARENA"], order = 1,
                                get = function() return GetOption("zoneArena") end,
                                set = function(_, v) SetOption("zoneArena", v) end
                            },
                            zoneBg = { type = "toggle", name = L["ZONE_BG"], order = 2,
                                get = function() return GetOption("zoneBg") end,
                                set = function(_, v) SetOption("zoneBg", v) end
                            },

                            br2 = { type = "header", name = "PVE", order = 2.1, width = "full" },

                            zoneParty = { type = "toggle", name = L["ZONE_PARTY"], order = 3,
                                get = function() return GetOption("zoneParty") end,
                                set = function(_, v) SetOption("zoneParty", v) end
                            },
                            zoneRaid = { type = "toggle", name = L["ZONE_RAID"], order = 4,
                                get = function() return GetOption("zoneRaid") end,
                                set = function(_, v) SetOption("zoneRaid", v) end
                            },

                            -- Scenario: only show on Retail (Delves/Scenarios)
                            zoneScenario = {
                                type = "toggle",
                                name = L["ZONE_SCENARIO"],
                                order = 5,
                                hidden = function() return not SupportsScenarioZone() end,
                                get = function() return GetOption("zoneScenario") end,
                                set = function(_, v) SetOption("zoneScenario", v) end
                            },

                            zoneWorldBoss = { type = "toggle", name = L["ZONE_WORLD_BOSS"], desc = L["ZONE_WORLD_BOSS_DESC"], order = 6, width = "full",
                                get = function() return GetOption("zoneWorldBoss") end,
                                set = function(_, v) SetOption("zoneWorldBoss", v) end
                            },
                        }
                    },

                    combatMaxZoom = {
                        type = "range",
                        name = (L["MAX_COMBAT_ZOOM_FACTOR"] or "Combat Max Zoom") .. " (Yards)",
                        desc = L["MAX_COMBAT_ZOOM_FACTOR_DESC"],
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("maxZoomFactor") end,
                        set = function(_, val) SetOption("maxZoomFactor", val) end,
                        order = 12,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    combatMinZoom = {
                        type = "range",
                        name = (L["MIN_COMBAT_ZOOM_FACTOR"] or "Combat Min Zoom") .. " (Yards)",
                        desc = L["MIN_COMBAT_ZOOM_FACTOR_DESC"],
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("minZoomFactor") end,
                        set = function(_, val) SetOption("minZoomFactor", val) end,
                        order = 13,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },

                    mountHeader = { type = "header", name = L["MOUNT_SETTINGS_HEADER"], order = 20 },
                    autoMountZoom = {
                        type = "toggle",
                        name = L["AUTO_MOUNT_ZOOM"],
                        desc = L["AUTO_MOUNT_ZOOM_DESC"],
                        get = function() return GetOption("autoMountZoom") end,
                        set = function(_, val) SetOption("autoMountZoom", val) end,
                        order = 21,
                        width = "full"
                    },
                    mountZoomFactor = {
                        type = "range",
                        name = (L["MOUNT_ZOOM_FACTOR"] or "Mount Zoom") .. " (Yards)",
                        desc = L["MOUNT_ZOOM_FACTOR_DESC"],
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("mountZoomFactor") end,
                        set = function(_, val) SetOption("mountZoomFactor", val) end,
                        order = 22,
                        disabled = function() return not GetOption("autoMountZoom") end
                    },

                    delayHeader = { type = "header", name = "Transition Delay", order = 30 },
                    dismountDelay = {
                        type = "range",
                        name = L["DISMOUNT_DELAY"],
                        desc = L["DISMOUNT_DELAY_DESC"],
                        min = 0,
                        max = 10,
                        step = 0.5,
                        get = function() return GetOption("dismountDelay") end,
                        set = function(_, val) SetOption("dismountDelay", val) end,
                        order = 31,
                        disabled = function() return not (GetOption("autoCombatZoom") or GetOption("autoMountZoom")) end
                    },
                },
            },

            -- Advanced
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
                        order = 1
                    },
                    indirectVis = {
                        type = "toggle",
                        name = L["INDIRECT_VISIBILITY"],
                        desc = L["INDIRECT_VISIBILITY_DESC"],
                        get = function() return GetOption("cameraIndirectVisibility") end,
                        set = function(_, val) SetOption("cameraIndirectVisibility", val) end,
                        order = 2
                    },

                    -- Retail-only, and only if CVAR exists
                    resampleAlwaysSharpen = {
                        type = "toggle",
                        name = L["RESAMPLE_ALWAYS_SHARPEN"],
                        desc = L["RESAMPLE_ALWAYS_SHARPEN_DESC"],
                        hidden = function() return not SupportsFSRSharpen() end,
                        get = function() return GetOption("resampleAlwaysSharpen") end,
                        set = function(_, val) SetOption("resampleAlwaysSharpen", val) end,
                        order = 3
                    },

                    softTargetInteract = {
                        type = "toggle",
                        name = L["SOFT_TARGET_INTERACT"],
                        desc = L["SOFT_TARGET_INTERACT_DESC"],
                        hidden = function() return not SupportsSoftTargetIcons() end,
                        get = function() return GetOption("softTargetInteract") end,
                        set = function(_, val) SetOption("softTargetInteract", val) end,
                        order = 4
                    },
                },
            },

            -- Extra
            extraFeatures = {
                type = "group",
                name = L["EXTRA_FEATURES"],
                order = 5,
                args = {
                    clearTrackerBtn = {
                        type = "execute",
                        name = L["UNTRACK_QUESTS_BUTTON"],
                        desc = L["UNTRACK_QUESTS_DESC"],
                        func = function()
                            if ns.Functions and ns.Functions.ClearAllQuestTracking then
                                ns.Functions:ClearAllQuestTracking()
                            end
                        end,
                        order = 0.5,
                        width = "full",
                        hidden = function() return not hasQuestWatch end,
                    },

                    -- ActionCam: show ONLY if the client has the CVars
                    actionCamHeader = {
                        type = "header",
                        name = L["ACTION_CAM_HEADER"],
                        order = 1,
                        hidden = function() return not SupportsActionCam() end,
                    },
                    descActionCam = {
                        type = "description",
                        name = L["ACTION_CAM_DESC"],
                        order = 2,
                        hidden = function() return not SupportsActionCam() end,
                    },
                    enableShoulder = {
                        type = "toggle",
                        name = L["ACTION_CAM_SHOULDER_NAME"],
                        desc = L["ACTION_CAM_SHOULDER_DESC"],
                        hidden = function() return not HasCVar("test_cameraOverShoulder") end,
                        get = function() return GetOption("actionCamShoulder") end,
                        set = function(_, val) SetOption("actionCamShoulder", val) end,
                        order = 3
                    },
                    enableDynamicPitch = {
                        type = "toggle",
                        name = L["ACTION_CAM_PITCH_NAME"],
                        desc = L["ACTION_CAM_PITCH_DESC"],
                        hidden = function() return not HasCVar("test_cameraDynamicPitch") end,
                        get = function() return GetOption("actionCamPitch") end,
                        set = function(_, val) SetOption("actionCamPitch", val) end,
                        order = 4
                    },

                    afkHeader = { type = "header", name = L["AFK_MODE_HEADER"], order = 10 },
                    descAFK = { type = "description", name = L["AFK_MODE_DESC_SAFE"], order = 10.5 },
                    enableAFK = {
                        type = "toggle",
                        name = L["AFK_MODE_ENABLE"],
                        desc = L["AFK_MODE_ENABLE_DESC"],
                        get = function() return GetOption("afkMode") end,
                        set = function(_, val) SetOption("afkMode", val) end,
                        order = 11
                    },
                }
            },

            -- Debug
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
                        set = function(_, val)
                            SetOption("enableDebugLogging", val)
                            local db = GetDB()
                            if db then EnsureDebugLevelTable(db) end
                        end,
                        order = 1
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
                            local db = GetDB()
                            if not db then return false end
                            EnsureDebugLevelTable(db)
                            return db.debugLevel[key]
                        end,
                        set = function(_, key, val)
                            local db = GetDB()
                            if not db then return end
                            EnsureDebugLevelTable(db)
                            db.debugLevel[key] = val
                        end,
                        disabled = function()
                            return not GetOption("enableDebugLogging")
                        end,
                        order = 2
                    }
                }
            }
        }
    }

    AceConfig:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName, "Max Camera Distance")
end

-- =====================================================================
-- BLIZZARD SETTINGS HOOK (Retail only, Dragonflight+ UI)
-- =====================================================================
if IS_RETAIL
   and SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList
   and SettingsPanel.Container.SettingsList.ScrollBox
   and hooksecurefunc then

    local MOUSE_LOOK_SPEED = _G.MOUSE_LOOK_SPEED
    local CONTROLS_LABEL = _G.CONTROLS_LABEL

    hooksecurefunc(SettingsPanel.Container.SettingsList.ScrollBox, "Update", function(self)
        local header = SettingsPanel.Container.SettingsList.Header
        if not header or not header.Title or not header.Title.GetText then return end

        local headerText = header.Title:GetText()
        if headerText ~= CONTROLS_LABEL then return end

        local scrollTarget = SettingsPanel.Container.SettingsList.ScrollBox.ScrollTarget
        if not scrollTarget or not scrollTarget.GetChildren then return end

        local children = { scrollTarget:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.Text and child.Text.GetText and (child.Text:GetText() == MOUSE_LOOK_SPEED) then
                local slider = child.SliderWithSteppers or child.Slider
                if slider then
                    if slider.SetEnabled then
                        slider:SetEnabled(false)
                    elseif slider.SetEnabled_ then
                        slider:SetEnabled_(false)
                    end

                    if slider.Slider and slider.Slider.SetScript then
                        slider.Slider:SetScript("OnEnter", function(s)
                            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                            GameTooltip:SetText(L["HOOK_DISABLED_BY_ADDON"])
                            GameTooltip:AddLine(L["HOOK_MOUSE_SPEED_DESC"], 1, 1, 1)
                            GameTooltip:AddLine(L["HOOK_MOUSE_SPEED_PATH"], 1, 0.82, 0)
                            GameTooltip:Show()
                        end)

                        slider.Slider:SetScript("OnLeave", function()
                            GameTooltip:Hide()
                        end)
                    end
                end
                break
            end
        end
    end)
end