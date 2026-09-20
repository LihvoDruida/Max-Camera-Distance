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

local IS_FOREVER = Compat.IS_FOREVER and true or false
local USES_MODERN_API = Compat.USES_MODERN_API and true or false
local CONVERSION_RATIO = Compat.CONVERSION_RATIO or (USES_MODERN_API and 15 or 12.5)

local CVAR_ALIASES = {
    cameraReduceUnexpectedMovement = { "cameraReduceUnexpectedMovement", "CameraReduceUnexpectedMovement" },
    CameraReduceUnexpectedMovement = { "cameraReduceUnexpectedMovement", "CameraReduceUnexpectedMovement" },
}

-- The client's own spelling of a CVar is not always the spelling this addon
-- uses. GetCVar/SetCVar are case-insensitive so writes always worked, but the
-- CVAR_UPDATE event delivers the CLIENT's canonical name, and every dispatch
-- below compares it with ==. The 12.1 CVar table registers, among others,
-- "ResampleAlwaysSharpen" and "CameraReduceUnexpectedMovement" with capitals
-- the addon does not use, so those updates silently fell through and the addon
-- never re-applied the setting when something else changed it. Matching on a
-- lowercased key makes the dispatch immune to this and to any future drift.
local MANAGED_CVAR_NAMES = {
    "cameraDistanceMaxZoomFactor",
    "cameraDistanceMax",
    "cameraDistanceMoveSpeed",
    "cameraYawMoveSpeed",
    "cameraPitchMoveSpeed",
    "cameraZoomSpeed",
    "cameraView",
    "cameraIndirectVisibility",
    "cameraIndirectOffset",
    "CameraKeepCharacterCentered",
    "cameraReduceUnexpectedMovement",
    "test_cameraOverShoulder",
    "test_cameraDynamicPitch",
    "occludedSilhouettePlayer",
    "resampleAlwaysSharpen",
    "SoftTargetIconGameObject",
}

