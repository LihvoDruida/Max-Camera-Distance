local addonName, ns = ...
ns.Functions = ns.Functions or {}
local Functions = ns.Functions

local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true) or {}
local Compat = ns.Compat or {}
local ShoulderCompensation = ns.ShoulderCompensation or {}

local LibCamera    = LibStub("LibCamera-1.0", true)
local LibMountInfo = LibStub("LibMountInfo-1.0", true)
local ACD          = LibStub("AceConfigDialog-3.0", true)

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
local GetCameraZoom         = GetCameraZoom
local IsEncounterInProgress = IsEncounterInProgress
local GetTime = GetTime

local IsInRaid             = IsInRaid
local IsInGroup            = IsInGroup
local GetNumGroupMembers   = GetNumGroupMembers
local GetNumSubgroupMembers= GetNumSubgroupMembers

local IS_RETAIL = Compat.IS_RETAIL and true or false
local CONVERSION_RATIO = Compat.CONVERSION_RATIO or (IS_RETAIL and 15 or 12.5)

-- =====================================================================
-- 2) STATE
-- =====================================================================
local ZOOM_STATE_NONE   = "none"
local ZOOM_STATE_MOUNT  = "mount"
local ZOOM_STATE_COMBAT = "combat"

local currentZoomState = ZOOM_STATE_NONE

local transitionTimer = nil
local isInternalUpdate = false
local pendingReturnInfo = nil
local lastCombatContext = "world"

-- token that invalidates old delayed transitions (fixes “sticky states”)
local stateToken = 0
local refreshBurstToken = 0

-- Throttling (no permanent OnUpdate)
local updatePending = false
local updateFrame = CreateFrame("Frame")
updateFrame:Hide()

-- AFK
local wasAFK = false
local savedYawSpeed = 180
local AFK_YAW_SPEED = 4

-- Frames
local safeExitFrame = CreateFrame("Frame", "MCD_SafeExitFrame", UIParent)
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

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff0070deMCD|r %s: %s%s|r", prefix, color, tostring(message)))
end

function Functions:SendMessage(message)
    print("|cff0070deMax Camera Distance|r: " .. tostring(message))
end

local function NotifyConfigChanged()
    if ns.Config and ns.Config.NotifyChange then
        ns.Config:NotifyChange()
    end
end

-- =====================================================================
-- 6) SAFE CVAR HELPERS (fix SafeGetCVar nil + cross-client)
-- =====================================================================
local function SafeGetCVar(name)
    if Compat.SafeGetCVarNumber then
        return Compat.SafeGetCVarNumber(name)
    end
    return nil
end


local function SafeSetCVar(name, value)
    if Compat.SafeSetCVar then
        return Compat.SafeSetCVar(name, value)
    end
    return false
end

local function ClampNumber(value, minValue, maxValue)
    local num = tonumber(value)
    if not num then return nil end
    if num < minValue then return minValue end
    if num > maxValue then return maxValue end
    return num
end

local function NormalizeManagedCVarValue(cvarName, value, db)
    local defaults = ns.Database and ns.Database.DEFAULTS
    local maxYards = (defaults and defaults.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
    local maxFactor = maxYards / CONVERSION_RATIO

    if cvarName == "cameraDistanceMoveSpeed" then
        return ClampNumber(value, 1, 50)
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
    db.moveViewDistance = ClampNumber(db.moveViewDistance, 1, 50) or 20
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
    local db = DB()
    local normalizedValue = NormalizeManagedCVarValue(key, value, db)
    if normalizedValue == nil then return end

    local currentValue = Compat.SafeGetCVar and Compat.SafeGetCVar(key) or nil
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

    isInternalUpdate = true
    SafeSetCVar(key, normalizedValue)
    isInternalUpdate = false
end

-- =====================================================================
-- 7) MOUNT / TRAVEL DETECT
-- =====================================================================
function Functions:IsSkyriding()
    if IsMounted() and LibMountInfo and LibMountInfo.IsSkyriding then
        return LibMountInfo:IsSkyriding()
    end

    if IS_RETAIL and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        if C_UnitAuras.GetPlayerAuraBySpellID(404464) then return true end
        if C_UnitAuras.GetPlayerAuraBySpellID(404468) then return false end
    end

    return false
