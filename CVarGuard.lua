local addonName, ns = ...
ns.CVarGuard = ns.CVarGuard or {}
local CVarGuard = ns.CVarGuard
ns.CVarMonitor = CVarGuard -- legacy alias for older modules

local type = type
local tonumber = tonumber
local tostring = tostring
local pcall = pcall
local select = select
local hooksecurefunc = hooksecurefunc

local Compat = ns.Compat or {}
local C_CVar = C_CVar

local internalWriteDepth = 0
local isInitialized = false

local debugCounters = {
    cvarWrites = 0,
    skippedUnsupportedCvars = 0,
    preventedExternalCvars = 0,
    restoredMotionSicknessSettings = 0,
    ignoredInternalWrites = 0,
}

local REDUCE_UNEXPECTED_MOVEMENT_CVARS = {
    "cameraReduceUnexpectedMovement",
    "CameraReduceUnexpectedMovement",
}

local savedUserValues = {
    CameraKeepCharacterCentered = nil,
    cameraReduceUnexpectedMovement = nil,
}

-- Cache of current guard state to avoid repeated force/restore work.
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

-- Hooked SetCVar callers may use any capitalisation, and so does the client's
-- own CVar table ("CameraReduceUnexpectedMovement", "ResampleAlwaysSharpen").
-- Every comparison in OnExternalCVarSet below is an ==, so normalise first.
local CVAR_CANONICAL = {}
for _, name in ipairs({
    "cameraView",
    "cameraZoomSpeed",
    "CameraKeepCharacterCentered",
    "cameraReduceUnexpectedMovement",
    "test_cameraOverShoulder",
    "test_cameraDynamicPitch",
}) do
    CVAR_CANONICAL[name:lower()] = name
end

local function NormalizeCVarName(name)
    if type(name) ~= "string" then
        return name
    end
    return CVAR_CANONICAL[name:lower()] or name
end

local function GetCVarLookupNames(name)
    local canonical = NormalizeCVarName(name)
    if canonical == "cameraReduceUnexpectedMovement" then
        return REDUCE_UNEXPECTED_MOVEMENT_CVARS
    end
    return canonical
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

local function SetManagedCVar(name, value)
    local current = SafeGetCVar(name)
    local target = tonumber(value) or 0

    if current == nil then
        debugCounters.skippedUnsupportedCvars = debugCounters.skippedUnsupportedCvars + 1
        return false
    end

    if current == target then
        return false
    end

    internalWriteDepth = internalWriteDepth + 1
    local ok = SafeSetCVar(name, value)
    internalWriteDepth = internalWriteDepth - 1
    if ok then
        debugCounters.cvarWrites = debugCounters.cvarWrites + 1
    else
        debugCounters.skippedUnsupportedCvars = debugCounters.skippedUnsupportedCvars + 1
    end
    return ok and true or false
end

local function IsInternalWrite()
    return internalWriteDepth > 0
end

function CVarGuard:BeginInternalWrite()
    internalWriteDepth = internalWriteDepth + 1
end

function CVarGuard:EndInternalWrite()
    internalWriteDepth = internalWriteDepth - 1
    if internalWriteDepth < 0 then
        internalWriteDepth = 0
    end
end

function CVarGuard:IsInternalWrite()
    return IsInternalWrite()
end

-- The addon's INTENT, published by Functions:UpdateActionCam.
--
-- Reading test_cameraOverShoulder back was a feedback loop that could deadlock
-- the whole ActionCam: CameraKeepCharacterCentered overrides ActionCam (it was
-- added in 9.0.1 for exactly that purpose), and since 11.0.2
-- cameraReduceUnexpectedMovement affects test_cameraOverShoulder too. So once
-- either of those got turned on - which is what happens when the player enables
-- the gamepad and goes through Blizzard's camera/gamepad settings - the shoulder
-- offset read back as 0, this guard concluded "shoulder is not active", stopped
-- blocking keep-centered, restored it to 1, and the shoulder offset could never
-- come back. Intent is the only signal that does not participate in that loop.
local shoulderIntent = false
local dynamicPitchIntent = false

local function IsShoulderActive()
    if shoulderIntent then return true end
    local v = SafeGetCVar("test_cameraOverShoulder")
    return v ~= nil and (v > 0.0001 or v < -0.0001)
end

