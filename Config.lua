local addonName, ns = ...
local LibStub = _G.LibStub
ns.Config = ns.Config or {}
local Config = ns.Config

-- Libs

local L = setmetatable({}, {
    __index = function(_, key)
        if ns.Locale and ns.Locale.Get then
            return ns.Locale:Get(key)
        end
        local aceLocale = (LibStub and LibStub("AceLocale-3.0", true))
        local tbl = aceLocale and aceLocale:GetLocale(addonName, true)
        local value = tbl and tbl[key]
        if value ~= nil then
            return value
        end
        return key
    end,
})
local AceConfig = (LibStub and LibStub("AceConfig-3.0", true))
local AceConfigDialog = (LibStub and LibStub("AceConfigDialog-3.0", true))
local AceDBOptions = (LibStub and LibStub("AceDBOptions-3.0", true))
local AceConfigRegistry = (LibStub and LibStub("AceConfigRegistry-3.0", true))

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

local function GetLanguageChoices()
    if ns.Locale and ns.Locale.GetOptionsValues then
        return ns.Locale:GetOptionsValues()
    end
    return {
        client = "Client Default",
        enUS = "English",
        ukUA = "Українська",
        deDE = "Deutsch",
        frFR = "Français",
        zhCN = "简体中文",
    }
end

local function GetLanguageOption()
    local db = GetDB()
    if not db or type(db.language) ~= "string" then
        return "client"
    end
    return db.language
end

local function SetLanguageOption(value)
    local db = GetDB()
    if not db then return end

    local normalized = type(value) == "string" and value or "client"
    if ns.Locale and ns.Locale.SetOverride then
        ns.Locale:SetOverride(normalized)
    else
        db.language = normalized
    end

    Config:NotifyChange()
    SafeReload()
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

    if key == "afkMode"
        or key == "afkHideUI"
        or key == "afkDelay"
        or key == "afkDirection"
        or key == "afkRotationSpeed"
        or key == "afkSkipMounted"
        or key == "afkSkipFlying"
        or key == "afkResumeAfterCombat"
        or key == "afkZoomOut" then
        if ns.Functions and ns.Functions.RefreshAfkMode then
            ns.Functions:RefreshAfkMode(true)
        end
    elseif shouldApplyNow then
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
    if value == "afk" then return L["STATUS_STATE_AFK"] or "AFK" end
    if value == "dragonrace_first_person" then return L["STATUS_STATE_DRAGONRACE_FIRST_PERSON"] or "Dragon Race First Person" end
    if value == "combat" then return L["STATUS_STATE_COMBAT"] or "Combat" end
    if value == "mount" then return L["STATUS_STATE_MOUNT"] or "Mount" end
    if value == "normal" then return L["STATUS_STATE_NORMAL"] or "Normal" end
    if value == "manual" then return L["STATUS_STATE_MANUAL"] or "Manual" end
    return L["STATUS_STATE_NONE"] or "None"
end

local Contexts = ns.Contexts

-- Every activity carries its own localisation key and English fallback, so the
-- status line, the preset selector and the slider all read the same name.
local function ContextLabel(context)
    if not (Contexts and Contexts.Get) then
        return tostring(context or "-")
    end
    local def = Contexts:Get(context)
    return L[def.labelKey] or def.defaultLabel or context
end

local function ContextText(value)
    return ContextLabel(value)
end

local function MountZoomModeText(value)
    if value == "flying" then return L["MOUNT_ZOOM_MODE_FLYING"] or "Flying mounts only" end
    if value == "skyriding" then return L["MOUNT_ZOOM_MODE_SKYRIDING"] or "Skyriding only" end
    if value == "forms" then return L["MOUNT_ZOOM_MODE_FORMS"] or "Travel forms only" end
    return L["MOUNT_ZOOM_MODE_ALL"] or "All mounts and travel forms"
end

local function PendingReturnText(snapshot)
    if not snapshot or not snapshot.pendingReturnActive then
        return L["STATUS_PENDING_RETURN_NONE"] or "No delayed return is pending."
    end

    local contextText = snapshot.pendingReturnContext and ContextText(snapshot.pendingReturnContext) or (L["STATUS_STATE_NONE"] or "None")
    local delayText = snapshot.pendingReturnKind == "mount" and (L["STATUS_RETURN_KIND_MOUNT"] or "Mount Return") or (L["STATUS_RETURN_KIND_COMBAT"] or "Combat Return")
    return string.format(
        L["STATUS_PENDING_RETURN_ACTIVE"] or "%s: %s, %.1fs remaining (total %.1fs).",
        delayText,
        contextText,
        snapshot.pendingReturnRemaining or 0,
        snapshot.pendingReturnDelay or 0
    )
end

local DistanceKeyText

local function BuildCollisionSummaryText()
    local db = GetDB()
    if not db then
        return L["STATUS_UNAVAILABLE"] or "Live status is unavailable right now."
    end

    local enabledText = BoolText(db.cameraIndirectVisibility)
    local offsetText = string.format("%.1f", db.cameraIndirectOffset or 1.5)
    local silhouetteText = BoolText(db.occludedSilhouettePlayer)
    local smartPivotText = BoolText(db.reduceUnexpectedMovement)

    return string.format(
        L["COLLISION_SUMMARY_TEXT"] or "Reduced Camera Collision: %s\nCollision Sensitivity: %s\nShow Silhouette when Obstructed: %s\nReduce Unexpected Movement: %s\nThese settings are global and apply everywhere.",
        enabledText,
        offsetText,
        silhouetteText,
        smartPivotText
    )
