local addonName, ns = ...
local LibStub = _G.LibStub
ns.Functions = ns.Functions or {}
local Functions = ns.Functions


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
local Compat = ns.Compat or {}
local ShoulderCompensation = ns.ShoulderCompensation or {}
local CameraStateController = ns.CameraStateController

-- Optional libraries are resolved lazily: a standalone provider addon (or an
-- addon that embeds Ace3 / LibMountInfo) can finish loading AFTER this file, and
-- capturing the LibStub result once at load time left them nil forever.
local LibCamera, LibMountInfo, ACD

local function ResolveOptionalLibs()
    if not LibStub then return end
    LibCamera    = LibCamera or LibStub("LibCamera-1.0", true)
    LibMountInfo = LibMountInfo or LibStub("LibMountInfo-1.1", true) or LibStub("LibMountInfo-1.0", true)
    ACD          = ACD or LibStub("AceConfigDialog-3.0", true)
end

ResolveOptionalLibs()

-- =====================================================================
-- 1) FAST LOCALS / API
-- =====================================================================
local C_Timer     = C_Timer
local C_UnitAuras = C_UnitAuras
local C_MountJournal = _G.C_MountJournal
local AuraUtil = _G.AuraUtil

local pcall    = pcall
local tonumber = tonumber
local tostring = tostring
local type     = type
local pairs    = pairs
local print    = print

local math_abs = math.abs
local math_floor = math.floor
local tinsert  = table.insert
local strlower = string.lower

local UnitAffectingCombat   = UnitAffectingCombat
local UnitThreatSituation   = UnitThreatSituation
local IsInInstance          = IsInInstance
local IsMounted             = IsMounted
local GetShapeshiftForm     = GetShapeshiftForm
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local UnitIsAFK             = UnitIsAFK
local MoveViewRightStart    = MoveViewRightStart
local MoveViewRightStop     = MoveViewRightStop
local MoveViewLeftStart     = MoveViewLeftStart
local MoveViewLeftStop      = MoveViewLeftStop
local GetCameraZoom         = GetCameraZoom
local UnitExists            = UnitExists
local UnitIsUnit            = UnitIsUnit
local IsEncounterInProgress = IsEncounterInProgress
local GetTime = GetTime
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local UnitOnTaxi = UnitOnTaxi
local IsFlying = IsFlying
local CloseAllWindows = CloseAllWindows

local IsInRaid             = IsInRaid
local IsInGroup            = IsInGroup
local GetNumGroupMembers   = GetNumGroupMembers
local GetNumSubgroupMembers= GetNumSubgroupMembers

local IS_RETAIL = Compat.IS_RETAIL and true or false
local CONVERSION_RATIO = Compat.CONVERSION_RATIO or (IS_RETAIL and 15 or 12.5)

local CVAR_ALIASES = {
    cameraReduceUnexpectedMovement = { "cameraReduceUnexpectedMovement", "CameraReduceUnexpectedMovement" },
    CameraReduceUnexpectedMovement = { "cameraReduceUnexpectedMovement", "CameraReduceUnexpectedMovement" },
}

local CVAR_CANONICAL = {
    CameraReduceUnexpectedMovement = "cameraReduceUnexpectedMovement",
}

local function CanonicalCVarName(cvarName)
    return CVAR_CANONICAL[cvarName] or cvarName
end

-- Patch 12.1 made AuraData structs fully secret while auras are secret (combat,
-- encounters, M+, PvP). The spellID-based lookups below are still legal to CALL
-- there, but the table that comes back may be a secret, and `if aura then` on a
-- secret is an immediate Lua error - the pcall around the API call does not
-- cover the truthiness test in the caller. So the presence check happens here,
-- once, and every call site gets a plain boolean.
local IsTruthySafe = Compat.IsTruthy or function(value) return value and true or false end

local function HasPlayerAura(spellID)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
        return false
    end

    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    if not ok then
        return false
    end

    return IsTruthySafe(aura)
end

-- Kept for backwards compatibility with any external caller; it now answers the
-- same question as HasPlayerAura instead of handing out a possibly-secret table.
local function SafePlayerAuraBySpellID(spellID)
    return HasPlayerAura(spellID) or nil
end

-- =====================================================================
-- 2) STATE
-- =====================================================================
local ZOOM_STATE_AFK = "afk"
local ZOOM_STATE_DRAGON_RACE_FIRST_PERSON = "dragonrace_first_person"
local ZOOM_STATE_COMBAT = "combat"
local ZOOM_STATE_MOUNT = "mount"
local ZOOM_STATE_NORMAL = "normal"
local ZOOM_STATE_MANUAL = "manual"
-- Backward-compatible name used by older internal logic for the non-combat/non-mount state.
local ZOOM_STATE_NONE = ZOOM_STATE_NORMAL

local currentZoomState = (CameraStateController and CameraStateController.GetState and CameraStateController:GetState()) or ZOOM_STATE_NORMAL

local transitionTimer = nil
local isInternalUpdate = false
local pendingReturnInfo = nil
local lastCombatContext = "world"
local lastAutoAppliedZoomYards = nil
local lastAutoAppliedAt = 0
local stateManualOverride = {
    [ZOOM_STATE_MOUNT] = false,
    [ZOOM_STATE_COMBAT] = false,
}
local lastZoomByState = {}
local lastStateSource = {}

-- token that invalidates old delayed transitions (fixes “sticky states”)
local stateToken = 0
local refreshBurstToken = 0

-- Throttling (no permanent OnUpdate)
local updatePending = false
local updateFrame = CreateFrame("Frame")
updateFrame:Hide()

-- Runtime caches are deliberately short lived. They let one camera pass reuse
-- expensive state checks (raid combat scan, mount/aura probes, context resolve)
-- without making mount/combat reactions feel delayed.
local RUNTIME_SIGNAL_CACHE_SECONDS = 0.05
local GROUP_COMBAT_CACHE_SECONDS = 0.12
local CVAR_GUARD_REFRESH_SECONDS = 0.12
local SHOULDER_UPDATE_INTERVAL = 0.033
local runtimeCache = {
    combatSignals = nil,
    combatSignalsExpiresAt = 0,
    combatSignalsDb = nil,
    groupCombat = nil,
    groupCombatExpiresAt = 0,
    groupCombatKey = nil,
    cvarGuardRefreshAt = 0,
    cvarGuardPending = false,
}

-- AFK
local afkActive = false
local afkUIHidden = false
local afkPendingToken = 0
local afkSuppressUntilClear = false
local afkResumeAfterCombat = false
local AFK_DEFAULT_DELAY = 3
local AFK_DEFAULT_SPEED = 0.5

-- Frames
local safeExitFrame = CreateFrame("Frame", "MCD_SafeExitFrame", WorldFrame)
local shoulderHandlerFrame = CreateFrame("Frame")

-- =====================================================================
-- 3) FALLBACK DATA (travel forms / buffs)
-- =====================================================================
local TRAVEL_FORM_IDS = {
    [783]=true, [1066]=true, [276012]=true, [33943]=true, [40120]=true,
    [165962]=true, [210053]=true, [232323]=true, [29166]=true,
    [2645]=true, [292651]=true, [125565]=true, [310143]=true, [311648]=true
}

local TRAVEL_BUFF_IDS = {
    [369536]=true, [359618]=true, [375087]=true, [375088]=true, [462245]=true,
    [221883]=true, [254471]=true, [254472]=true, [254473]=true, [254474]=true,
    [221885]=true, [221886]=true, [221887]=true, [87840]=true, [392376]=true,
    [783]=true, [165962]=true, [276029]=true, [232323]=true, [2645]=true, [292651]=true
}

local FLYCAM_FLYING_MOUNT_TYPES = {
    [242] = true,
    [247] = true,
    [248] = true,
    [306] = true,
    [398] = true,
    [402] = true,
    [407] = true,
    [424] = true,
    [436] = true,
    [444] = true,
}

local DRAGONRACING_RACE_AURAS = {
    [439239] = true,
    [369968] = true,
}

local FLYING_TRAVEL_FORM_IDS = {
    [33943] = true,
    [40120] = true,
    [165962] = true,
}

local FLYING_TRAVEL_BUFF_IDS = {
    [276029] = true,
    [165962] = true,
}

local MOUNT_ZOOM_MODE_ALL = "all"
local MOUNT_ZOOM_MODE_FLYING = "flying"
local MOUNT_ZOOM_MODE_SKYRIDING = "skyriding"
local MOUNT_ZOOM_MODE_FORMS = "forms"
local RACE_FIRST_PERSON_YARDS = 1

local IsInTravelForm

-- =====================================================================
-- 4) DB helper
-- =====================================================================
local function DB()
    return (ns.Database and ns.Database.db and ns.Database.db.profile) or nil
end

-- =====================================================================
-- 5) LOG
-- =====================================================================
function Functions:logMessage(level, message)
    local db = DB()
    if not (db and db.enableDebugLogging) then return end
    if not (db.debugLevel and db.debugLevel[level]) then return end

    local color = "|cffffffff"
    local prefix = "[D]"
    if level == "error" then color, prefix = "|cffff0000", "[E]"
    elseif level == "warning" then color, prefix = "|cffffff00", "[W]"
    elseif level == "info" then color, prefix = "|cff00ff00", "[I]"
    end

    local line = string.format("|cff0070deMCD|r %s: %s%s|r", prefix, color, tostring(message))
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(line)
    else
        print(line)
    end
end

function Functions:SendMessage(message)
    print("|cff0070deMax Camera Distance|r: " .. tostring(message))
end

local function NotifyConfigChanged()
    if ns.Config and ns.Config.NotifyChange then
        ns.Config:NotifyChange()
    end
end

function Functions:InvalidateRuntimeCaches(scope)
    runtimeCache.combatSignals = nil
    runtimeCache.combatSignalsExpiresAt = 0
    runtimeCache.combatSignalsDb = nil

    if scope ~= "combat-only" then
        runtimeCache.groupCombat = nil
        runtimeCache.groupCombatExpiresAt = 0
        runtimeCache.groupCombatKey = nil
    end
end

local function RequestCVarGuardRefresh(force)
    local guard = ns.CVarGuard
    if not (guard and guard.Refresh) then return end

    if force then
        runtimeCache.cvarGuardPending = false
        runtimeCache.cvarGuardRefreshAt = GetTime and GetTime() or 0
        guard:Refresh(true)
        return
    end

    local now = GetTime and GetTime() or 0
    if now == 0 or (now - (runtimeCache.cvarGuardRefreshAt or 0)) >= CVAR_GUARD_REFRESH_SECONDS then
        runtimeCache.cvarGuardRefreshAt = now
        guard:Refresh(false)
        return
    end

    if runtimeCache.cvarGuardPending then return end
    if not (C_Timer and C_Timer.After) then return end

    runtimeCache.cvarGuardPending = true
    C_Timer.After(CVAR_GUARD_REFRESH_SECONDS, function()
        runtimeCache.cvarGuardPending = false
        runtimeCache.cvarGuardRefreshAt = GetTime and GetTime() or runtimeCache.cvarGuardRefreshAt
        if ns.CVarGuard and ns.CVarGuard.Refresh then
            ns.CVarGuard:Refresh(false)
        end
    end)
end

-- =====================================================================
-- 6) SAFE CVAR HELPERS (fix SafeGetCVar nil + cross-client)
-- =====================================================================
local function GetCVarLookupNames(name)
    return CVAR_ALIASES[name] or name
end

local function SafeGetCVar(name)
    if Compat.SafeGetCVarNumberAny then
        local value = Compat.SafeGetCVarNumberAny(GetCVarLookupNames(name))
        return value
    elseif Compat.SafeGetCVarNumber then
        return Compat.SafeGetCVarNumber(name)
    end
    return nil
end


local function SafeSetCVar(name, value)
    if Compat.SafeSetCVarAny then
        return Compat.SafeSetCVarAny(GetCVarLookupNames(name), value)
    elseif Compat.SafeSetCVar then
        return Compat.SafeSetCVar(name, value)
    end
    return false