if IS_FOREVER then
    MANAGED_CVAR_NAMES[#MANAGED_CVAR_NAMES + 1] = "volumeFog"
    MANAGED_CVAR_NAMES[#MANAGED_CVAR_NAMES + 1] = "volumeFogInterior"
    MANAGED_CVAR_NAMES[#MANAGED_CVAR_NAMES + 1] = "volumeFogLevel"
    MANAGED_CVAR_NAMES[#MANAGED_CVAR_NAMES + 1] = "groundEffectDensity"
    MANAGED_CVAR_NAMES[#MANAGED_CVAR_NAMES + 1] = "groundEffectDist"
    MANAGED_CVAR_NAMES[#MANAGED_CVAR_NAMES + 1] = "groundEffectFade"
end

local CVAR_CANONICAL = {}
for _, name in ipairs(MANAGED_CVAR_NAMES) do
    CVAR_CANONICAL[name:lower()] = name
end

local function CanonicalCVarName(cvarName)
    if type(cvarName) ~= "string" then
        return cvarName
    end
    return CVAR_CANONICAL[cvarName:lower()] or cvarName
end

ns.MANAGED_CVAR_NAMES = MANAGED_CVAR_NAMES

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
local GROUP_COMBAT_CACHE_SECONDS = 0.25
local CVAR_GUARD_REFRESH_SECONDS = 0.12
-- Grouped in one table rather than as separate file-level locals on purpose:
-- Lua 5.1 allows at most 200 locals in a chunk and this file is close to that
-- ceiling, so every new tuning knob would otherwise cost a slot.
local SHOULDER = {
    -- Per-frame polling while the camera is actually moving.
    UPDATE_INTERVAL = 0.033,
    -- While the camera is parked - standing in a city, reading quest text,
    -- waiting for a pull - the offset cannot change, so polling it every frame
    -- is pure overhead. Back off after IDLE_AFTER seconds of a completely
    -- static camera and snap back the instant it moves again. 0.10 rather than
    -- something larger on purpose: the backoff can only ever delay NOTICING
    -- that movement resumed, and 100 ms after a full second of stillness is not
    -- perceptible, whereas 250 ms would be.
    IDLE_INTERVAL = 0.10,
    IDLE_AFTER = 1.00,
    ZOOM_EPSILON = 0.01,
    OFFSET_EPSILON = 0.002,
    OFFSET_DEFAULT = 1.0,
    -- DynamicCam and the current Blizzard CVar range both allow the full
    -- test_cameraOverShoulder interval. Keep our UI/profile clamp aligned with
    -- the engine instead of silently truncating valid Forever values.
    OFFSET_MIN = -15.0,
    OFFSET_MAX = 15.0,
    FADE_START_DEFAULT = 5.0,
    FADE_END_DEFAULT = 2.0,
    FADE_MAX = 25.0,
}
local RAID_UNITS, PARTY_UNITS = {}, {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end
for i = 1, 4 do PARTY_UNITS[i] = "party" .. i end

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

-- AceConfigRegistry:NotifyChange walks its callback registry and makes an open
-- AceConfigDialog rebuild the whole options tree. UpdateSmartZoomState called
-- this unconditionally, including on the two "nothing changed, bail out" early
-- returns - so with the panel open it re-rendered on every queued camera pass.
--
-- The status panel only shows the state and the target distance, so notifying
-- when neither moved is pure waste. A short floor also collapses the bursts that
-- ScheduleStabilizedUpdate fires during login and zoning into a single refresh.
local CONFIG_NOTIFY_MIN_INTERVAL = 0.2
local lastNotifiedState, lastNotifiedTarget, lastNotifiedAt = nil, nil, 0

local function NotifyConfigChanged(state, targetYards)
    if not (ns.Config and ns.Config.NotifyChange) then return end

    if state ~= nil then
        local now = (GetTime and GetTime()) or 0
        local unchanged = (state == lastNotifiedState) and (targetYards == lastNotifiedTarget)

        if unchanged and now > 0 and (now - lastNotifiedAt) < CONFIG_NOTIFY_MIN_INTERVAL then
            return
        end

        lastNotifiedState = state
        lastNotifiedTarget = targetYards
        lastNotifiedAt = now
    end

    ns.Config:NotifyChange()
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

    -- Every LibCamera call routed through here drives the camera on the addon's
    -- behalf. Reactive Zoom's wheel target describes where the PLAYER last
    -- pointed the camera, so it is meaningless afterwards; leaving it in place
    -- made the next wheel notch ease back to the pre-transition distance.
    -- Catching it centrally covers all four call sites at once.
    if ns.ReactiveZoom and ns.ReactiveZoom.ResetTarget then
        ns.ReactiveZoom:ResetTarget()
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

    -- Avoid allocating a temporary { d, c, b, a } table on every form check;
    -- this path is hit by shapeshift/aura-driven camera updates.
    for i = 1, 4 do
        local value
        if i == 1 then value = d
        elseif i == 2 then value = c
        elseif i == 3 then value = b
        else value = a end

        local plainValue = Compat.Plain and Compat.Plain(value) or value
        if plainValue ~= nil then
            local num = tonumber(plainValue)
            if num and num > 0 and type(plainValue) ~= "boolean" then
                return num
            end
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
        local plainInstanceType
        if Compat.Plain then
            plainInstanceType = Compat.Plain(instanceType)
        else
            plainInstanceType = instanceType
        end
        return IsTruthySafe(inInstance), plainInstanceType
    end
    return false, nil
end

local function GetIndirectOffsetDefault()
    local defaults = ns.Database and ns.Database.DEFAULTS
    return (defaults and tonumber(defaults.CAMERA_INDIRECT_OFFSET_DEFAULT)) or 6.0
end


local function NormalizeManagedCVarValue(cvarName, value, db)
    cvarName = CanonicalCVarName(cvarName)
    local defaults = ns.Database and ns.Database.DEFAULTS
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (USES_MODERN_API and 39 or 50))
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
        or cvarName == "test_cameraDynamicPitch"
        or cvarName == "volumeFog"
        or cvarName == "volumeFogInterior" then
        local num = tonumber(value)
        if value == true or value == "true" or num == 1 then
            return 1
        end
        return 0
    elseif cvarName == "volumeFogLevel" then
        local level = ClampNumber(value, 0, 3)
        if level == nil and db then
            level = ClampNumber(db.volumeFogLevel, 0, 3)
        end
        return math_floor((level or 2) + 0.5)
    elseif cvarName == "groundEffectDensity" then
        local density = ClampNumber(value, 16, 256)
        if density == nil and db then density = ClampNumber(db.groundEffectDensity, 16, 256) end
        return math_floor((density or 16) + 0.5)
    elseif cvarName == "groundEffectDist" then
        local distance = ClampNumber(value, 32, 600)
        if distance == nil and db then distance = ClampNumber(db.groundEffectDist, 32, 600) end
        return math_floor((distance or 70) + 0.5)
    elseif cvarName == "groundEffectFade" then
        local fade = ClampNumber(value, 0, 600)
        if fade == nil and db then fade = ClampNumber(db.groundEffectFade, 0, 600) end
        return math_floor((fade or 70) + 0.5)
    elseif cvarName == "cameraIndirectOffset" then
        return ClampNumber(value, 0, 10) or ((db and ClampNumber(db.cameraIndirectOffset, 0, 10)) or GetIndirectOffsetDefault())
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
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (USES_MODERN_API and 39 or 50))
    local defaultNormal = (defaults and defaults.BLIZZARD_DEFAULT_YARDS) or 20

    db.maxZoomFactor = ClampNumber(db.maxZoomFactor, 1, maxYards) or maxYards
    db.minZoomFactor = ClampNumber(db.minZoomFactor, 1, maxYards) or defaultNormal
    db.mountZoomFactor = ClampNumber(db.mountZoomFactor, 1, maxYards) or db.maxZoomFactor
    db.worldCombatZoomFactor = ClampNumber(db.worldCombatZoomFactor, 1, maxYards) or db.maxZoomFactor

    -- Clamp every activity's distance and return delay from the taxonomy. Note
    -- ns.Contexts is read here rather than through an upvalue: this function is
    -- defined above the file-level Contexts local.
    local contexts = ns.Contexts
    if contexts and contexts.DEFINITIONS then
        for _, def in pairs(contexts.DEFINITIONS) do
            db[def.distanceKey] = ClampNumber(db[def.distanceKey], 1, maxYards)
                or db.worldCombatZoomFactor
            db[def.delayKey] = ClampNumber(db[def.delayKey], 0, 10)
                or def.defaultDelay or 0.4
        end
    end

    db.groupCombatZoomFactor = nil
    db.moveViewDistance = ClampNumber(db.moveViewDistance, 20, 50) or 50
    db.cameraYawMoveSpeed = ClampNumber(db.cameraYawMoveSpeed, 1, 360) or (ClampNumber(SafeGetCVar("cameraYawMoveSpeed"), 1, 360) or 180)
    db.cameraPitchMoveSpeed = ClampNumber(db.cameraPitchMoveSpeed, 1, 360) or (ClampNumber(SafeGetCVar("cameraPitchMoveSpeed"), 1, 360) or 90)
    db.zoomTransitionTime = ClampNumber(db.zoomTransitionTime, 0, 2) or 0.5
    db.dismountDelay = ClampNumber(db.dismountDelay, 0, 10) or 0
    db.cameraIndirectOffset = ClampNumber(db.cameraIndirectOffset, 0, 10) or GetIndirectOffsetDefault()
    if IS_FOREVER then
        local envDefaults = defaults and defaults.FOREVER_ENVIRONMENT
        local densityDefault = envDefaults and tonumber(envDefaults.groundEffectDensity) or 16
        local distDefault = envDefaults and tonumber(envDefaults.groundEffectDist) or 70
        local fadeDefault = envDefaults and tonumber(envDefaults.groundEffectFade) or 70
        db.groundEffectDensity = math_floor((ClampNumber(db.groundEffectDensity, 16, 256) or densityDefault) + 0.5)
        db.groundEffectDist = math_floor((ClampNumber(db.groundEffectDist, 32, 600) or distDefault) + 0.5)
        db.groundEffectFade = math_floor((ClampNumber(db.groundEffectFade, 0, 600) or fadeDefault) + 0.5)
    end
end


local Contexts = ns.Contexts

local DISTANCE_PRESET_BINDINGS = {
    maxZoomFactor = "manualMaxPreset",
    minZoomFactor = "normalZoomPreset",
    mountZoomFactor = "mountZoomPreset",
}

-- One binding per activity, generated from ns.Contexts so the two lists cannot
-- disagree about which preset key belongs to which distance.
local COMBAT_CONTEXT_BY_DISTANCE_KEY = {}
local DELAY_KEYS = {}

if Contexts and Contexts.DEFINITIONS then
    for id, def in pairs(Contexts.DEFINITIONS) do
        DISTANCE_PRESET_BINDINGS[def.distanceKey] = def.presetKey
        COMBAT_CONTEXT_BY_DISTANCE_KEY[def.distanceKey] = id
        DELAY_KEYS[def.delayKey] = true
    end
end

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
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (USES_MODERN_API and 39 or 50))
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
    if Contexts and Contexts.GetDistanceKey then
        return Contexts:GetDistanceKey(context)
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

-- ActionCam outputs are different from ordinary managed CVars: the player or a
-- second camera addon may already have a shoulder/pitch value before MCD takes
-- control. Capture that value once and let CVarGuard restore it when MCD stops
-- managing the output, instead of assuming zero is always the correct teardown.
-- These are methods rather than more top-level locals because Functions.lua is
-- already close to Lua 5.1's 200-local limit for one chunk.
function Functions:ArmExperimentalCameraWarningSuppression()
    if not IS_FOREVER then return end

    local now = (GetTime and GetTime()) or 0
    self._experimentalCameraSuppressUntil = now + 0.35

    if not self._experimentalCameraHookInstalled
        and type(hooksecurefunc) == "function"
        and type(_G.StaticPopup_Show) == "function" then
        local ok = pcall(hooksecurefunc, "StaticPopup_Show", function(which)
            if which ~= "EXPERIMENTAL_CVAR_WARNING" then return end
            local deadline = Functions._experimentalCameraSuppressUntil or 0
            local current = (GetTime and GetTime()) or 0
            if current <= deadline and type(_G.StaticPopup_Hide) == "function" then
                pcall(_G.StaticPopup_Hide, which)
            end
        end)
        self._experimentalCameraHookInstalled = ok and true or false
    end
end

function Functions:HideOwnExperimentalCameraWarning()
    if not IS_FOREVER then return end
    local deadline = self._experimentalCameraSuppressUntil or 0
    local now = (GetTime and GetTime()) or 0
    if now <= deadline and type(_G.StaticPopup_Hide) == "function" then
        pcall(_G.StaticPopup_Hide, "EXPERIMENTAL_CVAR_WARNING")
    end
end

function Functions:UpdateOwnedActionCamCVar(key, value)
    self:ArmExperimentalCameraWarningSuppression()
    local guard = ns.CVarGuard
    if guard and guard.CaptureActionCamOutput then
        guard:CaptureActionCamOutput(key)
    end

    UpdateCVar(key, value)
    self:HideOwnExperimentalCameraWarning()

    if guard and guard.RecordActionCamOutputWrite then
        guard:RecordActionCamOutputWrite(key)
    end
end

function Functions:RestoreOwnedActionCamCVar(key)
    local guard = ns.CVarGuard
    if guard and guard.RestoreActionCamOutput then
        return guard:RestoreActionCamOutput(key)
    end
    return false
end

-- =====================================================================
-- 7) MOUNT / TRAVEL DETECT
-- =====================================================================
function Functions:IsSkyriding()
    if SafeBoolCall(IsMounted) and LibMountInfo and LibMountInfo.IsSkyriding then
        local ok, result = pcall(LibMountInfo.IsSkyriding, LibMountInfo)
        if ok then
            return result and true or false
        end
    end

    if USES_MODERN_API and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
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
    -- Survives cache expiry on purpose: it is only a hint for where to look
    -- first, and it is re-validated with GetMountInfoByID before being trusted.
    lastKnownMountID = nil,
}

function Functions:InvalidateMountCache()
    activeMountCache.expiresAt = 0
end

function Functions:GetActiveMountID()
    local mounted = SafeBoolCall(IsMounted)
    if not USES_MODERN_API or not mounted or not C_MountJournal or not C_MountJournal.GetMountIDs or not C_MountJournal.GetMountInfoByID then
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

    -- Two cost fixes over the old scan.
    --
    -- 1. Check the previously active mount first. Re-summoning the same mount is
    --    overwhelmingly the common case, and it turns a full journal walk into a
    --    single lookup.
    -- 2. One pcall around the whole loop instead of one per mount. A large
    --    collection is well over a thousand entries, so the old version paid
    --    1000+ pcalls per rebuild - and this rebuilds several times a second
    --    while mounted.
    local mountID = nil

    local lastID = activeMountCache.lastKnownMountID
    if lastID then
        local okLast, _, _, _, lastActive = pcall(C_MountJournal.GetMountInfoByID, lastID)
        if okLast and lastActive then
            mountID = lastID
        end
    end

    if not mountID then
        local function ScanJournal()
            local mountIDs = C_MountJournal.GetMountIDs()
            if type(mountIDs) ~= "table" then return nil end
            for _, id in ipairs(mountIDs) do
                local _, _, _, isActive = C_MountJournal.GetMountInfoByID(id)
                if isActive then
                    return id
                end
            end
            return nil
        end

        local okScan, scanned = pcall(ScanJournal)
        mountID = okScan and scanned or nil
    end

    activeMountCache.lastKnownMountID = mountID or activeMountCache.lastKnownMountID

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
    if not SafeBoolCall(IsMounted) then
        return false
    end

    if USES_MODERN_API and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
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
            -- Test secrecy before any comparison/table-key operation.
            if issecretvalue then
                local okSecret, isSecret = pcall(issecretvalue, spellId)
                if not okSecret or isSecret then
                    return false
                end
            end
            if spellId == nil then
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

    if USES_MODERN_API and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
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
        if ok and IsTruthySafe(mounted) then
            return false
        end
    elseif SafeBoolCall(IsMounted) then
        return false
    end

    local formIndex = GetShapeshiftForm and GetShapeshiftForm() or nil
    if formIndex and formIndex > 0 and GetShapeshiftFormInfo then
        local spellID = GetShapeshiftFormSpellID(formIndex)
        if spellID and TRAVEL_FORM_IDS[spellID] then
            return true
        end
    end

    if USES_MODERN_API and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
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

function Functions:ShouldUseMountZoom(db, knownTravelActive)
    local travelActive = knownTravelActive
    if travelActive == nil then
        travelActive = IsInTravelForm()
    end
    if not travelActive then
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
        if ok and IsTruthySafe(mounted) then return true end
    else
        if SafeBoolCall(IsMounted) then return true end
    end

    local formIndex = GetShapeshiftForm and GetShapeshiftForm() or nil
    if formIndex and formIndex > 0 and GetShapeshiftFormInfo then
        local spellID = GetShapeshiftFormSpellID(formIndex)
        if spellID and TRAVEL_FORM_IDS[spellID] then return true end
    end

    if USES_MODERN_API then
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

    if Contexts and Contexts.GetDelayKey then
        local value = tonumber(db[Contexts:GetDelayKey(context)])
        if value then return value end
    end

    return db.worldCombatReturnDelay or 0
end

-- =====================================================================
-- ADAPTIVE RETURN DELAY
-- =====================================================================
-- The problem this solves: while farming, mobs are spaced far enough apart that
-- combat genuinely drops between them. The fixed return delay (0.4s in the open
-- world) expires during that lull, the camera zooms all the way in, and the next
-- pull immediately zooms it back out. The result is a camera that pumps in and
-- out on every mob even though the player never stopped fighting.
--
-- Raising the fixed delay is not a fix: it would also make the camera linger
-- after the player has genuinely finished, and the right value differs per zone,
-- per class, and per pull.
--
-- Instead, measure the player's actual rhythm. Every time combat restarts we
-- record how long the lull was. If those lulls keep being short, we are farming,
-- so the return delay grows to cover them and the camera simply stays out. When
-- the lulls stop arriving the samples age out and the delay returns to the
-- configured value on its own.
-- All rhythm state lives in one table: Lua 5.1 allows only 200 locals per chunk
-- and this file is already close to that ceiling.
local rhythm = {
    gaps = {},          -- ring buffer of recent lull lengths
    at = {},            -- when each lull ended, for ageing
    count = 0,
    lastEndAt = nil,
    lastApplied = nil,  -- last adaptive delay actually used, for /mcd status

    SAMPLES = 5,        -- a few pulls is enough to establish a rhythm
    GAP_MAX = 12,       -- a longer lull is a break, not a farming gap
    WINDOW = 45,        -- samples older than this stop counting
    MARGIN = 0.6,       -- headroom over the observed lull
    MIN_SAMPLES = 2,    -- one long lull must not trigger farming mode
}

local function ResetCombatRhythm()
    for i = 1, rhythm.SAMPLES do
        rhythm.gaps[i] = nil
        rhythm.at[i] = nil
    end
    rhythm.count = 0
    rhythm.lastEndAt = nil
    rhythm.lastApplied = nil
end

-- Called when the zoom state leaves combat.
local function NoteCombatEnded()
    rhythm.lastEndAt = (GetTime and GetTime()) or nil
end

-- Called when the zoom state enters combat. The interesting number is how long
-- the player was out of combat before this pull.
local function NoteCombatStarted()
    local now = (GetTime and GetTime()) or nil
    if not now or not rhythm.lastEndAt then
        rhythm.lastEndAt = nil
        return
    end

    local gap = now - rhythm.lastEndAt
    rhythm.lastEndAt = nil

    -- Ignore lulls long enough to mean the player actually stopped. Recording
    -- them would inflate the delay long after farming ended.
    if gap <= 0 or gap > rhythm.GAP_MAX then
        return
    end

    rhythm.count = rhythm.count + 1
    local slot = ((rhythm.count - 1) % rhythm.SAMPLES) + 1
    -- Parallel arrays rather than a table per sample: this runs on every pull,
    -- and a farming session is thousands of pulls of needless garbage.
    rhythm.gaps[slot] = gap
    rhythm.at[slot] = now
end

-- Returns the delay to actually use, and whether adaptation changed it.
local function GetAdaptiveReturnDelay(db, context)
    local base = GetCombatReturnDelay(db, context)

    if not db or db.adaptiveCombatReturn == false then
        return base, false
    end

    local now = (GetTime and GetTime()) or 0
    if now == 0 then return base, false end

    -- Use the LONGEST recent lull, not the average: the delay has to cover the
    -- worst gap seen, otherwise the camera still snaps in on the slowest pull.
    local longest, samples = 0, 0
    for i = 1, rhythm.SAMPLES do
        local gap = rhythm.gaps[i]
        if gap and (now - rhythm.at[i]) <= rhythm.WINDOW then
            samples = samples + 1
            if gap > longest then longest = gap end
        end
    end

    if samples < rhythm.MIN_SAMPLES then
        return base, false
    end

    local cap = tonumber(db.adaptiveCombatReturnMax) or 5
    local adaptive = math.min(cap, longest + rhythm.MARGIN)

    if adaptive <= base then
        rhythm.lastApplied = nil
        return base, false
    end

    rhythm.lastApplied = adaptive
    return adaptive, true
end

-- Diagnostics for /mcd status.
local function GetRhythmStatus(db)
    local now = (GetTime and GetTime()) or 0
    local longest, samples = 0, 0
    for i = 1, rhythm.SAMPLES do
        local gap = rhythm.gaps[i]
        if gap and (now - rhythm.at[i]) <= rhythm.WINDOW then
            samples = samples + 1
            if gap > longest then longest = gap end
        end
    end
    return samples, longest, rhythm.lastApplied,
        (db and db.adaptiveCombatReturn ~= false) and true or false
end

local function GetPendingReturnRemaining()
    if not pendingReturnInfo or not pendingReturnInfo.fireAt or not GetTime then
        return 0
    end
    return math.max(0, pendingReturnInfo.fireAt - GetTime())
end


local function NormalizeTargetYards(targetYards)
    local defaults = ns.Database and ns.Database.DEFAULTS
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (USES_MODERN_API and 39 or 50))
    return ClampNumber(targetYards, 1, maxYards) or maxYards
end

local function ApplyZoomCap(targetYards)
    targetYards = NormalizeTargetYards(targetYards)
    local targetFactor = targetYards / CONVERSION_RATIO

    -- Reactive Zoom keeps its own target zoom. Moving the cap underneath it
    -- would leave that target outside the new range, and the next wheel notch
    -- would ease back to a distance the player can no longer reach.
    if ns.ReactiveZoom and ns.ReactiveZoom.ResetTarget then
        ns.ReactiveZoom:ResetTarget()
    end

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
    local maxYards = (ns.Database and ns.Database.DEFAULTS and ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (USES_MODERN_API and 39 or 50))
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

-- Errors here used to reach the default error handler unprotected. Because this
-- pass is re-queued by events that keep firing (combat, auras, zoning), a single
-- bad state resolve turned into a wall of identical errors and every subsequent
-- camera update in that frame was skipped. Now one failure is reported at most
-- once every 10s and the other half of the pass still runs.
local lastUpdateErrorAt = {}

local function RunGuarded(func, label, ...)
    local ok, err = pcall(func, ...)
    if ok then return true end

    local now = (GetTime and GetTime()) or 0
    local previous = lastUpdateErrorAt[label] or 0
    if now == 0 or (now - previous) > 10 then
        lastUpdateErrorAt[label] = now
        Functions:logMessage("error", label .. ": " .. tostring(err))
    end
    return false
end

updateFrame:SetScript("OnUpdate", function(self)
    if not updatePending then
        self:Hide()
        return
    end
    updatePending = false
    self:Hide()

    -- Always refresh ActionCam too, so shoulder mode can switch on combat enter/leave.
    -- Pass methods directly instead of allocating two closures for every update.
    RunGuarded(Functions.UpdateActionCam, "UpdateActionCam", Functions)
    RunGuarded(Functions.UpdateSmartZoomState, "UpdateSmartZoomState", Functions, "auto_update")
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

    -- Roster counts already define which raid/party unit tokens can exist, so
    -- UnitExists() was pure duplicate work. Prebuilt unit-token arrays also avoid
    -- allocating "raid"..i / "party"..i strings on every scan. Group-unit API
    -- returns may be secret on modern clients, so each value still goes through
    -- the secret-safe helper; an unreadable member is ignored instead of aborting
    -- the whole scan.
    local function ScanRaid(count)
        for i = 1, count do
            local unit = RAID_UNITS[i]
            local isSelf = IsTruthySafe(SafeValueCall(UnitIsUnit, unit, "player"))
            if not isSelf and IsTruthySafe(SafeValueCall(UnitAffectingCombat, unit)) then
                return true
            end
        end
        return false
    end

    local function ScanParty(count)
        for i = 1, count do
            if IsTruthySafe(SafeValueCall(UnitAffectingCombat, PARTY_UNITS[i])) then
                return true
            end
        end
        return false
    end

    if inRaid then
        if SafeBoolCall(IsEncounterInProgress) then
            result = true
        else
            result = ScanRaid(math.min(memberCount, 40))
        end
    elseif inGroup then
        result = ScanParty(math.min(memberCount, 4))
    end

    runtimeCache.groupCombatKey = key
    runtimeCache.groupCombat = result
    runtimeCache.groupCombatExpiresAt = now + GROUP_COMBAT_CACHE_SECONDS

    return result
end

-- Activity detection now lives in Contexts.lua, which distinguishes arena from
-- battleground from world PvP, and dungeon from Mythic+ from scenario, instead
-- of collapsing them into the old "pvp" / "party" buckets.
local function GetCombatContextRaw(db)
    if Contexts and Contexts.Resolve then
        return Contexts:Resolve(db)
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

-- Threat APIs conditionally return secrets since 12.0.1, and the whole point of
-- a secret is that `threatStatus > 0` errors rather than lying. SafeValueCall
-- only guards the CALL, so the comparison used to raise a Lua error on every
-- camera pass inside instanced content - which is precisely where threat-driven
-- combat zoom is supposed to work. An unreadable threat level means "no threat
-- signal", and the player/group triggers still drive combat zoom there.
local function ResolveThreatFlag()
    local status = SafeValueCall(UnitThreatSituation, "player")
    local plainStatus
    if Compat.Plain then
        plainStatus = Compat.Plain(status)
    else
        plainStatus = status
    end
    if plainStatus == nil then return false end
    local numericStatus = tonumber(plainStatus)
    return (numericStatus ~= nil and numericStatus > 0) and true or false
end

function Functions:ResolveGlidingInfo(signals)
    if rawget(signals, "__glideResolved") then return end
    rawset(signals, "__glideResolved", true)

    local isGliding, canGlide, forwardSpeed = false, false, nil
    if _G.C_PlayerInfo and _G.C_PlayerInfo.GetGlidingInfo then
        local ok, glidingValue, canGlideValue, speedValue = pcall(_G.C_PlayerInfo.GetGlidingInfo)
        if ok then
            isGliding = IsTruthySafe(glidingValue)
            canGlide = IsTruthySafe(canGlideValue)
            local plainSpeed = Compat.Plain and Compat.Plain(speedValue) or speedValue
            forwardSpeed = tonumber(plainSpeed)
        end
    end

    rawset(signals, "isGliding", isGliding)
    rawset(signals, "canGlide", canGlide)
    rawset(signals, "glideSpeed", forwardSpeed)
end

-- Signals are lazy except for the activity context, which is cheap and shared.
-- Combat/threat and anything that touches the mount journal, aura scans or
-- shapeshift probes is computed on FIRST ACCESS and then memoised.
--
-- This matters because the state machine is a priority ladder: AFK and combat
-- both outrank mount, and each of their branches is guarded by its own db
-- option. Previously every camera pass paid for IsFlyingMountActive (a scan of
-- the entire mount journal), IsDragonRacingRaceActive and IsSkyriding even when
-- the player was in combat and the result was discarded, or when
-- autoMountZoom was switched off entirely and it could never be read.
local LAZY_SIGNALS = {
    playerInCombat = function()
        return SafeBoolCall(UnitAffectingCombat, "player")
    end,
    groupInCombat = function()
        return Functions:IsGroupInCombat()
    end,
    hasThreat = function()
        return ResolveThreatFlag()
    end,
    forceCombatZoom = function(db)
        return (db and ShouldForceCombatZoom(db)) and true or false
    end,
    -- Keep physical mount and shapeshift/travel-form state separate.
    -- called their union "isMounted", which made Druid travel form look like a
    -- mount and triggered unnecessary mount-journal resolution in diagnostics.
    isMounted = function()
        return SafeBoolCall(IsMounted)
    end,
    isTravelForm = function()
        return Functions:IsTravelFormOnlyActive() and true or false
    end,
    travelActive = function(db, s)
        return s.isMounted or s.isTravelForm
    end,
    mountZoomActive = function(db, s)
        return s.travelActive and Functions:ShouldUseMountZoom(db, true) or false
    end,
    isSkyriding = function(db, s)
        return s.travelActive and Functions:IsSkyriding() or false
    end,
    isDragonRacing = function(db, s)
        return s.isMounted and Functions:IsDragonRacingRaceActive() or false
    end,
    inVehicle = function()
        return SafeBoolCall(_G.UnitInVehicle, "player")
    end,
    onTaxi = function()
        return SafeBoolCall(UnitOnTaxi, "player")
    end,
    isFlying = function()
        return SafeBoolCall(IsFlying, "player")
    end,
    isFalling = function()
        return SafeBoolCall(_G.IsFalling, "player")
    end,
    isSwimming = function()
        return SafeBoolCall(_G.IsSwimming, "player")
    end,
    isSubmerged = function()
        return SafeBoolCall(_G.IsSubmerged, "player")
    end,
    isGliding = function(db, s)
        Functions:ResolveGlidingInfo(s)
        return rawget(s, "isGliding")
    end,
    canGlide = function(db, s)
        Functions:ResolveGlidingInfo(s)
        return rawget(s, "canGlide")
    end,
    glideSpeed = function(db, s)
        Functions:ResolveGlidingInfo(s)
        return rawget(s, "glideSpeed")
    end,
    dragonRacingFirstPerson = function(db)
        return Functions:ShouldUseDragonRacingFirstPerson(db) and true or false
    end,
    mountZoomMode = function(db)
        return Functions:GetMountZoomMode(db)
    end,
    isFlyingMount = function(db, s)
        s:ResolveActiveMount()
        return rawget(s, "isFlyingMount")
    end,
    mountTypeID = function(db, s)
        s:ResolveActiveMount()
        return rawget(s, "mountTypeID")
    end,
    activeMountID = function(db, s)
        s:ResolveActiveMount()
        return rawget(s, "activeMountID")
    end,
}

local signalsMeta = {
    __index = function(self, key)
        local resolver = LAZY_SIGNALS[key]
        if not resolver then return nil end

        local value = resolver(rawget(self, "__db"), self)
        rawset(self, key, value)
        return value
    end,
}

-- IsFlyingMountActive returns three values from one journal lookup, so resolve
-- them together instead of scanning three times.
local function ResolveActiveMount(self)
    if rawget(self, "__mountResolved") then return end
    rawset(self, "__mountResolved", true)

    if not self.isMounted then
        rawset(self, "isFlyingMount", false)
        rawset(self, "mountTypeID", nil)
        rawset(self, "activeMountID", nil)
        return
    end

    local isFlying, mountTypeID, mountID = Functions:IsFlyingMountActive()
    rawset(self, "isFlyingMount", isFlying and true or false)
    rawset(self, "mountTypeID", mountTypeID)
    rawset(self, "activeMountID", mountID)
end

local function GetCombatSignals(db)
    local now = GetTime and GetTime() or 0
    if runtimeCache.combatSignals
        and runtimeCache.combatSignalsDb == db
        and runtimeCache.combatSignalsExpiresAt > now then
        return runtimeCache.combatSignals
    end

    local signals = setmetatable({
        __db = db,
        ResolveActiveMount = ResolveActiveMount,

        -- Only context is eager. Combat, threat and mount signals resolve on first
        -- access, so mount-only/manual profiles do not pay for raid scans or
        -- threat queries that cannot affect their camera state.
        rawContext = GetCombatContextRaw(db),
    }, signalsMeta)

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

-- Resolves ONLY what the camera pass needs: which state we are in and how far
-- to zoom. Kept separate from BuildStatusSnapshot because that function
-- allocates a ~50 field table and, more importantly, reads every mount signal
-- in order to populate it - which defeats the lazy tier above. The camera pass
-- runs on every queued update; the full snapshot is only needed by /mcd status
-- and the options panel, where an extra mount journal lookup costs nothing.
local function ResolveZoomTarget(db, includeDiagnostics)
    local defaults = ns.Database and ns.Database.DEFAULTS
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or 39

    local signals = GetCombatSignals(db)
    local rawContext = signals.rawContext
    local resolvedContext = rawContext
    local triggerConfig = GetCombatTriggerConfig(db)
    local activeTriggers = { player = false, group = false, threat = false, worldBoss = false }
    local combatActive = false
    if includeDiagnostics or (db and db.autoCombatZoom) then
        combatActive, triggerConfig, activeTriggers = GetCombatActivation(db, signals)
    end

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

    return state, targetYards, resolvedContext, signals, combatActive,
        triggerConfig, activeTriggers, rawContext,
        targetDistanceKey, targetSourceType, targetPresetId, maxYards
end

local function BuildStatusSnapshot(db)
    local state, targetYards, resolvedContext, signals, _,
        triggerConfig, activeTriggers, rawContext,
        targetDistanceKey, targetSourceType, targetPresetId = ResolveZoomTarget(db, true)

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
        isTravelForm = signals.isTravelForm,
        travelActive = signals.travelActive,
        inVehicle = signals.inVehicle,
        onTaxi = signals.onTaxi,
        isFlying = signals.isFlying,
        isFalling = signals.isFalling,
        isSwimming = signals.isSwimming,
        isSubmerged = signals.isSubmerged,
        isGliding = signals.isGliding,
        canGlide = signals.canGlide,
        glideSpeed = signals.glideSpeed,
        isAFK = SafeBoolCall(UnitIsAFK, "player"),
        isDead = SafeBoolCall(UnitIsDead, "player"),
        isGhost = SafeBoolCall(UnitIsGhost, "player"),
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
        indirectCollisionOffset = (db and db.cameraIndirectOffset) or GetIndirectOffsetDefault(),
        occludedSilhouetteEnabled = (db and db.occludedSilhouettePlayer) and true or false,
        triggerConfig = triggerConfig,
        activeTriggers = activeTriggers,
        activeReturnDelay = GetCombatReturnDelay(db, resolvedContext),
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

-- Called once per option row while the settings panel is drawing, so it must
-- not allocate the full status snapshot just to read two fields off it.
local function GetCurrentZoomContext(db)
    local state, _, resolvedContext = ResolveZoomTarget(db)
    return state, resolvedContext
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
    return SafeBoolCall(UnitIsAFK, "player")
end

local function IsProfessionActivityBlockingAfk()
    if not USES_MODERN_API then
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
        or (Compat.MAX_CAMERA_YARDS or (USES_MODERN_API and 39 or 50))
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

    if SafeBoolCall(_G.UnitInVehicle, "player") then
        return false, "in_vehicle"
    end

    if db.afkSkipMounted ~= false and IsInTravelForm() then
        return false, "travel_active"
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

-- The AFK safe exit was keyboard-only, which is a trap on a gamepad: the UI is
-- hidden, the frame above swallows keyboard input, and a player on a controller
-- may have no ESC to press at all. Gamepad buttons arrive through a separate
-- input path (Frame:EnableGamePadButton + OnGamePadButtonDown), so they have to
-- be wired up explicitly.
--
-- ANY button exits, not just the one mapped to Esc. AFK mode is a screensaver;
-- if the player touched the controller they are back, and guessing at
-- GamePadEmulateEsc would leave anyone with a custom mapping stuck.
if safeExitFrame.EnableGamePadButton then
    pcall(safeExitFrame.EnableGamePadButton, safeExitFrame, true)
end
if safeExitFrame.SetPropagateGamePadInput then
    -- Deliberately propagating rather than swallowing. This frame sits at
    -- TOOLTIP strata over the whole WorldFrame, so blocking gamepad input here
    -- would make the controller feel dead for the frame or two before the UI
    -- comes back.
    pcall(safeExitFrame.SetPropagateGamePadInput, safeExitFrame, true)
end
safeExitFrame:SetScript("OnGamePadButtonDown", function()
    Functions:ManualExitAfkMode()
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

-- Linear cross-fade between "fully centred" at fadeEnd yards and "full
-- shoulder offset" at fadeStart yards. Both edges are configurable now; they
-- used to be hardcoded at 2.0 and 5.0.
local function GetShoulderOffsetZoomFactor(zoomLevel, fadeStart, fadeEnd)
    if not (fadeStart and fadeEnd) or fadeStart <= fadeEnd then
        return 1
    end

    if zoomLevel <= fadeEnd then
        return 0
    elseif zoomLevel >= fadeStart then
        return 1
    end

    return (zoomLevel - fadeEnd) / (fadeStart - fadeEnd)
end

function Functions:GetShoulderSettings(db)
    db = db or DB()
    if not db then
        return SHOULDER.OFFSET_DEFAULT, SHOULDER.FADE_START_DEFAULT, SHOULDER.FADE_END_DEFAULT, true, true
    end

    local offset = ClampNumber(db.actionCamShoulderOffset, SHOULDER.OFFSET_MIN, SHOULDER.OFFSET_MAX)
    if offset == nil then offset = SHOULDER.OFFSET_DEFAULT end

    local smartFade = db.actionCamShoulderSmartFade ~= false
    local compensate = db.actionCamShoulderModelCompensation ~= false

    local fadeEnd = ClampNumber(db.actionCamShoulderFadeEnd, 0, SHOULDER.FADE_MAX) or SHOULDER.FADE_END_DEFAULT
    local fadeStart = ClampNumber(db.actionCamShoulderFadeStart, 0, SHOULDER.FADE_MAX) or SHOULDER.FADE_START_DEFAULT

    -- An inverted or collapsed window would make the offset flip between 0 and
    -- full on a single zoom tick. Treat it as "no fade" instead.
    if fadeStart <= fadeEnd then
        smartFade = false
    end

    return offset, fadeStart, fadeEnd, smartFade, compensate
end

-- Returns two flags: whether the CVar had to be rewritten, and whether the
-- camera moved at all. The OnUpdate driver below backs its polling off on the
-- second one, so a completely static camera stops costing a frame slot while a
-- zoom that happens to leave the offset unchanged still keeps polling hot.
function Functions:ApplyShoulderOffset(force)
    local db = DB()
    if not db then return false, false end

    if raceFirstPersonApplied or not shoulderHandlerFrame:IsShown() then
        shoulderHandlerFrame.lastZoom = -1
        shoulderHandlerFrame.lastOffset = nil
        return false, false
    end

    local offset, fadeStart, fadeEnd, smartFade, compensate = self:GetShoulderSettings(db)

    local currentZoom = (GetCameraZoom and GetCameraZoom()) or 0
    if (not force)
        and shoulderHandlerFrame.lastZoom >= 0
        and math_abs(shoulderHandlerFrame.lastZoom - currentZoom) < SHOULDER.ZOOM_EPSILON then
        return false, false
    end
    shoulderHandlerFrame.lastZoom = currentZoom

    local zoomFactor = smartFade and GetShoulderOffsetZoomFactor(currentZoom, fadeStart, fadeEnd) or 1

    local modelFactor = 1.0
    -- Skipping compensation is not just a preference: it removes the model /
    -- mount / shapeshift lookups from the hot path entirely for players who want
    -- the raw CVar value.
    if compensate and ShoulderCompensation and ShoulderCompensation.GetFactor then
        local okFactor, value = pcall(ShoulderCompensation.GetFactor, ShoulderCompensation)
        if okFactor and tonumber(value) then
            modelFactor = value
        elseif not okFactor then
            Functions:logMessage("warning", "Shoulder compensation failed; using neutral offset factor.")
        end
    end

    local target = offset * zoomFactor * modelFactor

    -- The old code compared ZOOM and then wrote the CVar unconditionally. Past
    -- the outer fade edge - which is where the camera sits most of the time -
    -- every bit of zoom jitter therefore produced a full GetCVar/SetCVar pair
    -- for a value that had not changed. Compare the RESULT instead.
    local previous = shoulderHandlerFrame.lastOffset
    if (not force) and previous ~= nil and math_abs(previous - target) < SHOULDER.OFFSET_EPSILON then
        return false, true
    end

    shoulderHandlerFrame.lastOffset = target
    self:UpdateOwnedActionCamCVar("test_cameraOverShoulder", target)
    return true, true
end

local shoulderRefreshQueued = false

function Functions:RequestShoulderRefresh()
    -- When ActionCam shoulder tracking is not active there is nothing to write.
    -- Keep only the compensation cache invalidation so the next activation uses
    -- fresh model/mount data instead of scheduling timers for every aura/spell.
    if not shoulderHandlerFrame:IsShown() then
        if ShoulderCompensation and ShoulderCompensation.Invalidate then
            ShoulderCompensation:Invalidate()
        end
        shoulderHandlerFrame.lastZoom = -1
        return
    end

    if shoulderRefreshQueued then
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

    -- One immediate pass makes model changes feel instant. One trailing pass
    -- catches the final model after shapeshift/mount event bursts settle. The old
    -- 0/.05/.18 three-pass recursion could remain alive indefinitely under
    -- UNIT_AURA churn.
    RefreshShoulderNow(false)

    if not (C_Timer and C_Timer.After) then
        shoulderRefreshQueued = false
        RefreshShoulderNow(true)
        return
    end

    C_Timer.After(0.16, function()
        if not shoulderRefreshQueued then return end
        -- The trailing pass observes the latest state after the event burst, so
        -- no recursive refresh series is necessary.
        shoulderRefreshQueued = false
        RefreshShoulderNow(true)
    end)
end

shoulderHandlerFrame.lastZoom = -1
shoulderHandlerFrame.lastOffset = nil
shoulderHandlerFrame.elapsed = 0
shoulderHandlerFrame.interval = SHOULDER.UPDATE_INTERVAL
shoulderHandlerFrame.idleFor = 0

function shoulderHandlerFrame:ResetPolling()
    self.elapsed = 0
    self.idleFor = 0
    self.interval = SHOULDER.UPDATE_INTERVAL
end

shoulderHandlerFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + (elapsed or 0)

    local interval = self.interval or SHOULDER.UPDATE_INTERVAL
    if self.elapsed < interval then
        return
    end
    self.elapsed = 0

    local _, moved = Functions:ApplyShoulderOffset(false)
    if moved then
        -- The camera moved: go back to per-frame responsiveness immediately.
        self.idleFor = 0
        self.interval = SHOULDER.UPDATE_INTERVAL
        return
    end

    self.idleFor = (self.idleFor or 0) + interval
    if self.idleFor >= SHOULDER.IDLE_AFTER then
        self.interval = SHOULDER.IDLE_INTERVAL
    end
end)
shoulderHandlerFrame:Hide()

function Functions:IsForeverActionCamRuntimeAllowed()
    -- Product rule: on Forever, Action Camera now belongs to the built-in
    -- Gamepad UI (Alpha) workflow. Do not leave a previously-enabled shoulder
    -- profile active after that master mode is turned off. Other WoW flavours
    -- keep their existing, independent ActionCam behaviour.
    if not Compat.IS_FOREVER then
        return true
    end

    local gamePad = ns.GamePad
    if not (gamePad and gamePad.IsSupported and gamePad:IsSupported()) then
        return false
    end
    return gamePad:IsActive() and true or false
end

function Functions:ShouldEnableShoulderNow()
    local db = DB()
    if not db then return false end
    if not self:IsForeverActionCamRuntimeAllowed() then return false end

    local inCombatEnabled = db.actionCamShoulderInCombat and true or false
    local outOfCombatEnabled = db.actionCamShoulderOutOfCombat and true or false

    if not inCombatEnabled and not outOfCombatEnabled then
        return false
    end
    if inCombatEnabled and outOfCombatEnabled then
        return true
    end

    local signals = GetCombatSignals(db)
    local inCombat = GetCombatActivation(db, signals)
    return inCombat and inCombatEnabled or outOfCombatEnabled
end

function Functions:UpdateActionCam()
    local db = DB()
    if not db then return end

    local guard = ns.CVarGuard

    local function PublishActionCamIntent(shoulderWanted, pitchWanted)
        if not (guard and guard.SetActionCamIntent) then return false end
        local ok, changed = pcall(guard.SetActionCamIntent, guard, shoulderWanted, pitchWanted)
        return ok and changed and true or false
    end

    local runtimeAllowed = self:IsForeverActionCamRuntimeAllowed()
    local shoulderManaged = runtimeAllowed
        and (db.actionCamShoulderInCombat or db.actionCamShoulderOutOfCombat)
        and true or false
    local pitchManaged = runtimeAllowed and db.actionCamPitch and true or false
    local pitchWanted = pitchManaged

    local dragonRaceFirstPerson = runtimeAllowed and self:ShouldUseDragonRacingFirstPerson(db) or false
    local shoulderWanted = shoulderManaged
        and (not dragonRaceFirstPerson)
        and self:ShouldEnableShoulderNow()
        or false

    -- ActionCam order matters on Forever. Its client default currently leaves
    -- CameraKeepCharacterCentered enabled, and since 11.0.2
    -- cameraReduceUnexpectedMovement can also suppress test_cameraOverShoulder.
    -- Mature camera addons such as DynamicCam disable those blockers before
    -- applying the shoulder CVar. Publish intent first, then synchronously arm
    -- CVarGuard before touching test_cameraDynamicPitch/test_cameraOverShoulder.
    local intentChanged = PublishActionCamIntent(shoulderWanted, pitchWanted)

    local blockersReady = true
    local blockerReason = nil
    if shoulderWanted or pitchWanted then
        -- Fast path: when intent has not changed and both blocker CVars are
        -- already clear, do not force a full guard reconciliation on every
        -- Smart Zoom/camera pass. External CVar changes have their own event
        -- path and will invalidate this state immediately.
        if guard and guard.IsActionCamReady then
            local ok, ready, reason = pcall(guard.IsActionCamReady, guard, shoulderWanted, pitchWanted)
            if ok then
                blockersReady = ready and true or false
                blockerReason = reason
            end
        end

        if intentChanged or not blockersReady then
            if guard and guard.Refresh then
                local ok, err = pcall(guard.Refresh, guard, true)
                if not ok then
                    blockersReady = false
                    blockerReason = "guard-error"
                    Functions:logMessage("error", "ActionCam compatibility guard failed: " .. tostring(err))
                end
            end

            if blockerReason ~= "guard-error" and guard and guard.IsActionCamReady then
                local ok, ready, reason = pcall(guard.IsActionCamReady, guard, shoulderWanted, pitchWanted)
                if ok then
                    blockersReady = ready and true or false
                    blockerReason = reason
                else
                    blockersReady = false
                    blockerReason = "readiness-error"
                    Functions:logMessage("error", "ActionCam readiness check failed: " .. tostring(ready))
                end
            end
        end
    end

    -- If a client-protected blocker could not be cleared, keep the desired
    -- intent published so the guard can retry after combat, but do not repeatedly
    -- hammer ActionCam CVars that the client is currently suppressing.
    local pitchApplied = pitchWanted and blockersReady
    if pitchManaged then
        self:UpdateOwnedActionCamCVar("test_cameraDynamicPitch", pitchApplied and 1 or 0)
    else
        self:RestoreOwnedActionCamCVar("test_cameraDynamicPitch")
    end

    local shoulderApplied = shoulderWanted and blockersReady
    if shoulderManaged and dragonRaceFirstPerson then
        if not raceFirstPersonApplied then
            raceFirstPersonApplied = true
        end
        ApplyRaceFirstPersonZoom()
        shoulderHandlerFrame:Hide()
        shoulderHandlerFrame:ResetPolling()
        shoulderHandlerFrame.lastZoom = -1
        shoulderHandlerFrame.lastOffset = nil
        self:UpdateOwnedActionCamCVar("test_cameraOverShoulder", 0)
    else
        if raceFirstPersonApplied then
            raceFirstPersonApplied = false
            self:ScheduleStabilizedUpdate({ 0, 0.05, 0.20 }, true)
        end

        if shoulderManaged and shoulderApplied then
            shoulderHandlerFrame:Show()
            shoulderHandlerFrame:ResetPolling()
            self:ApplyShoulderOffset(true)
        else
            shoulderHandlerFrame:Hide()
            shoulderHandlerFrame:ResetPolling()
            shoulderHandlerFrame.lastZoom = -1
            shoulderHandlerFrame.lastOffset = nil
            if shoulderManaged then
                self:UpdateOwnedActionCamCVar("test_cameraOverShoulder", 0)
            else
                self:RestoreOwnedActionCamCVar("test_cameraOverShoulder")
            end
        end
    end

    -- Gamepad face-direction compatibility is a second layer: ActionCam intent
    -- and blockers are resolved first, then controller-specific movement policy.
    if intentChanged and ns.GamePad and ns.GamePad.RefreshFaceMovement then
        pcall(ns.GamePad.RefreshFaceMovement, ns.GamePad)
    end

    -- On disable (or a partial transition such as shoulder off / pitch still on)
    -- reconcile after the ActionCam CVars have been cleared so saved Blizzard
    -- motion settings can be restored without a one-frame fight.
    if not shoulderWanted and not pitchWanted then
        if ns.GamePad and ns.GamePad.SetActionCamBlockerReason then
            pcall(ns.GamePad.SetActionCamBlockerReason, ns.GamePad, nil)
        end
        RequestCVarGuardRefresh(true)
    elseif not blockersReady then
        RequestCVarGuardRefresh(true)
        if blockerReason and ns.GamePad and ns.GamePad.SetActionCamBlockerReason then
            pcall(ns.GamePad.SetActionCamBlockerReason, ns.GamePad, blockerReason)
        end
    else
        if ns.GamePad and ns.GamePad.SetActionCamBlockerReason then
            pcall(ns.GamePad.SetActionCamBlockerReason, ns.GamePad, nil)
        end
        RequestCVarGuardRefresh(false)
    end
end

function Functions:ToggleActionCamShoulderForCurrentContext()
    local db = DB()
    if not db then return false end

    local inCombat = SafeBoolCall(UnitAffectingCombat, "player")
    local key = inCombat and "actionCamShoulderInCombat" or "actionCamShoulderOutOfCombat"
    db[key] = not db[key]
    self:UpdateActionCam()
    NotifyConfigChanged()
    return db[key]
end

function Functions:SwapActionCamShoulder()
    local db = DB()
    if not db then return nil end

    local offset = ClampNumber(db.actionCamShoulderOffset, SHOULDER.OFFSET_MIN, SHOULDER.OFFSET_MAX)
        or SHOULDER.OFFSET_DEFAULT
    if math_abs(offset) < SHOULDER.OFFSET_EPSILON then
        offset = SHOULDER.OFFSET_DEFAULT
    else
        offset = -offset
    end
    db.actionCamShoulderOffset = offset
    self:UpdateActionCam()
    NotifyConfigChanged()
    return offset
end

function Functions:CenterActionCamShoulder()
    local db = DB()
    if not db then return false end
    db.actionCamShoulderOffset = 0
    self:UpdateActionCam()
    NotifyConfigChanged()
    return true
end

function Functions:OpenActionCamSettings()
    if IS_FOREVER and ns.Config and ns.Config.OpenGamePadPanel then
        ns.Config:OpenGamePadPanel()
        return true
    end
    if ns.Config and ns.Config.Open then
        ns.Config:Open()
        return true
    end
    return false
end

function Functions:PrepareForLogout()
    -- Temporary ActionCam values should never become the next session's client
    -- defaults simply because the player logged out while the feature was on.
    -- Keep the profile preference, release only the runtime ownership. The next
    -- login/world-entry pass will re-apply it after the camera is initialized.
    shoulderHandlerFrame:Hide()
    shoulderHandlerFrame:ResetPolling()
    shoulderHandlerFrame.lastZoom = -1
    shoulderHandlerFrame.lastOffset = nil
    raceFirstPersonApplied = false

    local guard = ns.CVarGuard
    if guard and guard.SetActionCamIntent then
        guard:SetActionCamIntent(false, false)
    end
    if guard and guard.RestoreActionCamOutputs then
        guard:RestoreActionCamOutputs()
    end
    if guard and guard.Refresh then
        guard:Refresh(true)
    end

    if ns.GamePad and ns.GamePad.RestoreFaceMovementDefaults then
        pcall(ns.GamePad.RestoreFaceMovementDefaults, ns.GamePad)
    elseif ns.GamePad and ns.GamePad.RefreshFaceMovement then
        pcall(ns.GamePad.RefreshFaceMovement, ns.GamePad)
    end
end

-- =====================================================================
-- 12) SMART ZOOM CORE (FIXED: no “sticky” state)
-- =====================================================================
-- Hot path. Returns a tiny context table rather than the full status snapshot;
-- UpdateSmartZoomState only ever reads resolvedContext off the third value.
local function ComputeDesiredState(db)
    local state, targetYards, resolvedContext = ResolveZoomTarget(db)
    return state, targetYards, { resolvedContext = resolvedContext }
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

    -- Return delays are hysteresis values: changing one must not yank the camera
    -- right now, it only affects the next time combat ends.
    if key == "dismountDelay" or DELAY_KEYS[key] then
        return false
    end

    local state, combatContext = GetCurrentZoomContext(db)

    if key == "minZoomFactor" then
        return state == ZOOM_STATE_NONE and GetDistancePresetId(db, key) == "manual"
    elseif key == "mountZoomFactor" then
        return state == ZOOM_STATE_MOUNT and GetDistancePresetId(db, key) == "manual"
    elseif key == "worldCombatZoomFactor" then
        return state == ZOOM_STATE_COMBAT and combatContext == "world" and GetDistancePresetId(db, key) == "manual"
    elseif COMBAT_CONTEXT_BY_DISTANCE_KEY[key] then
        return state == ZOOM_STATE_COMBAT
            and combatContext == COMBAT_CONTEXT_BY_DISTANCE_KEY[key]
            and GetDistancePresetId(db, key) == "manual"
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
        elseif COMBAT_CONTEXT_BY_DISTANCE_KEY[distanceKey] then
            return state == ZOOM_STATE_COMBAT
                and combatContext == COMBAT_CONTEXT_BY_DISTANCE_KEY[distanceKey]
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
        NotifyConfigChanged(newState, targetYards)
        return
    end
    if stateSame and capAligned and event ~= "manual_update" then
        NotifyConfigChanged(newState, targetYards)
        return
    end

    -- Any change invalidates old delayed timers
    stateToken = stateToken + 1
    currentZoomState = newState

    -- Record the player's combat rhythm across this transition. This has to
    -- happen before the delay is computed below, so the lull that just ended is
    -- already part of the sample set that decides how long to wait.
    if newState == ZOOM_STATE_COMBAT then
        if previousState ~= ZOOM_STATE_COMBAT then
            NoteCombatStarted()
        end
    elseif previousState == ZOOM_STATE_COMBAT then
        NoteCombatEnded()
    end

    if newState == ZOOM_STATE_NONE and event ~= "manual_update" then
        local delay = 0
        local returnKind = nil
        local returnContext = nil

        if previousState == ZOOM_STATE_COMBAT then
            returnKind = "combat"
            returnContext = previousCombatContext or "world"
            -- Adaptive: while the player keeps re-pulling, this stretches to
            -- cover the observed lulls so the camera stops pumping in and out.
            delay = GetAdaptiveReturnDelay(db, returnContext)
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

function Functions:ResetCombatRhythm()
    ResetCombatRhythm()
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

        -- The library being present is not the same as the options table having
        -- been registered: if Ace3 arrived after this addon loaded, every lib
        -- below reports "found" while the settings window still refuses to open.
        -- This line is the one that distinguishes those two cases.
        {
            label = "Options registered",
            found = (ns.Config and ns.Config.IsRegistered and ns.Config:IsRegistered()) or false,
            required = true,
        },
        {
            label = "Profile storage",
            found = (ns.Database and ns.Database.db and not ns.Database.usingFallbackDB) or false,
            required = true,
        },
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
        .. " interface=" .. tostring(Compat.INTERFACE or "unknown")
        .. " modernAPI=" .. FormatBool(Compat.USES_MODERN_API)
        .. " forever=" .. FormatBool(Compat.IS_FOREVER))
    self:SendMessage(" - zoom: " .. tostring((GetCameraZoom and GetCameraZoom()) or "unknown"))
    self:SendMessage(" - state: " .. tostring(snapshot and snapshot.state or "unknown") .. " previous=" .. tostring(snapshot and snapshot.previousState or (controllerSnapshot and controllerSnapshot.previousState) or "none"))
    self:SendMessage(" - target yards: " .. tostring(snapshot and snapshot.targetYards or "unknown"))
    self:SendMessage(" - pending return: " .. tostring(snapshot and snapshot.pendingReturnActive and "active" or "none") .. " remaining=" .. tostring(snapshot and snapshot.pendingReturnRemaining or 0))
    self:SendMessage(" - combat: player=" .. FormatBool(snapshot and snapshot.playerInCombat) .. " group=" .. FormatBool(snapshot and snapshot.groupInCombat) .. " threat=" .. FormatBool(snapshot and snapshot.hasThreat))
    self:SendMessage(" - travel: mounted=" .. FormatBool(snapshot and snapshot.isMounted)
        .. " travelForm=" .. FormatBool(snapshot and snapshot.isTravelForm)
        .. " active=" .. FormatBool(snapshot and snapshot.travelActive)
        .. " flying=" .. FormatBool(snapshot and snapshot.isFlying)
        .. " skyriding=" .. FormatBool(snapshot and snapshot.isSkyriding))
    self:SendMessage(" - movement: gliding=" .. FormatBool(snapshot and snapshot.isGliding)
        .. " canGlide=" .. FormatBool(snapshot and snapshot.canGlide)
        .. " glideSpeed=" .. tostring(snapshot and snapshot.glideSpeed or "n/a")
        .. " vehicle=" .. FormatBool(snapshot and snapshot.inVehicle)
        .. " taxi=" .. FormatBool(snapshot and snapshot.onTaxi)
        .. " falling=" .. FormatBool(snapshot and snapshot.isFalling)
        .. " swimming=" .. FormatBool(snapshot and snapshot.isSwimming)
        .. " submerged=" .. FormatBool(snapshot and snapshot.isSubmerged))
    self:SendMessage(" - player: afkFlag=" .. FormatBool(snapshot and snapshot.isAFK)
        .. " dead=" .. FormatBool(snapshot and snapshot.isDead)
        .. " ghost=" .. FormatBool(snapshot and snapshot.isGhost)
        .. " afkMode=" .. FormatBool(snapshot and snapshot.afkActive)
        .. " shoulder=" .. FormatBool(snapshot and snapshot.actionCamShoulderActive)
        .. " dynamicPitch=" .. FormatBool(snapshot and snapshot.dynamicPitchActive))
    self:SendMessage(" - CVars: cameraDistanceMaxZoomFactor=" .. FormatCVar("cameraDistanceMaxZoomFactor") .. ", cameraDistanceMax=" .. FormatCVar("cameraDistanceMax") .. ", cameraDistanceMoveSpeed=" .. FormatCVar("cameraDistanceMoveSpeed") .. ", cameraZoomSpeed=" .. FormatCVar("cameraZoomSpeed"))
    self:SendMessage(" - timing: manualWheelSpeed=" .. tostring(db.moveViewDistance or "unknown") .. ", zoomTransitionTime=" .. tostring(db.zoomTransitionTime or "unknown"))
    self:SendMessage(" - CVars: keepCentered=" .. FormatCVar("CameraKeepCharacterCentered") .. ", reduceUnexpectedMovement=" .. FormatCVar("cameraReduceUnexpectedMovement") .. ", shoulder=" .. FormatCVar("test_cameraOverShoulder") .. ", dynamicPitch=" .. FormatCVar("test_cameraDynamicPitch"))

    do
        local shoulderIntent, pitchIntent = false, false
        local guard = ns.CVarGuard
        if guard and guard.GetActionCamIntent then
            local ok, wantShoulder, wantPitch = pcall(guard.GetActionCamIntent, guard)
            if ok then
                shoulderIntent, pitchIntent = wantShoulder, wantPitch
            end
        end
        local offset, fadeStart, fadeEnd, smartFade, compensate = self:GetShoulderSettings(db)
        self:SendMessage(string.format(" - shoulder: intent=%s pitchIntent=%s offset=%.2f fade=%s(%.1f..%.1f) modelCompensation=%s poll=%.0fms",
            FormatBool(shoulderIntent), FormatBool(pitchIntent), offset,
            FormatBool(smartFade), fadeEnd, fadeStart, FormatBool(compensate),
            (shoulderHandlerFrame.interval or SHOULDER.UPDATE_INTERVAL) * 1000))
    end

    self:PrintGamePadStatus()
    if IS_FOREVER then
        self:SendMessage(" - Forever fog: volumeFog=" .. FormatCVar("volumeFog") .. ", interior=" .. FormatCVar("volumeFogInterior") .. ", level=" .. FormatCVar("volumeFogLevel"))
        self:SendMessage(" - Forever ground effects: managed=" .. FormatBool(db and db.foreverGroundEffectsOverride) .. ", density=" .. FormatCVar("groundEffectDensity") .. ", distance=" .. FormatCVar("groundEffectDist") .. ", fade=" .. FormatCVar("groundEffectFade"))
    end

    -- Adaptive return: without these numbers there is no way to tell whether
    -- the camera stayed out because adaptation kicked in or because the pull
    -- simply never ended.
    do
        local samples, longest, applied, enabled = GetRhythmStatus(db)
        self:SendMessage(string.format(" - adaptiveReturn: enabled=%s samples=%d longestGap=%.1fs applied=%s",
            FormatBool(enabled), samples, longest,
            applied and string.format("%.1fs", applied) or "base"))
    end

    -- Reactive Zoom is hard to tune blind: the useful numbers are the live gap
    -- between the wheel target and the camera, and the measured frame time that
    -- decides whether a notch gets eased at all.
    if ns.ReactiveZoom and ns.ReactiveZoom.GetStatus then
        local rz = ns.ReactiveZoom:GetStatus()
        self:SendMessage(" - reactiveZoom: enabled=" .. FormatBool(rz.enabled)
            .. " installed=" .. FormatBool(rz.installed)
            .. " libCamera=" .. FormatBool(rz.libCamera)
            .. " easing=" .. tostring(rz.easing))
        self:SendMessage(string.format(" - reactiveZoom: zoom=%.2f target=%s max=%.2f frame=%.1fms passthrough=%s",
            tonumber(rz.currentZoom) or -1,
            rz.target and string.format("%.2f", rz.target) or "none",
            tonumber(rz.maxZoom) or -1,
            (tonumber(rz.secondsPerFrame) or 0) * 1000,
            FormatBool(rz.passthrough)))
    end
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
        local maxYards = (ns.Database and ns.Database.DEFAULTS and ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (USES_MODERN_API and 39 or 50))
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