local function IsDynamicPitchActive()
    if dynamicPitchIntent then return true end
    local v = SafeGetCVar("test_cameraDynamicPitch")
    return v ~= nil and v == 1
end

-- Returns true when the value actually changed, so callers can skip a refresh.
function CVarGuard:SetActionCamIntent(shoulderWanted, pitchWanted)
    local newShoulder = shoulderWanted and true or false
    local newPitch = pitchWanted and true or false

    if newShoulder == shoulderIntent and newPitch == dynamicPitchIntent then
        return false
    end

    shoulderIntent = newShoulder
    dynamicPitchIntent = newPitch
    return true
end

function CVarGuard:GetActionCamIntent()
    return shoulderIntent, dynamicPitchIntent
end

local function GetCameraViewDefault()
    local value = nil
    if Compat.SafeGetCVarDefault then
        value = tonumber(Compat.SafeGetCVarDefault("cameraView"))
    end
    return value or 1
end

local function IsValidCameraView(value)
    local num = tonumber(value)
    return num == 1 or num == 2 or num == 3 or num == 4 or num == 5
end

function CVarGuard:ShouldBlockKeepCentered()
    return IsShoulderActive() or IsDynamicPitchActive()
end

function CVarGuard:ShouldBlockReduceUnexpectedMovement()
    return IsShoulderActive()
end

function CVarGuard:CaptureUserValue(name)
    local canonical = NormalizeCVarName(name)
    local current = SafeGetCVar(canonical)
    if current == nil then return end

    if savedUserValues[canonical] == nil then
        savedUserValues[canonical] = current
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

    local restoreValue = savedUserValues.CameraKeepCharacterCentered
    if restoreValue == nil then return end

    local current = SafeGetCVar("CameraKeepCharacterCentered")
    local target = tonumber(restoreValue) or 0
    if current == target then
        savedUserValues.CameraKeepCharacterCentered = nil
        return
    end

    local changed = SetManagedCVar("CameraKeepCharacterCentered", restoreValue)
    if changed then
        -- Only forget the user's value after the restore actually committed. A
        -- secure-in-combat rejection must remain retryable after combat ends.
        savedUserValues.CameraKeepCharacterCentered = nil
        stateCache.lastRestoreKeepCentered = true
        debugCounters.restoredMotionSicknessSettings = debugCounters.restoredMotionSicknessSettings + 1
    end
end

function CVarGuard:RestoreReduceUnexpectedMovementIfPossible()
    if self:ShouldBlockReduceUnexpectedMovement() then
        self:ResetLogFlag("lastRestoreReduceUnexpectedMovement")
        return
    end

    local restoreValue = savedUserValues.cameraReduceUnexpectedMovement
    if restoreValue == nil then return end

    local current = SafeGetCVar("cameraReduceUnexpectedMovement")
    local target = tonumber(restoreValue) or 0
    if current == target then
        savedUserValues.cameraReduceUnexpectedMovement = nil
        return
    end

    local changed = SetManagedCVar("cameraReduceUnexpectedMovement", restoreValue)
    if changed then
        savedUserValues.cameraReduceUnexpectedMovement = nil
        stateCache.lastRestoreReduceUnexpectedMovement = true
        debugCounters.restoredMotionSicknessSettings = debugCounters.restoredMotionSicknessSettings + 1
    end
end

function CVarGuard:Refresh(force)
    local blockKeepCentered = self:ShouldBlockKeepCentered()
    local blockReduceUnexpectedMovement = self:ShouldBlockReduceUnexpectedMovement()

    -- This used to return early whenever the blocking state had not changed,
    -- which meant a CVar that drifted underneath the guard (Blizzard's camera or
    -- gamepad settings panel, a saved view restore, another addon) was never
    -- reconciled until something else happened to flip the state. The four
    -- helpers below already compare against the live value before writing, so
    -- running them unconditionally costs a couple of CVar reads on a call that
    -- is throttled to CVAR_GUARD_REFRESH_SECONDS anyway.
    local stateChanged =
        force
        or stateCache.blockKeepCentered ~= blockKeepCentered
        or stateCache.blockReduceUnexpectedMovement ~= blockReduceUnexpectedMovement

    if stateChanged then
        self:ResetLogFlag("lastRestoreKeepCentered")
        self:ResetLogFlag("lastRestoreReduceUnexpectedMovement")
    end

    stateCache.blockKeepCentered = blockKeepCentered
    stateCache.blockReduceUnexpectedMovement = blockReduceUnexpectedMovement

    self:ForceKeepCenteredIfNeeded()
    self:ForceReduceUnexpectedMovementIfNeeded()
    self:RestoreKeepCenteredIfPossible()
    self:RestoreReduceUnexpectedMovementIfPossible()
