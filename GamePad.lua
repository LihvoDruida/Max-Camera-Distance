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
local select = select
local table = table

local C_GamePad = _G.C_GamePad
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

-- =====================================================================
-- SCOPE
-- =====================================================================
-- Gamepad handling is intentionally limited to WoW: Forever.
--
-- The CVars and the C_GamePad namespace exist on Retail and the Classic
-- branches too, so this is a product decision rather than a technical limit:
-- the behaviour below has only been reasoned about and tested against Forever,
-- and silently managing somebody's controller CVars on a client where that was
-- never verified is worse than doing nothing. Compat.IS_FOREVER is the same
-- signal the rest of the addon uses, set from the Camelot TOC's Forever.lua
-- marker because Forever still reports the mainline project ID.
local IS_FOREVER = Compat.IS_FOREVER and true or false
GamePad.IS_SUPPORTED_FLAVOR = IS_FOREVER

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
    FACE_MOVEMENT = "GamePadFaceMovement", -- legacy fallback; absent from current public CVar table
    FACE_MAX_ANGLE = "GamePadFaceMovementMaxAngle",
    FACE_MAX_ANGLE_COMBAT = "GamePadFaceMovementMaxAngleCombat",
    TANK_TURN     = "GamePadTankTurnSpeed",
    PUSH_CAMERA   = "GamePadCursorPushCamera",

    -- ActionCam-adjacent gamepad CVars. These remain diagnostic unless the
    -- addon has an explicit, documented control for them: they alter camera /
    -- character policy rather than merely camera speed.
    TURN_WITH_CAMERA = "GamePadTurnWithCamera",
    LOOK_MAX_PITCH = "GamePadCameraLookMaxPitch",
    LOOK_MAX_YAW = "GamePadCameraLookMaxYaw",
    FOLLOW_ADJUST_DELAY = "CameraFollowGamepadAdjustDelay",
    FOLLOW_ADJUST_EASE_IN = "CameraFollowGamepadAdjustEaseIn",
}
GamePad.CVAR = CVAR

-- Forever's Gameplay > Gamepad (Alpha) panel is gated behind its own toggle
-- ("Enable Gamepad UI (Alpha)"), and that toggle - not merely a connected
-- controller - is what the player means by "I am playing on a gamepad".
--
-- The CVar behind it is NOT documented anywhere public: the panel is alpha and
-- post-dates every CVar list we can check against. Hardcoding a guess would
-- fail silently, so the name is DISCOVERED at runtime from the candidates below
-- and, failing those, by scanning the client's own CVar table. GamePadEnable is
-- the last resort, which is also the correct answer on a client that has the
-- old gamepad support but no Gamepad UI.
local UI_CVAR_CANDIDATES = {
    "GamePadUIEnable",
    "gamePadUIEnable",
    "GamePadEnableUI",
    "GamePadUI",
    "gamePadUI",
    "GamePadUIAlpha",
    "GamePadShowUI",
}