local FOREVER_GROUND_EFFECT_SPECS = {
    groundEffectDensity = { min = 16, max = 256, fallback = 16 },
    groundEffectDist = { min = 32, max = 600, fallback = 70 },
    groundEffectFade = { min = 0, max = 600, fallback = 70 },
}

local function GetForeverGroundEffectDefault(cvarName)
    local spec = FOREVER_GROUND_EFFECT_SPECS[cvarName]
    if not spec then return nil end

    local value = Compat.SafeGetCVarNumberDefault and Compat.SafeGetCVarNumberDefault(cvarName) or nil
    if value == nil then
        local defaults = ns.Database and ns.Database.DEFAULTS and ns.Database.DEFAULTS.FOREVER_ENVIRONMENT
        value = defaults and tonumber(defaults[cvarName]) or nil
    end

    value = ClampNumber(value, spec.min, spec.max) or spec.fallback
    return math_floor(value + 0.5)
end

function Functions:ResetForeverGroundEffectCVar(cvarName, suppressNotify)
    if not IS_FOREVER then return false end
    if not FOREVER_GROUND_EFFECT_SPECS[cvarName] then return false end
    if Compat.HasCVar and not Compat.HasCVar(cvarName) then return true end

    local db = DB()
    if not db then return false end

    local defaultValue = GetForeverGroundEffectDefault(cvarName)
    if defaultValue == nil then return false end

    -- Keep the profile and the live CVar in lockstep. The reset uses the
    -- client's own built-in default, not the current graphics preset value.
    db[cvarName] = defaultValue
    UpdateCVar(cvarName, defaultValue)
    if not suppressNotify then
        NotifyConfigChanged()
    end
    return true, defaultValue