end

function Functions:GetMountZoomMode(db)
    local mode = db and db.mountZoomMode
    if mode == MOUNT_ZOOM_MODE_FLYING or mode == MOUNT_ZOOM_MODE_SKYRIDING then
        return mode
    end
    return MOUNT_ZOOM_MODE_ALL
end

function Functions:GetActiveMountID()
    if not IS_RETAIL or not IsMounted() or not C_MountJournal or not C_MountJournal.GetMountIDs then
        return nil
    end

    local mountIDs = C_MountJournal.GetMountIDs()
    if not mountIDs then return nil end

    for _, mountID in ipairs(mountIDs) do
        local _, _, _, isActive = C_MountJournal.GetMountInfoByID(mountID)
        if isActive then
            return mountID
        end
    end

    return nil
end

function Functions:IsFlyingMountActive()
    local mountID = self:GetActiveMountID()
    if not mountID or not C_MountJournal or not C_MountJournal.GetMountInfoExtraByID then
        return false, nil, mountID
    end

    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    if mountTypeID and FLYCAM_FLYING_MOUNT_TYPES[mountTypeID] then
        return true, mountTypeID, mountID
    end

    return false, mountTypeID, mountID
end

function Functions:IsDragonRacingRaceActive()
    if not IsMounted() then
        return false
    end

    if IS_RETAIL and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for spellID in pairs(DRAGONRACING_RACE_AURAS) do
            if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
                return true
            end
        end
    end

    if AuraUtil and AuraUtil.ForEachAura then
        local canaccessvalue = _G.canaccessvalue
        local issecretvalue = _G.isecretvalue
        local inRace = false

        local function CheckAura(auraData)
            if canaccessvalue and not canaccessvalue(auraData) then
                return
            end

            local spellId = auraData and auraData.spellId
            if issecretvalue and issecretvalue(spellId) then
                return
            end

            if spellId and DRAGONRACING_RACE_AURAS[spellId] then
                inRace = true
                return true
            end
        end

        AuraUtil.ForEachAura("player", "HELPFUL", nil, CheckAura, true)
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

    local formIndex = GetShapeshiftForm()
    if formIndex and formIndex > 0 then
        local _, _, _, spellID = GetShapeshiftFormInfo(formIndex)
        if spellID and FLYING_TRAVEL_FORM_IDS[spellID] then
            return true
        end
    end

    if IS_RETAIL and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for spellID in pairs(FLYING_TRAVEL_BUFF_IDS) do
            if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
                return true
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
        if LibMountInfo:IsMounted() then return true end
    else
        if IsMounted() then return true end
    end

    local formIndex = GetShapeshiftForm()
    if formIndex and formIndex > 0 then
        local _, _, _, spellID = GetShapeshiftFormInfo(formIndex)
        if spellID and TRAVEL_FORM_IDS[spellID] then return true end
    end

    if IS_RETAIL then
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            for spellID in pairs(TRAVEL_BUFF_IDS) do
                if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then return true end
            end
        end
    else
        local UnitBuff = _G.UnitBuff
        if UnitBuff then
            for i = 1, 40 do
                local _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
                if not spellID then break end
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

    if C_Timer and C_Timer.NewTimer then
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


local function ApplyZoomCap(targetYards)
    local targetFactor = targetYards / CONVERSION_RATIO

    if SafeGetCVar("cameraDistanceMaxZoomFactor") ~= nil then
        UpdateCVar("cameraDistanceMaxZoomFactor", targetFactor)
    end

    if SafeGetCVar("cameraDistanceMax") ~= nil then
        UpdateCVar("cameraDistanceMax", targetYards)
    end
