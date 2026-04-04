local addonName, ns = ...
ns.Config = ns.Config or {}
local Config = ns.Config

-- Libs
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true) or {}
local AceConfig = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceDBOptions = LibStub("AceDBOptions-3.0", true)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)

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

local function GetDatabaseObject()
    return (ns.Database and ns.Database.db) or nil
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

    Config:NotifyChange()
end

local function GetOption(key)
    local db = GetDB()
    if not db then return nil end
    return db[key]
end

function Config:NotifyChange()
    if AceConfigRegistry and AceConfigRegistry.NotifyChange then
        AceConfigRegistry:NotifyChange(addonName)
    end
end

local function BoolText(value)
    return value and (L["STATUS_YES"] or "Yes") or (L["STATUS_NO"] or "No")
end

local function StateText(value)
    if value == "combat" then return L["STATUS_STATE_COMBAT"] or "Combat" end
    if value == "mount" then return L["STATUS_STATE_MOUNT"] or "Mount" end
    return L["STATUS_STATE_NONE"] or "None"
end

local function ContextText(value)
    if value == "raid" then return L["STATUS_CONTEXT_RAID"] or "Raid" end
    if value == "party" then return L["STATUS_CONTEXT_PARTY"] or "Party" end
    if value == "pvp" then return L["STATUS_CONTEXT_PVP"] or "PvP" end
    return L["STATUS_CONTEXT_WORLD"] or "World"
end

local function ZoneSourceText(value)
    if value == "raid" then return L["STATUS_ZONE_SOURCE_RAID"] or "Raid" end
    if value == "party" then return L["STATUS_ZONE_SOURCE_PARTY"] or "Party" end
    if value == "arena" then return L["STATUS_ZONE_SOURCE_ARENA"] or "Arena" end
    if value == "bg" then return L["STATUS_ZONE_SOURCE_BG"] or "Battleground" end
    if value == "scenario" then return L["STATUS_ZONE_SOURCE_SCENARIO"] or "Scenario / Delve" end
    return L["STATUS_ZONE_SOURCE_WORLD"] or "World"
end

local DistanceKeyText

local function BuildLiveStatusText()
    if not (ns.Functions and ns.Functions.GetStatusSnapshot) then
        return L["STATUS_UNAVAILABLE"] or "Live status is unavailable right now."
    end

    local snapshot = ns.Functions:GetStatusSnapshot()
    if not snapshot then
        return L["STATUS_UNAVAILABLE"] or "Live status is unavailable right now."
    end

    local distanceSourceLabel = L["PRESET_MANUAL"] or "Manual"
    if snapshot.targetSourceType == "preset" then
        local presetChoices = ns.Functions and ns.Functions.GetPresetChoices and ns.Functions:GetPresetChoices(snapshot.targetDistanceKey)
        distanceSourceLabel = (presetChoices and presetChoices[snapshot.targetPresetId]) or snapshot.targetPresetId or "preset"
    end

    return table.concat({
        string.format("%s: %s", L["STATUS_ZOOM_STATE"] or "Zoom State", StateText(snapshot.state)),
        string.format("%s: %s", L["STATUS_CONTEXT"] or "Resolved Context", ContextText(snapshot.resolvedContext)),
        string.format("%s: %s", L["STATUS_RAW_CONTEXT"] or "Raw Context", ContextText(snapshot.rawContext)),
        string.format("%s: %s", L["STATUS_ZONE_SOURCE"] or "Zone Source", ZoneSourceText(snapshot.zoneSource)),
        string.format("%s: %.1f", L["STATUS_TARGET_DISTANCE"] or "Target Distance", snapshot.targetYards or 0),
        string.format("%s: %s (%s)",
            L["STATUS_DISTANCE_SOURCE"] or "Distance Source",
            DistanceKeyText(snapshot.targetDistanceKey),
            distanceSourceLabel
        ),
        string.format("%s: %s", L["STATUS_WORLD_FALLBACK"] or "Using World Fallback", BoolText(snapshot.usedWorldFallback)),
        string.format("%s: %s=%s, %s=%s, %s=%s, %s=%s, %s=%s",
            L["STATUS_REASON_FLAGS"] or "Reason Flags",
            L["STATUS_REASON_PLAYER"] or "Player",
            BoolText(snapshot.playerInCombat),
            L["STATUS_REASON_GROUP"] or "Group",
            BoolText(snapshot.groupInCombat),
            L["STATUS_REASON_THREAT"] or "Threat",
            BoolText(snapshot.hasThreat),
            L["STATUS_REASON_MOUNTED"] or "Mounted",
            BoolText(snapshot.isMounted),
            L["STATUS_REASON_WORLD_BOSS"] or "World Boss",
            BoolText(snapshot.forceWorldBoss)
        ),
        string.format("%s: %s=%s, %s=%s, %s=%s, %s=%s, %s=%s, %s=%s",
            L["STATUS_ZONE_FLAGS"] or "Zone Flags",
            L["ZONE_PARTY"] or "Dungeons",
            BoolText(snapshot.zoneFlags and snapshot.zoneFlags.party),
            L["ZONE_RAID"] or "Raids",
            BoolText(snapshot.zoneFlags and snapshot.zoneFlags.raid),
            L["ZONE_ARENA"] or "Arenas",
            BoolText(snapshot.zoneFlags and snapshot.zoneFlags.arena),
            L["ZONE_BG"] or "Battlegrounds",
            BoolText(snapshot.zoneFlags and snapshot.zoneFlags.bg),
            L["ZONE_SCENARIO"] or "Scenarios / Delves",
            BoolText(snapshot.zoneFlags and snapshot.zoneFlags.scenario),
            L["ZONE_WORLD_BOSS"] or "World Bosses / Events",
            BoolText(snapshot.zoneFlags and snapshot.zoneFlags.worldBoss)
        )
    }, "\n")