end

function Functions:ResetForeverGroundEffectsToDefaults()
    if not IS_FOREVER then return false end

    local ok = true
    for _, cvarName in ipairs({ "groundEffectDensity", "groundEffectDist", "groundEffectFade" }) do
        if not self:ResetForeverGroundEffectCVar(cvarName, true) then
            ok = false
        end
    end
    NotifyConfigChanged()
    return ok
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

    -- CVarGuard owns the temporary ActionCam exception. Never briefly re-enable
    -- Reduce Unexpected Movement from the profile while shoulder intent says it
    -- must stay off; doing so causes a visible snap on Forever and an immediate
    -- write-back from the guard.
    local reduceUnexpectedMovement = db.reduceUnexpectedMovement and 1 or 0
    local guard = ns.CVarGuard
    if guard and guard.ShouldBlockReduceUnexpectedMovement then
        local ok, shouldBlock = pcall(guard.ShouldBlockReduceUnexpectedMovement, guard)
        if ok and shouldBlock then
            reduceUnexpectedMovement = 0
        end
    end
    UpdateCVar("cameraReduceUnexpectedMovement", reduceUnexpectedMovement)

    UpdateCVar("cameraYawMoveSpeed", db.cameraYawMoveSpeed)
    UpdateCVar("cameraPitchMoveSpeed", db.cameraPitchMoveSpeed)
    UpdateCVar("cameraIndirectVisibility", db.cameraIndirectVisibility and 1 or 0)
    UpdateCVar("cameraIndirectOffset", db.cameraIndirectOffset or GetIndirectOffsetDefault())
    UpdateCVar("occludedSilhouettePlayer", db.occludedSilhouettePlayer and 1 or 0)
    UpdateCVar("resampleAlwaysSharpen", db.resampleAlwaysSharpen and 1 or 0)
    UpdateCVar("SoftTargetIconGameObject", db.softTargetInteract and 1 or 0)

    if IS_FOREVER then
        UpdateCVar("volumeFog", db.volumeFog and 1 or 0)
        UpdateCVar("volumeFogInterior", db.volumeFogInterior and 1 or 0)
        UpdateCVar("volumeFogLevel", db.volumeFogLevel)
        if db.foreverGroundEffectsOverride then
            UpdateCVar("groundEffectDensity", db.groundEffectDensity)
            UpdateCVar("groundEffectDist", db.groundEffectDist)
            UpdateCVar("groundEffectFade", db.groundEffectFade)
        end
    end

    -- The gamepad has its own camera speed CVars; cameraYawMoveSpeed and
    -- cameraPitchMoveSpeed above only ever drive the mouse/keyboard camera.
    if ns.GamePad and ns.GamePad.Refresh then
        pcall(ns.GamePad.Refresh, ns.GamePad, false)
    end

    RequestCVarGuardRefresh(false)