end

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

    local triggerConfig = snapshot.triggerConfig or {}
    local activeTriggers = snapshot.activeTriggers or {}

    return table.concat({
        string.format("%s: %s", L["STATUS_ZOOM_STATE"] or "Zoom State", StateText(snapshot.state)),
        string.format("%s: %s", L["STATUS_CONTEXT"] or "Context", ContextText(snapshot.resolvedContext)),
        string.format("%s: %.1f", L["STATUS_TARGET_DISTANCE"] or "Target Distance", snapshot.targetYards or 0),
        string.format("%s: %s",
            L["STATUS_COLLISION_ENABLED"] or "Reduced Camera Collision",
            BoolText(snapshot.indirectCollisionEnabled)
        ),
        string.format("%s: %.1f",
            L["STATUS_COLLISION_OFFSET"] or "Collision Sensitivity",
            snapshot.indirectCollisionOffset or 0
        ),
        string.format("%s: %s",
            L["STATUS_SILHOUETTE"] or "Show Silhouette when Obstructed",
            BoolText(snapshot.occludedSilhouetteEnabled)
        ),
        string.format("%s: %s",
            L["STATUS_SMART_PIVOT"] or "Reduce Unexpected Movement",
            BoolText(snapshot.reduceUnexpectedMovement)
        ),
        string.format("%s: %s (%s)",
            L["STATUS_DISTANCE_SOURCE"] or "Distance Source",
            DistanceKeyText(snapshot.targetDistanceKey),
            distanceSourceLabel
        ),
        string.format("%s: %s=%s, %s=%s, %s=%s",
            L["STATUS_TRIGGER_RULES"] or "Trigger Rules",
            L["COMBAT_TRIGGER_PLAYER"] or "Self Combat",
            BoolText(triggerConfig.player),
            L["COMBAT_TRIGGER_GROUP"] or "Group Combat",
            BoolText(triggerConfig.group),
            L["COMBAT_TRIGGER_THREAT"] or "Threat Only",
            BoolText(triggerConfig.threat)
        ),
        string.format("%s: %s=%s, %s=%s, %s=%s, %s=%s",
            L["STATUS_ACTIVE_TRIGGERS"] or "Active Triggers",
            L["STATUS_REASON_PLAYER"] or "Player",
            BoolText(activeTriggers.player),
            L["STATUS_REASON_GROUP"] or "Group",
            BoolText(activeTriggers.group),
            L["STATUS_REASON_THREAT"] or "Threat",
            BoolText(activeTriggers.threat),
            L["STATUS_REASON_WORLD_BOSS"] or "World Boss",
            BoolText(activeTriggers.worldBoss)
        ),
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
        string.format("%s: %s",
            L["STATUS_MOUNT_MODE"] or "Mount Zoom Mode",
            MountZoomModeText(snapshot.mountZoomMode)
        ),
        string.format("%s: %s=%s, %s=%s, %s=%s, %s=%s",
            L["STATUS_TRAVEL_SIGNALS"] or "Travel Signals",
            L["STATUS_MOUNT_ZOOM_ACTIVE"] or "Mount Zoom Active",
            BoolText(snapshot.mountZoomActive),
            L["STATUS_FLYING_MOUNT"] or "Flying Mount",
            BoolText(snapshot.isFlyingMount),
            L["STATUS_SKYRIDING"] or "Skyriding",
            BoolText(snapshot.isSkyriding),
            L["STATUS_DRAGON_RACE"] or "Dragonriding Race",
            BoolText(snapshot.isDragonRacing)
        ),
        string.format("%s: %s",
            L["STATUS_DRAGON_RACE_FP"] or "Race First Person",
            BoolText(snapshot.dragonRacingFirstPerson)
        ),
        string.format("%s: %s=%s, %s=%s, %s=%s",
            L["STATUS_RUNTIME_GUARDS"] or "Runtime Guards",
            L["STATUS_STATE_AFK"] or "AFK",
            BoolText(snapshot.afkActive),
            L["STATUS_ACTIONCAM_SHOULDER"] or "ActionCam Shoulder",
            BoolText(snapshot.actionCamShoulderActive),
            L["STATUS_DYNAMIC_PITCH"] or "Dynamic Pitch",
            BoolText(snapshot.dynamicPitchActive)
        ),
        -- Only the delay for the activity the player is actually in, plus the
        -- mount delay. Listing all eight would push the useful lines off screen.
        string.format("%s: %s=%.1fs, %s=%.1fs",
            L["STATUS_RETURN_DELAYS"] or "Return Delays",
            ContextLabel(snapshot.resolvedContext),
            snapshot.activeReturnDelay or 0,
            L["STATUS_RETURN_KIND_MOUNT"] or "Mount Return",
            snapshot.mountReturnDelay or 0
        ),
        string.format("%s: %s",
            L["STATUS_PENDING_RETURN"] or "Pending Return",
            PendingReturnText(snapshot)
        ),
        string.format("%s: %s=%s, %s=%s, %s=%s",
            L["STATUS_DYNAMIC_BEHAVIOR"] or "Dynamic Behavior",
            L["ZOOM_RESTORE_SETTING"] or "Restore Zoom",
            tostring(snapshot.zoomRestoreSetting or "adaptive"),
            L["STATUS_STATE_MOUNT"] or "Mount",
            BoolText(snapshot.mountManualOverride),
            L["STATUS_STATE_COMBAT"] or "Combat",
            BoolText(snapshot.combatManualOverride)
        )
    }, "\n")
end


local PRESET_DISTANCE_KEYS = {
    maxZoomFactor = true,
    minZoomFactor = true,
    mountZoomFactor = true,
}

if Contexts and Contexts.DEFINITIONS then
    for _, def in pairs(Contexts.DEFINITIONS) do
        PRESET_DISTANCE_KEYS[def.distanceKey] = true
    end
end

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
    }
    if Contexts and Contexts.DEFINITIONS then
        for _, def in pairs(Contexts.DEFINITIONS) do
            mapping[def.distanceKey] = def.presetKey
        end
    end
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
    if Contexts and Contexts.DEFINITIONS then
        for id, def in pairs(Contexts.DEFINITIONS) do
            if def.distanceKey == distanceKey then
                return ContextLabel(id)
            end
        end
    end
    return distanceKey or "-"
end

-- =====================================================================
-- OPTIONS
-- =====================================================================

