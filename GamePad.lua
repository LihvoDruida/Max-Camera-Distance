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
    FACE_MOVEMENT = "GamePadFaceMovement",
    TANK_TURN     = "GamePadTankTurnSpeed",
    PUSH_CAMERA   = "GamePadCursorPushCamera",
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

local function ResolveUICVar()
    if resolvedUICVar then
        return resolvedUICVar, resolvedUICVarIsFallback
    end

    -- Wait for the CVar table before concluding anything, or an early probe
    -- would pin the fallback for the whole session.
    if Compat.AreCVarsLoaded and not Compat.AreCVarsLoaded() then
        return nil, false
    end

    for _, name in ipairs(UI_CVAR_CANDIDATES) do
        if HasCVar(name) then
            resolvedUICVar = name
            resolvedUICVarIsFallback = false
            return resolvedUICVar, false
        end
    end

    -- Nothing from the candidate list. Ask the client what it actually has:
    -- any gamepad CVar whose name also mentions the UI is the one we want, and
    -- this keeps working if Blizzard renames the toggle before launch.
    local C_Console = _G.C_Console
    if C_Console and C_Console.GetAllCommands then
        local ok, commands = pcall(C_Console.GetAllCommands)
        if ok and type(commands) == "table" then
            for _, command in ipairs(commands) do
                local name = type(command) == "table" and command.command or nil
                if type(name) == "string" then
                    local lowered = name:lower()
                    if lowered:find("gamepad", 1, true) and lowered:find("ui", 1, true) then
                        resolvedUICVar = name
                        resolvedUICVarIsFallback = false
                        return resolvedUICVar, false
                    end
                end
            end
        end
    end

    resolvedUICVar = CVAR.ENABLE
    resolvedUICVarIsFallback = true
    return resolvedUICVar, true
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

-- True when the addon should offer its own camera speed controls at all.
-- Once the Gamepad (Alpha) panel grows its own Camera sliders for these, the
-- addon steps aside rather than fighting them.
function GamePad:CanManageCameraSpeed()
    return self:CanManage(CVAR.YAW_SPEED) or self:CanManage(CVAR.PITCH_SPEED)
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

    if yawDefault ~= nil then SetCVarManaged(CVAR.YAW_SPEED, yawDefault) end
    if pitchDefault ~= nil then SetCVarManaged(CVAR.PITCH_SPEED, pitchDefault) end

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

-- Seeds the profile from the live CVars so that switching management ON does
-- not itself change how the controller feels. Mirrors the Forever ground-effect
-- override elsewhere in this addon.
function GamePad:CaptureAdvancedValues()
    local db = DB()
    if not db then return end

    for _, control in ipairs(GamePad.ADVANCED_CONTROLS) do
        local live = GetNumber(control.cvar)
        if live ~= nil then
            db[control.key] = live
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
        if default ~= nil and HasCVar(control.cvar) then
            SetCVarManaged(control.cvar, default)
        end
    end
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
    -- If the Gamepad panel gains its own face-movement control, the player's
    -- choice there wins and the addon stops touching it.
    if not self:CanManage(CVAR.FACE_MOVEMENT) then return end

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
        autoOpenPanel = (db and db.gamePadAutoOpenConfig ~= false) and true or false,
        panelShown = (db and db.gamePadPanelShown) and true or false,
        uiCVar = select(1, ResolveUICVar()),
        uiCVarIsFallback = select(2, ResolveUICVar()) and true or false,
        uiCVarValue = (function()
            local name = ResolveUICVar()
            return name and GetNumber(name) or nil
        end)(),
        managingAdvanced = (db and db.gamePadAdvancedOverride) and true or false,
        speedOwnedByGame = self:IsExposedInGameUI(CVAR.YAW_SPEED) or self:IsExposedInGameUI(CVAR.PITCH_SPEED),
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
                if type(name) == "string" and name:lower():find("gamepad", 1, true) then
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

    -- Only an inactive -> active transition counts as "the player just turned
    -- the gamepad on". Refresh runs on plenty of other paths (login, every
    -- managed-CVar pass) and must not pop a window on any of them.
    if self:IsActive() and not wasActive then
        self:OfferConfigPanel()
    end

    if db.gamePadManageCameraSpeed then
        self:ApplyCameraSpeeds(force)
    end

    if db.gamePadAdvancedOverride then
        self:ApplyAdvancedControls(force)
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
    local uiCVar = ResolveUICVar()
    if lowered == CVAR.ENABLE:lower() or (uiCVar and lowered == uiCVar:lower()) then
        self:Invalidate()
        -- Blizzard's settings tables are rebuilt when the Gamepad UI turns on,
        -- so anything we concluded about what the game exposes is now stale.
        self:InvalidateExposureCache()
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

    if key == "gamePadAdvancedOverride" then
        if value then
            -- Capture first, then manage: enabling must not change anything.
            self:CaptureAdvancedValues()
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