end

function Functions:OnCVarUpdate(_, cvarName, value)
    if isInternalUpdate then return end

    -- CVarGuard and GamePad wrap addon-owned writes with an internal-write scope.
    -- Forever may fire CVAR_UPDATE from inside SetCVar before the new value is
    -- observable, so processing that event as external state creates recursion.
    local cvarGuard = ns.CVarGuard
    if cvarGuard and cvarGuard.IsInternalWrite and cvarGuard:IsInternalWrite() then
        return
    end

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
        local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (USES_MODERN_API and 39 or 50))
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
        -- Let CVarGuard own conflict resolution. In particular, do not call the
        -- generic UpdateCVar path from this event: on Forever CVAR_UPDATE may be
        -- delivered synchronously while the originating SetCVar is still active.
        local guard = ns.CVarGuard
        if guard and guard.OnExternalCVarSet then
            guard:OnExternalCVarSet(cvarName, value)
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
    elseif IS_FOREVER and cvarName == "volumeFog" then
        -- Blizzard's own graphics UI/console may change this CVar. Mirror that
        -- external change into the profile instead of fighting it.
        db.volumeFog = (numValue == 1)
        NotifyConfigChanged()
    elseif IS_FOREVER and cvarName == "volumeFogInterior" then
        db.volumeFogInterior = (numValue == 1)
        NotifyConfigChanged()
    elseif IS_FOREVER and cvarName == "volumeFogLevel" then
        db.volumeFogLevel = math_floor((ClampNumber(numValue, 0, 3) or db.volumeFogLevel or 2) + 0.5)
        NotifyConfigChanged()
    elseif IS_FOREVER and cvarName == "groundEffectDensity" then
        db.groundEffectDensity = math_floor((ClampNumber(numValue, 16, 256) or 16) + 0.5)
        NotifyConfigChanged()
    elseif IS_FOREVER and cvarName == "groundEffectDist" then
        db.groundEffectDist = math_floor((ClampNumber(numValue, 32, 600) or 70) + 0.5)
        NotifyConfigChanged()
    elseif IS_FOREVER and cvarName == "groundEffectFade" then
        db.groundEffectFade = math_floor((ClampNumber(numValue, 0, 600) or 70) + 0.5)
        NotifyConfigChanged()
    elseif cvarName == "CameraKeepCharacterCentered" then
        -- Forward the event VALUE to the guard instead of forcing a live-value
        -- Refresh. On Forever the event can arrive before GetCVar observes the
        -- SetCVar commit, which previously caused an unbounded recursive write.
        local guard = ns.CVarGuard
        if guard and guard.OnExternalCVarSet then
            guard:OnExternalCVarSet(cvarName, value)
        end
        return
    elseif cvarName == "test_cameraDynamicPitch" or cvarName == "test_cameraOverShoulder" then
        local guard = ns.CVarGuard
        if guard and guard.OnExternalCVarSet then
            guard:OnExternalCVarSet(cvarName, value)
        end
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
function Functions:PrintGamePadStatus()
    local gamePad = ns.GamePad
    if not (gamePad and gamePad.GetDiagnostics) then
        self:SendMessage(" - gamepad: module unavailable")
        return
    end

    local info = gamePad:GetDiagnostics()
    if not info.supported then
        if gamePad.IS_SUPPORTED_FLAVOR == false then
            self:SendMessage(" - gamepad: handled on WoW: Forever only (client is " .. tostring(Compat.CLIENT_TAG or "unknown") .. ")")
        else
            self:SendMessage(" - gamepad: not supported on this client")
        end
        return
    end

    local function Show(value)
        if value == nil then return "n/a" end
        return tostring(value)
    end

    self:SendMessage(" - gamepad: modeActive=" .. FormatBool(info.active)
        .. " inputActive=" .. Show(info.inputActive)
        .. " device=" .. Show(info.activeDeviceID)
        .. " cvarsReady=" .. FormatBool(info.cvarEnumerationReady)
        .. " GamePadEnable=" .. Show(info.enableCVar)
        .. " managingSpeed=" .. FormatBool(info.managingSpeed)
        .. " relaxFaceMovement=" .. FormatBool(info.relaxFaceMovement)
        .. " autoOpenPanel=" .. FormatBool(info.autoOpenPanel)
        .. " panelShown=" .. FormatBool(info.panelShown))
    self:SendMessage(" - gamepad sticks: camera=" .. Show(info.cameraStick)
        .. " move=" .. Show(info.moveStick)
        .. " cursor=" .. Show(info.cursorStick)
        .. " faceMovement=" .. Show(info.faceMovement)
        .. "  (0=none, 1=left, 2=right)")
    self:SendMessage(" - gamepad camera speed: yaw=" .. Show(info.yawSpeed) .. " (default " .. Show(info.yawDefault) .. ")"
        .. ", pitch=" .. Show(info.pitchSpeed) .. " (default " .. Show(info.pitchDefault) .. ")"
        .. ", ownedByGameUI=" .. FormatBool(info.speedOwnedByGame))
    self:SendMessage(" - gamepad UI toggle: cvar=" .. Show(info.uiCVar)
        .. " value=" .. Show(info.uiCVarValue)
        .. " discovered=" .. (info.uiCVarIsFallback and "no (fell back to GamePadEnable)" or "yes"))

    local actionCam = info.actionCam
    if actionCam then
        self:SendMessage(" - gamepad ActionCam: allowed=" .. FormatBool(actionCam.runtimeAllowed)
            .. " shoulderIntent=" .. FormatBool(actionCam.shoulderIntent)
            .. " pitchIntent=" .. FormatBool(actionCam.pitchIntent)
            .. " ready=" .. FormatBool(actionCam.ready)
            .. " blocker=" .. Show(actionCam.blockerReason))
        self:SendMessage(" - gamepad ActionCam CVars: shoulder=" .. Show(actionCam.shoulder)
            .. " dynamicPitch=" .. Show(actionCam.dynamicPitch)
            .. " keepCentered=" .. Show(actionCam.keepCentered)
            .. " reduceUnexpected=" .. Show(actionCam.reduceUnexpectedMovement))
        self:SendMessage(" - gamepad camera policy: turnWithCamera=" .. Show(actionCam.turnWithCamera)
            .. " lookMaxPitch=" .. Show(actionCam.lookMaxPitch)
            .. " lookMaxYaw=" .. Show(actionCam.lookMaxYaw)
            .. " followDelay=" .. Show(actionCam.followAdjustDelay)
            .. " followEase=" .. Show(actionCam.followAdjustEaseIn))
    end

    if info.problems and #info.problems > 0 then
        for _, id in ipairs(info.problems) do
            if id == "cameraStickUnassigned" then
                self:SendMessage(" - |cffff5555gamepad: no stick is assigned to the camera, so the client sends no camera input at all.|r")
            elseif id == "cameraStickSharedWithMovement" then
                self:SendMessage(" - |cffffcc00gamepad: the camera and movement share a physical stick.|r")
            elseif id == "cameraStickSharedWithCursor" then
                self:SendMessage(" - |cffffcc00gamepad: the camera and cursor share a physical stick.|r")
            end
        end
    end