end


local PRESET_DISTANCE_KEYS = {
    maxZoomFactor = true,
    minZoomFactor = true,
    mountZoomFactor = true,
    worldCombatZoomFactor = true,
    partyCombatZoomFactor = true,
    raidCombatZoomFactor = true,
    pvpCombatZoomFactor = true,
}

local function GetPresetChoices(distanceKey)
    if ns.Functions and ns.Functions.GetPresetChoices then
        return ns.Functions:GetPresetChoices(distanceKey)
    end
    return {
        manual = L["PRESET_MANUAL"] or "Manual",
    }
end

local function GetControlSnapshot(distanceKey)
    if ns.Functions and ns.Functions.GetDistanceControlSnapshot then
        return ns.Functions:GetDistanceControlSnapshot(distanceKey)
    end
    local db = GetDB()
    if not db then return nil end
    return {
        distanceKey = distanceKey,
        manualValue = db[distanceKey],
        effectiveValue = db[distanceKey],
        sourceType = "manual",
        presetId = "manual",
        isManual = true,
    }
end

local function GetPresetBindingKey(distanceKey)
    if ns.Functions and ns.Functions.GetPresetBindingKey then
        return ns.Functions:GetPresetBindingKey(distanceKey)
    end
    local mapping = {
        maxZoomFactor = "manualMaxPreset",
        minZoomFactor = "normalZoomPreset",
        mountZoomFactor = "mountZoomPreset",
        worldCombatZoomFactor = "worldCombatPreset",
        partyCombatZoomFactor = "partyCombatPreset",
        raidCombatZoomFactor = "raidCombatPreset",
        pvpCombatZoomFactor = "pvpCombatPreset",
    }
    return mapping[distanceKey]
end

local function GetPresetSelectValue(distanceKey)
    local db = GetDB()
    if not db then return "manual" end
    local presetKey = GetPresetBindingKey(distanceKey)
    return (presetKey and db[presetKey]) or "manual"
end

local function SetPresetSelectValue(distanceKey, presetId)
    local db = GetDB()
    if not db then return end
    local presetKey = GetPresetBindingKey(distanceKey)
    if not presetKey then return end
    SetOption(presetKey, presetId)
end