end

local function SafeLibCall(object, methodName, ...)
    if not object or type(object[methodName]) ~= "function" then
        return false
    end

    local ok, err = pcall(object[methodName], object, ...)
    if not ok then
        Functions:logMessage("error", tostring(methodName) .. " failed: " .. tostring(err))
        return false
    end

    return true
end

local function SafeFunctionCall(func, ...)
    if type(func) ~= "function" then return false end
    local ok, err = pcall(func, ...)
    if not ok then
        Functions:logMessage("error", "Camera helper failed: " .. tostring(err))
        return false
    end
    return true
end

local function ClampNumber(value, minValue, maxValue)
    local num = tonumber(value)
    if not num then return nil end
    if num < minValue then return minValue end
    if num > maxValue then return maxValue end
    return num
end

-- The pcall only protects the CALL. Coercing the result with `and result and
-- true` happens back in tainted context, so a secret return value (12.0+ marks
-- plenty of unit APIs as conditionally secret) would error here rather than at
-- the API. IsTruthySafe screens the value before it is ever used in a condition.
local function SafeBoolCall(func, ...)
    if type(func) ~= "function" then return false end
    local ok, result = pcall(func, ...)
    if not ok then return false end
    return IsTruthySafe(result)
end

local function SafeValueCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c = pcall(func, ...)
    if ok then
        return a, b, c
    end
    return nil
end

-- GetShapeshiftFormInfo does not return the same tuple on every branch: modern
-- clients give (icon, active, castable, spellID) while older ones insert a name
-- as the second value. Blindly taking the 4th return gave a boolean on those
-- clients, so druid travel forms were never detected. Pick the first numeric
-- return that actually looks like a spell ID instead.
local function GetShapeshiftFormSpellID(formIndex)
    if type(GetShapeshiftFormInfo) ~= "function" then return nil end

    local ok, a, b, c, d = pcall(GetShapeshiftFormInfo, formIndex)
    if not ok then return nil end

    for _, value in ipairs({ d, c, b, a }) do
        local num = tonumber(value)
        if num and num > 0 and type(value) ~= "boolean" then
            return num
        end
    end

    return nil
end

local function SafeIsInInstance()
    if type(IsInInstance) ~= "function" then
        return false, nil
    end
    local ok, inInstance, instanceType = pcall(IsInInstance)
    if ok then
        return inInstance and true or false, instanceType
    end
    return false, nil
end


local function NormalizeManagedCVarValue(cvarName, value, db)
    cvarName = CanonicalCVarName(cvarName)
    local defaults = ns.Database and ns.Database.DEFAULTS
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
    local maxFactor = maxYards / CONVERSION_RATIO

    if cvarName == "cameraDistanceMoveSpeed" then
        return ClampNumber(value, 20, 50)
    elseif cvarName == "cameraYawMoveSpeed" then
        return ClampNumber(value, 1, 360) or (db and ClampNumber(db.cameraYawMoveSpeed, 1, 360)) or 180
    elseif cvarName == "cameraPitchMoveSpeed" then
        return ClampNumber(value, 1, 360) or (db and ClampNumber(db.cameraPitchMoveSpeed, 1, 360)) or 90
    elseif cvarName == "cameraDistanceMaxZoomFactor" then
        return ClampNumber(value, 1 / CONVERSION_RATIO, maxFactor)
    elseif cvarName == "cameraDistanceMax" then
        return ClampNumber(value, 1, maxYards)
    elseif cvarName == "cameraReduceUnexpectedMovement"
        or cvarName == "cameraIndirectVisibility"
        or cvarName == "occludedSilhouettePlayer"
        or cvarName == "resampleAlwaysSharpen"
        or cvarName == "SoftTargetIconGameObject"
        or cvarName == "CameraKeepCharacterCentered"
        or cvarName == "test_cameraDynamicPitch" then
        local num = tonumber(value)
        if value == true or value == "true" or num == 1 then
            return 1
        end
        return 0
    elseif cvarName == "cameraIndirectOffset" then
        return ClampNumber(value, 0, 10) or ((db and ClampNumber(db.cameraIndirectOffset, 0, 10)) or 1.5)
    elseif cvarName == "test_cameraOverShoulder" then
        return ClampNumber(value, -15, 15) or 0
    elseif cvarName == "cameraView" then
        local view = tonumber(value)
        if view == 1 or view == 2 or view == 3 or view == 4 or view == 5 then
            return view
        end
        if Compat.SafeGetCVarDefault then
            return tonumber(Compat.SafeGetCVarDefault("cameraView")) or 1
        end
        return 1
    end

    local num = tonumber(value)
    return num ~= nil and num or value
end

local function SanitizeRuntimeProfile(db)
    if not db then return end

    local defaults = ns.Database and ns.Database.DEFAULTS
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
    local defaultNormal = (defaults and defaults.BLIZZARD_DEFAULT_YARDS) or 20

    db.maxZoomFactor = ClampNumber(db.maxZoomFactor, 1, maxYards) or maxYards
    db.minZoomFactor = ClampNumber(db.minZoomFactor, 1, maxYards) or defaultNormal
    db.mountZoomFactor = ClampNumber(db.mountZoomFactor, 1, maxYards) or db.maxZoomFactor
    db.worldCombatZoomFactor = ClampNumber(db.worldCombatZoomFactor, 1, maxYards) or db.maxZoomFactor
    db.partyCombatZoomFactor = ClampNumber(db.partyCombatZoomFactor, 1, maxYards) or db.worldCombatZoomFactor
    db.raidCombatZoomFactor = ClampNumber(db.raidCombatZoomFactor, 1, maxYards) or db.worldCombatZoomFactor
    db.pvpCombatZoomFactor = ClampNumber(db.pvpCombatZoomFactor, 1, maxYards) or db.partyCombatZoomFactor or db.raidCombatZoomFactor or db.worldCombatZoomFactor
    db.groupCombatZoomFactor = nil
    db.moveViewDistance = ClampNumber(db.moveViewDistance, 20, 50) or 50
    db.cameraYawMoveSpeed = ClampNumber(db.cameraYawMoveSpeed, 1, 360) or (ClampNumber(SafeGetCVar("cameraYawMoveSpeed"), 1, 360) or 180)
    db.cameraPitchMoveSpeed = ClampNumber(db.cameraPitchMoveSpeed, 1, 360) or (ClampNumber(SafeGetCVar("cameraPitchMoveSpeed"), 1, 360) or 90)
    db.zoomTransitionTime = ClampNumber(db.zoomTransitionTime, 0, 2) or 0.5
    db.dismountDelay = ClampNumber(db.dismountDelay, 0, 10) or 0
    db.worldCombatReturnDelay = ClampNumber(db.worldCombatReturnDelay, 0, 10) or 0.4
    db.partyCombatReturnDelay = ClampNumber(db.partyCombatReturnDelay, 0, 10) or 0.8
    db.raidCombatReturnDelay = ClampNumber(db.raidCombatReturnDelay, 0, 10) or 1.2
    db.cameraIndirectOffset = ClampNumber(db.cameraIndirectOffset, 0, 10) or 1.5
end


local DISTANCE_PRESET_BINDINGS = {
    maxZoomFactor = "manualMaxPreset",
    minZoomFactor = "normalZoomPreset",
    mountZoomFactor = "mountZoomPreset",
    worldCombatZoomFactor = "worldCombatPreset",
    partyCombatZoomFactor = "partyCombatPreset",
    raidCombatZoomFactor = "raidCombatPreset",
    pvpCombatZoomFactor = "pvpCombatPreset",
}

local PRESET_ORDER = { "manual", "client_default", "close", "balanced", "far", "max" }

local function RoundHalfUp(value)
    if not value then return 0 end
    return math.floor(value + 0.5)
end

local function GetPresetDistanceValue(presetId, db, distanceKey)
    if presetId == nil or presetId == "manual" then
        return nil
    end

    local defaults = ns.Database and ns.Database.DEFAULTS
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
    local defaultNormal = (defaults and defaults.BLIZZARD_DEFAULT_YARDS) or 20

    if presetId == "client_default" then
        if distanceKey == "maxZoomFactor" then
            return maxYards
        end
        return ClampNumber(defaultNormal, 1, maxYards) or defaultNormal
    elseif presetId == "close" then
        return ClampNumber(RoundHalfUp(maxYards * 0.35), 1, maxYards) or maxYards
    elseif presetId == "balanced" then
        return ClampNumber(RoundHalfUp(maxYards * 0.55), 1, maxYards) or maxYards
    elseif presetId == "far" then
        return ClampNumber(RoundHalfUp(maxYards * 0.75), 1, maxYards) or maxYards
    elseif presetId == "max" then
        return maxYards
    end

    return nil
end

local function GetDistancePresetId(db, distanceKey)
    if not db or not distanceKey then return "manual" end
    local presetKey = DISTANCE_PRESET_BINDINGS[distanceKey]
    if not presetKey then return "manual" end
    local presetId = db[presetKey]
    for _, validId in ipairs(PRESET_ORDER) do
        if presetId == validId then
            return presetId
        end
    end
    return "manual"
end

local function GetDistanceValue(db, distanceKey)
    if not db or not distanceKey then return nil, "manual", "manual" end

    local presetId = GetDistancePresetId(db, distanceKey)
    local manualValue = db[distanceKey]

    if presetId ~= "manual" then
        local presetValue = GetPresetDistanceValue(presetId, db, distanceKey)
        if presetValue ~= nil then
            return presetValue, "preset", presetId
        end
    end

    return manualValue, "manual", "manual"
end

local function GetContextDistanceKey(context)
    if context == "pvp" then
        return "pvpCombatZoomFactor"
    elseif context == "raid" then
        return "raidCombatZoomFactor"
    elseif context == "party" then
        return "partyCombatZoomFactor"
    end
    return "worldCombatZoomFactor"
end

function Functions:GetPresetChoices(distanceKey)
    local db = DB()
    local choices = {}
    for _, presetId in ipairs(PRESET_ORDER) do
        local yards = GetPresetDistanceValue(presetId, db, distanceKey)
        local label
        if presetId == "manual" then
            label = L["PRESET_MANUAL"] or "Manual"
        elseif presetId == "client_default" then
            label = string.format("%s (%.1f yd)", L["PRESET_CLIENT_DEFAULT"] or "Game Default", yards or 0)
        elseif presetId == "close" then
            label = string.format("%s (%.1f yd)", L["PRESET_CLOSE"] or "Close", yards or 0)
        elseif presetId == "balanced" then
            label = string.format("%s (%.1f yd)", L["PRESET_BALANCED"] or "Balanced", yards or 0)
        elseif presetId == "far" then
            label = string.format("%s (%.1f yd)", L["PRESET_FAR"] or "Far", yards or 0)
        elseif presetId == "max" then
            label = string.format("%s (%.1f yd)", L["PRESET_MAX"] or "Maximum", yards or 0)
        end
        choices[presetId] = label or presetId
    end
    return choices
end

function Functions:GetDistanceControlSnapshot(distanceKey)
    local db = DB()
    if not db then return nil end
    SanitizeRuntimeProfile(db)
    local effectiveValue, sourceType, presetId = GetDistanceValue(db, distanceKey)
    local manualValue = db[distanceKey]
    return {
        distanceKey = distanceKey,
        manualValue = manualValue,
        effectiveValue = effectiveValue or manualValue,
        sourceType = sourceType,
        presetId = presetId,
        isManual = (sourceType == "manual"),
    }
end


function Functions:GetPresetBindingKey(distanceKey)
    return DISTANCE_PRESET_BINDINGS[distanceKey]
end

function Functions:GetDistancePresetId(distanceKey)
    local db = DB()
    if not db then return "manual" end
    return GetDistancePresetId(db, distanceKey)
end

