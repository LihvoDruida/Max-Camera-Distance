local addonName, ns = ...
ns.GamePad = ns.GamePad or {}
local GamePad = ns.GamePad

local Compat = ns.Compat or {}

local type = type
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local math_abs = math.abs

local C_GamePad = _G.C_GamePad
local GetTime = GetTime

-- =====================================================================
-- CVAR NAMES
-- =====================================================================
-- Native gamepad support was added in 9.0.1 and is still the same CVar family
-- on the modern clients (Midnight and Forever share the modern runtime).
--
-- The important point for this addon: the gamepad has its OWN camera speed
-- CVars. cameraYawMoveSpeed / cameraPitchMoveSpeed - which every "camera
-- turning speed" option in this addon writes - only drive the keyboard/mouse
-- camera. That is why the addon's camera sliders appeared to do nothing the
-- moment a player enabled the gamepad: they were writing the wrong CVars.
local CVAR = {
    ENABLE        = "GamePadEnable",
    ID            = "GamePadId",
    YAW_SPEED     = "GamePadCameraYawSpeed",
    PITCH_SPEED   = "GamePadCameraPitchSpeed",
    CAMERA_STICK  = "GamePadCameraStick",
    MOVE_STICK    = "GamePadMoveStick",
    CURSOR_STICK  = "GamePadCursorStick",
    FACE_MOVEMENT = "GamePadFaceMovement",
    TANK_TURN     = "GamePadTankTurnSpeed",
}
GamePad.CVAR = CVAR

-- Everything this module reads or writes, so Core can put them on the
-- CVAR_UPDATE watch list from one place.
GamePad.WATCHED_CVARS = {
    CVAR.ENABLE,
    CVAR.YAW_SPEED,
    CVAR.PITCH_SPEED,
    CVAR.CAMERA_STICK,
    CVAR.MOVE_STICK,
    CVAR.CURSOR_STICK,
    CVAR.FACE_MOVEMENT,
}

GamePad.EVENTS = {
    "GAME_PAD_ACTIVE_CHANGED",
    "GAME_PAD_CONNECTED",
    "GAME_PAD_DISCONNECTED",
    "GAME_PAD_CONFIGS_CHANGED",
}

-- Stick assignment values shared by GamePadMoveStick / GamePadCameraStick /
-- GamePadCursorStick: 0 = none, 1 = left, 2 = right.
local STICK_NONE = 0

local STATE_CACHE_SECONDS = 0.5

local state = {
    active = false,
    activeCheckedAt = 0,
    lastAppliedYaw = nil,
    lastAppliedPitch = nil,
    warnedCameraStick = false,
    warnedStickCollision = false,
}

-- =====================================================================
-- SAFE CVAR ACCESS
-- =====================================================================
local function DB()
    return (ns.Database and ns.Database.db and ns.Database.db.profile) or nil
end

local function HasCVar(name)
    if Compat.HasCVar then
        return Compat.HasCVar(name)
    end
    return false
end

local function GetNumber(name)
    if Compat.SafeGetCVarNumber then
        return Compat.SafeGetCVarNumber(name)
    end
    return nil
end

-- Client built-in defaults, cached once CVars are readable. Never cache a nil
-- result before AreCVarsLoaded() says the table exists, otherwise an early probe
-- would permanently mark a supported CVar as missing (the same trap Compat
-- documents for HasCVar).
local defaultCache = {}

local function GetClientDefault(name)
    local cached = defaultCache[name]
    if cached ~= nil then
        return cached
    end

    local value = Compat.SafeGetCVarNumberDefault and Compat.SafeGetCVarNumberDefault(name) or nil
    if value == nil then
        if Compat.AreCVarsLoaded and not Compat.AreCVarsLoaded() then
            return nil
        end
        -- Fall back to the live value: it is still a far better anchor for a
        -- multiplier than a hardcoded guess, and the gamepad speed CVars are
        -- not documented with a stable numeric default anywhere we can rely on.
        value = GetNumber(name)
    end

    if value ~= nil then
        defaultCache[name] = value
    end
    return value
end

