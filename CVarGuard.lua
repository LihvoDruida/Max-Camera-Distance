local addonName, ns = ...
ns.CVarGuard = ns.CVarGuard or {}
local CVarGuard = ns.CVarGuard

local type = type
local pcall = pcall
local tonumber = tonumber
local hooksecurefunc = hooksecurefunc

local C_CVar = C_CVar

local internalWriteDepth = 0
local isInitialized = false

local savedUserValues = {
    CameraKeepCharacterCentered = nil,
    cameraReduceUnexpectedMovement = nil,
}

-- Cache of current guard state to avoid repeated force/restore work
local stateCache = {
    blockKeepCentered = nil,
    blockReduceUnexpectedMovement = nil,
    lastForcedKeepCentered = nil,
    lastForcedReduceUnexpectedMovement = nil,
    lastRestoreKeepCentered = nil,
    lastRestoreReduceUnexpectedMovement = nil,
}

local function DB()
    return (ns.Database and ns.Database.db and ns.Database.db.profile) or nil
end

local function SafeGetCVar(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, val = pcall(C_CVar.GetCVar, name)
        if ok and val ~= nil then
            return tonumber(val)
        end
    end

    if type(_G.GetCVar) == "function" then
        local ok, val = pcall(_G.GetCVar, name)
        if ok and val ~= nil then
            return tonumber(val)
        end
    end

    return nil
end

local function SafeSetCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        return pcall(C_CVar.SetCVar, name, value)
    end

    if type(_G.SetCVar) == "function" then
        return pcall(_G.SetCVar, name, value)
    end

    return false
end

local function SetManagedCVar(name, value)
    local current = SafeGetCVar(name)
    local target = tonumber(value) or 0

    if current ~= nil and current == target then
        return false
    end

    internalWriteDepth = internalWriteDepth + 1
    SafeSetCVar(name, value)
    internalWriteDepth = internalWriteDepth - 1
    return true
end

local function IsInternalWrite()
    return internalWriteDepth > 0
end

local function IsShoulderActive()
    local v = SafeGetCVar("test_cameraOverShoulder")
    return v ~= nil and v ~= 0
end

local function IsDynamicPitchActive()
    local v = SafeGetCVar("test_cameraDynamicPitch")
    return v ~= nil and v == 1
end

function CVarGuard:ShouldBlockKeepCentered()
    return IsShoulderActive() or IsDynamicPitchActive()
end

function CVarGuard:ShouldBlockReduceUnexpectedMovement()
    return IsShoulderActive()
end

function CVarGuard:CaptureUserValue(name)
    local current = SafeGetCVar(name)
    if current == nil then return end

    if savedUserValues[name] == nil then
        savedUserValues[name] = current
    end
end

function CVarGuard:LogOnce(key, text)
    if stateCache[key] then return end
    stateCache[key] = true

    if ns.Functions and ns.Functions.logMessage then
        ns.Functions:logMessage("warning", text)
    end
end

function CVarGuard:ResetLogFlag(key)
    stateCache[key] = nil
end

function CVarGuard:ForceKeepCenteredIfNeeded()
    local shouldBlock = self:ShouldBlockKeepCentered()
    local current = SafeGetCVar("CameraKeepCharacterCentered")

    if not shouldBlock then
        self:ResetLogFlag("lastForcedKeepCentered")
        return
    end

    if current == 1 then
        self:CaptureUserValue("CameraKeepCharacterCentered")

        local changed = SetManagedCVar("CameraKeepCharacterCentered", 0)
        if changed then
            self:LogOnce("lastForcedKeepCentered", "Disabled CameraKeepCharacterCentered because it conflicts with ActionCam.")
        end
    end
end

function CVarGuard:ForceReduceUnexpectedMovementIfNeeded()
    local shouldBlock = self:ShouldBlockReduceUnexpectedMovement()
    local current = SafeGetCVar("cameraReduceUnexpectedMovement")

    if not shouldBlock then
        self:ResetLogFlag("lastForcedReduceUnexpectedMovement")
        return
    end

    if current == 1 then
        self:CaptureUserValue("cameraReduceUnexpectedMovement")

        local changed = SetManagedCVar("cameraReduceUnexpectedMovement", 0)
        if changed then
            self:LogOnce("lastForcedReduceUnexpectedMovement", "Disabled cameraReduceUnexpectedMovement because it conflicts with shoulder offset.")
        end
    end
end

function CVarGuard:RestoreKeepCenteredIfPossible()
    if self:ShouldBlockKeepCentered() then
        self:ResetLogFlag("lastRestoreKeepCentered")
        return
    end

    if savedUserValues.CameraKeepCharacterCentered ~= nil then
        local changed = SetManagedCVar("CameraKeepCharacterCentered", savedUserValues.CameraKeepCharacterCentered)
        savedUserValues.CameraKeepCharacterCentered = nil

        if changed then
            stateCache.lastRestoreKeepCentered = true
        end
    end
end

function CVarGuard:RestoreReduceUnexpectedMovementIfPossible()
    if self:ShouldBlockReduceUnexpectedMovement() then
        self:ResetLogFlag("lastRestoreReduceUnexpectedMovement")
        return
    end

    local db = DB()
    local restoreValue = nil

    if savedUserValues.cameraReduceUnexpectedMovement ~= nil then
        restoreValue = savedUserValues.cameraReduceUnexpectedMovement
        savedUserValues.cameraReduceUnexpectedMovement = nil
    elseif db then
        restoreValue = db.reduceUnexpectedMovement and 1 or 0
    end

    if restoreValue ~= nil then
        local changed = SetManagedCVar("cameraReduceUnexpectedMovement", restoreValue)
        if changed then
            stateCache.lastRestoreReduceUnexpectedMovement = true
        end
    end
end

function CVarGuard:Refresh(force)
    local blockKeepCentered = self:ShouldBlockKeepCentered()
    local blockReduceUnexpectedMovement = self:ShouldBlockReduceUnexpectedMovement()

    local stateChanged =
        force
        or stateCache.blockKeepCentered ~= blockKeepCentered
        or stateCache.blockReduceUnexpectedMovement ~= blockReduceUnexpectedMovement

    if not stateChanged then
        return
    end

    stateCache.blockKeepCentered = blockKeepCentered
    stateCache.blockReduceUnexpectedMovement = blockReduceUnexpectedMovement

    self:ForceKeepCenteredIfNeeded()
    self:ForceReduceUnexpectedMovementIfNeeded()
    self:RestoreKeepCenteredIfPossible()
    self:RestoreReduceUnexpectedMovementIfPossible()
end

function CVarGuard:OnExternalCVarSet(cvar, value)
    if IsInternalWrite() then return end

    if cvar == "CameraKeepCharacterCentered" then
        local num = tonumber(value)

        if num == 1 or value == true then
            if self:ShouldBlockKeepCentered() then
                self:CaptureUserValue("CameraKeepCharacterCentered")
                SetManagedCVar("CameraKeepCharacterCentered", 0)
                self:LogOnce("lastForcedKeepCentered", "Disabled CameraKeepCharacterCentered because it conflicts with ActionCam.")
            else
                savedUserValues.CameraKeepCharacterCentered = 1
            end
        elseif num == 0 or value == false then
            if not self:ShouldBlockKeepCentered() then
                savedUserValues.CameraKeepCharacterCentered = 0
            end
        end

        return
    end

    if cvar == "cameraReduceUnexpectedMovement" then
        local num = tonumber(value)

        if num == 1 or value == true then
            if self:ShouldBlockReduceUnexpectedMovement() then
                self:CaptureUserValue("cameraReduceUnexpectedMovement")
                SetManagedCVar("cameraReduceUnexpectedMovement", 0)
                self:LogOnce("lastForcedReduceUnexpectedMovement", "Disabled cameraReduceUnexpectedMovement because it conflicts with shoulder offset.")
            else
                savedUserValues.cameraReduceUnexpectedMovement = 1
            end
        elseif num == 0 or value == false then
            if not self:ShouldBlockReduceUnexpectedMovement() then
                savedUserValues.cameraReduceUnexpectedMovement = 0
            end
        end

        return
    end

    if cvar == "test_cameraOverShoulder" or cvar == "test_cameraDynamicPitch" then
        self:Refresh(true)
    end
end

function CVarGuard:InvalidateCache()
    stateCache.blockKeepCentered = nil
    stateCache.blockReduceUnexpectedMovement = nil
end

function CVarGuard:Init()
    if isInitialized then return end
    isInitialized = true

    if type(_G.SetCVar) == "function" then
        hooksecurefunc("SetCVar", function(cvar, value)
            CVarGuard:OnExternalCVarSet(cvar, value)
        end)
    end

    if C_CVar and C_CVar.SetCVar then
        hooksecurefunc(C_CVar, "SetCVar", function(_, cvar, value)
            CVarGuard:OnExternalCVarSet(cvar, value)
        end)
    end

    self:Refresh(true)
end