local function UpdateCVar(key, value)
    key = CanonicalCVarName(key)

    local db = DB()
    local normalizedValue = NormalizeManagedCVarValue(key, value, db)
    if normalizedValue == nil then return end

    local currentValue = SafeGetCVar(key)
    if currentValue == nil then return end

    local strValue = tostring(normalizedValue)

    if type(normalizedValue) == "number" then
        local numCurrent = tonumber(currentValue)
        if numCurrent and math_abs(numCurrent - normalizedValue) < 0.005 then
            return
        end
    else
        if currentValue == strValue then return end
    end

    local guard = ns.CVarGuard
    if guard and guard.BeginInternalWrite then
        guard:BeginInternalWrite()
    end

    isInternalUpdate = true
    SafeSetCVar(key, normalizedValue)
    isInternalUpdate = false

    if guard and guard.EndInternalWrite then
        guard:EndInternalWrite()
    end
end

-- =====================================================================
-- 7) MOUNT / TRAVEL DETECT
-- =====================================================================
function Functions:IsSkyriding()
    if IsMounted and IsMounted() and LibMountInfo and LibMountInfo.IsSkyriding then
        local ok, result = pcall(LibMountInfo.IsSkyriding, LibMountInfo)
        if ok then
            return result and true or false
        end
    end

    if IS_RETAIL and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        if HasPlayerAura(404464) then return true end
        if HasPlayerAura(404468) then return false end
    end

    return false
end

function Functions:GetMountZoomMode(db)
    local mode = db and db.mountZoomMode
    if mode == MOUNT_ZOOM_MODE_FLYING or mode == MOUNT_ZOOM_MODE_SKYRIDING or mode == MOUNT_ZOOM_MODE_FORMS then
        return mode
    end
    return MOUNT_ZOOM_MODE_ALL
end

local activeMountCache = {
    expiresAt = 0,
    mounted = false,
    mountID = nil,
    mountTypeID = nil,
    isFlying = false,
}

function Functions:InvalidateMountCache()
    activeMountCache.expiresAt = 0
end

function Functions:GetActiveMountID()
    local mounted = IsMounted and IsMounted() or false
    if not IS_RETAIL or not mounted or not C_MountJournal or not C_MountJournal.GetMountIDs or not C_MountJournal.GetMountInfoByID then
        activeMountCache.mounted = mounted
        activeMountCache.mountID = nil
        activeMountCache.mountTypeID = nil
        activeMountCache.isFlying = false
        activeMountCache.expiresAt = 0
        return nil
    end

    local now = GetTime and GetTime() or 0
    if activeMountCache.expiresAt > now and activeMountCache.mounted == mounted then
        return activeMountCache.mountID
    end

    local mountID = nil
    local okMountIDs, mountIDs = pcall(C_MountJournal.GetMountIDs)
    if okMountIDs and type(mountIDs) == "table" then
        for _, id in ipairs(mountIDs) do
            local ok, _, _, _, isActive = pcall(C_MountJournal.GetMountInfoByID, id)
            if ok and isActive then
                mountID = id
                break
            end
        end
    end

    activeMountCache.mounted = mounted
    activeMountCache.mountID = mountID
    activeMountCache.mountTypeID = nil
    activeMountCache.isFlying = false
    activeMountCache.expiresAt = now + 0.35

    return mountID
end

function Functions:IsFlyingMountActive()
    local mountID = self:GetActiveMountID()
    if not mountID or not C_MountJournal or not C_MountJournal.GetMountInfoExtraByID then
        return false, nil, mountID
    end

    if activeMountCache.mountID == mountID and activeMountCache.mountTypeID ~= nil then
        return activeMountCache.isFlying, activeMountCache.mountTypeID, mountID
    end

    local ok, _, _, _, _, mountTypeID = pcall(C_MountJournal.GetMountInfoExtraByID, mountID)
    if not ok then
        return false, nil, mountID
    end

    activeMountCache.mountTypeID = mountTypeID
    activeMountCache.isFlying = (mountTypeID and FLYCAM_FLYING_MOUNT_TYPES[mountTypeID]) and true or false

    return activeMountCache.isFlying, mountTypeID, mountID
end

function Functions:IsDragonRacingRaceActive()
    if not (IsMounted and IsMounted()) then
        return false
    end

    if IS_RETAIL and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for spellID in pairs(DRAGONRACING_RACE_AURAS) do
            if HasPlayerAura(spellID) then
                return true
            end
        end
    end

    -- AuraUtil.ForEachAura walks auras by index. As of 12.1, every index-, slot-
    -- and instanceID-based aura lookup raises a Lua error whenever auras are
    -- secret - which is exactly when a dragonriding race is running. The
    -- spellID path above already covers every ID in DRAGONRACING_RACE_AURAS on
    -- those clients, so the scan is now a fallback only for builds that lack
    -- GetPlayerAuraBySpellID (Classic flavors and pre-Midnight retail).
    local hasSpellIDLookup = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and true or false

    if AuraUtil and AuraUtil.ForEachAura and not hasSpellIDLookup then
        local canaccessvalue = _G.canaccessvalue
        -- was misspelled as _G.isecretvalue, which silently disabled this guard
        -- and let secret aura spellIDs reach the table lookup below.
        local issecretvalue = _G.issecretvalue
        local inRace = false

        local function HasSafeDragonracingAuraSpellID(spellId)
            if spellId == nil then
                return false
            end

            if issecretvalue and issecretvalue(spellId) then
                return false
            end

            local ok, result = pcall(function()
                return DRAGONRACING_RACE_AURAS[spellId]
            end)

            return ok and result == true
        end

        local function CheckAura(auraData)
            if canaccessvalue and not canaccessvalue(auraData) then
                return
            end

            local spellId = auraData and auraData.spellId
            if HasSafeDragonracingAuraSpellID(spellId) then
                inRace = true
                return true
            end
        end

        pcall(AuraUtil.ForEachAura, "player", "HELPFUL", nil, CheckAura, true)
        if inRace then
            return true
        end
    end

    return false
end

function Functions:IsFlyingTravelContext()
    if self:IsSkyriding() then
        return true
    end

    local isFlyingMount = self:IsFlyingMountActive()
    if isFlyingMount then
        return true
    end

    local formIndex = GetShapeshiftForm and GetShapeshiftForm() or nil
    if formIndex and formIndex > 0 and GetShapeshiftFormInfo then
        local spellID = GetShapeshiftFormSpellID(formIndex)
        if spellID and FLYING_TRAVEL_FORM_IDS[spellID] then
            return true
        end
    end

    if IS_RETAIL and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for spellID in pairs(FLYING_TRAVEL_BUFF_IDS) do
            if HasPlayerAura(spellID) then
                return true
            end
        end
    end

    return false
end

function Functions:IsTravelFormOnlyActive()
    if LibMountInfo and LibMountInfo.IsMounted then
        local ok, mounted = pcall(LibMountInfo.IsMounted, LibMountInfo)
        if ok and mounted then
            return false
        end
    elseif IsMounted and IsMounted() then
        return false
    end

    local formIndex = GetShapeshiftForm and GetShapeshiftForm() or nil
    if formIndex and formIndex > 0 and GetShapeshiftFormInfo then
        local spellID = GetShapeshiftFormSpellID(formIndex)
        if spellID and TRAVEL_FORM_IDS[spellID] then
            return true
        end
    end

    if IS_RETAIL and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for spellID in pairs(TRAVEL_BUFF_IDS) do
            if HasPlayerAura(spellID) then
                return true
            end
        end
    else
        local UnitBuff = _G.UnitBuff
        if UnitBuff then
            for i = 1, 40 do
                local okBuff, _, _, _, _, _, _, _, _, _, spellID = pcall(UnitBuff, "player", i)
                if not okBuff or not spellID then break end
                if TRAVEL_BUFF_IDS[spellID] then
                    return true
                end
            end
        end
    end

    return false
end

function Functions:ShouldUseMountZoom(db)
    if not IsInTravelForm() then
        return false
    end

    local mode = self:GetMountZoomMode(db)
    if mode == MOUNT_ZOOM_MODE_SKYRIDING then
        return self:IsSkyriding() or self:IsDragonRacingRaceActive()
    elseif mode == MOUNT_ZOOM_MODE_FLYING then
        return self:IsFlyingTravelContext()
    elseif mode == MOUNT_ZOOM_MODE_FORMS then
        return self:IsTravelFormOnlyActive()
    end

    return true
end

function Functions:ShouldUseDragonRacingFirstPerson(db)
    if not (db and db.dragonRacingRaceFirstPerson) then
        return false
    end

    if not self:IsDragonRacingRaceActive() then
        return false
    end

    return self:IsFlyingTravelContext()
end

function IsInTravelForm()
    if LibMountInfo and LibMountInfo.IsMounted then
        local ok, mounted = pcall(LibMountInfo.IsMounted, LibMountInfo)
        if ok and mounted then return true end
    else
        if IsMounted and IsMounted() then return true end
    end

    local formIndex = GetShapeshiftForm and GetShapeshiftForm() or nil
    if formIndex and formIndex > 0 and GetShapeshiftFormInfo then
        local spellID = GetShapeshiftFormSpellID(formIndex)
        if spellID and TRAVEL_FORM_IDS[spellID] then return true end
    end

    if IS_RETAIL then
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            for spellID in pairs(TRAVEL_BUFF_IDS) do
                if HasPlayerAura(spellID) then return true end
            end
        end
    else
        local UnitBuff = _G.UnitBuff
        if UnitBuff then
            for i = 1, 40 do
                local okBuff, _, _, _, _, _, _, _, _, _, spellID = pcall(UnitBuff, "player", i)
                if not okBuff or not spellID then break end
                if TRAVEL_BUFF_IDS[spellID] then return true end
            end
        end
    end

    return false
end

-- =====================================================================
-- 8) TRANSITIONS (fix race conditions)
-- =====================================================================
local function CancelTransition()
    pendingReturnInfo = nil
    if CameraStateController and CameraStateController.ClearPendingReturn then
        CameraStateController:ClearPendingReturn()
        CameraStateController:TouchTransition()
    end

    if not transitionTimer then return end

    if type(transitionTimer) == "table" and type(transitionTimer.Cancel) == "function" then
        pcall(function() transitionTimer:Cancel() end)
    elseif C_Timer and C_Timer.CancelTimer then
        pcall(C_Timer.CancelTimer, transitionTimer)
    end

    transitionTimer = nil
end

local function ScheduleTransition(delay, callback)
    CancelTransition()

    if not (C_Timer and (C_Timer.NewTimer or C_Timer.After)) then
        callback()
        return
    end

    if C_Timer.NewTimer then
        transitionTimer = C_Timer.NewTimer(delay, function()
            transitionTimer = nil
            callback()
        end)
        return
    end

    transitionTimer = true
    C_Timer.After(delay, function()
        if transitionTimer ~= true then return end
        transitionTimer = nil
        callback()
    end)
end
local function GetCombatReturnDelay(db, context)
    if not db then return 0 end

    if context == "raid" then
        return db.raidCombatReturnDelay or 0
    elseif context == "party" then
        return db.partyCombatReturnDelay or 0
    end

    return db.worldCombatReturnDelay or 0
end

local function GetPendingReturnRemaining()
    if not pendingReturnInfo or not pendingReturnInfo.fireAt or not GetTime then
        return 0
    end
    return math.max(0, pendingReturnInfo.fireAt - GetTime())
end


local function NormalizeTargetYards(targetYards)
    local defaults = ns.Database and ns.Database.DEFAULTS
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
    return ClampNumber(targetYards, 1, maxYards) or maxYards
end

local function ApplyZoomCap(targetYards)
    targetYards = NormalizeTargetYards(targetYards)
    local targetFactor = targetYards / CONVERSION_RATIO

    if SafeGetCVar("cameraDistanceMaxZoomFactor") ~= nil then
        UpdateCVar("cameraDistanceMaxZoomFactor", targetFactor)
    end

    if SafeGetCVar("cameraDistanceMax") ~= nil then
        UpdateCVar("cameraDistanceMax", targetYards)
    end
end