-- Writes are funnelled through CVarGuard's internal-write depth so the guard
-- does not mistake the addon's own writes for the player changing a setting.
local function SetCVarManaged(name, value)
    if not HasCVar(name) then return false end
    if not Compat.SafeSetCVar then return false end

    local guard = ns.CVarGuard
    if guard and guard.BeginInternalWrite then
        guard:BeginInternalWrite()
    end

    local ok = Compat.SafeSetCVar(name, value)

    if guard and guard.EndInternalWrite then
        guard:EndInternalWrite()
    end

    return ok and true or false
end

local function LogMessage(level, text)
    if ns.Functions and ns.Functions.logMessage then
        ns.Functions:logMessage(level, text)
    end
end

-- =====================================================================
-- SUPPORT / ACTIVE DETECTION
-- =====================================================================
function GamePad:IsSupported()
    if type(C_GamePad) == "table" then
        return true
    end
    return HasCVar(CVAR.ENABLE)
end

local function ResolveActive()
    -- C_GamePad.IsEnabled is the authoritative runtime answer where it exists;
    -- the CVar only records the setting and can be 1 with nothing plugged in.
    if C_GamePad and C_GamePad.IsEnabled then
        local ok, enabled = pcall(C_GamePad.IsEnabled)
        if ok then
            if Compat.IsTruthy then
                return Compat.IsTruthy(enabled)
            end
            return enabled and true or false
        end
    end

    local enableCVar = GetNumber(CVAR.ENABLE)
    if enableCVar == nil or enableCVar == 0 then
        return false
    end

    -- No IsEnabled on this client: require a device to actually be present
    -- before declaring the gamepad active, so a leftover GamePadEnable 1 does
    -- not make the addon manage gamepad CVars for a keyboard/mouse player.
    if C_GamePad and C_GamePad.GetActiveDeviceID then
        local ok, deviceID = pcall(C_GamePad.GetActiveDeviceID)
        if ok then
            local plain = Compat.Plain and Compat.Plain(deviceID) or deviceID
            local num = tonumber(plain)
            if num ~= nil then
                return num >= 0
            end
        end
    end

    return true
end

function GamePad:IsActive()
    if not self:IsSupported() then
        return false
    end

    local now = (GetTime and GetTime()) or 0
    if now > 0 and (now - state.activeCheckedAt) < STATE_CACHE_SECONDS then
        return state.active
    end

    state.activeCheckedAt = now
    state.active = ResolveActive() and true or false
    return state.active
end

function GamePad:Invalidate()
    state.activeCheckedAt = 0
    state.lastAppliedYaw = nil
    state.lastAppliedPitch = nil
end

-- =====================================================================
-- CAMERA SPEED MIRRORING
-- =====================================================================
-- The gamepad speed CVars are on a different scale from cameraYawMoveSpeed and
-- there is no dependable published default to hardcode, so the options are
-- MULTIPLIERS of whatever the client itself considers default. That stays
-- correct if Blizzard retunes the defaults and it works identically on Retail,
-- Forever and any future flavour.
local MIN_MULTIPLIER = 0.1
local MAX_MULTIPLIER = 4.0

local function ClampMultiplier(value, fallback)
    local num = tonumber(value)
    if not num then return fallback end
    if num < MIN_MULTIPLIER then return MIN_MULTIPLIER end
    if num > MAX_MULTIPLIER then return MAX_MULTIPLIER end
    return num
end

function GamePad:GetSpeedBaseline(axis)
    local name = (axis == "pitch") and CVAR.PITCH_SPEED or CVAR.YAW_SPEED
    return GetClientDefault(name)
end

function GamePad:GetResolvedSpeed(axis)
    local db = DB()
    if not db then return nil end

    local baseline = self:GetSpeedBaseline(axis)
    if baseline == nil then return nil end

    local multiplier
    if axis == "pitch" then
        multiplier = ClampMultiplier(db.gamePadCameraPitchMultiplier, 1)
    else
        multiplier = ClampMultiplier(db.gamePadCameraYawMultiplier, 1)
    end

    return baseline * multiplier
end

function GamePad:ApplyCameraSpeeds(force)
    local db = DB()
    if not db then return end
    if not db.gamePadManageCameraSpeed then return end
    if not self:IsActive() then return end

    local yaw = self:GetResolvedSpeed("yaw")
    if yaw ~= nil and (force or state.lastAppliedYaw == nil or math_abs(state.lastAppliedYaw - yaw) > 0.0005) then
        if SetCVarManaged(CVAR.YAW_SPEED, yaw) then
            state.lastAppliedYaw = yaw
        end
    end

    local pitch = self:GetResolvedSpeed("pitch")
    if pitch ~= nil and (force or state.lastAppliedPitch == nil or math_abs(state.lastAppliedPitch - pitch) > 0.0005) then
        if SetCVarManaged(CVAR.PITCH_SPEED, pitch) then
            state.lastAppliedPitch = pitch
        end
    end