local function BuildPresetStatusText(distanceKey)
    local snapshot = GetControlSnapshot(distanceKey)
    if not snapshot then
        return L["PRESET_STATUS_UNAVAILABLE"] or "Preset status is unavailable."
    end

    if snapshot.isManual then
        return string.format(
            L["PRESET_STATUS_MANUAL"] or "Manual control is active. Slider value: %.1f yd.",
            snapshot.manualValue or 0
        )
    end

    local choices = GetPresetChoices(distanceKey)
    local presetLabel = choices[snapshot.presetId] or snapshot.presetId or (L["PRESET_UNKNOWN"] or "Unknown")
    return string.format(
        L["PRESET_STATUS_LOCKED"] or "Preset: %s. Effective distance: %.1f yd. Matching manual control is locked until you switch back to Manual.",
        presetLabel,
        snapshot.effectiveValue or 0
    )
end

local function IsManualControlLocked(distanceKey)
    local snapshot = GetControlSnapshot(distanceKey)
    return snapshot and not snapshot.isManual or false
end

local function BuildRangeDesc(baseDesc, distanceKey)
    local statusText = BuildPresetStatusText(distanceKey)
    if baseDesc and baseDesc ~= "" then
        return baseDesc .. "\n\n" .. statusText
    end
    return statusText
end

DistanceKeyText = function(distanceKey)
    if distanceKey == "maxZoomFactor" then return L["MAX_ZOOM_FACTOR"] or "Max Zoom" end
    if distanceKey == "minZoomFactor" then return L["MIN_COMBAT_ZOOM_FACTOR"] or "Normal Distance" end
    if distanceKey == "mountZoomFactor" then return L["MOUNT_ZOOM_FACTOR"] or "Mount Distance" end
    if distanceKey == "worldCombatZoomFactor" then return L["WORLD_COMBAT_ZOOM_FACTOR"] or "Open World Combat Distance" end
    if distanceKey == "partyCombatZoomFactor" then return L["PARTY_COMBAT_ZOOM_FACTOR"] or "Party Combat Distance" end
    if distanceKey == "raidCombatZoomFactor" then return L["RAID_COMBAT_ZOOM_FACTOR"] or "Raid Combat Distance" end
    if distanceKey == "pvpCombatZoomFactor" then return L["PVP_COMBAT_ZOOM_FACTOR"] or "PvP Combat Distance" end
    return distanceKey or "-"
end