-- =====================================================================
-- PER-ACTIVITY OPTION ROWS
-- =====================================================================
-- The combat distance controls used to be four hand-written blocks per section
-- (preset select, manual slider, return delay). Splitting PvE and PvP into eight
-- activities would have meant twenty-four such blocks kept in sync by hand, so
-- they are generated from ns.Contexts instead. Adding an activity is now a
-- single entry in Contexts.lua.
--
-- Ordering: activities are emitted in taxonomy order (neutral, then PvP, then
-- PvE) and grouped under their own headers so PvP and PvE never interleave.
local CONTEXT_GROUP_HEADERS = {
    neutral = { labelKey = "CONTEXT_GROUP_NEUTRAL", fallback = "Outside Activities" },
    pvp = { labelKey = "CONTEXT_GROUP_PVP", fallback = "PvP" },
    pve = { labelKey = "CONTEXT_GROUP_PVE", fallback = "PvE" },
}

local CONTEXT_KIND_ORDER = { "neutral", "pvp", "pve" }

local function EachSupportedContext(callback)
    if not (Contexts and Contexts.ORDER) then return end

    for _, kind in ipairs(CONTEXT_KIND_ORDER) do
        local first = true
        for _, id in ipairs(Contexts.ORDER) do
            local def = Contexts.DEFINITIONS[id]
            if def.kind == kind and Contexts:IsSupported(id) then
                callback(id, def, first and kind or nil)
                first = false
            end
        end
    end
end

-- Returns the next free order. Callers MUST use it for anything that has to
-- appear after the generated rows: the number of activities is data, so a
-- hand-written order below the generated block will eventually land inside it.
-- That is exactly what happened when four combat contexts became eight - the
-- Normal Distance slider ended up rendered in the middle of the PvP group, and
-- the mount preset and dismount delay landed inside the PvE group.
local function InjectContextOptions(args, baseOrder, mode, maxDistance)
    local order = baseOrder

    EachSupportedContext(function(id, def, headerKind)
        if headerKind then
            local header = CONTEXT_GROUP_HEADERS[headerKind]
            args["ctxHeader_" .. mode .. "_" .. headerKind] = {
                type = "header",
                name = L[header.labelKey] or header.fallback,
                order = order,
            }
            order = order + 1
        end

        local label = ContextLabel(id)

        if mode == "preset" then
            local distanceKey = def.distanceKey
            args["ctxPreset_" .. id] = {
                type = "select",
                name = label,
                desc = function() return BuildPresetStatusText(distanceKey) end,
                values = function() return GetPresetChoices(distanceKey) end,
                get = function() return GetPresetSelectValue(distanceKey) end,
                set = function(_, value) SetPresetSelectValue(distanceKey, value) end,
                order = order,
                disabled = function() return not GetOption("autoCombatZoom") end,
            }
            order = order + 1
            args["ctxPresetInfo_" .. id] = {
                type = "description",
                name = function() return BuildPresetStatusText(distanceKey) end,
                order = order,
                hidden = function() return not GetOption("autoCombatZoom") end,
            }
            order = order + 1

        elseif mode == "slider" then
            local distanceKey = def.distanceKey
            args["ctxSlider_" .. id] = {
                type = "range",
                name = label .. " (Yards)",
                desc = function()
                    return BuildRangeDesc(L[def.labelKey .. "_DESC"], distanceKey)
                end,
                min = 1.0,
                max = maxDistance,
                step = 1.0,
                get = function() return GetOption(distanceKey) end,
                set = function(_, val) SetOption(distanceKey, val) end,
                order = order,
                disabled = function()
                    return not GetOption("autoCombatZoom") or IsManualControlLocked(distanceKey)
                end,
            }
            order = order + 1

        elseif mode == "delay" then
            local delayKey = def.delayKey
            args["ctxDelay_" .. id] = {
                type = "range",
                name = label,
                desc = L[def.labelKey .. "_DELAY_DESC"]
                    or (L["DELAY_HEADER_DESC"] or "Delay before returning to Normal after combat ends."),
                min = 0,
                max = 10,
                step = 0.1,
                get = function() return GetOption(delayKey) end,
                set = function(_, val) SetOption(delayKey, val) end,
                order = order,
                disabled = function() return not GetOption("autoCombatZoom") end,
            }
            order = order + 1
        end
    end)

    return order
end