end

-- Hand the gamepad speed CVars back to the client's own defaults. Called when
-- the player switches the option off, so the addon never leaves a value behind.
function GamePad:RestoreCameraSpeeds()
    local yawDefault = GetClientDefault(CVAR.YAW_SPEED)
    local pitchDefault = GetClientDefault(CVAR.PITCH_SPEED)

    if yawDefault ~= nil then SetCVarManaged(CVAR.YAW_SPEED, yawDefault) end
    if pitchDefault ~= nil then SetCVarManaged(CVAR.PITCH_SPEED, pitchDefault) end

    state.lastAppliedYaw = nil
    state.lastAppliedPitch = nil
end

-- =====================================================================
-- ACTIONCAM COMPATIBILITY
-- =====================================================================
-- GamePadFaceMovement turns the character to face the movement direction. With
-- an over-the-shoulder offset applied that produces a permanent fight between
-- the engine's auto-facing and the offset, which reads to the player as "the
-- shoulder camera does nothing / snaps back". It is a real control-scheme
-- choice though, so it is only ever touched when the player opts in.
function GamePad:ShouldRelaxFaceMovement()
    local db = DB()
    if not db then return false end
    if not db.gamePadRelaxFaceMovement then return false end
    if not self:IsActive() then return false end

    local functions = ns.Functions
    if functions and functions.ShouldEnableShoulderNow then
        local ok, wanted = pcall(functions.ShouldEnableShoulderNow, functions)
        return ok and wanted and true or false
    end
    return false
end

local savedFaceMovement = nil

function GamePad:RefreshFaceMovement()
    if not HasCVar(CVAR.FACE_MOVEMENT) then return end

    if self:ShouldRelaxFaceMovement() then
        local current = GetNumber(CVAR.FACE_MOVEMENT)
        if current ~= nil and current ~= 0 then
            if savedFaceMovement == nil then
                savedFaceMovement = current
            end
            SetCVarManaged(CVAR.FACE_MOVEMENT, 0)
        end
        return
    end

    if savedFaceMovement ~= nil then
        local restore = savedFaceMovement
        savedFaceMovement = nil
        SetCVarManaged(CVAR.FACE_MOVEMENT, restore)
    end
end

