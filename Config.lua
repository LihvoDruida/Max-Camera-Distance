local addonName, ns = ...
ns.Config = ns.Config or {}
local Config = ns.Config

-- Libs
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true) or {}
local AceConfig = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)

local Compat = ns.Compat or {}
local IS_RETAIL = Compat.IS_RETAIL and true or false
local HasCVar = Compat.HasCVar or function() return false end
local SupportsFSRSharpen = Compat.SupportsFSRSharpen or function() return false end
local SupportsSoftTargetIcons = Compat.SupportsSoftTargetIcons or function() return false end
local SupportsActionCam = Compat.SupportsActionCam or function() return false end
local SupportsScenarioZone = Compat.SupportsScenarioZone or function() return IS_RETAIL end
local versionNumber = (Compat.GetAddonVersion and Compat.GetAddonVersion()) or "Dev"
local clientTag = Compat.CLIENT_TAG or (IS_RETAIL and "Retail" or "Classic")

-- =====================================================================
-- SAFE HELPERS
-- =====================================================================
local function SafeReload()
    if Compat.SafeReload then
        Compat.SafeReload()
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

    local shouldApplyNow = true
    if ns.Functions and ns.Functions.ShouldApplyOptionImmediately then
        shouldApplyNow = ns.Functions:ShouldApplyOptionImmediately(key)
    end

    if shouldApplyNow then
        ApplyNow()
    end
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
    local maxDistance = defaults.MAX_POSSIBLE_DISTANCE or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
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
                        .. " |cff00ff00(" .. clientTag .. ")|r"
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

                    combatHeader = { type = "header", name = L["COMBAT_HEADER"], order = 10 },

                    autoCombatZoom = {
                        type = "toggle",
                        name = L["AUTO_ZOOM_COMBAT"],
                        desc = L["AUTO_ZOOM_COMBAT_DESC"],
                        get = function() return GetOption("autoCombatZoom") end,
                        set = function(_, val) SetOption("autoCombatZoom", val) end,
                        order = 11,
                        width = "full",
                    },

                    worldCombatZoom = {
                        type = "range",
                        name = (L["WORLD_COMBAT_ZOOM_FACTOR"] or "Open World Combat Distance") .. " (Yards)",
                        desc = L["WORLD_COMBAT_ZOOM_FACTOR_DESC"],
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("worldCombatZoomFactor") end,
                        set = function(_, val) SetOption("worldCombatZoomFactor", val) end,
                        order = 12,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    groupCombatZoom = {
                        type = "range",
                        name = (L["GROUP_COMBAT_ZOOM_FACTOR"] or "Raid / Party Combat Distance") .. " (Yards)",
                        desc = L["GROUP_COMBAT_ZOOM_FACTOR_DESC"],
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("groupCombatZoomFactor") end,
                        set = function(_, val) SetOption("groupCombatZoomFactor", val) end,
                        order = 13,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    pvpCombatZoom = {
                        type = "range",
                        name = (L["PVP_COMBAT_ZOOM_FACTOR"] or "PvP Combat Distance") .. " (Yards)",
                        desc = L["PVP_COMBAT_ZOOM_FACTOR_DESC"],
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("pvpCombatZoomFactor") end,
                        set = function(_, val) SetOption("pvpCombatZoomFactor", val) end,
                        order = 14,
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
                        order = 15,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    zoneWorldBoss = {
                        type = "toggle",
                        name = L["ZONE_WORLD_BOSS"],
                        desc = L["ZONE_WORLD_BOSS_DESC"],
                        order = 16,
                        width = "full",
                        get = function() return GetOption("zoneWorldBoss") end,
                        set = function(_, v) SetOption("zoneWorldBoss", v) end,
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

                    delayHeader = { type = "header", name = L["DELAY_HEADER"], order = 30 },
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
                    enableShoulderInCombat = {
                        type = "toggle",
                        name = L["ACTION_CAM_SHOULDER_IN_COMBAT_NAME"],
                        desc = L["ACTION_CAM_SHOULDER_IN_COMBAT_DESC"],
                        hidden = function() return not HasCVar("test_cameraOverShoulder") end,
                        get = function() return GetOption("actionCamShoulderInCombat") end,
                        set = function(_, val) SetOption("actionCamShoulderInCombat", val) end,
                        order = 3
                    },
                    enableShoulderOutOfCombat = {
                        type = "toggle",
                        name = L["ACTION_CAM_SHOULDER_OUT_OF_COMBAT_NAME"],
                        desc = L["ACTION_CAM_SHOULDER_OUT_OF_COMBAT_DESC"],
                        hidden = function() return not HasCVar("test_cameraOverShoulder") end,
                        get = function() return GetOption("actionCamShoulderOutOfCombat") end,
                        set = function(_, val) SetOption("actionCamShoulderOutOfCombat", val) end,
                        order = 4
                    },
                    enableDynamicPitch = {
                        type = "toggle",
                        name = L["ACTION_CAM_PITCH_NAME"],
                        desc = L["ACTION_CAM_PITCH_DESC"],
                        hidden = function() return not HasCVar("test_cameraDynamicPitch") end,
                        get = function() return GetOption("actionCamPitch") end,
                        set = function(_, val) SetOption("actionCamPitch", val) end,
                        order = 5
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

    if not AceConfig then
        print(addonName .. ": AceConfig-3.0 not found.")
        return
    end

    AceConfig:RegisterOptionsTable(addonName, options)

    if AceConfigDialog and AceConfigDialog.AddToBlizOptions then
        AceConfigDialog:AddToBlizOptions(addonName, "Max Camera Distance")
    end
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