function Config:SetupOptions()
    if not ns.Database or not ns.Database.db then return end
    local defaults = ns.Database.DEFAULTS

    local maxDistance = defaults.MAX_POSSIBLE_DISTANCE or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
    local hasQuestWatch = (C_QuestLog and C_QuestLog.GetNumQuestWatches) and true or false

    local options = {
        name = L["ADDON_TITLE"] or "Max Camera Distance",
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

                            local iconLib = (LibStub and LibStub("LibDBIcon-1.0", true))
                            if iconLib then
                                if val then iconLib:Show(addonName) else iconLib:Hide(addonName) end
                            end

                            if ns.Core and ns.Core.RefreshMinimapButton then
                                ns.Core:RefreshMinimapButton()
                            end
                        end,
                    },
                    languageOverride = {
                        type = "select",
                        name = L["LANGUAGE_SETTING"] or "Addon Language",
                        desc = L["LANGUAGE_SETTING_DESC"] or "Choose the addon language. Client Default follows the game client language. The UI reloads immediately after changing this option.",
                        order = 5,
                        width = "double",
                        values = function()
                            return GetLanguageChoices()
                        end,
                        get = function()
                            return GetLanguageOption()
                        end,
                        set = function(_, value)
                            SetLanguageOption(value)
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
                    -- Hidden where the CVar does not exist. cameraDistanceMoveSpeed
                    -- is absent from the 12.0.7 and 12.1 CVar tables (and from the
                    -- Classic ones), so on those clients this slider did nothing at
                    -- all. Reactive Zoom below is the working replacement.
                    moveViewDistance = {
                        type = "range",
                        name = L["MOVE_VIEW_DISTANCE"],
                        desc = L["MOVE_VIEW_DISTANCE_DESC"],
                        min = 20,
                        max = 50,
                        step = 1,
                        hidden = function() return not HasCVar("cameraDistanceMoveSpeed") end,
                        get = function() return GetOption("moveViewDistance") end,
                        set = function(_, val) SetOption("moveViewDistance", val) end,
                        order = 30,
                    },

                    reactiveZoomHeader = {
                        type = "header",
                        name = L["REACTIVE_ZOOM_HEADER"] or "Reactive Zoom",
                        order = 31,
                    },
                    reactiveZoomDesc = {
                        type = "description",
                        name = L["REACTIVE_ZOOM_DESC"] or "Makes the mouse wheel cover more distance while you keep spinning it, instead of stepping one fixed notch at a time. Based on the Reactive Zoom feature of DynamicCam.",
                        order = 32,
                    },
                    reactiveZoom = {
                        type = "toggle",
                        name = L["REACTIVE_ZOOM"] or "Enable Reactive Zoom",
                        desc = L["REACTIVE_ZOOM_TOGGLE_DESC"] or "Replaces the client's fixed zoom steps with an accelerating, eased zoom.",
                        get = function() return GetOption("reactiveZoom") end,
                        set = function(_, val)
                            SetOption("reactiveZoom", val)
                            if ns.ReactiveZoom and ns.ReactiveZoom.Refresh then
                                ns.ReactiveZoom:Refresh()
                            end
                        end,
                        order = 33,
                        width = "full",
                    },
                    reactiveZoomAddIncrementsAlways = {
                        type = "range",
                        name = L["REACTIVE_ZOOM_ALWAYS"] or "Extra Steps (always)",
                        desc = L["REACTIVE_ZOOM_ALWAYS_DESC"] or "Added to every wheel notch. Raise this to make a single notch travel further.",
                        min = 0, max = 5, step = 0.5,
                        get = function() return GetOption("reactiveZoomAddIncrementsAlways") end,
                        set = function(_, val) SetOption("reactiveZoomAddIncrementsAlways", val) end,
                        order = 34,
                        disabled = function() return not GetOption("reactiveZoom") end,
                    },
                    reactiveZoomAddIncrements = {
                        type = "range",
                        name = L["REACTIVE_ZOOM_EXTRA"] or "Extra Steps (while spinning)",
                        desc = L["REACTIVE_ZOOM_EXTRA_DESC"] or "Added on top when the camera has not caught up yet, which is what makes fast spinning travel much further than slow clicking.",
                        min = 0, max = 5, step = 0.5,
                        get = function() return GetOption("reactiveZoomAddIncrements") end,
                        set = function(_, val) SetOption("reactiveZoomAddIncrements", val) end,
                        order = 35,
                        disabled = function() return not GetOption("reactiveZoom") end,
                    },
                    reactiveZoomIncAddDifference = {
                        type = "range",
                        name = L["REACTIVE_ZOOM_THRESHOLD"] or "Spin Detection Threshold",
                        desc = L["REACTIVE_ZOOM_THRESHOLD_DESC"] or "How far behind the camera must be before the extra steps kick in. Lower reacts sooner.",
                        min = 0, max = 5, step = 0.1,
                        get = function() return GetOption("reactiveZoomIncAddDifference") end,
                        set = function(_, val) SetOption("reactiveZoomIncAddDifference", val) end,
                        order = 36,
                        disabled = function() return not GetOption("reactiveZoom") end,
                    },
                    reactiveZoomMaxZoomTime = {
                        type = "range",
                        name = L["REACTIVE_ZOOM_MAX_TIME"] or "Maximum Zoom Time",
                        desc = L["REACTIVE_ZOOM_MAX_TIME_DESC"] or "Upper bound on how long one eased zoom may take. Lower feels snappier, higher feels smoother.",
                        min = 0.05, max = 1, step = 0.05,
                        get = function() return GetOption("reactiveZoomMaxZoomTime") end,
                        set = function(_, val) SetOption("reactiveZoomMaxZoomTime", val) end,
                        order = 37,
                        disabled = function() return not GetOption("reactiveZoom") end,
                    },
                    reactiveZoomEasing = {
                        type = "select",
                        name = L["REACTIVE_ZOOM_EASING"] or "Zoom Curve",
                        desc = L["REACTIVE_ZOOM_EASING_DESC"] or "How the eased zoom is distributed over time. Out curves leave immediately and slow into the target, which feels the most responsive on a wheel.",
                        values = function()
                            return {
                                OutQuad = L["REACTIVE_ZOOM_EASING_OUTQUAD"] or "Responsive (Out Quad)",
                                OutCubic = L["REACTIVE_ZOOM_EASING_OUTCUBIC"] or "Very Responsive (Out Cubic)",
                                InOutQuad = L["REACTIVE_ZOOM_EASING_INOUTQUAD"] or "Smooth (In-Out Quad)",
                                Linear = L["REACTIVE_ZOOM_EASING_LINEAR"] or "Constant (Linear)",
                            }
                        end,
                        sorting = function() return { "OutQuad", "OutCubic", "InOutQuad", "Linear" } end,
                        get = function() return GetOption("reactiveZoomEasing") end,
                        set = function(_, val) SetOption("reactiveZoomEasing", val) end,
                        order = 37.5,
                        disabled = function() return not GetOption("reactiveZoom") end,
                    },
                    reactiveZoomSpeed = {
                        type = "range",
                        name = L["CAMERA_ZOOM_SPEED"] or "Client Zoom Speed",
                        desc = L["CAMERA_ZOOM_SPEED_DESC"] or "Blizzard's own cameraZoomSpeed CVar. Reactive Zoom uses it to work out how long a zoom should take.",
                        min = 1, max = 50, step = 1,
                        hidden = function() return not HasCVar("cameraZoomSpeed") end,
                        get = function() return tonumber(Compat.SafeGetCVar and Compat.SafeGetCVar("cameraZoomSpeed")) or 20 end,
                        set = function(_, val)
                            if Compat.SafeSetCVar then Compat.SafeSetCVar("cameraZoomSpeed", val) end
                        end,
                        order = 38,
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
                    mountPresetHeader = {
                        type = "header",
                        name = L["PRESET_MOUNT_GROUP_HEADER"] or "Mount / Travel",
                        order = 60,
                    },
                    mountZoomPreset = {
                        type = "select",
                        name = L["MOUNT_ZOOM_PRESET"] or "Mount Distance Preset",
                        desc = function() return BuildPresetStatusText("mountZoomFactor") end,
                        values = function() return GetPresetChoices("mountZoomFactor") end,
                        get = function() return GetPresetSelectValue("mountZoomFactor") end,
                        set = function(_, value) SetPresetSelectValue("mountZoomFactor", value) end,
                        order = 61,
                        disabled = function() return not GetOption("autoMountZoom") end,
                    },
                    mountZoomPresetInfo = { type = "description", name = function() return BuildPresetStatusText("mountZoomFactor") end, order = 62, hidden = function() return not GetOption("autoMountZoom") end },
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
                    worldPvpZoom = {
                        type = "toggle",
                        name = L["WORLD_PVP_ZOOM"] or "Treat World PvP as its own activity",
                        desc = L["WORLD_PVP_ZOOM_DESC"] or "When on, being flagged for PvP or having War Mode active outdoors uses the World PvP distance instead of the Open World distance. Turn this off if you are permanently flagged and want a single open-world distance.",
                        get = function() return GetOption("worldPvpZoom") end,
                        set = function(_, val) SetOption("worldPvpZoom", val) end,
                        order = 12,
                        width = "full",
                        disabled = function() return not GetOption("autoCombatZoom") end,
                    },
                    combatTriggerHeader = {
                        type = "header",
                        name = L["COMBAT_TRIGGER_HEADER"] or "Combat Triggers",
                        order = 20,
                    },
                    combatTriggerDesc = {
                        type = "description",
                        name = L["COMBAT_TRIGGER_DESC"] or "Choose which events are allowed to activate combat zoom.",
                        order = 21,
                    },
                    combatZoomOnPlayer = {
                        type = "toggle",
                        name = L["COMBAT_TRIGGER_PLAYER"] or "Zoom when I enter combat",
                        desc = L["COMBAT_TRIGGER_PLAYER_DESC"] or "Triggers combat zoom when your character enters combat.",
                        get = function() return GetOption("combatZoomOnPlayer") end,
                        set = function(_, val) SetOption("combatZoomOnPlayer", val) end,
                        order = 22,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                        width = "full",
                    },
                    combatZoomOnGroup = {
                        type = "toggle",
                        name = L["COMBAT_TRIGGER_GROUP"] or "Zoom when party or raid enters combat",
                        desc = L["COMBAT_TRIGGER_GROUP_DESC"] or "Triggers combat zoom when your party or raid is fighting, even if you are not actively in combat yet.",
                        get = function() return GetOption("combatZoomOnGroup") end,
                        set = function(_, val) SetOption("combatZoomOnGroup", val) end,
                        order = 23,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                        width = "full",
                    },
                    combatZoomOnThreat = {
                        type = "toggle",
                        name = L["COMBAT_TRIGGER_THREAT"] or "Zoom on threat only",
                        desc = L["COMBAT_TRIGGER_THREAT_DESC"] or "Triggers combat zoom when you have threat, even if the normal combat flag has not settled yet.",
                        get = function() return GetOption("combatZoomOnThreat") end,
                        set = function(_, val) SetOption("combatZoomOnThreat", val) end,
                        order = 24,
                        disabled = function() return not GetOption("autoCombatZoom") end,
                        width = "full",
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
                    -- The Normal Distance is the baseline every activity returns
                    -- to, so it gets its own header and sits ahead of the
                    -- per-activity list instead of being buried inside it.
                    normalDistanceHeader = {
                        type = "header",
                        name = L["NORMAL_DISTANCE_HEADER"] or "Normal Distance",
                        order = 42,
                    },
                    normalDistanceDesc = {
                        type = "description",
                        name = L["NORMAL_DISTANCE_HEADER_DESC"] or "The distance the camera returns to when you are neither in combat nor mounted. Every activity below is a deviation from this baseline.",
                        order = 43,
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
                        order = 44,
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
                    mountZoomMode = {
                        type = "select",
                        name = L["MOUNT_ZOOM_MODE_NAME"] or "Mount Zoom Mode",
                        desc = L["MOUNT_ZOOM_MODE_DESC"] or "Choose whether mount zoom should apply to all mounts and travel forms, only to flying mounts, only to Skyriding, or only to travel forms.",
                        values = function()
                            return {
                                all = L["MOUNT_ZOOM_MODE_ALL"] or "All mounts and travel forms",
                                flying = L["MOUNT_ZOOM_MODE_FLYING"] or "Flying mounts only",
                                skyriding = L["MOUNT_ZOOM_MODE_SKYRIDING"] or "Skyriding only",
                                forms = L["MOUNT_ZOOM_MODE_FORMS"] or "Travel forms only",
                            }
                        end,
                        get = function() return GetOption("mountZoomMode") or "all" end,
                        set = function(_, val) SetOption("mountZoomMode", val) end,
                        order = 61.5,
                        disabled = function() return not GetOption("autoMountZoom") end,
                        width = "full",
                    },
                    dragonRacingRaceFirstPerson = {
                        type = "toggle",
                        name = L["DRAGON_RACE_FP_NAME"] or "First-Person during Dragonriding Races",
                        desc = L["DRAGON_RACE_FP_DESC"] or "Temporarily switches to first-person when a Dragonriding race aura is active, then restores Smart Zoom control when the race ends.",
                        get = function() return GetOption("dragonRacingRaceFirstPerson") end,
                        set = function(_, val) SetOption("dragonRacingRaceFirstPerson", val) end,
                        order = 61.6,
                        disabled = function() return not GetOption("autoMountZoom") end,
                        width = "full",
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
                    zoomRestoreSetting = {
                        type = "select",
                        name = L["ZOOM_RESTORE_SETTING"] or "Restore Zoom Behavior",
                        desc = L["ZOOM_RESTORE_SETTING_DESC"] or "Controls how Smart Zoom restores a previously used zoom value. Never = always use configured targets. Adaptive = restore the last zoom only when returning to the state you came from. Always = always prefer the last stored zoom for that state when it fits within the state cap.",
                        values = function()
                            return {
                                never = L["ZOOM_RESTORE_NEVER"] or "Never",
                                adaptive = L["ZOOM_RESTORE_ADAPTIVE"] or "Adaptive",
                                always = L["ZOOM_RESTORE_ALWAYS"] or "Always",
                            }
                        end,
                        get = function() return GetOption("zoomRestoreSetting") or "adaptive" end,
                        set = function(_, val) SetOption("zoomRestoreSetting", val) end,
                        order = 63,
                        width = "full",
                    },
                    respectManualStateZoom = {
                        type = "toggle",
                        name = L["RESPECT_MANUAL_STATE_ZOOM"] or "Respect Manual Zoom in Smart States",
                        desc = L["RESPECT_MANUAL_STATE_ZOOM_DESC"] or "When Smart Zoom is active for Mount or Combat, manual mouse-wheel zoom is preserved until the state changes instead of being forced back every refresh.",
                        get = function() return GetOption("respectManualStateZoom") end,
                        set = function(_, val) SetOption("respectManualStateZoom", val) end,
                        order = 64,
                        width = "full",
                    },
                    delayHeader = { type = "header", name = L["DELAY_HEADER"], order = 80 },
                    delayDesc = {
                        type = "description",
                        name = L["DELAY_HEADER_DESC"] or "Combat zoom-out is instant. Returning to Normal is delayed per context to avoid camera flicker.",
                        order = 81,
                    },
                    dismountDelay = {
                        type = "range",
                        name = L["DISMOUNT_DELAY"],
                        desc = L["DISMOUNT_DELAY_DESC"],
                        min = 0,
                        max = 10,
                        step = 0.1,
                        get = function() return GetOption("dismountDelay") end,
                        set = function(_, val) SetOption("dismountDelay", val) end,
                        order = 95,
                        disabled = function() return not GetOption("autoMountZoom") end
                    },
                },
            },

            advancedSettings = {
                type = "group",
                name = L["ADVANCED_SETTINGS"],
                order = 5,
                args = {
                    collisionHeader = {
                        type = "header",
                        name = L["COLLISION_HEADER"] or "Camera Collision",
                        order = 1,
                    },
                    collisionDesc = {
                        type = "description",
                        name = L["COLLISION_DESC"] or "General camera collision behavior. These settings are global and apply everywhere, not per combat context.",
                        order = 2,
                    },
                    reduceMovement = {
                        type = "toggle",
                        name = L["REDUCE_UNEXPECTED_MOVEMENT"],
                        desc = L["REDUCE_UNEXPECTED_MOVEMENT_DESC"],
                        get = function() return GetOption("reduceUnexpectedMovement") end,
                        set = function(_, val) SetOption("reduceUnexpectedMovement", val) end,
                        order = 3,
                        width = "full",
                    },
                    indirectVis = {
                        type = "toggle",
                        name = L["INDIRECT_VISIBILITY"],
                        desc = L["INDIRECT_VISIBILITY_DESC"],
                        hidden = function() return not HasCVar("cameraIndirectVisibility") end,
                        get = function() return GetOption("cameraIndirectVisibility") end,
                        set = function(_, val) SetOption("cameraIndirectVisibility", val) end,
                        order = 4,
                    },
                    indirectOffset = {
                        type = "range",
                        name = L["INDIRECT_OFFSET"] or "Collision Sensitivity",
                        desc = L["INDIRECT_OFFSET_DESC"] or "Controls Blizzard's reduced camera collision sensitivity. 0.0 is the minimum, 10.0 is the maximum, and the game's default is 1.5.",
                        hidden = function() return not HasCVar("cameraIndirectOffset") end,
                        disabled = function() return not GetOption("cameraIndirectVisibility") end,
                        min = 0,
                        max = 10,
                        step = 0.1,
                        get = function() return GetOption("cameraIndirectOffset") end,
                        set = function(_, val) SetOption("cameraIndirectOffset", val) end,
                        order = 5,
                    },
                    collisionSummary = {
                        type = "description",
                        name = function() return BuildCollisionSummaryText() end,
                        order = 6,
                        width = "full",
                    },
                    visualHeader = {
                        type = "header",
                        name = L["VISUAL_UTILITY_HEADER"] or "Visual Utility",
                        order = 20,
                    },
                    occludedSilhouettePlayer = {
                        type = "toggle",
                        name = L["OCCLUDED_SILHOUETTE_PLAYER"] or "Show Silhouette when Obstructed",
                        desc = L["OCCLUDED_SILHOUETTE_PLAYER_DESC"] or "Turns on Blizzard's character silhouette when your player is blocked by objects. This is a global client setting and applies everywhere.",
                        hidden = function() return not HasCVar("occludedSilhouettePlayer") end,
                        get = function() return GetOption("occludedSilhouettePlayer") end,
                        set = function(_, val) SetOption("occludedSilhouettePlayer", val) end,
                        order = 21,
                        width = "full",
                    },
                    resampleAlwaysSharpen = {
                        type = "toggle",
                        name = L["RESAMPLE_ALWAYS_SHARPEN"],
                        desc = L["RESAMPLE_ALWAYS_SHARPEN_DESC"],
                        hidden = function() return not SupportsFSRSharpen() end,
                        get = function() return GetOption("resampleAlwaysSharpen") end,
                        set = function(_, val) SetOption("resampleAlwaysSharpen", val) end,
                        order = 21
                    },
                    softTargetInteract = {
                        type = "toggle",
                        name = L["SOFT_TARGET_INTERACT"],
                        desc = L["SOFT_TARGET_INTERACT_DESC"],
                        hidden = function() return not SupportsSoftTargetIcons() end,
                        get = function() return GetOption("softTargetInteract") end,
                        set = function(_, val) SetOption("softTargetInteract", val) end,
                        order = 22
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
                    afkHideUI = {
                        type = "toggle",
                        name = L["AFK_HIDE_UI_NAME"] or "Hide UI in AFK mode",
                        desc = L["AFK_HIDE_UI_DESC"] or "Hides the full UI for a cinematic AFK mode. ESC safely restores it.",
                        get = function() return GetOption("afkHideUI") end,
                        set = function(_, val) SetOption("afkHideUI", val) end,
                        disabled = function() return not GetOption("afkMode") end,
                        order = 12
                    },
                    afkZoomOut = {
                        type = "toggle",
                        name = L["AFK_ZOOM_OUT_NAME"] or "Zoom out while AFK",
                        desc = L["AFK_ZOOM_OUT_DESC"] or "Pushes the camera to the maximum managed distance when AFK mode starts.",
                        get = function() return GetOption("afkZoomOut") end,
                        set = function(_, val) SetOption("afkZoomOut", val) end,
                        disabled = function() return not GetOption("afkMode") end,
                        order = 13
                    },
                    afkDelay = {
                        type = "range",
                        name = L["AFK_DELAY_NAME"] or "Start delay",
                        desc = L["AFK_DELAY_DESC"] or "How many seconds to wait after the game marks you AFK before the cinematic mode starts.",
                        min = 0,
                        max = 30,
                        step = 1,
                        get = function() return GetOption("afkDelay") end,
                        set = function(_, val) SetOption("afkDelay", val) end,
                        disabled = function() return not GetOption("afkMode") end,
                        order = 14
                    },
                    afkDirection = {
                        type = "select",
                        name = L["AFK_DIRECTION_NAME"] or "Rotation direction",
                        desc = L["AFK_DIRECTION_DESC"] or "Chooses the camera rotation direction used in AFK mode.",
                        values = function()
                            return {
                                left = L["AFK_DIRECTION_LEFT"] or "Left",
                                right = L["AFK_DIRECTION_RIGHT"] or "Right",
                            }
                        end,
                        get = function() return GetOption("afkDirection") end,
                        set = function(_, val) SetOption("afkDirection", val) end,
                        disabled = function() return not GetOption("afkMode") end,
                        order = 15
                    },
                    afkRotationSpeed = {
                        type = "range",
                        name = L["AFK_SPEED_NAME"] or "Rotation speed",
                        desc = L["AFK_SPEED_DESC"] or "Normalized MoveView speed used by AFK rotation. Lower values are calmer.",
                        min = 0.1,
                        max = 2.0,
                        step = 0.1,
                        bigStep = 0.1,
                        isPercent = false,
                        get = function() return GetOption("afkRotationSpeed") end,
                        set = function(_, val) SetOption("afkRotationSpeed", val) end,
                        disabled = function() return not GetOption("afkMode") end,
                        order = 16
                    },
                    afkSkipMounted = {
                        type = "toggle",
                        name = L["AFK_SKIP_MOUNTED_NAME"] or "Do not start on mounts",
                        desc = L["AFK_SKIP_MOUNTED_DESC"] or "Prevents AFK mode from starting while mounted.",
                        get = function() return GetOption("afkSkipMounted") end,
                        set = function(_, val) SetOption("afkSkipMounted", val) end,
                        disabled = function() return not GetOption("afkMode") end,
                        order = 17
                    },
                    afkSkipFlying = {
                        type = "toggle",
                        name = L["AFK_SKIP_FLYING_NAME"] or "Do not start while flying",
                        desc = L["AFK_SKIP_FLYING_DESC"] or "Prevents AFK mode from starting while the character is flying.",
                        get = function() return GetOption("afkSkipFlying") end,
                        set = function(_, val) SetOption("afkSkipFlying", val) end,
                        disabled = function() return not GetOption("afkMode") end,
                        order = 18
                    },
                    afkResumeAfterCombat = {
                        type = "toggle",
                        name = L["AFK_RESUME_AFTER_COMBAT_NAME"] or "Resume after combat",
                        desc = L["AFK_RESUME_AFTER_COMBAT_DESC"] or "If AFK mode is interrupted by combat, it starts again after combat ends as long as you are still AFK.",
                        get = function() return GetOption("afkResumeAfterCombat") end,
                        set = function(_, val) SetOption("afkResumeAfterCombat", val) end,
                        disabled = function() return not GetOption("afkMode") end,
                        order = 19
                    },
                }
            },

            debugSettings = {
                type = "group",
                name = L["DEBUG_SETTINGS"] or "Status & Debug",
                order = 7,
                args = {
                    statusHeader = {
                        type = "header",
                        name = L["STATUS_HEADER"] or "Live Status",
                        order = 0,
                    },
                    statusDesc = {
                        type = "description",
                        name = L["STATUS_DESC"] or "Shows the current resolved zoom decision, active combat triggers, and delayed return state.",
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
                    loggingHeader = {
                        type = "header",
                        name = L["DEBUG_LOGGING_HEADER"] or "Chat Logging",
                        order = 1,
                    },
                    loggingDesc = {
                        type = "description",
                        name = L["DEBUG_LOGGING_DESC"] or "These options control what gets printed to chat. Live Status above is always available even with logging disabled.",
                        order = 1.1,
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

    -- Generated per-activity rows. Injected here rather than written into the
    -- literal above because the set of activities is data, not layout.
    -- Reserved order bands. Each generated block gets a range with headroom, and
    -- the static rows that follow start after that range - never at a number
    -- picked to sit just past today's activity count. Re-anchoring the static
    -- rows individually was tried and rejected: it moves a group's header
    -- without moving the group's contents, which reorders the block itself.
    local BANDS = {
        preset = { first = 21, last = 59 },   -- mount presets resume at 60
        slider = { first = 45, last = 59 },   -- mount settings resume at 60
        delay  = { first = 82, last = 94 },   -- dismount delay sits at 95
    }

    for mode, band in pairs(BANDS) do
        local args = (mode == "preset") and options.args.presetSettings.args
            or options.args.smartSettings.args
        local nextOrder = InjectContextOptions(args, band.first, mode, maxDistance)

        -- A silent overrun is what produced the original bug, so say so loudly
        -- rather than letting rows render inside the wrong group.
        if nextOrder > band.last + 1 and ns.Functions and ns.Functions.logMessage then
            ns.Functions:logMessage("error", string.format(
                "Option order band '%s' overflowed (%d > %d); widen it in Config.lua.",
                mode, nextOrder - 1, band.last))
        end
    end

    if not AceConfig then
        print(addonName .. ": AceConfig-3.0 not found.")
        return
    end

    local okRegister, errRegister = pcall(AceConfig.RegisterOptionsTable, AceConfig, addonName, options)
    if not okRegister then
        print(addonName .. ": AceConfig registration failed: " .. tostring(errRegister))
        return
    end

    if AceConfigDialog and AceConfigDialog.AddToBlizOptions then
        local rootCategoryName = L["ADDON_TITLE"] or "Max Camera Distance"
        pcall(AceConfigDialog.AddToBlizOptions, AceConfigDialog, addonName, rootCategoryName)
        pcall(AceConfigDialog.AddToBlizOptions, AceConfigDialog, addonName, L["PROFILES"] or "Profiles", rootCategoryName, "profiles")
    end
end

local function ApplyHookTooltip(target, titleText, descText, pathText)
    if not target or not target.SetScript then return end

    target:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(titleText)
        if descText and descText ~= "" then
            GameTooltip:AddLine(descText, 1, 1, 1, true)
        end
        if pathText and pathText ~= "" then
            GameTooltip:AddLine(pathText, 1, 0.82, 0, true)
        end
        GameTooltip:Show()
    end)

    target:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function DisableSettingControl(child, titleText, descText, pathText)
    if not child then return false end

    local candidates = {
        child.CheckboxControl and (child.CheckboxControl.Checkbox or child.CheckboxControl),
        child.Checkbox,
        child.Control and (child.Control.Checkbox or child.Control),
        child.SliderWithSteppers,
        child.Slider,
        child.Dropdown,
        child.Button,
    }

    local target = nil
    for _, candidate in ipairs(candidates) do
        if candidate then
            target = candidate
            break
        end
    end

    if not target then return false end

    if target.SetEnabled then
        target:SetEnabled(false)
    elseif target.SetEnabled_ then
        target:SetEnabled_(false)
    end

    local tooltipTarget = target.Checkbox or target.Slider or target
    ApplyHookTooltip(tooltipTarget, titleText, descText, pathText)
    if child ~= tooltipTarget then
        if child.EnableMouse then
            child:EnableMouse(true)
        end
        ApplyHookTooltip(child, titleText, descText, pathText)
    end
    return true
end

local function IsSilhouetteSettingLabel(text)
    if type(text) ~= "string" or text == "" then return false end

    local exact1 = L["HOOK_SILHOUETTE_LABEL_OBSTRUCTED"] or "Show Silhouette when Obstructed"
    local exact2 = L["HOOK_SILHOUETTE_LABEL_OBSCURED"] or "Show Silhouette when Obscured"
    if text == exact1 or text == exact2 then
        return true
    end

    local lowered = string.lower(text)
    return lowered:find("silhouette", 1, true) ~= nil
        and (lowered:find("obstruct", 1, true) ~= nil or lowered:find("obscur", 1, true) ~= nil)
end

-- =====================================================================
-- BLIZZARD SETTINGS HOOK (Retail only, Dragonflight+ UI)
-- =====================================================================
-- This used to run at file-load time. If SettingsPanel was not built yet the
-- whole hook was skipped for the rest of the session, so it is now deferred and
-- retried until it succeeds.
local blizzardSettingsHookInstalled = false

local function InstallBlizzardSettingsHook()
    if blizzardSettingsHookInstalled then return true end

    if not (IS_RETAIL
        and SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList
        and SettingsPanel.Container.SettingsList.ScrollBox
        and hooksecurefunc) then
        return false
    end

    blizzardSettingsHookInstalled = true
    local MOUSE_LOOK_SPEED = _G.MOUSE_LOOK_SPEED
    local CONTROLS_LABEL = _G.CONTROLS_LABEL
    local COMBAT_LABEL = _G.COMBAT_LABEL or "Combat"

    hooksecurefunc(SettingsPanel.Container.SettingsList.ScrollBox, "Update", function(self)
        local header = SettingsPanel.Container.SettingsList.Header
        if not header or not header.Title or not header.Title.GetText then return end

        local headerText = header.Title:GetText()
        local scrollTarget = SettingsPanel.Container.SettingsList.ScrollBox.ScrollTarget
        if not scrollTarget or not scrollTarget.GetChildren then return end

        local children = { scrollTarget:GetChildren() }
        for _, child in ipairs(children) do
            local childText = child and child.Text and child.Text.GetText and child.Text:GetText()
            if childText then
                if headerText == CONTROLS_LABEL and childText == MOUSE_LOOK_SPEED then
                    if DisableSettingControl(child, L["HOOK_DISABLED_BY_ADDON"], L["HOOK_MOUSE_SPEED_DESC"], L["HOOK_MOUSE_SPEED_PATH"]) then
                        break
                    end
                elseif headerText == COMBAT_LABEL and IsSilhouetteSettingLabel(childText) then
                    if DisableSettingControl(child, L["HOOK_DISABLED_BY_ADDON"], L["HOOK_SILHOUETTE_DESC"], L["HOOK_SILHOUETTE_PATH"]) then
                        break
                    end
                end
            end
        end
    end)

    return true
end

-- Try immediately, then retry on the events that can create SettingsPanel.
if not InstallBlizzardSettingsHook() and IS_RETAIL then
    local hookFrame = CreateFrame("Frame")
    hookFrame:RegisterEvent("PLAYER_LOGIN")
    hookFrame:RegisterEvent("ADDON_LOADED")
    hookFrame:SetScript("OnEvent", function(self, event, loadedAddon)
        if event == "ADDON_LOADED" and loadedAddon ~= "Blizzard_Settings" then return end
        if InstallBlizzardSettingsHook() then
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end
    end)
end