-- =====================================================================
-- DIAGNOSTICS
-- =====================================================================
-- "Camera inputs just don't work with the gamepad on" has a second, much more
-- mundane cause than any ActionCam conflict: the camera stick can simply be
-- unassigned, or assigned to the same physical stick as movement or the cursor.
-- The addon cannot silently rebind someone's controller, but it can say so.
function GamePad:GetStickProblems()
    local problems = {}

    if not HasCVar(CVAR.CAMERA_STICK) then
        return problems
    end

    local cameraStick = GetNumber(CVAR.CAMERA_STICK)
    local moveStick = GetNumber(CVAR.MOVE_STICK)
    local cursorStick = GetNumber(CVAR.CURSOR_STICK)

    if cameraStick == nil then
        return problems
    end

    if cameraStick == STICK_NONE then
        problems[#problems + 1] = "cameraStickUnassigned"
    else
        if moveStick ~= nil and moveStick == cameraStick then
            problems[#problems + 1] = "cameraStickSharedWithMovement"
        end
        if cursorStick ~= nil and cursorStick == cameraStick then
            problems[#problems + 1] = "cameraStickSharedWithCursor"
        end
    end

    return problems
end

function GamePad:WarnAboutStickProblemsOnce()
    if not self:IsActive() then return end

    local problems = self:GetStickProblems()
    for _, id in ipairs(problems) do
        if id == "cameraStickUnassigned" and not state.warnedCameraStick then
            state.warnedCameraStick = true
            LogMessage("warning", "GamePadCameraStick is set to 0 (no stick), so the client itself is not sending any camera input. Assign a stick in Options > Gamepad.")
        elseif (id == "cameraStickSharedWithMovement" or id == "cameraStickSharedWithCursor") and not state.warnedStickCollision then
            state.warnedStickCollision = true
            LogMessage("warning", "The gamepad camera stick shares a physical stick with movement or the cursor. Camera input will feel unresponsive until they are separated.")
        end
    end
end

function GamePad:GetDiagnostics()
    local db = DB()
    return {
        supported = self:IsSupported(),
        active = self:IsActive(),
        enableCVar = GetNumber(CVAR.ENABLE),
        cameraStick = GetNumber(CVAR.CAMERA_STICK),
        moveStick = GetNumber(CVAR.MOVE_STICK),
        cursorStick = GetNumber(CVAR.CURSOR_STICK),
        faceMovement = GetNumber(CVAR.FACE_MOVEMENT),
        yawSpeed = GetNumber(CVAR.YAW_SPEED),
        pitchSpeed = GetNumber(CVAR.PITCH_SPEED),
        yawDefault = GetClientDefault(CVAR.YAW_SPEED),
        pitchDefault = GetClientDefault(CVAR.PITCH_SPEED),
        managingSpeed = (db and db.gamePadManageCameraSpeed) and true or false,
        relaxFaceMovement = (db and db.gamePadRelaxFaceMovement) and true or false,
        problems = self:GetStickProblems(),
    }
end

-- =====================================================================
-- ENTRY POINTS
-- =====================================================================
-- Called from Core on every GAME_PAD_* event and after the profile changes.
function GamePad:Refresh(force)
    if not self:IsSupported() then return end

    self:Invalidate()

    local db = DB()
    if not db then return end

    if db.gamePadManageCameraSpeed then
        self:ApplyCameraSpeeds(force)
    end

    self:RefreshFaceMovement()

    -- The shoulder offset and the motion-sickness CVars are owned by
    -- CVarGuard/Functions; toggling the gamepad can move CameraKeepCharacterCentered
    -- underneath them, so force a reconciliation rather than waiting for the
    -- next camera event.
    local guard = ns.CVarGuard
    if guard and guard.Refresh then
        pcall(guard.Refresh, guard, true)
    end

    self:WarnAboutStickProblemsOnce()
end

-- CVAR_UPDATE dispatch. Only reacts to the CVars this module owns.
function GamePad:OnCVarUpdate(cvarName)
    if type(cvarName) ~= "string" then return end

    local lowered = cvarName:lower()
    if lowered == CVAR.ENABLE:lower() then
        self:Invalidate()
        self:Refresh(true)
        return
    end

    if lowered == CVAR.CAMERA_STICK:lower()
        or lowered == CVAR.MOVE_STICK:lower()
        or lowered == CVAR.CURSOR_STICK:lower() then
        state.warnedCameraStick = false
        state.warnedStickCollision = false
        self:WarnAboutStickProblemsOnce()
        return
    end

    if lowered == CVAR.FACE_MOVEMENT:lower() then
        -- An external change is the player's choice; forget the saved value so
        -- the addon never restores a stale one later.
        if not (ns.CVarGuard and ns.CVarGuard.IsInternalWrite and ns.CVarGuard:IsInternalWrite()) then
            savedFaceMovement = nil
        end
        return
    end

    if lowered == CVAR.YAW_SPEED:lower() or lowered == CVAR.PITCH_SPEED:lower() then
        if ns.CVarGuard and ns.CVarGuard.IsInternalWrite and ns.CVarGuard:IsInternalWrite() then
            return
        end
        -- The player (or Blizzard's gamepad panel) moved the slider. Drop the
        -- addon's applied-value memory so the option no longer claims ownership
        -- of a number it did not write.
        state.lastAppliedYaw = nil
        state.lastAppliedPitch = nil
        return
    end
end

-- Called when a gamepad option changes in the addon's own settings panel.
function GamePad:OnOptionChanged(key, value)
    if key == "gamePadManageCameraSpeed" then
        if value then
            self:ApplyCameraSpeeds(true)
        else
            self:RestoreCameraSpeeds()
        end
        return
    end

    if key == "gamePadCameraYawMultiplier" or key == "gamePadCameraPitchMultiplier" then
        self:ApplyCameraSpeeds(true)
        return
    end

    if key == "gamePadRelaxFaceMovement" then
        self:RefreshFaceMovement()
        return
    end
end