local function IsZoomCapAligned(targetYards)
    targetYards = NormalizeTargetYards(targetYards)
    local targetFactor = targetYards / CONVERSION_RATIO
    local currentFactor = SafeGetCVar("cameraDistanceMaxZoomFactor")
    local currentMax = SafeGetCVar("cameraDistanceMax")

    if currentFactor ~= nil and math_abs(currentFactor - targetFactor) > 0.01 then
        return false
    end

    if currentMax ~= nil and math_abs(currentMax - targetYards) > 0.1 then
        return false
    end

    return true
end

local function ApplyZoomTransition(targetYards, transitionTime)
    targetYards = NormalizeTargetYards(targetYards)
    lastAutoAppliedZoomYards = targetYards
    lastAutoAppliedAt = (GetTime and GetTime() or 0)

    local targetFactor = targetYards / CONVERSION_RATIO
    local currentFactor = SafeGetCVar("cameraDistanceMaxZoomFactor")

    if currentFactor == nil then
        currentFactor = targetFactor
    end

    -- If we are shrinking max factor, do zoom first then lower cap (prevents snap)
    if targetFactor < currentFactor then
        if LibCamera and LibCamera.SetZoomUsingCVar then
            SafeLibCall(LibCamera, "SetZoomUsingCVar", targetYards, transitionTime)
        end

        local myToken = stateToken
        ScheduleTransition((transitionTime or 0) + 0.05, function()
            -- If state changed since scheduling, ignore (prevents stale restore)
            if myToken ~= stateToken then return end
            ApplyZoomCap(targetYards)
        end)
    else
        ApplyZoomCap(targetYards)
        if LibCamera and LibCamera.SetZoomUsingCVar then
            SafeLibCall(LibCamera, "SetZoomUsingCVar", targetYards, transitionTime)
        end
    end
end

local function ApplyManualCameraCapOnly(targetYards, reason)
    -- Manual mode must only update the maximum camera cap.
    -- It must not call LibCamera, CameraZoomIn/Out, or change cameraZoomSpeed;
    -- otherwise the addon fights normal mouse-wheel zooming.
    targetYards = NormalizeTargetYards(targetYards)
    lastAutoAppliedZoomYards = nil
    ApplyZoomCap(targetYards)
    Functions:logMessage("debug", "Manual camera cap only: " .. tostring(reason or "manual") .. " -> " .. tostring(targetYards))
    return targetYards
end

function Functions:ApplyManualCameraCapOnly(reason)
    local db = DB()
    if not db then return nil end
    SanitizeRuntimeProfile(db)
    local maxYards = (ns.Database and ns.Database.DEFAULTS and ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
    local manualTargetYards = (GetDistanceValue(db, "maxZoomFactor")) or db.maxZoomFactor or maxYards
    return ApplyManualCameraCapOnly(manualTargetYards, reason or "manual")
end

-- =====================================================================
-- 9) EVENT THROTTLING
-- =====================================================================
function Functions:ScheduleStabilizedUpdate(delays, forceNow)
    if not C_Timer or not C_Timer.After then
        if forceNow then
            self:AdjustCamera(true)
        else
            self:RequestUpdate()
        end
        return
    end

    refreshBurstToken = refreshBurstToken + 1
    local myToken = refreshBurstToken
    local burstDelays = delays or { 0, 0.2, 0.8 }

    for _, delay in ipairs(burstDelays) do
        C_Timer.After(delay, function()
            if myToken ~= refreshBurstToken then return end
            if forceNow then
                Functions:AdjustCamera(true)
            else
                Functions:RequestUpdate()
            end
        end)
    end
end

function Functions:RequestUpdate()
    self:InvalidateRuntimeCaches()
    if updatePending then return end
    updatePending = true
    updateFrame:Show()
end

updateFrame:SetScript("OnUpdate", function(self)
    if not updatePending then
        self:Hide()
        return
    end
    updatePending = false
    self:Hide()

    -- Always refresh ActionCam too, so shoulder mode can switch on combat enter/leave
    Functions:UpdateActionCam()
    Functions:UpdateSmartZoomState("auto_update")
end)

-- =====================================================================
-- 10) COMBAT DETECT (group-safe)
-- =====================================================================
function Functions:IsGroupInCombat()
    -- This helper is intentionally GROUP-ONLY. Personal combat should be
    -- checked separately. The result is cached very briefly because the same
    -- camera pass can ask for it from ActionCam, Smart Zoom and status logic.
    local inRaid = SafeBoolCall(IsInRaid)
    local inGroup = (not inRaid) and SafeBoolCall(IsInGroup)
    local memberCount = 0
    if inRaid then
        memberCount = tonumber(SafeValueCall(GetNumGroupMembers)) or 0
    elseif inGroup then
        memberCount = tonumber(SafeValueCall(GetNumSubgroupMembers)) or 0
    end

    local key = (inRaid and "raid" or (inGroup and "party" or "solo")) .. ":" .. tostring(memberCount)
    local now = GetTime and GetTime() or 0

    if runtimeCache.groupCombatKey == key
        and runtimeCache.groupCombatExpiresAt > now
        and runtimeCache.groupCombat ~= nil then
        return runtimeCache.groupCombat
    end

    local result = false

    -- One pcall around the whole scan instead of three per unit. A 40-man raid
    -- used to cost up to 120 pcalls every time this cache expired.
    -- Every one of these three calls is conditionally secret for group members
    -- in instanced content. Previously a single secret return raised an error
    -- that unwound the whole loop through the outer pcall, so one unreadable
    -- unit made the entire raid read as "not in combat". Screening each result
    -- keeps the scan going and simply ignores the units we cannot read.
    local function ScanUnits(prefix, count)
        for i = 1, count do
            local unit = prefix .. i
            local exists = IsTruthySafe(SafeValueCall(UnitExists, unit))
            if exists then
                local isSelf = IsTruthySafe(SafeValueCall(UnitIsUnit, unit, "player"))
                if not isSelf and IsTruthySafe(SafeValueCall(UnitAffectingCombat, unit)) then
                    return true
                end
            end
        end
        return false
    end

    if inRaid then
        if SafeBoolCall(IsEncounterInProgress) then
            result = true
        else
            -- Cap defensive scan size. GetNumGroupMembers can briefly be stale during roster changes.
            local ok, scanned = pcall(ScanUnits, "raid", math.min(memberCount, 40))
            result = ok and scanned or false
        end
    elseif inGroup then
        local ok, scanned = pcall(ScanUnits, "party", math.min(memberCount, 4))
        result = ok and scanned or false
    end

    runtimeCache.groupCombatKey = key
    runtimeCache.groupCombat = result
    runtimeCache.groupCombatExpiresAt = now + GROUP_COMBAT_CACHE_SECONDS

    return result
end

local function GetCombatContextRaw()
    local inInstance, instanceType = SafeIsInInstance()

    if inInstance then
        if instanceType == "arena" or instanceType == "pvp" then
            return "pvp"
        end

        if instanceType == "raid" then
            return "raid"
        end

        if instanceType == "party" or instanceType == "scenario" then
            return "party"
        end
    end

    if SafeBoolCall(IsInRaid) then
        return "raid"
    end

    if SafeBoolCall(IsInGroup) then
        return "party"
    end

    return "world"
end

local ShouldForceCombatZoom

local function GetCombatTargetYards(db, context)
    local defaults = ns.Database and ns.Database.DEFAULTS
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or 39
    local resolvedContext = context or "world"
    local distanceKey = GetContextDistanceKey(resolvedContext)
    local value = GetDistanceValue(db, distanceKey)
    return value or db.worldCombatZoomFactor or db.maxZoomFactor or maxYards, distanceKey
end

local function GetCombatSignals(db)
    local now = GetTime and GetTime() or 0
    if runtimeCache.combatSignals
        and runtimeCache.combatSignalsDb == db
        and runtimeCache.combatSignalsExpiresAt > now then
        return runtimeCache.combatSignals
    end

    local threatStatus = SafeValueCall(UnitThreatSituation, "player")
    local mountedRaw = IsInTravelForm()
    local mountZoomActive = mountedRaw and Functions:ShouldUseMountZoom(db) or false
    local isSkyriding = mountedRaw and Functions:IsSkyriding() or false
    local isDragonRacing = mountedRaw and Functions:IsDragonRacingRaceActive() or false
    local isFlyingMount, mountTypeID, activeMountID = false, nil, nil

    if mountedRaw then
        isFlyingMount, mountTypeID, activeMountID = Functions:IsFlyingMountActive()
    end

    local signals = {
        playerInCombat = SafeBoolCall(UnitAffectingCombat, "player"),
        groupInCombat = Functions:IsGroupInCombat(),
        hasThreat = (threatStatus ~= nil and threatStatus > 0) and true or false,
        isMounted = mountedRaw,
        mountZoomActive = mountZoomActive,
        isSkyriding = isSkyriding,
        isDragonRacing = isDragonRacing,
        isFlyingMount = isFlyingMount and true or false,
        mountTypeID = mountTypeID,
        activeMountID = activeMountID,
        mountZoomMode = Functions:GetMountZoomMode(db),
        dragonRacingFirstPerson = Functions:ShouldUseDragonRacingFirstPerson(db),
        forceCombatZoom = (db and ShouldForceCombatZoom(db)) and true or false,
        rawContext = GetCombatContextRaw(),
    }

    runtimeCache.combatSignals = signals
    runtimeCache.combatSignalsDb = db
    runtimeCache.combatSignalsExpiresAt = now + RUNTIME_SIGNAL_CACHE_SECONDS

    return signals
end

local function GetCombatTriggerConfig(db)
    return {
        player = (db and db.combatZoomOnPlayer ~= false) and true or false,
        group = (db and db.combatZoomOnGroup ~= false) and true or false,
        threat = (db and db.combatZoomOnThreat ~= false) and true or false,
    }
end

local function GetCombatActivation(db, signals)
    local triggerConfig = GetCombatTriggerConfig(db)
    local activeTriggers = {
        player = triggerConfig.player and signals.playerInCombat or false,
        group = triggerConfig.group and signals.groupInCombat or false,
        threat = triggerConfig.threat and signals.hasThreat or false,
        worldBoss = signals.forceCombatZoom and true or false,
    }
    local isActive = activeTriggers.player or activeTriggers.group or activeTriggers.threat or activeTriggers.worldBoss
    return isActive, triggerConfig, activeTriggers
end