end

-- The Gamepad (Alpha) panel is undocumented, so rather than shipping a guessed
-- list this prints what the client itself reports, together with whether
-- Blizzard's Settings panel already owns each CVar.
function Functions:PrintGamePadCVarInventory()
    local gamePad = ns.GamePad
    if not (gamePad and gamePad.GetClientCVarInventory) then return end

    local inventory = gamePad:GetClientCVarInventory()
    if #inventory == 0 then
        self:SendMessage(" - gamepad CVars: none reported by this client")
        return
    end

    self:SendMessage(" - gamepad CVars (" .. #inventory .. "), [game] = already in Blizzard's settings panel:")
    for _, entry in ipairs(inventory) do
        self:SendMessage(string.format("    %s = %s %s",
            entry.name,
            tostring(entry.value ~= nil and entry.value or "?"),
            entry.exposed and "|cff88ff88[game]|r" or "|cffffcc00[addon-only]|r"))
    end
end

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
        Functions:SendMessage(L["CMD_USAGE"] or "Usage: /mcd config | autozoom | automount | shoulder [toggle|swap|center] | status | gamepad [cvars] | deps | fastzoom | slowzoom | reset | debug on | debug off")

    elseif command == "config" then
        if ns.Config and ns.Config.Open then
            ns.Config:Open()
        elseif ACD and ACD.Open then
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

    elseif command == "shoulder" or command == "actioncam" then
        if arg == "toggle" or arg == "" then
            local enabled = Functions:ToggleActionCamShoulderForCurrentContext()
            Functions:SendMessage("ActionCam shoulder (current context): " .. (enabled and (L["ENABLED"] or "enabled") or (L["DISABLED"] or "disabled")))
        elseif arg == "swap" then
            local offset = Functions:SwapActionCamShoulder()
            Functions:SendMessage(string.format("ActionCam shoulder offset: %.2f", tonumber(offset) or 0))
        elseif arg == "center" then
            Functions:CenterActionCamShoulder()
            Functions:SendMessage("ActionCam shoulder offset: 0")
        elseif arg == "config" then
            Functions:OpenActionCamSettings()
        else
            Functions:SendMessage("Usage: /mcd shoulder toggle | swap | center | config")
        end

    elseif command == "status" then
        Functions:PrintRuntimeStatus()

    elseif command == "deps" then
        Functions:PrintDependencyStatus()

    elseif command == "gamepad" then
        if ns.GamePad and ns.GamePad.Refresh then
            pcall(ns.GamePad.Refresh, ns.GamePad, true)
        end
        Functions:SendMessage("GamePad status:")
        Functions:PrintGamePadStatus()
        if arg == "cvars" then
            Functions:PrintGamePadCVarInventory()
        else
            Functions:SendMessage(" - use |cffffff00/mcd gamepad cvars|r to list every gamepad CVar this client has.")
        end

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