end

local function IsZoomCapAligned(targetYards)
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
    local targetFactor = targetYards / CONVERSION_RATIO
    local currentFactor = SafeGetCVar("cameraDistanceMaxZoomFactor")

    if currentFactor == nil then
        currentFactor = targetFactor
    end

    -- If we are shrinking max factor, do zoom first then lower cap (prevents snap)
    if targetFactor < currentFactor then
        if LibCamera and LibCamera.SetZoomUsingCVar then
            LibCamera:SetZoomUsingCVar(targetYards, transitionTime)
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
            LibCamera:SetZoomUsingCVar(targetYards, transitionTime)
        end
    end
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
    -- This helper is intentionally GROUP-ONLY.
    -- Personal combat should be checked separately (UnitAffectingCombat("player"),
    -- UnitThreatSituation("player"), etc.).
    if IsInRaid() then
        if IsEncounterInProgress() then
            return true
        end

        for i = 1, GetNumGroupMembers() do
            local unit = "raid"..i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") and UnitAffectingCombat(unit) then
                return true
            end
        end

        return false
    end

    if IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party"..i
            if UnitExists(unit) and UnitAffectingCombat(unit) then
                return true
            end
        end

        return false
    end

    return false
end

local function GetCombatContextRaw()
    local inInstance, instanceType = IsInInstance()

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

    if IsInRaid() then
        return "raid"
    end

    if IsInGroup() then
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
    local threatStatus = UnitThreatSituation("player")
    local mountedRaw = IsInTravelForm()
    local mountZoomActive = mountedRaw and Functions:ShouldUseMountZoom(db) or false
    local isSkyriding = mountedRaw and Functions:IsSkyriding() or false
    local isDragonRacing = mountedRaw and Functions:IsDragonRacingRaceActive() or false
    local isFlyingMount, mountTypeID, activeMountID = false, nil, nil

    if mountedRaw then
        isFlyingMount, mountTypeID, activeMountID = Functions:IsFlyingMountActive()
    end

    return {
        playerInCombat = UnitAffectingCombat("player") and true or false,
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

    local state = ZOOM_STATE_NONE
    if db and db.autoCombatZoom and combatActive then
        state = ZOOM_STATE_COMBAT
    elseif db and db.autoMountZoom and signals.mountZoomActive then
        state = ZOOM_STATE_MOUNT
    end

    local targetYards, targetDistanceKey, targetSourceType, targetPresetId
    if not db then
        targetYards = maxYards
        targetDistanceKey = "maxZoomFactor"
        targetSourceType = "manual"
        targetPresetId = "manual"
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

    return {
        state = state,
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
    }
end

local function GetCurrentZoomContext(db)
    local snapshot = BuildStatusSnapshot(db)
    return snapshot.state, snapshot.resolvedContext, snapshot
end

ShouldForceCombatZoom = function(db)
    local inInstance = IsInInstance()
    if inInstance then
        return false
    end

    return IsEncounterInProgress() and true or false
end

-- =====================================================================
-- 11) ACTIONCAM SHOULDER (dynamic shoulder offset + model compensation)
-- =====================================================================
tinsert(UISpecialFrames, safeExitFrame:GetName())
safeExitFrame:Hide()

safeExitFrame:SetScript("OnHide", function()
    if wasAFK then
        Functions:OnPlayerFlagsChanged()
    end
end)

local shoulderRefreshToken = 0
local raceFirstPersonApplied = false