local function BuildStatusSnapshot(db)
    local defaults = ns.Database and ns.Database.DEFAULTS
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or 39

    local signals = GetCombatSignals(db)
    local rawContext = signals.rawContext
    local resolvedContext = rawContext
    local combatActive, triggerConfig, activeTriggers = GetCombatActivation(db, signals)

    local state = ZOOM_STATE_NORMAL
    if db and afkActive then
        state = ZOOM_STATE_AFK
    elseif db and db.dragonRacingRaceFirstPerson and signals.dragonRacingFirstPerson then
        state = ZOOM_STATE_DRAGON_RACE_FIRST_PERSON
    elseif db and db.autoCombatZoom and combatActive then
        state = ZOOM_STATE_COMBAT
    elseif db and db.autoMountZoom and signals.mountZoomActive then
        state = ZOOM_STATE_MOUNT
    elseif db and not db.autoCombatZoom and not db.autoMountZoom then
        state = ZOOM_STATE_MANUAL
    end

    local targetYards, targetDistanceKey, targetSourceType, targetPresetId
    if not db then
        targetYards = maxYards
        targetDistanceKey = "maxZoomFactor"
        targetSourceType = "manual"
        targetPresetId = "manual"
    elseif state == ZOOM_STATE_AFK then
        targetYards = maxYards
        targetDistanceKey = "maxZoomFactor"
        targetSourceType = "afk"
        targetPresetId = "afk"
    elseif state == ZOOM_STATE_DRAGON_RACE_FIRST_PERSON then
        targetYards = RACE_FIRST_PERSON_YARDS
        targetDistanceKey = "mountZoomFactor"
        targetSourceType = "dragonrace_first_person"
        targetPresetId = "dragonrace_first_person"
    elseif state == ZOOM_STATE_COMBAT then
        local combatDistanceKey
        targetYards, combatDistanceKey = GetCombatTargetYards(db, resolvedContext)
        targetDistanceKey = combatDistanceKey
        local _, sourceType, presetId = GetDistanceValue(db, combatDistanceKey)
        targetSourceType = sourceType
        targetPresetId = presetId
    elseif state == ZOOM_STATE_MOUNT then
        targetDistanceKey = "mountZoomFactor"
        if signals.dragonRacingFirstPerson then
            targetYards = RACE_FIRST_PERSON_YARDS
            targetSourceType = "dragonrace_first_person"
            targetPresetId = "dragonrace_first_person"
        else
            targetYards, targetSourceType, targetPresetId = GetDistanceValue(db, targetDistanceKey)
            targetYards = targetYards or db.mountZoomFactor or db.maxZoomFactor or maxYards
        end
    elseif db.autoCombatZoom then
        targetDistanceKey = "minZoomFactor"
        targetYards, targetSourceType, targetPresetId = GetDistanceValue(db, targetDistanceKey)
        targetYards = targetYards or db.minZoomFactor or 15
    else
        targetDistanceKey = "maxZoomFactor"
        targetYards, targetSourceType, targetPresetId = GetDistanceValue(db, targetDistanceKey)
        targetYards = targetYards or db.maxZoomFactor or maxYards
    end

    local pendingReturnActive = pendingReturnInfo ~= nil
    local pendingReturnContext = pendingReturnActive and pendingReturnInfo.context or nil
    local pendingReturnKind = pendingReturnActive and pendingReturnInfo.kind or nil
    local pendingReturnDelay = pendingReturnActive and pendingReturnInfo.delay or 0
    local pendingReturnRemaining = pendingReturnActive and GetPendingReturnRemaining() or 0

    local controllerSnapshot = CameraStateController and CameraStateController.GetSnapshot and CameraStateController:GetSnapshot() or nil

    return {
        state = state,
        previousState = controllerSnapshot and controllerSnapshot.previousState or nil,
        stateToken = controllerSnapshot and controllerSnapshot.stateToken or stateToken,
        transitionToken = controllerSnapshot and controllerSnapshot.transitionToken or nil,
        sourceEvent = controllerSnapshot and controllerSnapshot.sourceEvent or nil,
        rawContext = rawContext,
        resolvedContext = resolvedContext,
        targetYards = targetYards,
        targetDistanceKey = targetDistanceKey,
        targetSourceType = targetSourceType,
        targetPresetId = targetPresetId,
        playerInCombat = signals.playerInCombat,
        groupInCombat = signals.groupInCombat,
        hasThreat = signals.hasThreat,
        isMounted = signals.isMounted,
        mountZoomActive = signals.mountZoomActive,
        mountZoomMode = signals.mountZoomMode,
        isFlyingMount = signals.isFlyingMount,
        isSkyriding = signals.isSkyriding,
        isDragonRacing = signals.isDragonRacing,
        dragonRacingFirstPerson = signals.dragonRacingFirstPerson,
        activeMountID = signals.activeMountID,
        mountTypeID = signals.mountTypeID,
        forceWorldBoss = signals.forceCombatZoom,
        reduceUnexpectedMovement = (db and db.reduceUnexpectedMovement) and true or false,
        indirectCollisionEnabled = (db and db.cameraIndirectVisibility) and true or false,
        indirectCollisionOffset = (db and db.cameraIndirectOffset) or 1.5,
        occludedSilhouetteEnabled = (db and db.occludedSilhouettePlayer) and true or false,
        triggerConfig = triggerConfig,
        activeTriggers = activeTriggers,
        worldCombatReturnDelay = (db and db.worldCombatReturnDelay) or 0,
        partyCombatReturnDelay = (db and db.partyCombatReturnDelay) or 0,
        raidCombatReturnDelay = (db and db.raidCombatReturnDelay) or 0,
        mountReturnDelay = (db and db.dismountDelay) or 0,
        pendingReturnActive = pendingReturnActive,
        pendingReturnContext = pendingReturnContext,
        pendingReturnKind = pendingReturnKind,
        pendingReturnDelay = pendingReturnDelay,
        pendingReturnRemaining = pendingReturnRemaining,
        zoomRestoreSetting = (db and db.zoomRestoreSetting) or "adaptive",
        respectManualStateZoom = (db and db.respectManualStateZoom ~= false) and true or false,
        afkActive = afkActive and true or false,
        actionCamShoulderActive = (SafeGetCVar("test_cameraOverShoulder") or 0) ~= 0,
        dynamicPitchActive = (SafeGetCVar("test_cameraDynamicPitch") or 0) == 1,
        mountManualOverride = stateManualOverride[ZOOM_STATE_MOUNT] and true or false,
        combatManualOverride = stateManualOverride[ZOOM_STATE_COMBAT] and true or false,
    }
end

local function GetCurrentZoomContext(db)
    local snapshot = BuildStatusSnapshot(db)
    return snapshot.state, snapshot.resolvedContext, snapshot
end

ShouldForceCombatZoom = function(db)
    -- IsEncounterInProgress does not exist on every branch (it is missing on the
    -- oldest Classic clients). This runs on every camera pass, so an unguarded
    -- call produced continuous Lua errors there.
    local inInstance = SafeIsInInstance()
    if inInstance then
        return false
    end

    return SafeBoolCall(IsEncounterInProgress)
end

local function ClampAfkDelay(value)
    value = tonumber(value)
    if not value or value ~= value then
        return AFK_DEFAULT_DELAY
    end
    return math.max(0, math.min(30, math_floor(value + 0.5)))
end

local function ClampAfkRotationSpeed(value)
    value = tonumber(value)
    if not value or value ~= value then
        return AFK_DEFAULT_SPEED
    end
    value = math_floor(value * 10 + 0.5) / 10
    return math.max(0.1, math.min(2.0, value))
end

local function NormalizeAfkDirection(value)
    return (value == "left") and "left" or "right"
end

local function IsPlayerAFKSafe()
    local ok, isAfk = pcall(function()
        return tostring(UnitIsAFK("player")) == "true"
    end)
    return ok and isAfk or false
end

local function IsProfessionActivityBlockingAfk()
    if not IS_RETAIL then
        return false
    end

    if type(IsRecipeRepeating) == "function" and IsRecipeRepeating() then
        return true
    end

    if _G.ProfessionsFrame and _G.ProfessionsFrame:IsShown() then
        return true
    end

    if _G.ProfessionsCustomerOrdersFrame and _G.ProfessionsCustomerOrdersFrame:IsShown() then
        return true
    end

    return false
end

local function StopAfkRotation()
    SafeFunctionCall(MoveViewRightStop)
    SafeFunctionCall(MoveViewLeftStop)
end

local function ShowUiAfterAfk()
    if afkUIHidden then
        SafeFunctionCall(UIParent and UIParent.Show, UIParent)
        afkUIHidden = false
    end
    safeExitFrame:Hide()
end

local function ApplyAfkZoom(db)
    if not db or db.afkZoomOut == false then return end

    local maxYards = (ns.Database and ns.Database.DEFAULTS and ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE)
        or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
    local transition = math.max(0.2, math.min(4, tonumber(db.zoomTransitionTime) or 0.5))

    ApplyZoomCap(maxYards)
    if LibCamera and LibCamera.SetZoomUsingCVar then
        SafeLibCall(LibCamera, "SetZoomUsingCVar", maxYards, transition)
    end
end

local function StartAfkRotation(db)
    if not db then return end

    local speed = ClampAfkRotationSpeed(db.afkRotationSpeed)
    local direction = NormalizeAfkDirection(db.afkDirection)

    StopAfkRotation()

    if direction == "left" then
        SafeFunctionCall(MoveViewLeftStart, speed)
    else
        SafeFunctionCall(MoveViewRightStart, speed)
    end
end

local function CanEnterAfkMode(db)
    if not db or not db.afkMode then
        return false, "disabled"
    end

    if not IsPlayerAFKSafe() then
        return false, "not_afk"
    end

    if SafeBoolCall(UnitAffectingCombat, "player") then
        return false, "in_combat"
    end

    if SafeBoolCall(UnitIsDead, "player") or SafeBoolCall(UnitIsGhost, "player") then
        return false, "dead"
    end

    if SafeBoolCall(UnitOnTaxi, "player") then
        return false, "on_taxi"
    end

    if db.afkSkipMounted ~= false and SafeBoolCall(IsMounted) then
        return false, "mounted"
    end

    if db.afkSkipFlying ~= false and SafeBoolCall(IsFlying) then
        return false, "flying"
    end

    if IsProfessionActivityBlockingAfk() then
        return false, "professions"
    end

    return true, nil
end

local ExitAfkMode

local function EnterAfkMode(db)
    if afkActive or not db then return end

    afkActive = true
    afkResumeAfterCombat = false

    ApplyAfkZoom(db)
    StartAfkRotation(db)

    if db.afkHideUI ~= false then
        SafeFunctionCall(CloseAllWindows)
        SafeFunctionCall(UIParent and UIParent.Hide, UIParent)
        afkUIHidden = true
        safeExitFrame:Show()
    else
        ShowUiAfterAfk()
    end

    Functions:logMessage("info", L["AFK_ENTER_MSG"] or "AFK Mode: enabled (cinematic rotation).")
end

ExitAfkMode = function(reason, suppressUntilClear, restoreCamera)
    afkPendingToken = afkPendingToken + 1

    if suppressUntilClear then
        afkSuppressUntilClear = true
    end

    local hadActiveAfk = afkActive or afkUIHidden

    StopAfkRotation()
    ShowUiAfterAfk()

    afkActive = false

    if hadActiveAfk then
        Functions:logMessage("info", L["AFK_EXIT_MSG"] or "AFK Mode: disabled (restored UI and camera).")
    end

    if restoreCamera ~= false and ns.Functions and ns.Functions.AdjustCamera then
        ns.Functions:AdjustCamera(true)
    end
end

local function ScheduleAfkModeEntry(db)
    afkPendingToken = afkPendingToken + 1
    local token = afkPendingToken
    local delay = ClampAfkDelay(db and db.afkDelay)

    if delay <= 0 then
        local currentDb = DB()
        local canEnter = currentDb and CanEnterAfkMode(currentDb)
        if canEnter and token == afkPendingToken then
            EnterAfkMode(currentDb)
        end
        return
    end

    if not (C_Timer and C_Timer.After) then
        local currentDb = DB()
        local canEnter = currentDb and CanEnterAfkMode(currentDb)
        if canEnter and token == afkPendingToken then
            EnterAfkMode(currentDb)
        end
        return
    end

    C_Timer.After(delay, function()
        if token ~= afkPendingToken then return end

        local currentDb = DB()
        if not currentDb then return end

        local canEnter = CanEnterAfkMode(currentDb)
        if not canEnter then return end

        EnterAfkMode(currentDb)
    end)
end

function Functions:ManualExitAfkMode()
    ExitAfkMode("manual_exit", true, true)
end

function Functions:RefreshAfkMode(force)
    local db = DB()
    if not db then return end

    local isAfk = IsPlayerAFKSafe()
    if not isAfk then
        afkSuppressUntilClear = false
    end

    if not db.afkMode then
        afkResumeAfterCombat = false
        if afkActive or afkUIHidden then
            ExitAfkMode("disabled", false, true)
        else
            afkPendingToken = afkPendingToken + 1
        end
        return
    end

    if not isAfk then
        afkResumeAfterCombat = false
        if afkActive or afkUIHidden then
            ExitAfkMode("not_afk", false, true)
        else
            afkPendingToken = afkPendingToken + 1
        end
        return
    end

    if afkSuppressUntilClear then
        afkPendingToken = afkPendingToken + 1
        return
    end

    local canEnter, reason = CanEnterAfkMode(db)
    if not canEnter then
        if reason == "in_combat" then
            afkResumeAfterCombat = (db.afkResumeAfterCombat ~= false) and true or false
            if afkResumeAfterCombat == false and (afkActive or afkUIHidden) then
                afkSuppressUntilClear = true
            end
        else
            afkResumeAfterCombat = false
        end

        if afkActive or afkUIHidden then
            ExitAfkMode(reason, false, true)
        else
            afkPendingToken = afkPendingToken + 1
        end
        return
    end

    afkResumeAfterCombat = false

    if afkActive then
        if force then
            ApplyAfkZoom(db)
            StartAfkRotation(db)
            if db.afkHideUI ~= false then
                SafeFunctionCall(CloseAllWindows)
                SafeFunctionCall(UIParent and UIParent.Hide, UIParent)
                afkUIHidden = true
                safeExitFrame:Show()
            else
                ShowUiAfterAfk()
            end
        end
        return
    end

    ScheduleAfkModeEntry(db)