end

function CVarGuard:OnExternalCVarSet(cvar, value)
    if IsInternalWrite() then
        debugCounters.ignoredInternalWrites = debugCounters.ignoredInternalWrites + 1
        return
    end
    if type(cvar) ~= "string" then return end

    cvar = NormalizeCVarName(cvar)

    if cvar == "cameraView" then
        if not IsValidCameraView(value) then
            SetManagedCVar("cameraView", GetCameraViewDefault())
        end
        return
    end

    if cvar == "CameraKeepCharacterCentered" then
        local num = tonumber(value)

        if num == 1 or value == true or value == "true" then
            if self:ShouldBlockKeepCentered() then
                self:CaptureUserValue("CameraKeepCharacterCentered")
                if SetManagedCVar("CameraKeepCharacterCentered", 0) then
                    debugCounters.preventedExternalCvars = debugCounters.preventedExternalCvars + 1
                end
                self:LogOnce("lastForcedKeepCentered", "Disabled CameraKeepCharacterCentered because it conflicts with ActionCam.")
            else
                savedUserValues.CameraKeepCharacterCentered = 1
            end
        elseif num == 0 or value == false or value == "false" then
            if not self:ShouldBlockKeepCentered() then
                savedUserValues.CameraKeepCharacterCentered = 0
            end
        end

        return
    end

    if cvar == "cameraReduceUnexpectedMovement" then
        local num = tonumber(value)

        if num == 1 or value == true or value == "true" then
            if self:ShouldBlockReduceUnexpectedMovement() then
                self:CaptureUserValue("cameraReduceUnexpectedMovement")
                if SetManagedCVar("cameraReduceUnexpectedMovement", 0) then
                    debugCounters.preventedExternalCvars = debugCounters.preventedExternalCvars + 1
                end
                self:LogOnce("lastForcedReduceUnexpectedMovement", "Disabled cameraReduceUnexpectedMovement because it conflicts with shoulder offset.")
            else
                savedUserValues.cameraReduceUnexpectedMovement = 1
                local db = DB()
                if db then db.reduceUnexpectedMovement = true end
            end
        elseif num == 0 or value == false or value == "false" then
            if not self:ShouldBlockReduceUnexpectedMovement() then
                savedUserValues.cameraReduceUnexpectedMovement = 0
                local db = DB()
                if db then db.reduceUnexpectedMovement = false end
            end
        end

        return
    end

    if cvar == "cameraZoomSpeed" then
        -- LibCamera temporarily changes this during smooth zoom transitions and restores it.
        -- Track it for diagnostics only; never persist or fight external writes here.
        return
    end

    if cvar == "test_cameraOverShoulder" or cvar == "test_cameraDynamicPitch" then
        self:Refresh(true)
    end
end

function CVarGuard:GetDebugCounters()
    return debugCounters
end

function CVarGuard:InvalidateCache()
    stateCache.blockKeepCentered = nil
    stateCache.blockReduceUnexpectedMovement = nil
end

local function SafeOnExternalCVarSet(cvar, value)
    local ok, err = pcall(CVarGuard.OnExternalCVarSet, CVarGuard, cvar, value)
    if not ok and ns.Functions and ns.Functions.logMessage then
        ns.Functions:logMessage("error", "CVarGuard error: " .. tostring(err))
    end
end

function CVarGuard:Init()
    if isInitialized then return end
    isInitialized = true

    if type(_G.SetCVar) == "function" and type(hooksecurefunc) == "function" then
        pcall(hooksecurefunc, "SetCVar", function(cvar, value)
            SafeOnExternalCVarSet(cvar, value)
        end)
    end

    if C_CVar and C_CVar.SetCVar and type(hooksecurefunc) == "function" then
        pcall(hooksecurefunc, C_CVar, "SetCVar", function(...)
            local argc = select("#", ...)
            local cvar, value

            if argc >= 3 and select(1, ...) == C_CVar then
                cvar, value = select(2, ...)
            else
                cvar, value = ...
            end

            SafeOnExternalCVarSet(cvar, value)
        end)
    end

    self:Refresh(true)
end