local function ApplyRaceFirstPersonZoom()
    ApplyZoomCap(RACE_FIRST_PERSON_YARDS)
    if LibCamera and LibCamera.SetZoomUsingCVar then
        LibCamera:SetZoomUsingCVar(RACE_FIRST_PERSON_YARDS, 0.20)
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

    local currentZoom = GetCameraZoom()
    if (not force) and math_abs(shoulderHandlerFrame.lastZoom - currentZoom) < 0.01 then
        return
    end
    shoulderHandlerFrame.lastZoom = currentZoom

    local zoomFactor = GetShoulderOffsetZoomFactor(currentZoom)
    local baseOffset = 1.0
    local modelFactor = 1.0

    if ShoulderCompensation and ShoulderCompensation.GetFactor then
        modelFactor = ShoulderCompensation:GetFactor() or 1.0
    end

    UpdateCVar("test_cameraOverShoulder", baseOffset * zoomFactor * modelFactor)
end

function Functions:RequestShoulderRefresh()
    shoulderRefreshToken = shoulderRefreshToken + 1
    local myToken = shoulderRefreshToken
    shoulderHandlerFrame.lastZoom = -1

    local function RefreshShoulderNow()
        if ShoulderCompensation and ShoulderCompensation.Invalidate then
            ShoulderCompensation:Invalidate()
        end
        Functions:ApplyShoulderOffset(true)
        if ns.CVarGuard and ns.CVarGuard.Refresh then
            ns.CVarGuard:Refresh(true)
        end
    end

    if not (C_Timer and C_Timer.After) then
        RefreshShoulderNow()
        return
    end

    local delays = { 0, 0.02, 0.08, 0.16 }
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if myToken ~= shoulderRefreshToken then return end
            RefreshShoulderNow()
        end)
    end
end

shoulderHandlerFrame.lastZoom = -1
shoulderHandlerFrame:SetScript("OnUpdate", function()
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

    if ns.CVarGuard and ns.CVarGuard.Refresh then
        ns.CVarGuard:Refresh()
    end
end

-- =====================================================================
-- 12) SMART ZOOM CORE (FIXED: no “sticky” state)
-- =====================================================================
local function ComputeDesiredState(db)
    local snapshot = BuildStatusSnapshot(db)
    return snapshot.state, snapshot.targetYards, snapshot
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

    if snapshot and snapshot.resolvedContext and newState == ZOOM_STATE_COMBAT then
        lastCombatContext = snapshot.resolvedContext
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
    if stateSame and capAligned and event ~= "manual_update" then
        NotifyConfigChanged()
        return
    end

    -- Any change invalidates old delayed timers
    stateToken = stateToken + 1
    currentZoomState = newState

    local transitionTime = db.zoomTransitionTime or 0.5

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
            ApplyZoomTransition(targetYards, transitionTime)
            Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"] or "Smart Zoom: state=%s, target=%.1f yards", newState, targetYards))
            NotifyConfigChanged()
            return
        end

        ScheduleTransition(delay, function()
            if myToken ~= stateToken then return end
            pendingReturnInfo = nil

            local liveDb = DB()
            if not liveDb then return end

            local nowState, nowYards = ComputeDesiredState(liveDb)
            if nowState ~= ZOOM_STATE_NONE then
                return
            end

            ApplyZoomTransition(nowYards, transitionTime)
            Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"] or "Smart Zoom: state=%s, target=%.1f yards", nowState, nowYards))
            NotifyConfigChanged()
        end)
        pendingReturnInfo = {
            kind = returnKind,
            context = returnContext,
            delay = delay,
            fireAt = (GetTime and GetTime() or 0) + delay,
        }
        NotifyConfigChanged()
    else
        pendingReturnInfo = nil
        ApplyZoomTransition(targetYards, transitionTime)
        if snapshot and snapshot.resolvedContext then
            Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"] or "Smart Zoom: state=%s, target=%.1f yards", newState, targetYards) .. " [" .. tostring(snapshot.resolvedContext) .. "]")
        else
            Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"] or "Smart Zoom: state=%s, target=%.1f yards", newState, targetYards))
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