end

function Functions:IsAfkModeActive()
    return afkActive
end

-- =====================================================================
-- 11) ACTIONCAM SHOULDER (dynamic shoulder offset + model compensation)
-- =====================================================================
safeExitFrame:Hide()
safeExitFrame:SetAllPoints(WorldFrame)
safeExitFrame:SetFrameStrata("TOOLTIP")
safeExitFrame:EnableKeyboard(true)
if safeExitFrame.SetPropagateKeyboardInput then
    safeExitFrame:SetPropagateKeyboardInput(false)
end
safeExitFrame:SetScript("OnKeyDown", function(_, key)
    if key == "ESCAPE" then
        Functions:ManualExitAfkMode()
    end
end)
if UISpecialFrames and safeExitFrame.GetName then
    tinsert(UISpecialFrames, safeExitFrame:GetName())
end

local shoulderRefreshToken = 0
local raceFirstPersonApplied = false

local function ApplyRaceFirstPersonZoom()
    ApplyZoomCap(RACE_FIRST_PERSON_YARDS)
    if LibCamera and LibCamera.SetZoomUsingCVar then
        SafeLibCall(LibCamera, "SetZoomUsingCVar", RACE_FIRST_PERSON_YARDS, 0.20)
    end
end

local function GetShoulderOffsetZoomFactor(zoomLevel)
    local startOffset = 5.0
    local endOffset = 2.0

    if zoomLevel < endOffset then
        return 0
    elseif zoomLevel > startOffset then
        return 1
    else
        return (zoomLevel - endOffset) / (startOffset - endOffset)
    end
end

function Functions:ApplyShoulderOffset(force)
    local db = DB()
    if not db then return end

    if raceFirstPersonApplied or not shoulderHandlerFrame:IsShown() then
        shoulderHandlerFrame.lastZoom = -1
        UpdateCVar("test_cameraOverShoulder", 0)
        return
    end

    local currentZoom = (GetCameraZoom and GetCameraZoom()) or 0
    if (not force) and math_abs(shoulderHandlerFrame.lastZoom - currentZoom) < 0.01 then
        return
    end
    shoulderHandlerFrame.lastZoom = currentZoom

    local zoomFactor = GetShoulderOffsetZoomFactor(currentZoom)
    local baseOffset = 1.0
    local modelFactor = 1.0

    if ShoulderCompensation and ShoulderCompensation.GetFactor then
        local okFactor, value = pcall(ShoulderCompensation.GetFactor, ShoulderCompensation)
        if okFactor and tonumber(value) then
            modelFactor = value
        elseif not okFactor then
            Functions:logMessage("warning", "Shoulder compensation failed; using neutral offset factor.")
        end
    end

    UpdateCVar("test_cameraOverShoulder", baseOffset * zoomFactor * modelFactor)
end

local shoulderRefreshQueued = false
local shoulderRefreshAgain = false

function Functions:RequestShoulderRefresh()
    if shoulderRefreshQueued then
        shoulderRefreshAgain = true
        return
    end

    shoulderRefreshQueued = true
    shoulderHandlerFrame.lastZoom = -1

    local function RefreshShoulderNow(isFinalPass)
        if ShoulderCompensation and ShoulderCompensation.Invalidate then
            ShoulderCompensation:Invalidate()
        end
        Functions:ApplyShoulderOffset(true)
        RequestCVarGuardRefresh(isFinalPass == true)
    end

    local function FinishSeries()
        shoulderRefreshQueued = false
        if shoulderRefreshAgain then
            shoulderRefreshAgain = false
            Functions:RequestShoulderRefresh()
        end
    end

    if not (C_Timer and C_Timer.After) then
        RefreshShoulderNow(true)
        FinishSeries()
        return
    end

    local delays = { 0, 0.05, 0.18 }
    local lastIndex = #delays
    for index, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if not shoulderRefreshQueued then return end
            RefreshShoulderNow(index == lastIndex)
            if index == lastIndex then
                FinishSeries()
            end
        end)
    end
end

shoulderHandlerFrame.lastZoom = -1
shoulderHandlerFrame.lastTick = 0
shoulderHandlerFrame:SetScript("OnUpdate", function(self)
    local now = GetTime and GetTime() or 0
    if now > 0 and (now - (self.lastTick or 0)) < SHOULDER_UPDATE_INTERVAL then
        return
    end
    self.lastTick = now
    Functions:ApplyShoulderOffset(false)
end)
shoulderHandlerFrame:Hide()

function Functions:ShouldEnableShoulderNow()
    local db = DB()
    if not db then return false end

    local signals = GetCombatSignals(db)
    local inCombat = GetCombatActivation(db, signals)

    if inCombat then
        return db.actionCamShoulderInCombat and true or false
    end

    return db.actionCamShoulderOutOfCombat and true or false
end

function Functions:UpdateActionCam()
    local db = DB()
    if not db then return end

    UpdateCVar("test_cameraDynamicPitch", db.actionCamPitch and 1 or 0)

    local dragonRaceFirstPerson = self:ShouldUseDragonRacingFirstPerson(db)

    if dragonRaceFirstPerson then
        if not raceFirstPersonApplied then
            raceFirstPersonApplied = true
        end
        ApplyRaceFirstPersonZoom()
        shoulderHandlerFrame:Hide()
        shoulderHandlerFrame.lastZoom = -1
        UpdateCVar("test_cameraOverShoulder", 0)
    else
        if raceFirstPersonApplied then
            raceFirstPersonApplied = false
            self:ScheduleStabilizedUpdate({ 0, 0.05, 0.20 }, true)
        end

        if self:ShouldEnableShoulderNow() then
            if SafeGetCVar("CameraKeepCharacterCentered") == 1 then
                UpdateCVar("CameraKeepCharacterCentered", 0)
                Functions:logMessage("warning", L["CONFLICT_FIX_MSG"] or "ActionCam: Disabled Keep Character Centered to prevent jitter.")
            end
            shoulderHandlerFrame:Show()
            self:ApplyShoulderOffset(true)
        else
            shoulderHandlerFrame:Hide()
            shoulderHandlerFrame.lastZoom = -1
            UpdateCVar("test_cameraOverShoulder", 0)
        end
    end

    RequestCVarGuardRefresh(false)
end

-- =====================================================================
-- 12) SMART ZOOM CORE (FIXED: no “sticky” state)
-- =====================================================================
local function ComputeDesiredState(db)
    local snapshot = BuildStatusSnapshot(db)
    return snapshot.state, snapshot.targetYards, snapshot
end

local function ClearStateManualOverride(state)
    if state then
        stateManualOverride[state] = false
        return
    end

    for stateKey in pairs(stateManualOverride) do
        stateManualOverride[stateKey] = false
    end
end

local function SaveCurrentZoomForState(state)
    if not state then return end
    local currentZoom = GetCameraZoom and GetCameraZoom()
    if currentZoom == nil then return end
    lastZoomByState[state] = currentZoom
end

local function RememberStateSource(newState, oldState)
    if not newState then return end
    lastStateSource[newState] = oldState
end

local function GetRestoreZoomTarget(db, oldState, newState, targetYards)
    if not db or not newState or not targetYards then return nil end

    local restoreSetting = tostring(db.zoomRestoreSetting or "adaptive")
    if restoreSetting == "never" then
        return nil
    end

    local savedZoom = lastZoomByState[newState]
    if savedZoom == nil then
        return nil
    end

    if savedZoom > (targetYards + 0.35) then
        return nil
    end

    if restoreSetting == "always" then
        return math.min(savedZoom, targetYards)
    end

    if lastStateSource[newState] ~= oldState then
        return nil
    end

    return math.min(savedZoom, targetYards)
end

local function HasStateManualOverride(state, targetYards, transitionTime, db)
    if currentZoomState ~= state then
        return false
    end

    if not db or db.respectManualStateZoom == false then
        return false
    end

    if state ~= ZOOM_STATE_MOUNT and state ~= ZOOM_STATE_COMBAT then
        return false
    end

    local currentZoom = GetCameraZoom and GetCameraZoom()
    if currentZoom == nil or targetYards == nil then
        return stateManualOverride[state]
    end

    if lastAutoAppliedZoomYards ~= nil and math_abs(targetYards - lastAutoAppliedZoomYards) > 0.1 then
        stateManualOverride[state] = false
        return false
    end

    local now = GetTime and GetTime() or 0
    local settleWindow = (transitionTime or 0) + 0.25
    if lastAutoAppliedAt and (now - lastAutoAppliedAt) < settleWindow then
        return stateManualOverride[state]
    end

    if math_abs(currentZoom - targetYards) > 0.35 then
        stateManualOverride[state] = true
    end

    return stateManualOverride[state]
end

function Functions:ShouldApplyOptionImmediately(key)
    local db = DB()
    if not db then return true end

    if key == "worldCombatReturnDelay" or key == "partyCombatReturnDelay" or key == "raidCombatReturnDelay" or key == "dismountDelay" then
        return false
    end

    local state, combatContext = GetCurrentZoomContext(db)

    if key == "minZoomFactor" then
        return state == ZOOM_STATE_NONE and GetDistancePresetId(db, key) == "manual"
    elseif key == "mountZoomFactor" then
        return state == ZOOM_STATE_MOUNT and GetDistancePresetId(db, key) == "manual"
    elseif key == "worldCombatZoomFactor" then
        return state == ZOOM_STATE_COMBAT and combatContext == "world" and GetDistancePresetId(db, key) == "manual"
    elseif key == "partyCombatZoomFactor" then
        return state == ZOOM_STATE_COMBAT and combatContext == "party" and GetDistancePresetId(db, key) == "manual"
    elseif key == "raidCombatZoomFactor" then
        return state == ZOOM_STATE_COMBAT and combatContext == "raid" and GetDistancePresetId(db, key) == "manual"
    elseif key == "pvpCombatZoomFactor" then
        return state == ZOOM_STATE_COMBAT and combatContext == "pvp" and GetDistancePresetId(db, key) == "manual"
    elseif key == "maxZoomFactor" then
        return not (db.autoCombatZoom or db.autoMountZoom) and GetDistancePresetId(db, key) == "manual"
    elseif key == "cameraIndirectOffset" then
        return true
    elseif DISTANCE_PRESET_BINDINGS[key] then
        local distanceKey = nil
        for boundDistanceKey, presetKey in pairs(DISTANCE_PRESET_BINDINGS) do
            if presetKey == key then
                distanceKey = boundDistanceKey
                break
            end
        end
        if distanceKey == "maxZoomFactor" then
            return not (db.autoCombatZoom or db.autoMountZoom)
        elseif distanceKey == "minZoomFactor" then
            return state == ZOOM_STATE_NONE and db.autoCombatZoom
        elseif distanceKey == "mountZoomFactor" then
            return state == ZOOM_STATE_MOUNT
        elseif distanceKey == "worldCombatZoomFactor" then
            return state == ZOOM_STATE_COMBAT and combatContext == "world"
        elseif distanceKey == "partyCombatZoomFactor" then
            return state == ZOOM_STATE_COMBAT and combatContext == "party"
        elseif distanceKey == "raidCombatZoomFactor" then
            return state == ZOOM_STATE_COMBAT and combatContext == "raid"
        elseif distanceKey == "pvpCombatZoomFactor" then
            return state == ZOOM_STATE_COMBAT and combatContext == "pvp"
        end
    end

    return true