-- =====================================================================
-- OPTIONS
-- =====================================================================
function Config:SetupOptions()
    if not ns.Database or not ns.Database.db then return end
    local defaults = ns.Database.DEFAULTS

    local maxDistance = defaults.MAX_POSSIBLE_DISTANCE or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
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

                            if ns.Core and ns.Core.RefreshMinimapButton then
                                ns.Core:RefreshMinimapButton()
                            end
                        end,
                    },
                },
            },

            generalSettings = {
                type = "group",
                name = L["GENERAL_SETTINGS"],
                inline = false,
                order = 2,
                args = {
                    manualHeader = {
                        type = "header",
                        name = L["MANUAL_SECTION_HEADER"] or "Manual Camera Controls",
                        order = 1,
                    },
                    manualDesc = {
                        type = "description",
                        name = L["MANUAL_SECTION_DESC"] or "Manual controls stay available only when the matching preset is set to Manual.",
                        order = 2,
                    },
                    maxZoomFactor = {
                        type = "range",
                        name = (L["MAX_ZOOM_FACTOR"] or "Max Zoom") .. " (Yards)",
                        desc = function() return BuildRangeDesc(L["MAX_ZOOM_FACTOR_DESC"], "maxZoomFactor") end,
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("maxZoomFactor") end,
                        set = function(_, val) SetOption("maxZoomFactor", val) end,
                        order = 10,
                        disabled = function() return GetOption("autoCombatZoom") or IsManualControlLocked("maxZoomFactor") end,
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
                        order = 20,
                    },
                    moveViewDistance = {
                        type = "range",
                        name = L["MOVE_VIEW_DISTANCE"],
                        desc = L["MOVE_VIEW_DISTANCE_DESC"],
                        min = 1,
                        max = 50,
                        step = 1,
                        get = function() return GetOption("moveViewDistance") end,
                        set = function(_, val) SetOption("moveViewDistance", val) end,
                        order = 30,
                    },
                    yawSpeed = {
                        type = "range",
                        name = L["YAW_MOVE_SPEED"],
                        desc = L["YAW_MOVE_SPEED_DESC"],
                        min = 1,
                        max = 360,
                        step = 10,
                        get = function() return GetOption("cameraYawMoveSpeed") end,
                        set = function(_, val) SetOption("cameraYawMoveSpeed", val) end,
                        order = 40,
                    },
                    pitchSpeed = {
                        type = "range",
                        name = L["PITCH_MOVE_SPEED"],
                        desc = L["PITCH_MOVE_SPEED_DESC"],
                        min = 1,
                        max = 360,
                        step = 10,
                        get = function() return GetOption("cameraPitchMoveSpeed") end,
                        set = function(_, val) SetOption("cameraPitchMoveSpeed", val) end,
                        order = 50,
                    },
                },
            },

            presetSettings = {
                type = "group",
                name = L["PRESET_SETTINGS"] or "Presets",
                order = 3,
                args = {
                    presetHeader = {
                        type = "header",
                        name = L["PRESET_SECTION_HEADER"] or "Distance Presets",
                        order = 1,
                    },
                    presetDesc = {
                        type = "description",
                        name = L["PRESET_SECTION_DESC"] or "Presets convert high-level choices into real distances. If a preset other than Manual is selected, the matching slider is locked automatically.",
                        order = 2,
                    },
                    manualPresetHeader = {
                        type = "header",
                        name = L["PRESET_MANUAL_GROUP_HEADER"] or "Manual / Normal",
                        order = 10,
                    },
                    manualMaxPreset = {
                        type = "select",
                        name = L["MANUAL_MAX_PRESET"] or "Manual Max Distance Preset",
                        desc = function() return BuildPresetStatusText("maxZoomFactor") end,
                        values = function() return GetPresetChoices("maxZoomFactor") end,
                        get = function() return GetPresetSelectValue("maxZoomFactor") end,
                        set = function(_, value) SetPresetSelectValue("maxZoomFactor", value) end,
                        order = 11,
                    },
                    manualMaxPresetInfo = {
                        type = "description",
                        name = function() return BuildPresetStatusText("maxZoomFactor") end,
                        order = 12,
                    },
                    normalZoomPreset = {
                        type = "select",
                        name = L["NORMAL_ZOOM_PRESET"] or "Normal Distance Preset",
                        desc = function() return BuildPresetStatusText("minZoomFactor") end,
                        values = function() return GetPresetChoices("minZoomFactor") end,
                        get = function() return GetPresetSelectValue("minZoomFactor") end,
                        set = function(_, value) SetPresetSelectValue("minZoomFactor", value) end,
                        order = 13,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    normalZoomPresetInfo = {
                        type = "description",
                        name = function() return BuildPresetStatusText("minZoomFactor") end,
                        order = 14,
                        hidden = function() return not GetOption("autoCombatZoom") end,
                    },
                    combatPresetHeader = {
                        type = "header",
                        name = L["PRESET_COMBAT_GROUP_HEADER"] or "Combat Presets",
                        order = 20,
                    },
                    worldCombatPreset = {
                        type = "select",
                        name = L["WORLD_COMBAT_PRESET"] or "Open World Combat Preset",
                        desc = function() return BuildPresetStatusText("worldCombatZoomFactor") end,
                        values = function() return GetPresetChoices("worldCombatZoomFactor") end,
                        get = function() return GetPresetSelectValue("worldCombatZoomFactor") end,
                        set = function(_, value) SetPresetSelectValue("worldCombatZoomFactor", value) end,
                        order = 21,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    worldCombatPresetInfo = { type = "description", name = function() return BuildPresetStatusText("worldCombatZoomFactor") end, order = 22, hidden = function() return not GetOption("autoCombatZoom") end },
                    partyCombatPreset = {
                        type = "select",
                        name = L["PARTY_COMBAT_PRESET"] or "Party Combat Preset",
                        desc = function() return BuildPresetStatusText("partyCombatZoomFactor") end,
                        values = function() return GetPresetChoices("partyCombatZoomFactor") end,
                        get = function() return GetPresetSelectValue("partyCombatZoomFactor") end,
                        set = function(_, value) SetPresetSelectValue("partyCombatZoomFactor", value) end,
                        order = 23,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    partyCombatPresetInfo = { type = "description", name = function() return BuildPresetStatusText("partyCombatZoomFactor") end, order = 24, hidden = function() return not GetOption("autoCombatZoom") end },
                    raidCombatPreset = {
                        type = "select",
                        name = L["RAID_COMBAT_PRESET"] or "Raid Combat Preset",
                        desc = function() return BuildPresetStatusText("raidCombatZoomFactor") end,
                        values = function() return GetPresetChoices("raidCombatZoomFactor") end,
                        get = function() return GetPresetSelectValue("raidCombatZoomFactor") end,
                        set = function(_, value) SetPresetSelectValue("raidCombatZoomFactor", value) end,
                        order = 25,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    raidCombatPresetInfo = { type = "description", name = function() return BuildPresetStatusText("raidCombatZoomFactor") end, order = 26, hidden = function() return not GetOption("autoCombatZoom") end },
                    pvpCombatPreset = {
                        type = "select",
                        name = L["PVP_COMBAT_PRESET"] or "PvP Combat Preset",
                        desc = function() return BuildPresetStatusText("pvpCombatZoomFactor") end,
                        values = function() return GetPresetChoices("pvpCombatZoomFactor") end,
                        get = function() return GetPresetSelectValue("pvpCombatZoomFactor") end,
                        set = function(_, value) SetPresetSelectValue("pvpCombatZoomFactor", value) end,
                        order = 27,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    pvpCombatPresetInfo = { type = "description", name = function() return BuildPresetStatusText("pvpCombatZoomFactor") end, order = 28, hidden = function() return not GetOption("autoCombatZoom") end },
                    mountPresetHeader = {
                        type = "header",
                        name = L["PRESET_MOUNT_GROUP_HEADER"] or "Mount / Travel",
                        order = 30,
                    },
                    mountZoomPreset = {
                        type = "select",
                        name = L["MOUNT_ZOOM_PRESET"] or "Mount Distance Preset",
                        desc = function() return BuildPresetStatusText("mountZoomFactor") end,
                        values = function() return GetPresetChoices("mountZoomFactor") end,
                        get = function() return GetPresetSelectValue("mountZoomFactor") end,
                        set = function(_, value) SetPresetSelectValue("mountZoomFactor", value) end,
                        order = 31,
                        disabled = function() return not GetOption("autoMountZoom") end,
                    },
                    mountZoomPresetInfo = { type = "description", name = function() return BuildPresetStatusText("mountZoomFactor") end, order = 32, hidden = function() return not GetOption("autoMountZoom") end },
                },
            },

            smartSettings = {
                type = "group",
                name = L["COMBAT_SETTINGS"],
                inline = false,
                order = 4,
                args = {
                    desc = { type = "description", name = L["COMBAT_SETTINGS_WARNING"], order = 1 },
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
                    zoneHeader = {
                        type = "header",
                        name = L["ZONE_CONTEXT_HEADER"] or "Context Rules",
                        order = 20,
                    },
                    zoneDesc = {
                        type = "description",
                        name = L["ZONE_CONTEXT_DESC"] or "These toggles decide whether party / raid / PvP content should use their own combat preset or fall back to the open-world combat distance.",
                        order = 21,
                    },
                    zoneParty = {
                        type = "toggle",
                        name = L["ZONE_PARTY"],
                        desc = L["ZONE_PARTY_DESC"],
                        order = 22,
                        get = function() return GetOption("zoneParty") end,
                        set = function(_, v) SetOption("zoneParty", v) end,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    zoneRaid = {
                        type = "toggle",
                        name = L["ZONE_RAID"],
                        desc = L["ZONE_RAID_DESC"],
                        order = 23,
                        get = function() return GetOption("zoneRaid") end,
                        set = function(_, v) SetOption("zoneRaid", v) end,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    zoneArena = {
                        type = "toggle",
                        name = L["ZONE_ARENA"],
                        desc = L["ZONE_ARENA_DESC"],
                        order = 24,
                        get = function() return GetOption("zoneArena") end,
                        set = function(_, v) SetOption("zoneArena", v) end,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    zoneBg = {
                        type = "toggle",
                        name = L["ZONE_BG"],
                        desc = L["ZONE_BG_DESC"],
                        order = 25,
                        get = function() return GetOption("zoneBg") end,
                        set = function(_, v) SetOption("zoneBg", v) end,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    zoneScenario = {
                        type = "toggle",
                        name = L["ZONE_SCENARIO"],
                        desc = L["ZONE_SCENARIO_DESC"],
                        order = 26,
                        hidden = function() return not SupportsScenarioZone() end,
                        get = function() return GetOption("zoneScenario") end,
                        set = function(_, v) SetOption("zoneScenario", v) end,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    zoneWorldBoss = {
                        type = "toggle",
                        name = L["ZONE_WORLD_BOSS"],
                        desc = L["ZONE_WORLD_BOSS_DESC"],
                        order = 27,
                        width = "full",
                        get = function() return GetOption("zoneWorldBoss") end,
                        set = function(_, v) SetOption("zoneWorldBoss", v) end,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    manualCombatHeader = {
                        type = "header",
                        name = L["MANUAL_COMBAT_HEADER"] or "Manual Distances",
                        order = 40,
                    },
                    manualCombatDesc = {
                        type = "description",
                        name = L["MANUAL_COMBAT_DESC"] or "These sliders are used only when their matching preset is set to Manual.",
                        order = 41,
                    },
                    worldCombatZoom = {
                        type = "range",
                        name = (L["WORLD_COMBAT_ZOOM_FACTOR"] or "Open World Combat Distance") .. " (Yards)",
                        desc = function() return BuildRangeDesc(L["WORLD_COMBAT_ZOOM_FACTOR_DESC"], "worldCombatZoomFactor") end,
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("worldCombatZoomFactor") end,
                        set = function(_, val) SetOption("worldCombatZoomFactor", val) end,
                        order = 42,
                        disabled = function() return not GetOption("autoCombatZoom") or IsManualControlLocked("worldCombatZoomFactor") end,
                    },
                    partyCombatZoom = {
                        type = "range",
                        name = (L["PARTY_COMBAT_ZOOM_FACTOR"] or "Party Combat Distance") .. " (Yards)",
                        desc = function() return BuildRangeDesc(L["PARTY_COMBAT_ZOOM_FACTOR_DESC"], "partyCombatZoomFactor") end,
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("partyCombatZoomFactor") end,
                        set = function(_, val) SetOption("partyCombatZoomFactor", val) end,
                        order = 43,
                        disabled = function() return not GetOption("autoCombatZoom") or IsManualControlLocked("partyCombatZoomFactor") end,
                    },
                    raidCombatZoom = {
                        type = "range",
                        name = (L["RAID_COMBAT_ZOOM_FACTOR"] or "Raid Combat Distance") .. " (Yards)",
                        desc = function() return BuildRangeDesc(L["RAID_COMBAT_ZOOM_FACTOR_DESC"], "raidCombatZoomFactor") end,
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("raidCombatZoomFactor") end,
                        set = function(_, val) SetOption("raidCombatZoomFactor", val) end,
                        order = 44,
                        disabled = function() return not GetOption("autoCombatZoom") or IsManualControlLocked("raidCombatZoomFactor") end,
                    },
                    pvpCombatZoom = {
                        type = "range",
                        name = (L["PVP_COMBAT_ZOOM_FACTOR"] or "PvP Combat Distance") .. " (Yards)",
                        desc = function() return BuildRangeDesc(L["PVP_COMBAT_ZOOM_FACTOR_DESC"], "pvpCombatZoomFactor") end,
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("pvpCombatZoomFactor") end,
                        set = function(_, val) SetOption("pvpCombatZoomFactor", val) end,
                        order = 45,
                        disabled = function() return not GetOption("autoCombatZoom") or IsManualControlLocked("pvpCombatZoomFactor") end,
                    },
                    combatMinZoom = {
                        type = "range",
                        name = (L["MIN_COMBAT_ZOOM_FACTOR"] or "Normal Distance") .. " (Yards)",
                        desc = function() return BuildRangeDesc(L["MIN_COMBAT_ZOOM_FACTOR_DESC"], "minZoomFactor") end,
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("minZoomFactor") end,
                        set = function(_, val) SetOption("minZoomFactor", val) end,
                        order = 46,
                        disabled = function() return not GetOption("autoCombatZoom") or IsManualControlLocked("minZoomFactor") end,
                    },
                    mountHeader = { type = "header", name = L["MOUNT_SETTINGS_HEADER"], order = 60 },
                    autoMountZoom = {
                        type = "toggle",
                        name = L["AUTO_MOUNT_ZOOM"],
                        desc = L["AUTO_MOUNT_ZOOM_DESC"],
                        get = function() return GetOption("autoMountZoom") end,
                        set = function(_, val) SetOption("autoMountZoom", val) end,
                        order = 61,
                        width = "full"
                    },
                    mountZoomFactor = {
                        type = "range",
                        name = (L["MOUNT_ZOOM_FACTOR"] or "Mount Zoom") .. " (Yards)",
                        desc = function() return BuildRangeDesc(L["MOUNT_ZOOM_FACTOR_DESC"], "mountZoomFactor") end,
                        min = 1.0,
                        max = maxDistance,
                        step = 1.0,
                        get = function() return GetOption("mountZoomFactor") end,
                        set = function(_, val) SetOption("mountZoomFactor", val) end,
                        order = 62,
                        disabled = function() return not GetOption("autoMountZoom") or IsManualControlLocked("mountZoomFactor") end
                    },
                    delayHeader = { type = "header", name = L["DELAY_HEADER"], order = 80 },
                    dismountDelay = {
                        type = "range",
                        name = L["DISMOUNT_DELAY"],
                        desc = L["DISMOUNT_DELAY_DESC"],
                        min = 0,
                        max = 10,
                        step = 0.5,
                        get = function() return GetOption("dismountDelay") end,
                        set = function(_, val) SetOption("dismountDelay", val) end,
                        order = 81,
                        disabled = function() return not (GetOption("autoCombatZoom") or GetOption("autoMountZoom")) end
                    },
                },
            },

            advancedSettings = {
                type = "group",
                name = L["ADVANCED_SETTINGS"],
                order = 5,
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

            extraFeatures = {
                type = "group",
                name = L["EXTRA_FEATURES"],
                order = 6,
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

            debugSettings = {
                type = "group",
                name = L["DEBUG_SETTINGS"],
                order = 7,
                args = {
                    statusHeader = {
                        type = "header",
                        name = L["STATUS_HEADER"] or "Live Status",
                        order = 0,
                    },
                    statusDesc = {
                        type = "description",
                        name = L["STATUS_DESC"] or "Shows the current resolved zoom decision and why it was chosen.",
                        order = 0.1,
                    },
                    statusSnapshot = {
                        type = "description",
                        name = function()
                            return BuildLiveStatusText()
                        end,
                        fontSize = "medium",
                        order = 0.2,
                    },
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
            },

            profiles = {
                type = "group",
                name = L["PROFILES"] or "Profiles",
                order = 8,
                args = {}
            },
        }
    }

    local dbObject = GetDatabaseObject()
    if dbObject and AceDBOptions and AceDBOptions.GetOptionsTable then
        options.args.profiles = AceDBOptions:GetOptionsTable(dbObject)
        options.args.profiles.order = 8
        options.args.profiles.name = L["PROFILES"] or "Profiles"
    else
        options.args.profiles = {
            type = "group",
            name = L["PROFILES"] or "Profiles",
            args = {
                info = {
                    type = "description",
                    name = L["PROFILES_MISSING_LIB_DESC"] or "AceDBOptions-3.0 was not found, so advanced profile controls are unavailable.",
                    order = 1,
                },
            },
            order = 8,
        }
    end

    if not AceConfig then
        print(addonName .. ": AceConfig-3.0 not found.")
        return
    end

    AceConfig:RegisterOptionsTable(addonName, options)

    if AceConfigDialog and AceConfigDialog.AddToBlizOptions then
        AceConfigDialog:AddToBlizOptions(addonName, "Max Camera Distance")
        AceConfigDialog:AddToBlizOptions(addonName, L["PROFILES"] or "Profiles", addonName, "profiles")
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