function Functions:AdjustCamera(forceNow)
    local db = DB()
    if not db then return end

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
        currentZoomState = ZOOM_STATE_NONE
        CancelTransition()

        ApplyZoomCap(manualTargetYards)
        if LibCamera and LibCamera.SetZoomUsingCVar then
            LibCamera:SetZoomUsingCVar(manualTargetYards, db.zoomTransitionTime or 0.5)
        end

        Functions:logMessage("info", L["SMART_ZOOM_DISABLED_MSG"] or "Smart Zoom is disabled. Using manual max distance settings.")
        NotifyConfigChanged()
    end

    -- Always apply other CVars
    UpdateCVar("cameraDistanceMoveSpeed", db.moveViewDistance)
    UpdateCVar("cameraReduceUnexpectedMovement", db.reduceUnexpectedMovement and 1 or 0)
    UpdateCVar("cameraYawMoveSpeed", db.cameraYawMoveSpeed)
    UpdateCVar("cameraPitchMoveSpeed", db.cameraPitchMoveSpeed)
    UpdateCVar("cameraIndirectVisibility", db.cameraIndirectVisibility and 1 or 0)
    UpdateCVar("cameraIndirectOffset", db.cameraIndirectOffset or 1.5)
    UpdateCVar("occludedSilhouettePlayer", db.occludedSilhouettePlayer and 1 or 0)
    UpdateCVar("resampleAlwaysSharpen", db.resampleAlwaysSharpen and 1 or 0)
    UpdateCVar("SoftTargetIconGameObject", db.softTargetInteract and 1 or 0)
    
    if ns.CVarGuard and ns.CVarGuard.Refresh then
        ns.CVarGuard:Refresh()
    end
end

function Functions:OnCVarUpdate(_, cvarName, value)
    if isInternalUpdate then return end
    local db = DB()
    if not db then return end

    if cvarName == "cameraView" then
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
        local desired = db.reduceUnexpectedMovement and 1 or 0
        if numValue ~= desired then
            UpdateCVar(cvarName, desired)
            return
        end
        db.reduceUnexpectedMovement = (desired == 1)
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
    local db = DB()
    if not db or not db.afkMode then return end

    local isAFK = UnitIsAFK("player")

    if isAFK and not wasAFK then
        wasAFK = true
        Functions:logMessage("info", L["AFK_ENTER_MSG"] or "AFK Mode: enabled (cinematic rotation).")

        savedYawSpeed = SafeGetCVar("cameraYawMoveSpeed") or 180
        SafeSetCVar("cameraYawMoveSpeed", AFK_YAW_SPEED)
        MoveViewRightStart()

        local maxYards = (ns.Database and ns.Database.DEFAULTS and ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE) or (Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50))
        if LibCamera and LibCamera.SetZoomUsingCVar then
            LibCamera:SetZoomUsingCVar(maxYards, 4.0)
        end

        UIParent:Hide()
        safeExitFrame:Show()

    elseif (not isAFK) and wasAFK then
        wasAFK = false
        Functions:logMessage("info", L["AFK_EXIT_MSG"] or "AFK Mode: disabled (restored UI and camera).")

        MoveViewRightStop()
        SafeSetCVar("cameraYawMoveSpeed", savedYawSpeed)

        UIParent:Show()
        safeExitFrame:Hide()

        Functions:AdjustCamera(true)
    end
end

-- =====================================================================
-- 14) QUEST TRACKER
-- =====================================================================
function Functions:ClearAllQuestTracking()
    if not C_QuestLog or not C_QuestLog.GetNumQuestWatches then
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
    local command = strlower(msg or "")

    if not (ns.Database and ns.Database.db) then
        Functions:SendMessage(L["DB_NOT_READY"] or "Database not initialized yet.")
        return
    end

    local db = ns.Database.db.profile

    if command == "config" then
        if ACD and ACD.Open then
            ACD:Open(addonName)
        else
            Functions:SendMessage("Error: AceConfigDialog not found. Cannot open settings.")
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

    else
        Functions:SendMessage(L["CMD_USAGE"] or "Usage: /mcd config | autozoom | automount")
    end
end