end

function Functions:UpdateSmartZoomState(event)
    local db = DB()
    if not db then return end
    if not db.autoCombatZoom and not db.autoMountZoom then return end

    local previousState = currentZoomState
    local previousCombatContext = lastCombatContext
    local newState, targetYards, snapshot = ComputeDesiredState(db)
    local transitionTime = db.zoomTransitionTime or 0.5

    if CameraStateController and CameraStateController.SetState then
        CameraStateController:SetState(newState, targetYards, snapshot and snapshot.resolvedContext, event or "smart_zoom")
    end

    if snapshot and snapshot.resolvedContext and newState == ZOOM_STATE_COMBAT then
        lastCombatContext = snapshot.resolvedContext
    end

    local stateChanged = (newState ~= previousState)
    if stateChanged then
        SaveCurrentZoomForState(previousState)
        RememberStateSource(newState, previousState)

        if newState == ZOOM_STATE_MOUNT or newState == ZOOM_STATE_COMBAT then
            ClearStateManualOverride(newState)
        end
        if previousState == ZOOM_STATE_MOUNT or previousState == ZOOM_STATE_COMBAT then
            ClearStateManualOverride(previousState)
        end
    end

    local appliedTargetYards = targetYards
    if stateChanged then
        local restoredTarget = GetRestoreZoomTarget(db, previousState, newState, targetYards)
        if restoredTarget ~= nil then
            appliedTargetYards = restoredTarget
        end
    end

    -- If going INTO combat or mount, always cancel pending “zoom-in”
    -- (prevents normal transition from firing after re-enter combat)
    if newState ~= ZOOM_STATE_NONE then
        CancelTransition()
    end

    -- Same state? only re-apply when the current camera cap drifted away
    -- or when we explicitly force a manual refresh.
    local stateSame = (newState == currentZoomState)
    local capAligned = IsZoomCapAligned(targetYards)
    if stateSame and HasStateManualOverride(newState, targetYards, transitionTime, db) then
        if not capAligned then
            ApplyZoomCap(targetYards)
        end
        NotifyConfigChanged()
        return
    end
    if stateSame and capAligned and event ~= "manual_update" then
        NotifyConfigChanged()
        return
    end

    -- Any change invalidates old delayed timers
    stateToken = stateToken + 1
    currentZoomState = newState

    if newState == ZOOM_STATE_NONE and event ~= "manual_update" then
        local delay = 0
        local returnKind = nil
        local returnContext = nil

        if previousState == ZOOM_STATE_COMBAT then
            returnKind = "combat"
            returnContext = previousCombatContext or "world"
            delay = GetCombatReturnDelay(db, returnContext)
        elseif previousState == ZOOM_STATE_MOUNT then
            returnKind = "mount"
            delay = db.dismountDelay or 0
        end

        local myToken = stateToken

        if delay <= 0 then
            pendingReturnInfo = nil
            if CameraStateController and CameraStateController.ClearPendingReturn then
                CameraStateController:ClearPendingReturn()
            end
            ApplyZoomTransition(appliedTargetYards, transitionTime)
            Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"] or "Smart Zoom: state=%s, target=%.1f yards", newState, appliedTargetYards))
            NotifyConfigChanged()
            return
        end

        ScheduleTransition(delay, function()
            if myToken ~= stateToken then return end
            pendingReturnInfo = nil
            if CameraStateController and CameraStateController.ClearPendingReturn then
                CameraStateController:ClearPendingReturn()
            end

            local liveDb = DB()
            if not liveDb then return end

            local nowState = ComputeDesiredState(liveDb)
            if nowState ~= ZOOM_STATE_NONE then
                return
            end

            ApplyZoomTransition(appliedTargetYards, transitionTime)
            Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"] or "Smart Zoom: state=%s, target=%.1f yards", ZOOM_STATE_NONE, appliedTargetYards))
            NotifyConfigChanged()
        end)
        pendingReturnInfo = {
            kind = returnKind,
            context = returnContext,
            delay = delay,
            fireAt = (GetTime and GetTime() or 0) + delay,
        }
        if CameraStateController and CameraStateController.SetPendingReturn then
            CameraStateController:SetPendingReturn(pendingReturnInfo)
        end
        NotifyConfigChanged()
    else
        pendingReturnInfo = nil
        if CameraStateController and CameraStateController.ClearPendingReturn then
            CameraStateController:ClearPendingReturn()
        end
        ApplyZoomTransition(appliedTargetYards, transitionTime)
        if snapshot and snapshot.resolvedContext then
            Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"] or "Smart Zoom: state=%s, target=%.1f yards", newState, appliedTargetYards) .. " [" .. tostring(snapshot.resolvedContext) .. "]")
        else
            Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"] or "Smart Zoom: state=%s, target=%.1f yards", newState, appliedTargetYards))
        end
        NotifyConfigChanged()
    end
end

function Functions:GetStatusSnapshot()
    local db = DB()
    if not db then return nil end
    SanitizeRuntimeProfile(db)
    return BuildStatusSnapshot(db)
end


local function FormatBool(value)
    return value and (L["STATUS_YES"] or "Yes") or (L["STATUS_NO"] or "No")
end

local function FormatCVar(name)
    local value = SafeGetCVar(name)
    if value == nil then
        return "unsupported"
    end
    return tostring(value)
end

function Functions:GetDependencySnapshot()
    local function HasLib(major)
        if major == "LibStub" then
            return type(_G.LibStub) == "table" or type(_G.LibStub) == "function"
        end
        return LibStub and LibStub(major, true) ~= nil
    end

    return {
        { label = "LibStub", found = HasLib("LibStub"), required = true },
        { label = "LibCamera", found = LibCamera ~= nil, required = true },
        { label = "AceDB", found = HasLib("AceDB-3.0"), optional = true },
        { label = "AceConfig", found = HasLib("AceConfig-3.0"), optional = true },
        { label = "AceConfigDialog", found = HasLib("AceConfigDialog-3.0"), optional = true },
        { label = "AceDBOptions", found = HasLib("AceDBOptions-3.0"), optional = true },
        { label = "AceLocale", found = HasLib("AceLocale-3.0"), optional = true },
        { label = "LibMountInfo", found = LibMountInfo ~= nil, optional = true },
        { label = "LibDataBroker", found = HasLib("LibDataBroker-1.1"), optional = true },
        { label = "LibDBIcon", found = HasLib("LibDBIcon-1.0"), optional = true },
    }
end

function Functions:PrintDependencyStatus()
    self:SendMessage("Dependency status:")
    for _, dep in ipairs(self:GetDependencySnapshot()) do
        local status
        if dep.found then
            status = "found"
        elseif dep.optional then
            status = "optional missing"
        else
            status = "missing"
        end
        self:SendMessage(" - " .. dep.label .. ": " .. status)
    end
end

function Functions:PrintRuntimeStatus()
    local db = DB()
    if not db then
        self:SendMessage(L["DB_NOT_READY"] or "Database not initialized yet.")
        return
    end

    local snapshot = self:GetStatusSnapshot()
    local version = Compat.GetAddonVersion and Compat.GetAddonVersion() or "Dev"
    local controllerSnapshot = CameraStateController and CameraStateController.GetSnapshot and CameraStateController:GetSnapshot() or nil

    self:SendMessage("Status:")
    self:SendMessage(" - version: " .. tostring(version))
    self:SendMessage(" - client: " .. tostring(Compat.CLIENT_TAG or "Unknown")
        .. " version=" .. tostring(Compat.VERSION ~= "" and Compat.VERSION or "unknown")
        .. " build=" .. tostring(Compat.BUILD_NUMBER or "unknown")
        .. " interface=" .. tostring(Compat.INTERFACE or "unknown"))
    self:SendMessage(" - zoom: " .. tostring((GetCameraZoom and GetCameraZoom()) or "unknown"))
    self:SendMessage(" - state: " .. tostring(snapshot and snapshot.state or "unknown") .. " previous=" .. tostring(snapshot and snapshot.previousState or (controllerSnapshot and controllerSnapshot.previousState) or "none"))
    self:SendMessage(" - target yards: " .. tostring(snapshot and snapshot.targetYards or "unknown"))
    self:SendMessage(" - pending return: " .. tostring(snapshot and snapshot.pendingReturnActive and "active" or "none") .. " remaining=" .. tostring(snapshot and snapshot.pendingReturnRemaining or 0))
    self:SendMessage(" - combat: player=" .. FormatBool(snapshot and snapshot.playerInCombat) .. " group=" .. FormatBool(snapshot and snapshot.groupInCombat) .. " threat=" .. FormatBool(snapshot and snapshot.hasThreat))
    self:SendMessage(" - travel: mounted=" .. FormatBool(snapshot and snapshot.isMounted) .. " skyriding=" .. FormatBool(snapshot and snapshot.isSkyriding) .. " dragonFP=" .. FormatBool(snapshot and snapshot.dragonRacingFirstPerson))
    self:SendMessage(" - afk=" .. FormatBool(snapshot and snapshot.afkActive) .. " shoulder=" .. FormatBool(snapshot and snapshot.actionCamShoulderActive) .. " dynamicPitch=" .. FormatBool(snapshot and snapshot.dynamicPitchActive))
    self:SendMessage(" - CVars: cameraDistanceMaxZoomFactor=" .. FormatCVar("cameraDistanceMaxZoomFactor") .. ", cameraDistanceMax=" .. FormatCVar("cameraDistanceMax") .. ", cameraDistanceMoveSpeed=" .. FormatCVar("cameraDistanceMoveSpeed") .. ", cameraZoomSpeed=" .. FormatCVar("cameraZoomSpeed"))
    self:SendMessage(" - timing: manualWheelSpeed=" .. tostring(db.moveViewDistance or "unknown") .. ", zoomTransitionTime=" .. tostring(db.zoomTransitionTime or "unknown"))
    self:SendMessage(" - CVars: keepCentered=" .. FormatCVar("CameraKeepCharacterCentered") .. ", reduceUnexpectedMovement=" .. FormatCVar("cameraReduceUnexpectedMovement") .. ", shoulder=" .. FormatCVar("test_cameraOverShoulder") .. ", dynamicPitch=" .. FormatCVar("test_cameraDynamicPitch"))
end