-- Everything this module reads or writes, so Core can put them on the
-- CVAR_UPDATE watch list from one place.
GamePad.WATCHED_CVARS = {
    CVAR.ENABLE,
    CVAR.TANK_TURN,
    CVAR.PUSH_CAMERA,
    CVAR.YAW_SPEED,
    CVAR.PITCH_SPEED,
    CVAR.CAMERA_STICK,
    CVAR.MOVE_STICK,
    CVAR.CURSOR_STICK,
    CVAR.FACE_MOVEMENT,
    CVAR.FACE_MAX_ANGLE,
    CVAR.FACE_MAX_ANGLE_COMBAT,
    CVAR.TURN_WITH_CAMERA,
    CVAR.LOOK_MAX_PITCH,
    CVAR.LOOK_MAX_YAW,
    CVAR.FOLLOW_ADJUST_DELAY,
    CVAR.FOLLOW_ADJUST_EASE_IN,
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

-- Dynamic UI-toggle discovery uses C_Console.GetAllCommands(), whose result is
-- explicitly incomplete until VARIABLES_LOADED. Even if C_CVar.AreCVarsLoaded
-- exists, it only describes the CVar subsystem; it does not make the console
-- enumeration contract stronger. Forever therefore waits for the event itself.
local cvarEnumerationReady = false

local state = {
    active = false,
    activeCheckedAt = 0,
    inputActive = nil,
    lastDeviceID = nil,
    inactiveDefaultsReconciled = false,
    lastAppliedYaw = nil,
    lastAppliedPitch = nil,
    warnedCameraStick = false,
    warnedStickCollision = false,
    pendingMasterEnabled = nil,
    actionCamBlockerReason = nil,
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

-- Documented client defaults. The live value is deliberately NOT used as a
-- default fallback: it may already contain a user override, which would make a
-- 1.0x multiplier silently mean "whatever happened to be configured at login".
local FALLBACK_DEFAULTS = {
    [CVAR.YAW_SPEED] = 1,
    [CVAR.PITCH_SPEED] = 1,
    [CVAR.PUSH_CAMERA] = 1,
    [CVAR.TANK_TURN] = 0,
    [CVAR.FACE_MAX_ANGLE] = 0,
    [CVAR.FACE_MAX_ANGLE_COMBAT] = 180,
    [CVAR.TURN_WITH_CAMERA] = 1,
    [CVAR.LOOK_MAX_PITCH] = 0,
    [CVAR.LOOK_MAX_YAW] = 0,
    [CVAR.FOLLOW_ADJUST_DELAY] = 1,
    [CVAR.FOLLOW_ADJUST_EASE_IN] = 1,
}

local function GetClientDefault(name)
    local cached = defaultCache[name]
    if cached ~= nil then
        return cached
    end

    local value = Compat.SafeGetCVarNumberDefault and Compat.SafeGetCVarNumberDefault(name) or nil
    if value == nil then
        value = FALLBACK_DEFAULTS[name]
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

-- Forever sequencing rule: Action Camera is the base camera layer. Gamepad
-- compatibility is applied only after ActionCam has published its shoulder /
-- pitch intent to CVarGuard. This prevents a gamepad transition from briefly
-- restoring Keep Character Centered before the shoulder intent is known.
local function SyncActionCamFirst()
    if ns.Functions and ns.Functions.UpdateActionCam then
        local ok, err = pcall(ns.Functions.UpdateActionCam, ns.Functions)
        if not ok then
            LogMessage("error", "ActionCam pre-sync failed before gamepad update: " .. tostring(err))
        end
    end
end

-- =====================================================================
-- WHAT THE GAME ALREADY EXPOSES
-- =====================================================================
-- Blizzard registers every CVar that appears in the Settings panel through
-- Settings.RegisterCVarSetting, keyed by the CVar name. So Settings.GetSetting
-- is an authoritative, self-updating answer to "does the game already have a
-- control for this?" - which is exactly the rule this addon follows: anything
-- the Gamepad (Alpha) panel owns is left alone and hidden here, and only the
-- CVars that exist in the API WITHOUT a control of their own are exposed.
--
-- It also means the addon corrects itself as the alpha evolves: the moment
-- Blizzard adds a slider for one of these, the addon's duplicate disappears.
local exposureCache = {}

function GamePad:IsExposedInGameUI(cvarName)
    if type(cvarName) ~= "string" then return false end

    local cached = exposureCache[cvarName]
    if cached ~= nil then
        return cached
    end

    local Settings = _G.Settings
    if not (Settings and Settings.GetSetting) then
        -- No Settings API (Classic-era builds). Nothing is "already exposed",
        -- which keeps the addon's own controls available there.
        return false
    end

    local ok, setting = pcall(Settings.GetSetting, cvarName)
    local exposed = ok and setting ~= nil

    -- Only cache a positive result. A negative one may simply mean Blizzard's
    -- settings tables have not been built yet this session.
    if exposed then
        exposureCache[cvarName] = true
    end
    return exposed
end

function GamePad:InvalidateExposureCache()
    for key in pairs(exposureCache) do
        exposureCache[key] = nil
    end
end

-- True when the addon should manage a CVar itself: it has to exist, and the
-- game must not already own a control for it.
function GamePad:CanManage(cvarName)
    return HasCVar(cvarName) and not self:IsExposedInGameUI(cvarName)
end

-- =====================================================================
-- SUPPORT / ACTIVE DETECTION
-- =====================================================================
local resolvedUICVar = nil
local resolvedUICVarIsFallback = false

local function IsConsoleCVar(command)
    if type(command) ~= "table" or type(command.command) ~= "string" then
        return false
    end

    -- Enum.ConsoleCommandType.Cvar is 0. Accept either representation because
    -- older/Forever builds do not always expose the Enum table identically.
    local commandType = command.commandType
    local cvarType = _G.Enum and _G.Enum.ConsoleCommandType and _G.Enum.ConsoleCommandType.Cvar or 0
    if commandType ~= nil and commandType ~= cvarType and commandType ~= 0 then
        return false
    end

    return HasCVar(command.command)
end

local function ScoreUICVarCandidate(command)
    if not IsConsoleCVar(command) then return nil end

    local name = command.command
    local lowered = name:lower()
    if not lowered:find("gamepad", 1, true) or not lowered:find("ui", 1, true) then
        return nil
    end

    -- The alpha toggle is boolean. Reject obviously unrelated numeric gamepad
    -- UI CVars rather than picking the first lexical match from GetAllCommands.
    local current = GetNumber(name)
    local default = GetClientDefault(name)
    if current ~= nil and current ~= 0 and current ~= 1 then return nil end
    if default ~= nil and default ~= 0 and default ~= 1 then return nil end

    local score = 0
    if lowered:sub(1, 7) == "gamepad" then score = score + 4 end
    if lowered:find("enable", 1, true) then score = score + 6 end
    if lowered:find("alpha", 1, true) then score = score + 3 end
    if lowered == "gamepaduienable" or lowered == "gamepadenableui" then score = score + 20 end

    local help = type(command.help) == "string" and command.help:lower() or ""
    if help:find("enable", 1, true) then score = score + 2 end
    if help:find("gamepad", 1, true) then score = score + 1 end
    if help:find("ui", 1, true) then score = score + 1 end
    return score
end

local function ResolveUICVar()
    if resolvedUICVar then
        return resolvedUICVar, resolvedUICVarIsFallback
    end

    -- Do not scan/fallback before VARIABLES_LOADED on Forever. Warcraft's own
    -- API documents GetAllCommands as incomplete before that event.
    if not cvarEnumerationReady then
        return nil, false
    end

    for _, name in ipairs(UI_CVAR_CANDIDATES) do
        if HasCVar(name) then
            resolvedUICVar = name
            resolvedUICVarIsFallback = false
            return resolvedUICVar, false
        end
    end

    local bestName, bestScore
    local C_Console = _G.C_Console
    if C_Console and C_Console.GetAllCommands then
        local ok, commands = pcall(C_Console.GetAllCommands)
        if ok and type(commands) == "table" then
            for _, command in ipairs(commands) do
                local score = ScoreUICVarCandidate(command)
                local name = type(command) == "table" and command.command or nil
                if score and type(name) == "string"
                    and (bestScore == nil or score > bestScore or (score == bestScore and name < bestName)) then
                    bestName, bestScore = name, score
                end
            end
        end
    end

    if bestName then
        resolvedUICVar = bestName
        resolvedUICVarIsFallback = false
        return resolvedUICVar, false
    end

    resolvedUICVar = CVAR.ENABLE
    resolvedUICVarIsFallback = true
    return resolvedUICVar, true
end

function GamePad:OnVariablesLoaded()
    if cvarEnumerationReady then return end
    cvarEnumerationReady = true
    resolvedUICVar = nil
    resolvedUICVarIsFallback = false
    for key in pairs(defaultCache) do defaultCache[key] = nil end
    self:InvalidateExposureCache()
    if Compat.InvalidateCVarCaches then Compat.InvalidateCVarCaches() end
    self:Invalidate()
    SyncActionCamFirst()
    self:Refresh(true)
end

function GamePad:GetUICVarName()
    return ResolveUICVar()
end

function GamePad:IsSupported()
    if not IS_FOREVER then
        return false
    end
    if type(C_GamePad) == "table" then
        return true
    end
    return HasCVar(CVAR.ENABLE)
end

local function ResolveActive()
    -- The Alpha UI CVar cannot be resolved safely before VARIABLES_LOADED.
    -- Treat the module as inactive during that short startup window rather than
    -- falling through to GamePadEnable / C_GamePad and applying overrides before
    -- the product-level master switch has actually been identified.
    if not cvarEnumerationReady then
        return false
    end

    -- CVAR_UPDATE can be delivered before the client commits the new CVar
    -- value. Use the event payload during that tiny window so turning the Alpha
    -- Gamepad UI off immediately tears down ActionCam/gamepad overrides instead
    -- of reading one stale frame of "enabled".
    if state.pendingMasterEnabled ~= nil then
        return state.pendingMasterEnabled and true or false
    end

    -- THE gate, and it is deliberately the first thing checked: the addon's
    -- gamepad mode follows "Enable Gamepad UI (Alpha)" in Gameplay > Gamepad,
    -- not merely a controller being plugged in. With it off, every gamepad
    -- option here stays inert and the client keeps its own default values.
    local uiCVar, isFallback = ResolveUICVar()
    if uiCVar then
        local enabled = GetNumber(uiCVar)
        if enabled == nil or enabled == 0 then
            return false
        end
        -- Where the toggle is a CVar of its own, it is the whole answer: the
        -- player has explicitly opted into the gamepad experience.
        if not isFallback then
            return true
        end
    end

    -- Fallback path only (no dedicated Gamepad UI CVar on this client, so the
    -- check above tested GamePadEnable). C_GamePad.IsEnabled is the
    -- authoritative runtime answer where it exists; the CVar only records the
    -- setting and can be 1 with nothing plugged in.
    if C_GamePad and C_GamePad.IsEnabled then
        local ok, enabled = pcall(C_GamePad.IsEnabled)
        if ok then
            if Compat.IsTruthy then
                return Compat.IsTruthy(enabled)
            end
            return enabled and true or false
        end
    end

    -- No IsEnabled either: require a device to actually be present before
    -- declaring the gamepad active, so a leftover GamePadEnable 1 does not make
    -- the addon manage gamepad CVars for a keyboard/mouse player.
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
-- Gamepad speed uses its own scale. Public API data currently documents a
-- default of 1 for both yaw and pitch, but the client default API remains
-- authoritative; the documented values are only fallbacks. The UI stores
-- multipliers so future client retuning still behaves predictably.
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

-- True when the addon should offer its own camera speed controls at all.
-- Once the Gamepad (Alpha) panel grows its own Camera sliders for these, the
-- addon steps aside rather than fighting them.
function GamePad:CanManageCameraSpeed()
    return self:CanManage(CVAR.YAW_SPEED) or self:CanManage(CVAR.PITCH_SPEED)
end

function GamePad:CanManageCameraAxis(axis)
    local name = (axis == "pitch") and CVAR.PITCH_SPEED or CVAR.YAW_SPEED
    return self:CanManage(name)
end

function GamePad:ApplyCameraSpeeds(force)
    local db = DB()
    if not db then return end
    if not db.gamePadManageCameraSpeed then return end
    if not self:IsActive() then return end
    if not self:CanManageCameraSpeed() then return end

    local yaw = self:CanManage(CVAR.YAW_SPEED) and self:GetResolvedSpeed("yaw") or nil
    if yaw ~= nil and (force or state.lastAppliedYaw == nil or math_abs(state.lastAppliedYaw - yaw) > 0.0005) then
        if SetCVarManaged(CVAR.YAW_SPEED, yaw) then
            state.lastAppliedYaw = yaw
        end
    end

    local pitch = self:CanManage(CVAR.PITCH_SPEED) and self:GetResolvedSpeed("pitch") or nil
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

    -- If Blizzard has taken ownership of an axis in its Settings UI, stop
    -- writing immediately. The game-owned setting is authoritative even for a
    -- restore path; using SetCVar here would violate the same no-duplication
    -- rule that hides the addon's slider.
    if yawDefault ~= nil and self:CanManage(CVAR.YAW_SPEED) then
        local current = GetNumber(CVAR.YAW_SPEED)
        if current == nil or math_abs(current - yawDefault) > 0.0005 then
            SetCVarManaged(CVAR.YAW_SPEED, yawDefault)
        end
    end
    if pitchDefault ~= nil and self:CanManage(CVAR.PITCH_SPEED) then
        local current = GetNumber(CVAR.PITCH_SPEED)
        if current == nil or math_abs(current - pitchDefault) > 0.0005 then
            SetCVarManaged(CVAR.PITCH_SPEED, pitchDefault)
        end
    end

    state.lastAppliedYaw = nil
    state.lastAppliedPitch = nil
end

-- =====================================================================
-- API-ONLY CAMERA CONTROLS
-- =====================================================================
-- These gamepad CVars exist in the API but have no control of their own in the
-- Gamepad (Alpha) panel, which is precisely the gap this addon is for. Each one
-- is still checked against Settings.GetSetting at runtime, so if the alpha
-- grows a slider for any of them the addon's copy disappears by itself.
--
-- Only camera-relevant CVars are listed. Cursor speed, button emulation and
-- stick assignment are input concerns and belong to the game's own panel.
GamePad.ADVANCED_CONTROLS = {
    {
        key = "gamePadCursorPushCamera",
        cvar = CVAR.PUSH_CAMERA,
        min = 0, max = 5, step = 0.05,
        fallbackDefault = 1,
    },
    {
        key = "gamePadTankTurnSpeed",
        cvar = CVAR.TANK_TURN,
        min = 0, max = 360, step = 1,
        fallbackDefault = 0,
    },
}

function GamePad:GetAdvancedControl(key)
    for _, control in ipairs(GamePad.ADVANCED_CONTROLS) do
        if control.key == key then
            return control
        end
    end
    return nil
end

function GamePad:GetAdvancedDefault(key)
    local control = self:GetAdvancedControl(key)
    if not control then return nil end
    local value = GetClientDefault(control.cvar)
    if value == nil then return control.fallbackDefault end
    return value
end

-- Seeds every addon-owned gamepad control from the CLIENT BUILT-IN DEFAULT.
-- This is intentionally different from the ground-effect override: the user
-- requested the Gamepad panel to start from defaults, not from whatever live
-- value may have been left behind by a previous experiment or console command.
-- Existing explicit profile edits are preserved until the management toggle is
-- switched on; enabling management establishes a clean default baseline first.
function GamePad:SeedAdvancedDefaults()
    local db = DB()
    if not db then return end

    for _, control in ipairs(GamePad.ADVANCED_CONTROLS) do
        local value = self:GetAdvancedDefault(control.key)
        if value ~= nil then
            db[control.key] = value
        end
    end
end

function GamePad:ApplyAdvancedControls(force)
    local db = DB()
    if not db then return end
    if not db.gamePadAdvancedOverride then return end
    if not self:IsActive() then return end

    for _, control in ipairs(GamePad.ADVANCED_CONTROLS) do
        if self:CanManage(control.cvar) then
            local value = tonumber(db[control.key])
            if value ~= nil then
                if value < control.min then value = control.min end
                if value > control.max then value = control.max end
                local current = GetNumber(control.cvar)
                if force or current == nil or math_abs(current - value) > 0.0005 then
                    SetCVarManaged(control.cvar, value)
                end
            end
        end
    end
end

function GamePad:RestoreAdvancedControls()
    for _, control in ipairs(GamePad.ADVANCED_CONTROLS) do
        local default = GetClientDefault(control.cvar)
        -- Respect Settings ownership on teardown as well as on apply. A control
        -- can become game-owned later in the session when Blizzard finishes
        -- registering the alpha panel; at that point the addon must step aside.
        if default ~= nil and self:CanManage(control.cvar) then
            local current = GetNumber(control.cvar)
            if current == nil or math_abs(current - default) > 0.0005 then
                SetCVarManaged(control.cvar, default)
            end
        end
    end
end

-- =====================================================================
-- ACTIONCAM COMPATIBILITY
-- =====================================================================
-- GamePad face-movement controls decide when movement direction rotates the
-- character relative to the camera. That can make an over-the-shoulder layout
-- feel as if it is snapping or steering differently from mouse/keyboard, but it
-- is a control-scheme preference rather than an ActionCam requirement. The
-- addon therefore changes it only when the player explicitly opts in.
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

local savedFaceMovement = {}
local FACE_MOVEMENT_CVARS = {
    CVAR.FACE_MAX_ANGLE,
    CVAR.FACE_MAX_ANGLE_COMBAT,
    CVAR.FACE_MOVEMENT,
}

local function SaveAndSetFaceCVar(name, value)
    if not GamePad:CanManage(name) then return false end
    local current = GetNumber(name)
    if current == nil then return false end
    if savedFaceMovement[name] == nil then
        savedFaceMovement[name] = current
    end
    if math_abs(current - value) <= 0.0005 then return true end
    return SetCVarManaged(name, value)
end

local function RestoreSavedFaceCVars(useDefaultsWhenMissing)
    for _, name in ipairs(FACE_MOVEMENT_CVARS) do
        if GamePad:CanManage(name) then
            local restore = savedFaceMovement[name]
            if restore == nil and useDefaultsWhenMissing then
                restore = GetClientDefault(name)
            end
            if restore ~= nil then
                local current = GetNumber(name)
                if current == nil or math_abs(current - restore) > 0.0005 then
                    SetCVarManaged(name, restore)
                end
            end
        end
        savedFaceMovement[name] = nil
    end
end

function GamePad:CanManageFaceMovement()
    -- Never fall back to the legacy binary CVar just because Blizzard owns the
    -- modern angle controls in its Settings UI. If either modern CVar exists,
    -- those are the authoritative controls for this client and our addon may
    -- only manage the subset that is not exposed by Blizzard.
    local hasModern = HasCVar(CVAR.FACE_MAX_ANGLE) or HasCVar(CVAR.FACE_MAX_ANGLE_COMBAT)
    if hasModern then
        return self:CanManage(CVAR.FACE_MAX_ANGLE)
            or self:CanManage(CVAR.FACE_MAX_ANGLE_COMBAT)
    end
    return self:CanManage(CVAR.FACE_MOVEMENT)
end

function GamePad:RefreshFaceMovement()
    if not self:CanManageFaceMovement() then return end

    if self:ShouldRelaxFaceMovement() then
        -- Current clients expose angle thresholds rather than the old binary
        -- GamePadFaceMovement CVar. 180 means "never face movement direction".
        -- If modern thresholds exist but Blizzard owns them, do not touch the
        -- legacy CVar as a side channel around the game's Settings ownership.
        local hasModern = HasCVar(CVAR.FACE_MAX_ANGLE) or HasCVar(CVAR.FACE_MAX_ANGLE_COMBAT)
        if hasModern then
            if self:CanManage(CVAR.FACE_MAX_ANGLE) then
                SaveAndSetFaceCVar(CVAR.FACE_MAX_ANGLE, 180)
            end
            if self:CanManage(CVAR.FACE_MAX_ANGLE_COMBAT) then
                SaveAndSetFaceCVar(CVAR.FACE_MAX_ANGLE_COMBAT, 180)
            end
        elseif self:CanManage(CVAR.FACE_MOVEMENT) then
            SaveAndSetFaceCVar(CVAR.FACE_MOVEMENT, 0)
        end
        return
    end

    RestoreSavedFaceCVars(false)
end

function GamePad:RestoreFaceMovementDefaults()
    RestoreSavedFaceCVars(true)
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

function GamePad:SetActionCamBlockerReason(reason)
    state.actionCamBlockerReason = reason
end

function GamePad:GetActionCamDiagnostics()
    local guard = ns.CVarGuard
    local shoulderIntent, pitchIntent = false, false
    if guard and guard.GetActionCamIntent then
        local ok, shoulder, pitch = pcall(guard.GetActionCamIntent, guard)
        if ok then
            shoulderIntent = shoulder and true or false
            pitchIntent = pitch and true or false
        end
    end

    local ready, reason = true, nil
    if guard and guard.IsActionCamReady then
        local ok, value, why = pcall(guard.IsActionCamReady, guard, shoulderIntent, pitchIntent)
        if ok then
            ready = value and true or false
            reason = why
        end
    end

    return {
        runtimeAllowed = self:IsActive(),
        shoulderIntent = shoulderIntent,
        pitchIntent = pitchIntent,
        ready = ready,
        blockerReason = reason or state.actionCamBlockerReason,
        keepCentered = GetNumber("CameraKeepCharacterCentered"),
        reduceUnexpectedMovement = GetNumber("cameraReduceUnexpectedMovement")
            or GetNumber("CameraReduceUnexpectedMovement"),
        shoulder = GetNumber("test_cameraOverShoulder"),
        dynamicPitch = GetNumber("test_cameraDynamicPitch"),
        turnWithCamera = GetNumber(CVAR.TURN_WITH_CAMERA),
        lookMaxPitch = GetNumber(CVAR.LOOK_MAX_PITCH),
        lookMaxYaw = GetNumber(CVAR.LOOK_MAX_YAW),
        followAdjustDelay = GetNumber(CVAR.FOLLOW_ADJUST_DELAY),
        followAdjustEaseIn = GetNumber(CVAR.FOLLOW_ADJUST_EASE_IN),
    }
end

function GamePad:GetDiagnostics()
    local db = DB()
    local uiCVar, uiCVarIsFallback = ResolveUICVar()
    local uiCVarValue = uiCVar and GetNumber(uiCVar) or nil
    return {
        supported = self:IsSupported(),
        active = self:IsActive(),
        inputActive = state.inputActive,
        activeDeviceID = state.lastDeviceID,
        cvarEnumerationReady = cvarEnumerationReady,
        enableCVar = GetNumber(CVAR.ENABLE),
        cameraStick = GetNumber(CVAR.CAMERA_STICK),
        moveStick = GetNumber(CVAR.MOVE_STICK),
        cursorStick = GetNumber(CVAR.CURSOR_STICK),
        faceMovement = GetNumber(CVAR.FACE_MOVEMENT),
        faceMovementMaxAngle = GetNumber(CVAR.FACE_MAX_ANGLE),
        faceMovementMaxAngleCombat = GetNumber(CVAR.FACE_MAX_ANGLE_COMBAT),
        yawSpeed = GetNumber(CVAR.YAW_SPEED),
        pitchSpeed = GetNumber(CVAR.PITCH_SPEED),
        yawDefault = GetClientDefault(CVAR.YAW_SPEED),
        pitchDefault = GetClientDefault(CVAR.PITCH_SPEED),
        managingSpeed = (db and db.gamePadManageCameraSpeed) and true or false,
        relaxFaceMovement = (db and db.gamePadRelaxFaceMovement) and true or false,
        autoOpenPanel = (db and db.gamePadAutoOpenConfig ~= false) and true or false,
        panelShown = (db and db.gamePadPanelShown) and true or false,
        uiCVar = uiCVar,
        uiCVarIsFallback = uiCVarIsFallback and true or false,
        uiCVarValue = uiCVarValue,
        managingAdvanced = (db and db.gamePadAdvancedOverride) and true or false,
        speedOwnedByGame = self:IsExposedInGameUI(CVAR.YAW_SPEED) or self:IsExposedInGameUI(CVAR.PITCH_SPEED),
        actionCam = self:GetActionCamDiagnostics(),
        problems = self:GetStickProblems(),
    }
end

-- Every gamepad CVar this client actually has, with whether the game's own
-- Settings panel already owns it. This is a reporting aid: the Gamepad (Alpha)
-- panel is undocumented, so /mcd gamepad can show exactly what is there rather
-- than relying on a list written from guesswork.
function GamePad:GetClientCVarInventory()
    local found = {}

    local C_Console = _G.C_Console
    if C_Console and C_Console.GetAllCommands then
        local ok, commands = pcall(C_Console.GetAllCommands)
        if ok and type(commands) == "table" then
            for _, command in ipairs(commands) do
                local name = type(command) == "table" and command.command or nil
                if type(name) == "string"
                    and name:lower():find("gamepad", 1, true)
                    and IsConsoleCVar(command) then
                    found[#found + 1] = {
                        name = name,
                        value = GetNumber(name),
                        exposed = self:IsExposedInGameUI(name),
                    }
                end
            end
        end
    end

    if #found == 0 then
        -- No console enumeration on this client: fall back to the names we know.
        for _, name in pairs(CVAR) do
            if HasCVar(name) then
                found[#found + 1] = {
                    name = name,
                    value = GetNumber(name),
                    exposed = self:IsExposedInGameUI(name),
                }
            end
        end
    end

    table.sort(found, function(a, b) return a.name < b.name end)
    return found
end

-- =====================================================================
-- FIRST-RUN PANEL
-- =====================================================================
-- When a player turns the gamepad on, the settings that actually apply to it
-- are not the ones they have been using, so the panel is surfaced once rather
-- than left to be discovered. Three rules keep this from being obnoxious:
--   * once per character, recorded in the profile;
--   * never in combat, and never while the player is dead - the window would
--     be in the way at exactly the wrong moment;
--   * a visible toggle that turns it off, and also re-arms it when switched
--     back on, so it is never a one-way door.
local function ShouldOfferPanel(db)
    if not db then return false end
    if db.gamePadAutoOpenConfig == false then return false end
    if db.gamePadPanelShown then return false end

    if type(InCombatLockdown) == "function" then
        local ok, inCombat = pcall(InCombatLockdown)
        if ok and inCombat then return false end
    end

    if type(UnitIsDeadOrGhost) == "function" then
        local ok, deadOrGhost = pcall(UnitIsDeadOrGhost, "player")
        if ok and deadOrGhost then return false end
    end

    return true
end

function GamePad:OfferConfigPanel()
    local db = DB()
    if not ShouldOfferPanel(db) then return false end
    if not self:IsActive() then return false end

    if not (ns.Config and ns.Config.OpenGamePadPanel) then return false end

    -- Recorded before the attempt, not after: if the window fails to open for
    -- any reason the player should get the chat pointer below once, not a retry
    -- on every gamepad event for the rest of the session.
    db.gamePadPanelShown = true

    local opened = false
    local ok, result = pcall(ns.Config.OpenGamePadPanel, ns.Config)
    if ok then opened = result and true or false end

    if opened then
        LogMessage("info", "Gamepad detected - opened the Max Camera Distance gamepad settings.")
    else
        LogMessage("warning", "Gamepad detected. Camera settings for it are under /mcd config > Gamepad.")
    end

    return opened
end

function GamePad:OnGamePadEvent(event, ...)
    if event == "GAME_PAD_ACTIVE_CHANGED" then
        -- This is the only connection-related event with an isActive payload.
        local value = select(1, ...)
        state.inputActive = Compat.IsTruthy and Compat.IsTruthy(value) or (value and true or false)
    elseif event == "GAME_PAD_DISCONNECTED" then
        -- CONNECTED / DISCONNECTED have no payload in Blizzard's API. Clear the
        -- cached device first and let GetActiveDeviceID below repopulate it if
        -- another controller remains active.
        state.lastDeviceID = nil
    end

    if C_GamePad and C_GamePad.GetActiveDeviceID then
        local ok, deviceID = pcall(C_GamePad.GetActiveDeviceID)
        if ok then
            local plain = Compat.Plain and Compat.Plain(deviceID) or deviceID
            local num = tonumber(plain)
            if num ~= nil and num >= 0 then state.lastDeviceID = num end
        end
    end

    SyncActionCamFirst()
    self:Refresh(true)
end

-- =====================================================================
-- ENTRY POINTS
-- =====================================================================
-- Called from Core on every GAME_PAD_* event and after the profile changes.
function GamePad:Refresh(force)
    if not self:IsSupported() then return end

    local wasActive = state.active
    self:Invalidate()

    local db = DB()
    if not db then return end

    local isActive = self:IsActive()
    if isActive and not wasActive then
        state.inactiveDefaultsReconciled = false
        self:OfferConfigPanel()
    elseif not isActive then
        -- Product rule for Forever: addon gamepad tuning only exists while the
        -- alpha Gamepad UI mode is enabled. If that master toggle is off, leave
        -- the underlying client at built-in defaults instead of persisting
        -- hidden addon overrides from an earlier session.
        if not state.inactiveDefaultsReconciled then
            if db.gamePadManageCameraSpeed then self:RestoreCameraSpeeds() end
            if db.gamePadAdvancedOverride then self:RestoreAdvancedControls() end
            if db.gamePadRelaxFaceMovement then self:RestoreFaceMovementDefaults() end
            state.inactiveDefaultsReconciled = true
        end
        local guard = ns.CVarGuard
        if guard and guard.Refresh then pcall(guard.Refresh, guard, true) end
        return
    else
        state.inactiveDefaultsReconciled = false
    end

    if db.gamePadManageCameraSpeed then
        self:ApplyCameraSpeeds(force)
    end

    if db.gamePadAdvancedOverride then
        self:ApplyAdvancedControls(force)
    end

    self:RefreshFaceMovement()

    local guard = ns.CVarGuard
    if guard and guard.Refresh then
        pcall(guard.Refresh, guard, true)
    end

    self:WarnAboutStickProblemsOnce()
end

-- CVAR_UPDATE dispatch. Only reacts to the CVars this module owns.
function GamePad:OnCVarUpdate(cvarName, eventValue)
    if type(cvarName) ~= "string" then return false end

    local lowered = cvarName:lower()
    local uiCVar = ResolveUICVar()
    local isMasterCVar = uiCVar and lowered == uiCVar:lower()

    if isMasterCVar then
        local numeric = tonumber(eventValue)
        if numeric ~= nil then
            state.pendingMasterEnabled = numeric ~= 0
        elseif eventValue == true or eventValue == "true" then
            state.pendingMasterEnabled = true
        elseif eventValue == false or eventValue == "false" then
            state.pendingMasterEnabled = false
        end

        self:Invalidate()
        self:InvalidateExposureCache()

        -- ActionCam is the first layer on Forever, so it must observe the
        -- master toggle's event value before gamepad-specific restoration.
        SyncActionCamFirst()
        self:Refresh(true)

        -- The event payload is only a synchronous pre-commit override. Clear it
        -- before returning so a dropped timer can never leave the module stuck
        -- in a synthetic state. The zero-delay pass below observes the actual
        -- committed CVar on clients that dispatch CVAR_UPDATE early.
        state.pendingMasterEnabled = nil
        self:Invalidate()

        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                GamePad:Invalidate()
                SyncActionCamFirst()
                GamePad:Refresh(true)
            end)
        end
        return true
    end

    -- GamePadEnable still matters for input availability, but when Forever has
    -- a dedicated Alpha UI master it is not allowed to replace that gate.
    if lowered == CVAR.ENABLE:lower() then
        self:Invalidate()
        self:Refresh(true)
        return true
    end

    if lowered == CVAR.CAMERA_STICK:lower()
        or lowered == CVAR.MOVE_STICK:lower()
        or lowered == CVAR.CURSOR_STICK:lower() then
        state.warnedCameraStick = false
        state.warnedStickCollision = false
        self:WarnAboutStickProblemsOnce()
        return true
    end

    if lowered == CVAR.FACE_MOVEMENT:lower()
        or lowered == CVAR.FACE_MAX_ANGLE:lower()
        or lowered == CVAR.FACE_MAX_ANGLE_COMBAT:lower() then
        if not (ns.CVarGuard and ns.CVarGuard.IsInternalWrite and ns.CVarGuard:IsInternalWrite()) then
            savedFaceMovement[cvarName] = nil
            savedFaceMovement[CVAR.FACE_MOVEMENT] = nil
            savedFaceMovement[CVAR.FACE_MAX_ANGLE] = nil
            savedFaceMovement[CVAR.FACE_MAX_ANGLE_COMBAT] = nil
        end
        return true
    end

    if lowered == CVAR.YAW_SPEED:lower() or lowered == CVAR.PITCH_SPEED:lower() then
        if ns.CVarGuard and ns.CVarGuard.IsInternalWrite and ns.CVarGuard:IsInternalWrite() then
            return true
        end
        state.lastAppliedYaw = nil
        state.lastAppliedPitch = nil
        return true
    end

    if lowered == CVAR.TANK_TURN:lower() or lowered == CVAR.PUSH_CAMERA:lower()
        or lowered == CVAR.TURN_WITH_CAMERA:lower()
        or lowered == CVAR.LOOK_MAX_PITCH:lower()
        or lowered == CVAR.LOOK_MAX_YAW:lower()
        or lowered == CVAR.FOLLOW_ADJUST_DELAY:lower()
        or lowered == CVAR.FOLLOW_ADJUST_EASE_IN:lower() then
        return true
    end

    return false
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

    if key == "gamePadAdvancedOverride" then
        if value then
            -- The Gamepad page is default-first by design. Never inherit an
            -- arbitrary live value here: seed from the client's built-in
            -- defaults, then apply only the CVars Blizzard does not own.
            self:SeedAdvancedDefaults()
            self:ApplyAdvancedControls(true)
        else
            self:RestoreAdvancedControls()
        end
        return
    end

    if self:GetAdvancedControl(key) then
        self:ApplyAdvancedControls(true)
        return
    end

    if key == "gamePadAutoOpenConfig" then
        -- Switching the option back on re-arms it, so the toggle means what it
        -- says instead of being permanently spent after the first showing.
        local db = DB()
        if db and value then
            db.gamePadPanelShown = false
        end
        return
    end
end