function Functions:AdjustCamera(forceNow)
    ResolveOptionalLibs()

    local db = DB()
    if not db then return end

    self:InvalidateRuntimeCaches()
    SanitizeRuntimeProfile(db)
    Functions:UpdateActionCam()

    if db.autoCombatZoom or db.autoMountZoom then
        if forceNow then
            Functions:UpdateSmartZoomState("manual_update")
        else
            Functions:RequestUpdate()
        end
    else
        -- Manual-only mode
        local maxYards = (ns.Database and ns.Database.DEFAULTS and ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
        local manualTargetYards = (GetDistanceValue(db, "maxZoomFactor")) or db.maxZoomFactor or maxYards

        stateToken = stateToken + 1
        currentZoomState = ZOOM_STATE_MANUAL
        if CameraStateController and CameraStateController.SetState then
            CameraStateController:SetState(ZOOM_STATE_MANUAL, manualTargetYards, "manual", "manual_mode")
        end
        CancelTransition()

        ApplyManualCameraCapOnly(manualTargetYards, "manual_mode")

        Functions:logMessage("info", L["SMART_ZOOM_DISABLED_MSG"] or "Smart Zoom is disabled. Using manual max distance settings.")
        NotifyConfigChanged()
    end

    Functions:ApplyManagedCVars()
end

-- Applies every CVar the addon owns that is NOT part of the zoom state machine.
-- Kept separate from AdjustCamera so it can also run on paths where Smart Zoom
-- bails out early (Smart Zoom disabled, logging in dead/as a ghost, ...).
-- Without this, "Camera Turning Speed" and friends were never re-applied on
-- those logins.
function Functions:ApplyManagedCVars()
    local db = DB()
    if not db then return end

    SanitizeRuntimeProfile(db)

    UpdateCVar("cameraDistanceMoveSpeed", db.moveViewDistance)
    UpdateCVar("cameraReduceUnexpectedMovement", db.reduceUnexpectedMovement and 1 or 0)
    UpdateCVar("cameraYawMoveSpeed", db.cameraYawMoveSpeed)
    UpdateCVar("cameraPitchMoveSpeed", db.cameraPitchMoveSpeed)
    UpdateCVar("cameraIndirectVisibility", db.cameraIndirectVisibility and 1 or 0)
    UpdateCVar("cameraIndirectOffset", db.cameraIndirectOffset or 1.5)
    UpdateCVar("occludedSilhouettePlayer", db.occludedSilhouettePlayer and 1 or 0)
    UpdateCVar("resampleAlwaysSharpen", db.resampleAlwaysSharpen and 1 or 0)
    UpdateCVar("SoftTargetIconGameObject", db.softTargetInteract and 1 or 0)

    RequestCVarGuardRefresh(false)
end

function Functions:OnCVarUpdate(_, cvarName, value)
    if isInternalUpdate then return end
    cvarName = CanonicalCVarName(cvarName)

    local db = DB()
    if not db then return end

    if cvarName == "cameraView" then
        local normalizedView = NormalizeManagedCVarValue(cvarName, value, db)
        if tonumber(value) ~= normalizedView then
            UpdateCVar("cameraView", normalizedView)
        end
        -- Saved camera views can override zoom, yaw, pitch and other camera CVars
        -- during login / view restore. Re-apply the full addon state, not just zoom.
        Functions:ScheduleStabilizedUpdate({ 0, 0.15, 0.75, 1.5 }, true)
        return
    end

    local normalizedValue = NormalizeManagedCVarValue(cvarName, value, db)
    local numValue = tonumber(normalizedValue) or 0

    if (cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax") then
        if db.autoCombatZoom or db.autoMountZoom then
            local _, desiredYards = ComputeDesiredState(db)
            local expected = (cvarName == "cameraDistanceMax") and desiredYards or (desiredYards / CONVERSION_RATIO)
            local expectedNormalized = NormalizeManagedCVarValue(cvarName, expected, db)
            local epsilon = (cvarName == "cameraDistanceMax") and 0.1 or 0.01

            if normalizedValue == nil or math_abs(numValue - expectedNormalized) > epsilon then
                UpdateCVar(cvarName, expectedNormalized)
            end
            return
        end
    end

    if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax" then
        if db.autoCombatZoom or db.autoMountZoom then
            return
        end

        local yards

        if cvarName == "cameraDistanceMaxZoomFactor" then
            yards = numValue * CONVERSION_RATIO
        else
            yards = numValue
        end

        local defaults = ns.Database and ns.Database.DEFAULTS
        local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
        yards = ClampNumber(yards, 1, maxYards)

        -- Only mirror the CVar back into the profile while the slider is actually
        -- the source of truth. With a preset selected the CVar holds the PRESET
        -- value, and writing it back would permanently destroy the manual value
        -- the user gets when switching the preset back to "Manual".
        if GetDistancePresetId(db, "maxZoomFactor") ~= "manual" then
            local presetYards = GetDistanceValue(db, "maxZoomFactor")
            if presetYards and yards and math_abs(presetYards - yards) > 0.1 then
                UpdateCVar(cvarName, (cvarName == "cameraDistanceMax") and presetYards or (presetYards / CONVERSION_RATIO))
            end
            return
        end

        if yards and db.maxZoomFactor and math_abs(db.maxZoomFactor - yards) > 0.1 then
            db.maxZoomFactor = yards
            Functions:logMessage("info", string.format("DB synced from CVar: %s -> %.1f yards", tostring(value), yards))
        end
    elseif cvarName == "cameraDistanceMoveSpeed" then
        local desired = NormalizeManagedCVarValue(cvarName, db.moveViewDistance, db)
        if normalizedValue == nil or math_abs(numValue - desired) > 0.005 then
            UpdateCVar(cvarName, desired)
            return
        end
        db.moveViewDistance = desired
    elseif cvarName == "cameraYawMoveSpeed" then
        local desired = NormalizeManagedCVarValue(cvarName, db.cameraYawMoveSpeed, db)
        if normalizedValue == nil or math_abs(numValue - desired) > 0.005 then
            UpdateCVar(cvarName, desired)
            return
        end
        db.cameraYawMoveSpeed = desired
    elseif cvarName == "cameraPitchMoveSpeed" then
        local desired = NormalizeManagedCVarValue(cvarName, db.cameraPitchMoveSpeed, db)
        if normalizedValue == nil or math_abs(numValue - desired) > 0.005 then
            UpdateCVar(cvarName, desired)
            return
        end
        db.cameraPitchMoveSpeed = desired
    elseif cvarName == "cameraReduceUnexpectedMovement" then
        -- Respect external/user changes unless the Motion Sickness guard is actively blocking it.
        local guard = ns.CVarGuard
        if guard and guard.ShouldBlockReduceUnexpectedMovement and guard:ShouldBlockReduceUnexpectedMovement() then
            if numValue ~= 0 then
                UpdateCVar(cvarName, 0)
            end
            return
        end
        db.reduceUnexpectedMovement = (numValue == 1)
    elseif cvarName == "cameraZoomSpeed" then
        -- LibCamera owns temporary cameraZoomSpeed transitions and restores the previous value.
        return
    elseif cvarName == "cameraIndirectVisibility" then
        local desired = db.cameraIndirectVisibility and 1 or 0
        if numValue ~= desired then
            UpdateCVar(cvarName, desired)
            return
        end
        db.cameraIndirectVisibility = (desired == 1)
    elseif cvarName == "cameraIndirectOffset" then
        local desired = NormalizeManagedCVarValue(cvarName, db.cameraIndirectOffset, db)
        if normalizedValue == nil or math_abs(numValue - desired) > 0.005 then
            UpdateCVar(cvarName, desired)
            return
        end
        db.cameraIndirectOffset = desired
    elseif cvarName == "occludedSilhouettePlayer" then
        local desired = db.occludedSilhouettePlayer and 1 or 0
        if numValue ~= desired then
            UpdateCVar(cvarName, desired)
            return
        end
        db.occludedSilhouettePlayer = (desired == 1)
    elseif cvarName == "resampleAlwaysSharpen" then
        local desired = db.resampleAlwaysSharpen and 1 or 0
        if numValue ~= desired then
            UpdateCVar(cvarName, desired)
            return
        end
        db.resampleAlwaysSharpen = (desired == 1)
    elseif cvarName == "SoftTargetIconGameObject" then
        local desired = db.softTargetInteract and 1 or 0
        if numValue ~= desired then
            UpdateCVar(cvarName, desired)
            return
        end
        db.softTargetInteract = (desired == 1)
    elseif cvarName == "test_cameraDynamicPitch" or cvarName == "test_cameraOverShoulder" then
        Functions:UpdateActionCam()
        return
    end
end

-- =====================================================================
-- 13) AFK (SAFE)
-- =====================================================================
function Functions:OnPlayerFlagsChanged()
    Functions:RefreshAfkMode(false)
end

function Functions:OnAfkRelevantStateChanged()
    Functions:RefreshAfkMode(false)
end

-- =====================================================================
-- 14) QUEST TRACKER
-- =====================================================================
function Functions:ClearAllQuestTracking()
    if not C_QuestLog or not C_QuestLog.GetNumQuestWatches then
        Functions:SendMessage("Quest tracking API not available in this client.")
        return
    end

    if not (C_QuestLog.GetQuestIDForQuestWatchIndex and C_QuestLog.RemoveQuestWatch) then
        Functions:SendMessage("Quest tracking API not available in this client.")
        return
    end

    local numWatches = C_QuestLog.GetNumQuestWatches()
    if not numWatches or numWatches <= 0 then
        Functions:SendMessage(L["QUEST_TRACKER_EMPTY"] or "Quest tracker is already empty.")
        return
    end

    for i = numWatches, 1, -1 do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID then
            C_QuestLog.RemoveQuestWatch(questID)
        end
    end

    Functions:SendMessage(string.format(L["QUEST_TRACKER_CLEARED"] or "Stopped tracking %d quests.", numWatches))
end

-- =====================================================================
-- 15) SLASH
-- =====================================================================
function Functions:SlashCmdHandler(msg)
    ResolveOptionalLibs()

    local raw = tostring(msg or "")
    local command, arg = raw:match("^%s*(%S*)%s*(.-)%s*$")
    command = strlower(command or "")
    arg = strlower(arg or "")

    if not (ns.Database and ns.Database.db) then
        Functions:SendMessage(L["DB_NOT_READY"] or "Database not initialized yet.")
        return
    end

    local db = ns.Database.db.profile

    if command == "" or command == "help" then
        Functions:SendMessage(L["CMD_USAGE"] or "Usage: /mcd config | autozoom | automount | status | deps | fastzoom | slowzoom | reset | debug on | debug off")

    elseif command == "config" then
        if ACD and ACD.Open then
            local ok, err = pcall(ACD.Open, ACD, addonName)
            if not ok then
                Functions:SendMessage("Error: settings window failed: " .. tostring(err))
            end
        else
            Functions:SendMessage("Error: AceConfigDialog not found. Cannot open settings. Use /mcd status and /mcd deps for diagnostics.")
        end

    elseif command == "autozoom" then
        db.autoCombatZoom = not db.autoCombatZoom
        Functions:AdjustCamera(true)
        local state = db.autoCombatZoom and (L["ENABLED"] or "|cff00ff00Enabled|r") or (L["DISABLED"] or "|cffff0000Disabled|r")
        Functions:SendMessage("Auto Combat Zoom: " .. state)

    elseif command == "automount" then
        db.autoMountZoom = not db.autoMountZoom
        Functions:AdjustCamera(true)
        local state = db.autoMountZoom and (L["ENABLED"] or "|cff00ff00Enabled|r") or (L["DISABLED"] or "|cffff0000Disabled|r")
        Functions:SendMessage("Auto Mount Zoom: " .. state)

    elseif command == "status" then
        Functions:PrintRuntimeStatus()

    elseif command == "deps" then
        Functions:PrintDependencyStatus()

    elseif command == "fastzoom" then
        db.moveViewDistance = 50
        db.zoomTransitionTime = 0.1
        UpdateCVar("cameraDistanceMoveSpeed", 50)
        Functions:SendMessage("Fast manual zoom enabled.")
        NotifyConfigChanged()

    elseif command == "slowzoom" then
        db.moveViewDistance = 20
        db.zoomTransitionTime = 0.5
        UpdateCVar("cameraDistanceMoveSpeed", 20)
        Functions:SendMessage("Slow manual zoom enabled.")
        NotifyConfigChanged()

    elseif command == "reset" then
        local ok = ns.Database and ns.Database.ResetCurrentProfile and ns.Database:ResetCurrentProfile()
        if ok then
            Functions:AdjustCamera(true)
            Functions:SendMessage(L["SETTINGS_RESET"] or "Profile has been reset to default values.")
        else
            Functions:SendMessage("Error: profile reset is unavailable.")
        end

    elseif command == "debug" then
        if arg == "on" then
            db.enableDebugLogging = true
            db.debugLevel = db.debugLevel or {}
            db.debugLevel.error = true
            db.debugLevel.warning = true
            db.debugLevel.info = true
            db.debugLevel.debug = true
            Functions:SendMessage("Debug logging: " .. (L["ENABLED"] or "enabled"))
        elseif arg == "off" then
            db.enableDebugLogging = false
            Functions:SendMessage("Debug logging: " .. (L["DISABLED"] or "disabled"))
        else
            Functions:SendMessage("Usage: /mcd debug on | debug off")
        end

    else
        Functions:SendMessage(L["CMD_USAGE"] or "Usage: /mcd config | autozoom | automount | status | deps | fastzoom | slowzoom | reset | debug on | debug off")
    end
end