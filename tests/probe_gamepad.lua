-- PROBE: configurable shoulder offset + gamepad compatibility.
--
-- Regressions guarded:
--
--  1. The shoulder offset used to be hardcoded to 1.0 in Functions.lua, so
--     there was no way to make the over-the-shoulder view stronger or weaker.
--
--  2. CVarGuard decided whether CameraKeepCharacterCentered had to be blocked
--     by READING test_cameraOverShoulder back. CameraKeepCharacterCentered
--     overrides ActionCam outright (that is what it was added for in 9.0.1),
--     and since 11.0.2 cameraReduceUnexpectedMovement affects the shoulder CVar
--     too. So once either of them got switched on - which is exactly what
--     happens when a player turns the gamepad on and walks through Blizzard's
--     camera settings - the shoulder value read back as 0, the guard concluded
--     "shoulder is not active", stopped blocking keep-centered, restored it,
--     and the shoulder camera could never come back. The guard now follows the
--     addon's published INTENT, which does not take part in that loop.
--
--  3. The OnUpdate driver compared ZOOM and then wrote the CVar unconditionally,
--     so camera jitter past the fade window produced a GetCVar/SetCVar pair per
--     frame for a value that had not changed.
--
--  4. The addon's camera speed options write cameraYawMoveSpeed /
--     cameraPitchMoveSpeed, which only drive the mouse camera. The gamepad has
--     its own GamePadCameraYawSpeed / GamePadCameraPitchSpeed.
--
-- LIMITATION, stated on purpose: the stub models a CVar table, not the client.
-- It cannot reproduce the engine's own reactions to these CVars, so this probe
-- proves what the ADDON does, never what the camera then looks like in game.

package.path = "./tests/?.lua;" .. package.path
local stub = require("wow_stub")

local failures = 0
local function check(label, ok, detail)
    if ok then
        print("  ok   " .. label)
    else
        failures = failures + 1
        print("  FAIL " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
    end
end

local function near(a, b, tolerance)
    if type(a) ~= "number" or type(b) ~= "number" then return false end
    return math.abs(a - b) <= (tolerance or 0.01)
end

-- ------------------------------------------------------------- WoW globals
local cameraZoom = 10
-- GamePad.lua caches InCombatLockdown as an upvalue at load time, exactly as
-- every other module here does, so the probe has to flip a variable the stub
-- closes over rather than swapping the global out afterwards.
local inCombat = false
local mounted = false
local travelForm = false
local inVehicle = false
local onTaxi = false
local flying = false
local falling = false
local swimming = false
local submerged = false
local gliding = false
local canGlide = false
local glideSpeed = 0
local dead = false
local ghost = false

_G.CreateFrame = stub.CreateFrame
_G.UnitName = function() return "Hiddenscar" end
_G.GetRealmName = function() return "Tichondrius" end
_G.UnitExists = function() return true end
_G.UnitIsDeadOrGhost = function() return dead or ghost end
_G.UnitClass = function() return "Monk", "MONK", 10 end
_G.UnitRace = function() return "Pandaren", "Pandaren", 24 end
_G.UnitSex = function() return 2 end
_G.UnitGUID = function() return nil end
_G.UnitInVehicle = function() return inVehicle end
_G.UnitOnTaxi = function() return onTaxi end
_G.UnitFactionGroup = function() return "Horde", "Horde" end
_G.GetLocale = function() return "enUS" end
_G.GetTime = function() return 0 end
_G.GetCameraZoom = function() return cameraZoom end
_G.hooksecurefunc = function() end
_G.CopyTable = nil
_G.C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end }
_G.SlashCmdList = {}
-- Forever, not Retail: gamepad handling is scoped to this flavour, and the
-- Camelot TOC supplies the marker below before Compat.lua classifies the client.
_G.GetBuildInfo = function() return "1.60.1", "69913", "Sep 18 2026", 16001 end
_G.C_AddOns = {
    GetAddOnMetadata = function(_, key) return key == "Version" and "v10.9" or nil end,
    IsAddOnLoaded = function() return false end,
}
_G.print = print
_G.GameTooltip = setmetatable({}, { __index = function() return function() end end })
_G.InCombatLockdown = function() return inCombat end
_G.IsInInstance = function() return false, "none" end
_G.IsInGroup = function() return false end
_G.IsInRaid = function() return false end
_G.UnitAffectingCombat = function() return false end
_G.IsMounted = function() return mounted end
_G.GetShapeshiftFormID = function() return nil end
_G.GetShapeshiftForm = function() return travelForm and 1 or 0 end
_G.GetShapeshiftFormInfo = function(index)
    if travelForm and index == 1 then return 0, true, true, 783 end
    return nil
end
_G.IsFlying = function() return flying end
_G.IsFalling = function() return falling end
_G.IsSwimming = function() return swimming end
_G.IsSubmerged = function() return submerged end
_G.UnitIsAFK = function() return false end
_G.UnitIsDead = function() return dead end
_G.UnitIsGhost = function() return ghost end
_G.C_PlayerInfo = {
    GetGlidingInfo = function() return gliding, canGlide, glideSpeed end,
}
_G.C_QuestLog = { GetNumQuestWatches = function() return 0 end }
_G.C_PetBattles = { IsInBattle = function() return false end }
_G.C_Map = { GetBestMapForUnit = function() return nil end }
_G.UIParent = stub.CreateFrame()
_G.WorldFrame = stub.CreateFrame()
_G.ReloadUI = function() end
_G.MaxCameraDistanceDB = nil

local cvars = stub.InstallCVars({
    cameraDistanceMaxZoomFactor = 2.6,
    cameraDistanceMax = 39,
    cameraDistanceMoveSpeed = 50,
    cameraYawMoveSpeed = 180,
    cameraPitchMoveSpeed = 90,
    cameraZoomSpeed = 20,
    cameraView = 1,
    cameraIndirectVisibility = 1,
    cameraIndirectOffset = 6,
    CameraKeepCharacterCentered = 0,
    cameraReduceUnexpectedMovement = 0,
    test_cameraOverShoulder = 0,
    test_cameraDynamicPitch = 0,
    occludedSilhouettePlayer = 0,
    resampleAlwaysSharpen = 0,
    SoftTargetIconGameObject = 0,

    -- Forever's "Enable Gamepad UI (Alpha)" toggle. A controller is connected
    -- (GamePadEnable = 1) but the player has not opted into the gamepad UI, so
    -- the addon must stay completely inert.
    GamePadExperimentalUIEnable = 0,
    GamePadEnable = 1,
    GamePadCameraYawSpeed = 2.5,
    GamePadCameraPitchSpeed = 1.75,
    GamePadCameraStick = 2,
    GamePadMoveStick = 1,
    GamePadCursorStick = 0,
    GamePadFaceMovement = 1,
    GamePadFaceMovementMaxAngle = 0,
    GamePadFaceMovementMaxAngleCombat = 180,
    GamePadCursorPushCamera = 1,
    GamePadTankTurnSpeed = 0,
    GamePadTurnWithCamera = 1,
    GamePadCameraLookMaxPitch = 0,
    GamePadCameraLookMaxYaw = 0,
    CameraFollowGamepadAdjustDelay = 1,
    CameraFollowGamepadAdjustEaseIn = 1,
    GamePadDebugUIScale = 2.5,
})
cvars:SetDefault("GamePadCursorPushCamera", 1)
cvars:SetDefault("GamePadTankTurnSpeed", 0)
cvars:SetDefault("GamePadFaceMovementMaxAngle", 0)
cvars:SetDefault("GamePadFaceMovementMaxAngleCombat", 180)
cvars:SetDefault("GamePadTurnWithCamera", 1)
cvars:SetDefault("GamePadCameraLookMaxPitch", 0)
cvars:SetDefault("GamePadCameraLookMaxYaw", 0)
cvars:SetDefault("CameraFollowGamepadAdjustDelay", 1)
cvars:SetDefault("CameraFollowGamepadAdjustEaseIn", 1)

-- No Settings API yet: nothing is "already in the game's panel", so the addon
-- offers its own controls. A later phase installs one and checks it steps aside.
_G.Settings = nil
cvars:SetDefault("GamePadCameraYawSpeed", 1)
cvars:SetDefault("GamePadCameraPitchSpeed", 1)
cvars:SetDefault("cameraYawMoveSpeed", 180)
cvars:SetDefault("cameraPitchMoveSpeed", 90)
cvars:SetDefault("cameraDistanceMaxZoomFactor", 2.6)

-- No gamepad device API on this client: GamePadEnable is the only signal, which
-- is also the path a Classic-family build would take.
_G.C_GamePad = nil
_G.C_Console = {
    GetAllCommands = function()
        return {
            { command = "GamePadExperimentalUIEnable", commandType = 0, help = "Enable Gamepad UI (Alpha)" },
            { command = "GamePadCursorPushCamera", commandType = 0, help = "Cursor pushes camera" },
            { command = "GamePadDebugUIScale", commandType = 0, help = "Internal non-boolean UI scale" },
            { command = "GamePadFakeUICommand", commandType = 1, help = "Not a CVar" },
        }
    end,
}

stub.InstallLibStub()

-- ------------------------------------------------------------- load the addon
local ns = {}

-- Exactly what Max_Camera_Distance_Camelot.toc does: load Forever.lua before
-- manifest.xml so Compat.lua gets an unambiguous flavour signal.
local function LoadFile(path)
    local chunk, err = loadfile(path)
    if not chunk then error("could not load " .. path .. ": " .. tostring(err)) end
    local ok, loadErr = pcall(chunk, "Max_Camera_Distance", ns)
    if not ok then error("error while loading " .. path .. ": " .. tostring(loadErr)) end
end

LoadFile("libs/LibCamera/LibCamera.lua")

-- Mirrors manifest.xml.
for _, file in ipairs({
    "Forever.lua",
    "Compatibility.lua",
    "locale/enUS.lua", "locale/deDE.lua", "locale/frFR.lua", "locale/zhCN.lua", "locale/ukUA.lua",
    "Locales.lua",
    "Compat.lua",
    "Contexts.lua",
    "Database.lua",
    "CVarGuard.lua",
    "GamePad.lua",
    "CameraStateController.lua",
    "ShoulderCompensation.lua",
    "Functions.lua",
    "ReactiveZoom.lua",
    "Config.lua",
    "Core.lua",
}) do
    LoadFile(file)
end

local ace = stub.InstallAce3()
stub.Fire("ADDON_LOADED", "Max_Camera_Distance")

-- C_Console.GetAllCommands is documented as incomplete before VARIABLES_LOADED.
-- The module must not cache GamePadEnable as a fallback during this window.
check("startup: UI toggle discovery waits for VARIABLES_LOADED",
    ns.GamePad:GetUICVarName() == nil,
    tostring(ns.GamePad:GetUICVarName()))
check("startup: gamepad mode stays inactive before the master CVar can be resolved",
    ns.GamePad:IsActive() == false,
    tostring(ns.GamePad:IsActive()))

stub.Fire("VARIABLES_LOADED")
stub.Fire("PLAYER_LOGIN")

local db = ns.Database.db.profile
local Functions = ns.Functions
local Guard = ns.CVarGuard
local GamePad = ns.GamePad

print("PROBE gamepad + shoulder offset")

-- -------------------------------- phase 0: Forever UI placement + defaults
local registeredOptions = ace.registry:GetOptionsTable("Max_Camera_Distance")
local extraArgs = registeredOptions and registeredOptions.args and registeredOptions.args.extraFeatures and registeredOptions.args.extraFeatures.args
local padArgs = registeredOptions and registeredOptions.args and registeredOptions.args.gamePadSettings and registeredOptions.args.gamePadSettings.args
check("phase 0: ActionCam is moved out of Extra Features on Forever",
    extraArgs and extraArgs.actionCamHeader and type(extraArgs.actionCamHeader.hidden) == "function" and extraArgs.actionCamHeader.hidden() == true)
check("phase 0: ActionCam is the first Gamepad settings section",
    padArgs and padArgs.gamePadActionCamHeader and padArgs.gamePadSpeedHeader
        and padArgs.gamePadActionCamHeader.order < padArgs.gamePadSpeedHeader.order
        and padArgs.gamePadActionCamHeader.order < padArgs.gamePadAdvancedHeader.order,
    padArgs and tostring(padArgs.gamePadActionCamHeader and padArgs.gamePadActionCamHeader.order) or "no gamepad args")
check("phase 0: Forever ActionCam toggles use full-width rows so labels are not clipped",
    padArgs
        and padArgs.gamePadEnableShoulderInCombat and padArgs.gamePadEnableShoulderInCombat.width == "full"
        and padArgs.gamePadEnableShoulderOutOfCombat and padArgs.gamePadEnableShoulderOutOfCombat.width == "full"
        and padArgs.gamePadEnableDynamicPitch and padArgs.gamePadEnableDynamicPitch.width == "full")
check("phase 0: Forever shoulder offset exposes the engine's full documented range",
    padArgs and padArgs.gamePadShoulderOffset
        and padArgs.gamePadShoulderOffset.min == -15
        and padArgs.gamePadShoulderOffset.max == 15,
    padArgs and padArgs.gamePadShoulderOffset
        and (tostring(padArgs.gamePadShoulderOffset.min) .. "/" .. tostring(padArgs.gamePadShoulderOffset.max)) or "missing")
check("phase 0: Forever shoulder controls include reset, swap and center actions",
    padArgs and padArgs.gamePadShoulderOffsetReset
        and padArgs.gamePadShoulderOffsetSwap
        and padArgs.gamePadShoulderOffsetCenter)
local bindingsFile = io.open("Bindings.xml", "r")
local bindingsText = bindingsFile and bindingsFile:read("*a") or ""
if bindingsFile then bindingsFile:close() end
check("phase 0: static bindings expose shoulder toggle/swap/center/settings",
    bindingsText:find("MAXCAMDIST_TOGGLE_SHOULDER", 1, true)
        and bindingsText:find("MAXCAMDIST_SWAP_SHOULDER", 1, true)
        and bindingsText:find("MAXCAMDIST_CENTER_SHOULDER", 1, true)
        and bindingsText:find("MAXCAMDIST_OPEN_CAMERA_SETTINGS", 1, true))
check("phase 0: gamepad speed multipliers start at client-default 1x",
    near(db.gamePadCameraYawMultiplier, 1.0) and near(db.gamePadCameraPitchMultiplier, 1.0),
    tostring(db.gamePadCameraYawMultiplier) .. "/" .. tostring(db.gamePadCameraPitchMultiplier))
check("phase 0: API-only gamepad values start from built-in defaults",
    near(db.gamePadCursorPushCamera, 1) and near(db.gamePadTankTurnSpeed, 0),
    tostring(db.gamePadCursorPushCamera) .. "/" .. tostring(db.gamePadTankTurnSpeed))
check("phase 0: optional gamepad management starts disabled",
    db.gamePadManageCameraSpeed == false
        and db.gamePadAdvancedOverride == false
        and db.gamePadRelaxFaceMovement == false,
    tostring(db.gamePadManageCameraSpeed) .. "/" .. tostring(db.gamePadAdvancedOverride) .. "/" .. tostring(db.gamePadRelaxFaceMovement))
check("phase 0: ActionCam controls start from stable addon defaults",
    db.actionCamShoulderInCombat == false
        and db.actionCamShoulderOutOfCombat == false
        and db.actionCamPitch == false
        and near(db.actionCamShoulderOffset, 1.0)
        and db.actionCamShoulderSmartFade == true
        and near(db.actionCamShoulderFadeStart, 5.0)
        and near(db.actionCamShoulderFadeEnd, 2.0),
    tostring(db.actionCamShoulderOffset))

local sequence = {}
local originalUpdateActionCam = Functions.UpdateActionCam
local originalGamePadRefresh = GamePad.Refresh
Functions.UpdateActionCam = function(self, ...)
    sequence[#sequence + 1] = "actioncam"
    return originalUpdateActionCam(self, ...)
end
GamePad.Refresh = function(self, ...)
    sequence[#sequence + 1] = "gamepad"
    return originalGamePadRefresh(self, ...)
end
GamePad:OnGamePadEvent("GAME_PAD_CONFIGS_CHANGED")
Functions.UpdateActionCam = originalUpdateActionCam
GamePad.Refresh = originalGamePadRefresh
check("phase 0: ActionCam is synchronized before gamepad compatibility",
    sequence[1] == "actioncam" and sequence[2] == "gamepad",
    table.concat(sequence, " -> "))

-- Forever product rule: ActionCam in this panel is active only while the
-- built-in Gamepad UI (Alpha) master mode is on.
cvars:Set("GamePadExperimentalUIEnable", 1)
GamePad:Invalidate()
check("phase 0: enabling the Forever Gamepad UI arms ActionCam runtime",
    GamePad:IsActive() == true)

-- ------------------------------------------- phase 1: the offset is settable
db.actionCamShoulderInCombat = true
db.actionCamShoulderOutOfCombat = true
db.actionCamShoulderModelCompensation = false
db.actionCamShoulderSmartFade = false
db.actionCamShoulderOffset = 1.0

cameraZoom = 12
-- Forever currently starts with Keep Character Centered enabled. Reproduce that
-- exact client state, plus Reduce Unexpected Movement, and verify MCD clears
-- both BEFORE it commits the shoulder CVar.
cvars:Set("CameraKeepCharacterCentered", 1)
cvars:Set("cameraReduceUnexpectedMovement", 1)
Functions:UpdateActionCam()

check("phase 1: ActionCam blockers are cleared before shoulder application",
    cvars:Number("CameraKeepCharacterCentered") == 0
        and cvars:Number("cameraReduceUnexpectedMovement") == 0,
    tostring(cvars:Number("CameraKeepCharacterCentered")) .. "/"
        .. tostring(cvars:Number("cameraReduceUnexpectedMovement")))
check("phase 1: the shoulder CVar follows the configured offset (1.0)",
    near(cvars:Number("test_cameraOverShoulder"), 1.0),
    tostring(cvars:Number("test_cameraOverShoulder")))

db.actionCamShoulderOffset = 2.75
Functions:ApplyShoulderOffset(true)
check("phase 1: raising the offset to 2.75 reaches the CVar",
    near(cvars:Number("test_cameraOverShoulder"), 2.75),
    tostring(cvars:Number("test_cameraOverShoulder")))

db.actionCamShoulderOffset = -1.5
Functions:ApplyShoulderOffset(true)
check("phase 1: a negative offset swaps to the other shoulder",
    near(cvars:Number("test_cameraOverShoulder"), -1.5),
    tostring(cvars:Number("test_cameraOverShoulder")))

db.actionCamShoulderOffset = 15
Functions:ApplyShoulderOffset(true)
check("phase 1: the full documented +15 shoulder range is available",
    near(cvars:Number("test_cameraOverShoulder"), 15),
    tostring(cvars:Number("test_cameraOverShoulder")))
db.actionCamShoulderOffset = -15
Functions:ApplyShoulderOffset(true)
check("phase 1: the full documented -15 shoulder range is available",
    near(cvars:Number("test_cameraOverShoulder"), -15),
    tostring(cvars:Number("test_cameraOverShoulder")))

-- ------------------------------------------ phase 2: the fade window applies
db.actionCamShoulderOffset = 2.0
db.actionCamShoulderSmartFade = true
db.actionCamShoulderFadeEnd = 2.0
db.actionCamShoulderFadeStart = 6.0

cameraZoom = 1.0
Functions:ApplyShoulderOffset(true)
check("phase 2: fully centred below the inner fade edge",
    near(cvars:Number("test_cameraOverShoulder"), 0),
    tostring(cvars:Number("test_cameraOverShoulder")))

cameraZoom = 4.0
Functions:ApplyShoulderOffset(true)
check("phase 2: halfway through the window gives half the offset",
    near(cvars:Number("test_cameraOverShoulder"), 1.0),
    tostring(cvars:Number("test_cameraOverShoulder")))

cameraZoom = 20.0
Functions:ApplyShoulderOffset(true)
check("phase 2: full offset beyond the outer fade edge",
    near(cvars:Number("test_cameraOverShoulder"), 2.0),
    tostring(cvars:Number("test_cameraOverShoulder")))

-- --------------------------------- phase 3: no redundant writes when parked
cvars:ResetCounters()
for _ = 1, 30 do
    Functions:ApplyShoulderOffset(false)
end
check("phase 3: a static camera touches no CVars at all",
    cvars.writes == 0 and cvars.reads == 0,
    "reads=" .. cvars.reads .. " writes=" .. cvars.writes)

-- Jitter that stays past the outer fade edge changes the zoom but not the
-- resulting offset, which is the case the old zoom-only comparison missed.
--
-- UpdateCVar already refused to SET an unchanged value, so what the old code
-- burned here was a CVar READ (plus a tostring/tonumber round trip) on every
-- single frame. Count reads, not writes, or this assertion proves nothing.
cvars:ResetCounters()
for i = 1, 30 do
    cameraZoom = 20.0 + (i % 2) * 0.05
    Functions:ApplyShoulderOffset(false)
end
check("phase 3: zoom jitter past the fade window touches the shoulder CVar at most once",
    cvars:ReadsOf("test_cameraOverShoulder") <= 1 and cvars.writes == 0,
    "reads=" .. cvars:ReadsOf("test_cameraOverShoulder") .. " writes=" .. cvars.writes)

-- ...but a real change still gets through.
cvars:ResetCounters()
cameraZoom = 3.0
Functions:ApplyShoulderOffset(false)
check("phase 3: a zoom that does change the offset still writes once",
    cvars.writes == 1,
    "writes=" .. cvars.writes)

-- --------------------- phase 4: the keep-centered deadlock cannot come back
cameraZoom = 20.0
Functions:UpdateActionCam()

local shoulderIntent = select(1, Guard:GetActionCamIntent())
check("phase 4: the guard knows the addon wants the shoulder camera",
    shoulderIntent == true,
    tostring(shoulderIntent))

-- Simulate what the client does on the addon's behalf: zero the shoulder CVar
-- and switch keep-centered on, as Blizzard's own camera/gamepad panel would.
cvars:Set("test_cameraOverShoulder", 0)
cvars:Set("CameraKeepCharacterCentered", 1)

check("phase 4: the guard still blocks keep-centered with the CVar reading 0",
    Guard:ShouldBlockKeepCentered() == true)

Guard:Refresh(true)
check("phase 4: keep-centered is forced back off",
    cvars:Number("CameraKeepCharacterCentered") == 0,
    tostring(cvars:Number("CameraKeepCharacterCentered")))

-- And once the player turns the shoulder camera off, their own preference for
-- keep-centered has to come back rather than being held down forever.
db.actionCamShoulderInCombat = false
db.actionCamShoulderOutOfCombat = false
Functions:UpdateActionCam()
Guard:Refresh(true)
check("phase 4: the saved keep-centered value is restored afterwards",
    cvars:Number("CameraKeepCharacterCentered") == 1,
    tostring(cvars:Number("CameraKeepCharacterCentered")))

db.actionCamShoulderInCombat = true
db.actionCamShoulderOutOfCombat = true
Functions:UpdateActionCam()

-- Put the product master back to OFF so phase 5 can verify that a connected
-- controller alone never activates MCD's Forever gamepad layer.
cvars:Set("GamePadExperimentalUIEnable", 0)
GamePad:Invalidate()
Functions:UpdateActionCam()
check("phase 4: Gamepad UI master-off tears down Forever ActionCam",
    cvars:Number("test_cameraOverShoulder") == 0
        and select(1, Guard:GetActionCamIntent()) == false)

-- ------------------------------------------------- phase 5: gamepad plumbing
check("phase 5: the gamepad module reports support on Forever",
    GamePad:IsSupported() == true)
check("phase 5: the Gamepad UI toggle CVar is discovered, not guessed at",
    GamePad:GetUICVarName() == "GamePadExperimentalUIEnable",
    tostring(GamePad:GetUICVarName()))
check("phase 5: a connected controller with the UI toggle OFF is not active",
    GamePad:IsActive() == false,
    "GamePadEnable=" .. tostring(cvars:Number("GamePadEnable")))

cvars:Set("GamePadExperimentalUIEnable", 1)
GamePad:Invalidate()
check("phase 5: enabling the Gamepad UI toggle activates the addon's gamepad mode",
    GamePad:IsActive() == true)
local actionCamDiag = GamePad:GetActionCamDiagnostics()
check("phase 5: ActionCam diagnostics include non-managed gamepad camera-policy CVars",
    actionCamDiag
        and actionCamDiag.turnWithCamera == 1
        and actionCamDiag.lookMaxPitch == 0
        and actionCamDiag.lookMaxYaw == 0
        and actionCamDiag.followAdjustDelay == 1
        and actionCamDiag.followAdjustEaseIn == 1,
    actionCamDiag and tostring(actionCamDiag.turnWithCamera) or "nil")

-- Reproduce Forever's pre-commit CVAR_UPDATE ordering for the Alpha UI master:
-- the event says OFF while GetCVar still returns 1. ActionCam must tear down
-- during that callback, not wait for a later frame that may never arrive.
db.actionCamShoulderInCombat = true
db.actionCamShoulderOutOfCombat = true
db.actionCamShoulderSmartFade = false
db.actionCamShoulderOffset = 1.0
Functions:UpdateActionCam()
check("phase 5: pre-commit setup has a live shoulder before master-off",
    near(cvars:Number("test_cameraOverShoulder"), 1.0))
GamePad:OnCVarUpdate("GamePadExperimentalUIEnable", "0")
check("phase 5: pre-commit master-off event tears down ActionCam using the event value",
    near(cvars:Number("test_cameraOverShoulder"), 0)
        and select(1, Guard:GetActionCamIntent()) == false,
    tostring(cvars:Number("test_cameraOverShoulder")))
-- Simulate the outer client write committing after the callback, then re-enable
-- for the remaining gamepad phases.
cvars:Set("GamePadExperimentalUIEnable", 0)
GamePad:Invalidate()
cvars:Set("GamePadExperimentalUIEnable", 1)
GamePad:Invalidate()
Functions:UpdateActionCam()

-- The discovered alpha CVar is intentionally NOT in GamePad.WATCHED_CVARS.
-- Core must still forward its CVAR_UPDATE dynamically.
cvars:Set("GamePadExperimentalUIEnable", 0)
stub.Fire("CVAR_UPDATE", "GamePadExperimentalUIEnable", "0")
check("phase 5: Core reacts to a runtime-discovered UI CVar",
    GamePad:IsActive() == false)
cvars:Set("GamePadExperimentalUIEnable", 1)
stub.Fire("CVAR_UPDATE", "GamePadExperimentalUIEnable", "1")
check("phase 5: dynamic UI CVar can re-enable gamepad mode",
    GamePad:IsActive() == true)

-- Opted out by default: nothing is written until the player asks for it.
cvars:ResetCounters()
GamePad:ApplyCameraSpeeds(true)
check("phase 5: gamepad speeds are left alone while the option is off",
    cvars.writes == 0,
    "writes=" .. cvars.writes .. " " .. table.concat(cvars.writeLog, ","))

db.gamePadManageCameraSpeed = true
db.gamePadCameraYawMultiplier = 1.5
db.gamePadCameraPitchMultiplier = 1.0
GamePad:ApplyCameraSpeeds(true)

check("phase 5: the yaw multiplier scales the client's own default",
    near(cvars:Number("GamePadCameraYawSpeed"), 1.5),
    tostring(cvars:Number("GamePadCameraYawSpeed")))
check("phase 5: the pitch multiplier scales the client's own default",
    near(cvars:Number("GamePadCameraPitchSpeed"), 1.0),
    tostring(cvars:Number("GamePadCameraPitchSpeed")))
check("phase 5: the mouse camera CVars are untouched by gamepad settings",
    cvars:Number("cameraYawMoveSpeed") == 180 and cvars:Number("cameraPitchMoveSpeed") == 90,
    tostring(cvars:Number("cameraYawMoveSpeed")) .. "/" .. tostring(cvars:Number("cameraPitchMoveSpeed")))

GamePad:RestoreCameraSpeeds()
check("phase 5: switching the option off hands the CVars back to the client",
    near(cvars:Number("GamePadCameraYawSpeed"), 1) and near(cvars:Number("GamePadCameraPitchSpeed"), 1),
    tostring(cvars:Number("GamePadCameraYawSpeed")) .. "/" .. tostring(cvars:Number("GamePadCameraPitchSpeed")))

-- Live Forever validates both camera-speed CVars to 1..4. Old profiles from
-- builds that exposed 0.1x may still carry values below 1; resolution must
-- clamp them before they ever reach SetCVar.
db.gamePadCameraYawMultiplier = 0.1
db.gamePadCameraPitchMultiplier = 0.25
check("phase 5: legacy sub-1 gamepad multipliers clamp to the Forever minimum",
    near(GamePad:GetResolvedSpeed("yaw"), 1) and near(GamePad:GetResolvedSpeed("pitch"), 1),
    tostring(GamePad:GetResolvedSpeed("yaw")) .. "/" .. tostring(GamePad:GetResolvedSpeed("pitch")))
db.gamePadCameraYawMultiplier = 1.0
db.gamePadCameraPitchMultiplier = 1.0

-- --------------------------------- phase 6: face-movement is opt-in and safe
db.gamePadRelaxFaceMovement = false
GamePad:RefreshFaceMovement()
check("phase 6: face-movement is untouched while the option is off",
    cvars:Number("GamePadFaceMovement") == 1,
    tostring(cvars:Number("GamePadFaceMovement")))

db.gamePadRelaxFaceMovement = true
GamePad:RefreshFaceMovement()
check("phase 6: current angle-based face-movement is suspended with shoulder cam",
    cvars:Number("GamePadFaceMovementMaxAngle") == 180
        and cvars:Number("GamePadFaceMovementMaxAngleCombat") == 180
        and cvars:Number("GamePadFaceMovement") == 1,
    tostring(cvars:Number("GamePadFaceMovementMaxAngle")) .. "/"
        .. tostring(cvars:Number("GamePadFaceMovementMaxAngleCombat")) .. "/legacy="
        .. tostring(cvars:Number("GamePadFaceMovement")))

db.actionCamShoulderInCombat = false
db.actionCamShoulderOutOfCombat = false
Functions:UpdateActionCam()
GamePad:RefreshFaceMovement()
check("phase 6: the player's face-movement angles are restored, not clobbered",
    cvars:Number("GamePadFaceMovementMaxAngle") == 0
        and cvars:Number("GamePadFaceMovementMaxAngleCombat") == 180
        and cvars:Number("GamePadFaceMovement") == 1,
    tostring(cvars:Number("GamePadFaceMovementMaxAngle")) .. "/"
        .. tostring(cvars:Number("GamePadFaceMovementMaxAngleCombat")))

-- ------------------------------------------ phase 7: stick misconfiguration
local problems = GamePad:GetStickProblems()
check("phase 7: a correctly assigned camera stick reports no problem",
    #problems == 0,
    table.concat(problems, ","))

cvars:Set("GamePadCameraStick", 0)
problems = GamePad:GetStickProblems()
check("phase 7: an unassigned camera stick is reported",
    problems[1] == "cameraStickUnassigned",
    table.concat(problems, ","))

cvars:Set("GamePadCameraStick", 1)
problems = GamePad:GetStickProblems()
check("phase 7: sharing a stick with movement is reported",
    problems[1] == "cameraStickSharedWithMovement",
    table.concat(problems, ","))

-- ------------------------------------------- phase 8: flavour scoping
check("phase 8: the probe really is running as Forever",
    ns.Compat.IS_FOREVER == true and ns.Compat.IS_RETAIL == false,
    "forever=" .. tostring(ns.Compat.IS_FOREVER) .. " retail=" .. tostring(ns.Compat.IS_RETAIL))
check("phase 8: the module advertises itself as Forever-scoped",
    GamePad.IS_SUPPORTED_FLAVOR == true)
check("phase 8: Forever profiles carry the gamepad keys",
    db.gamePadAutoOpenConfig ~= nil and db.gamePadCameraYawMultiplier ~= nil)

-- --------------------------------- phase 9: the panel opens once, not always
local opened = 0
local originalOpen = ns.Config.OpenGamePadPanel
ns.Config.OpenGamePadPanel = function() opened = opened + 1; return true end

db.gamePadAutoOpenConfig = true
db.gamePadPanelShown = false

-- A Refresh while the gamepad is already active is not a transition.
GamePad:Refresh(true)
check("phase 9: an already-active gamepad does not open the panel",
    opened == 0,
    "opened=" .. opened)

-- Off and on again: that is the transition the player just made.
cvars:Set("GamePadExperimentalUIEnable", 0)
GamePad:Refresh(true)
cvars:Set("GamePadExperimentalUIEnable", 1)
GamePad:Refresh(true)
check("phase 9: enabling the gamepad opens the panel once",
    opened == 1,
    "opened=" .. opened)

cvars:Set("GamePadExperimentalUIEnable", 0)
GamePad:Refresh(true)
cvars:Set("GamePadExperimentalUIEnable", 1)
GamePad:Refresh(true)
check("phase 9: it does not open again on the next toggle",
    opened == 1,
    "opened=" .. opened)

-- Combat must never be interrupted by a settings window.
db.gamePadPanelShown = false
inCombat = true
cvars:Set("GamePadExperimentalUIEnable", 0)
GamePad:Refresh(true)
cvars:Set("GamePadExperimentalUIEnable", 1)
GamePad:Refresh(true)
check("phase 9: the panel never opens in combat",
    opened == 1,
    "opened=" .. opened)
inCombat = false

-- Death/ghost transitions must not surface a settings window over the death UI.
db.gamePadPanelShown = false
dead = true
cvars:Set("GamePadExperimentalUIEnable", 0)
GamePad:Refresh(true)
cvars:Set("GamePadExperimentalUIEnable", 1)
GamePad:Refresh(true)
check("phase 9: the panel never opens while dead",
    opened == 1,
    "opened=" .. opened)
dead = false

db.gamePadPanelShown = false
ghost = true
cvars:Set("GamePadExperimentalUIEnable", 0)
GamePad:Refresh(true)
cvars:Set("GamePadExperimentalUIEnable", 1)
GamePad:Refresh(true)
check("phase 9: the panel never opens while ghost",
    opened == 1,
    "opened=" .. opened)
ghost = false

-- Turning the toggle back on re-arms it rather than leaving it spent.
db.gamePadPanelShown = true
GamePad:OnOptionChanged("gamePadAutoOpenConfig", true)
check("phase 9: re-enabling the option re-arms the one-time panel",
    db.gamePadPanelShown == false,
    tostring(db.gamePadPanelShown))

-- And the opt-out is honoured.
db.gamePadAutoOpenConfig = false
db.gamePadPanelShown = false
cvars:Set("GamePadExperimentalUIEnable", 0)
GamePad:Refresh(true)
cvars:Set("GamePadExperimentalUIEnable", 1)
GamePad:Refresh(true)
check("phase 9: the opt-out is respected",
    opened == 1,
    "opened=" .. opened)

ns.Config.OpenGamePadPanel = originalOpen

-- ------------- phase 10: the addon never duplicates the game's own settings
-- Simulate Blizzard registering only ONE camera axis plus the modern face-turn
-- controls. Ownership is intentionally partial: the addon must step aside per
-- CVar, not hide/write both axes as one aggregate feature.
local gameOwnedCVars = {
    GamePadCameraYawSpeed = true,
    GamePadFaceMovementMaxAngle = true,
    GamePadFaceMovementMaxAngleCombat = true,
}
_G.Settings = {
    GetSetting = function(variable)
        if gameOwnedCVars[variable] then
            return { variable = variable }
        end
        return nil
    end,
}
GamePad:InvalidateExposureCache()

check("phase 10: a CVar with a Settings entry counts as owned by the game",
    GamePad:IsExposedInGameUI("GamePadCameraYawSpeed") == true)
check("phase 10: a CVar without one stays available to the addon",
    GamePad:IsExposedInGameUI("GamePadCameraPitchSpeed") == false)
check("phase 10: camera-speed ownership is resolved per axis",
    GamePad:CanManageCameraAxis("yaw") == false
        and GamePad:CanManageCameraAxis("pitch") == true
        and GamePad:CanManageCameraSpeed() == true)

cvars:Set("GamePadCameraYawSpeed", 2.0)
cvars:Set("GamePadCameraPitchSpeed", 1.0)
db.gamePadManageCameraSpeed = true
db.gamePadCameraYawMultiplier = 2.0
db.gamePadCameraPitchMultiplier = 1.0
cvars:ResetCounters()
GamePad:ApplyCameraSpeeds(true)
check("phase 10: the addon writes only the unowned camera axis",
    near(cvars:Number("GamePadCameraYawSpeed"), 2.0)
        and near(cvars:Number("GamePadCameraPitchSpeed"), 1.0)
        and cvars.writes == 1,
    "yaw=" .. tostring(cvars:Number("GamePadCameraYawSpeed"))
        .. " pitch=" .. tostring(cvars:Number("GamePadCameraPitchSpeed"))
        .. " writes=" .. cvars.writes)

-- Modern face-angle CVars take precedence over the legacy binary switch. If
-- Blizzard owns the modern controls, the addon must NOT use the legacy CVar as
-- a side channel around Settings ownership.
db.gamePadRelaxFaceMovement = true
cvars:Set("GamePadFaceMovement", 1)
cvars:ResetCounters()
GamePad:RefreshFaceMovement()
check("phase 10: game-owned modern face controls suppress the legacy fallback",
    GamePad:CanManageFaceMovement() == false
        and cvars:Number("GamePadFaceMovement") == 1
        and cvars.writes == 0,
    "legacy=" .. tostring(cvars:Number("GamePadFaceMovement")) .. " writes=" .. cvars.writes)

-- The no-duplication rule also applies to teardown. A control may become owned
-- after Blizzard finishes constructing the alpha settings panel; restoration
-- must not write through the game's setting in that case.
gameOwnedCVars.GamePadCursorPushCamera = true
GamePad:InvalidateExposureCache()
cvars:Set("GamePadCursorPushCamera", 2.5)
cvars:ResetCounters()
GamePad:RestoreAdvancedControls()
check("phase 10: restore paths also leave game-owned CVars untouched",
    near(cvars:Number("GamePadCursorPushCamera"), 2.5) and cvars.writes == 0,
    "push=" .. tostring(cvars:Number("GamePadCursorPushCamera")) .. " writes=" .. cvars.writes)

-- Release simulated Blizzard ownership before the API-only/default-restoration
-- phases below so those tests exercise the addon's own management paths.
for key in pairs(gameOwnedCVars) do gameOwnedCVars[key] = nil end
GamePad:InvalidateExposureCache()

-- ------------------------- phase 11: API-only controls are still the addon's
check("phase 11: an API-only CVar is manageable",
    GamePad:CanManage("GamePadCursorPushCamera") == true)

db.gamePadAdvancedOverride = false
cvars:Set("GamePadCursorPushCamera", 1)
cvars:ResetCounters()
GamePad:ApplyAdvancedControls(true)
check("phase 11: nothing is written while the override is off",
    cvars.writes == 0,
    "writes=" .. cvars.writes)

-- The Forever Gamepad panel is default-first: an arbitrary live console value
-- must NOT become the addon's baseline when management is enabled.
cvars:Set("GamePadCursorPushCamera", 2.5)
db.gamePadAdvancedOverride = true
GamePad:OnOptionChanged("gamePadAdvancedOverride", true)
check("phase 11: enabling the override seeds the client built-in default",
    near(tonumber(db.gamePadCursorPushCamera), 1)
        and near(cvars:Number("GamePadCursorPushCamera"), 1),
    tostring(db.gamePadCursorPushCamera) .. "/" .. tostring(cvars:Number("GamePadCursorPushCamera")))

db.gamePadCursorPushCamera = 0
GamePad:ApplyAdvancedControls(true)
check("phase 11: a changed value reaches the CVar",
    near(cvars:Number("GamePadCursorPushCamera"), 0),
    tostring(cvars:Number("GamePadCursorPushCamera")))

GamePad:RestoreAdvancedControls()
check("phase 11: turning the override off restores the client default",
    near(cvars:Number("GamePadCursorPushCamera"), 1),
    tostring(cvars:Number("GamePadCursorPushCamera")))

-- ------------------ phase 12: the UI toggle really is the master switch
db.gamePadAdvancedOverride = true
db.gamePadCursorPushCamera = 4
db.gamePadManageCameraSpeed = true
cvars:Set("GamePadCameraYawSpeed", 250)
cvars:Set("GamePadCameraPitchSpeed", 75)
cvars:Set("GamePadCursorPushCamera", 4)
cvars:ResetCounters()
cvars:Set("GamePadExperimentalUIEnable", 0)
stub.Fire("CVAR_UPDATE", "GamePadExperimentalUIEnable", "0")
check("phase 12: turning the Gamepad UI off deactivates the addon's gamepad mode",
    GamePad:IsActive() == false)
check("phase 12: master-off restores addon-managed CVars to client defaults",
    near(cvars:Number("GamePadCameraYawSpeed"), 1)
        and near(cvars:Number("GamePadCameraPitchSpeed"), 1)
        and near(cvars:Number("GamePadCursorPushCamera"), 1),
    tostring(cvars:Number("GamePadCameraYawSpeed")) .. "/"
        .. tostring(cvars:Number("GamePadCameraPitchSpeed")) .. "/"
        .. tostring(cvars:Number("GamePadCursorPushCamera")))

cvars:ResetCounters()
GamePad:ApplyAdvancedControls(true)
GamePad:ApplyCameraSpeeds(true)
GamePad:Refresh(true)
check("phase 12: once reconciled, UI-off produces no repeated writes",
    cvars.writes == 0,
    "writes=" .. cvars.writes .. " " .. table.concat(cvars.writeLog, ","))

-- ------------------ phase 13: character status semantics stay distinct
cvars:Set("GamePadExperimentalUIEnable", 1)
stub.Fire("CVAR_UPDATE", "GamePadExperimentalUIEnable", "1")
mounted = false
travelForm = true
inVehicle = false
onTaxi = false
flying = false
falling = false
swimming = false
submerged = false
gliding = false
canGlide = false
glideSpeed = 0
Functions:InvalidateRuntimeCaches()
local status = Functions:GetStatusSnapshot()
check("phase 13: Druid travel form is not reported as a physical mount",
    status and status.isMounted == false and status.isTravelForm == true and status.travelActive == true,
    status and (tostring(status.isMounted) .. "/" .. tostring(status.isTravelForm) .. "/" .. tostring(status.travelActive)) or "nil")

travelForm = false
mounted = true
inVehicle = true
onTaxi = true
flying = true
falling = true
swimming = true
submerged = true
gliding = true
canGlide = true
glideSpeed = 72.5
Functions:InvalidateRuntimeCaches()
status = Functions:GetStatusSnapshot()
check("phase 13: physical movement states are reported independently",
    status and status.isMounted == true and status.isTravelForm == false
        and status.inVehicle == true and status.onTaxi == true
        and status.isFlying == true and status.isFalling == true
        and status.isSwimming == true and status.isSubmerged == true,
    status and "movement snapshot mismatch" or "nil")
check("phase 13: gliding API is feature-detected and reported",
    status and status.isGliding == true and status.canGlide == true and near(status.glideSpeed, 72.5),
    status and tostring(status.glideSpeed) or "nil")

dead = true
ghost = false
Functions:InvalidateRuntimeCaches()
status = Functions:GetStatusSnapshot()
check("phase 13: dead state is reported independently",
    status and status.isDead == true and status.isGhost == false,
    status and (tostring(status.isDead) .. "/" .. tostring(status.isGhost)) or "nil")

dead = false
ghost = true
Functions:InvalidateRuntimeCaches()
status = Functions:GetStatusSnapshot()
check("phase 13: ghost state is reported independently",
    status and status.isDead == false and status.isGhost == true,
    status and (tostring(status.isDead) .. "/" .. tostring(status.isGhost)) or "nil")
dead = false
ghost = false


-- ------------------------------------------------ phase 14: synchronous CVAR_UPDATE reentrancy
-- Forever 1.60.1 can deliver CVAR_UPDATE from inside C_CVar.SetCVar before the
-- new value is visible to GetCVar. This is the exact ordering behind the live
-- C stack overflow reported for CameraKeepCharacterCentered.
local writesBeforeReentrantProbe = cvars.writes
cvars:Set("CameraKeepCharacterCentered", 1)
cvars:Set("cameraReduceUnexpectedMovement", 1)
Guard:SetActionCamIntent(true, false)
cvars:SetBeforeWriteHook(function(name, value)
    local lowered = tostring(name):lower()
    if lowered == "camerakeepcharactercentered" or lowered == "camerareduceunexpectedmovement" then
        stub.Fire("CVAR_UPDATE", name, tostring(value))
    end
end)
local reentrantOk, reentrantErr = pcall(Guard.Refresh, Guard, true)
cvars:SetBeforeWriteHook(nil)
check("phase 14: synchronous CVAR_UPDATE does not recurse/overflow", reentrantOk, reentrantErr)
check("phase 14: keep-centered still commits to 0",
    cvars:Number("CameraKeepCharacterCentered") == 0,
    cvars:Get("CameraKeepCharacterCentered"))
check("phase 14: reduce-unexpected-movement still commits to 0",
    cvars:Number("cameraReduceUnexpectedMovement") == 0,
    cvars:Get("cameraReduceUnexpectedMovement"))
check("phase 14: reentrant events do not explode write count",
    (cvars.writes - writesBeforeReentrantProbe) <= 3,
    cvars.writes - writesBeforeReentrantProbe)


-- -------------------------------- phase 15: early external event keeps user intent
-- Simulate an external SetCVar(1) whose CVAR_UPDATE arrives while GetCVar still
-- reports the previous 0. The guard must remember the requested 1 and restore it
-- once ActionCam no longer needs to block keep-centered.
cvars:Set("CameraKeepCharacterCentered", 0)
Guard:SetActionCamIntent(true, false)
Guard:OnExternalCVarSet("CameraKeepCharacterCentered", "1")
-- Outer client write commits after the event callback returns.
cvars:Set("CameraKeepCharacterCentered", 1)
Guard:Refresh(true)
check("phase 15: post-event reconcile re-blocks keep-centered",
    cvars:Number("CameraKeepCharacterCentered") == 0,
    cvars:Get("CameraKeepCharacterCentered"))
Guard:SetActionCamIntent(false, false)
Guard:Refresh(true)
check("phase 15: user keep-centered preference survives the early event",
    cvars:Number("CameraKeepCharacterCentered") == 1,
    cvars:Get("CameraKeepCharacterCentered"))


-- ------------------------ phase 16: ActionCam output ownership / restoration
-- Simple shoulder-only addons commonly preserve the pre-existing experimental
-- CVar values. MCD must do the same, otherwise disabling it destroys a shoulder
-- or dynamic-pitch configuration that belonged to the player/another addon.
cvars:Set("GamePadExperimentalUIEnable", 1)
GamePad:Invalidate()
db.actionCamShoulderInCombat = false
db.actionCamShoulderOutOfCombat = false
db.actionCamPitch = false
Functions:UpdateActionCam()

cvars:Set("test_cameraOverShoulder", 2.25)
cvars:Set("test_cameraDynamicPitch", 1)
cvars:Set("CameraKeepCharacterCentered", 1)
cvars:Set("cameraReduceUnexpectedMovement", 1)
db.actionCamShoulderInCombat = true
db.actionCamShoulderOutOfCombat = true
db.actionCamPitch = true
db.actionCamShoulderSmartFade = false
db.actionCamShoulderModelCompensation = false
db.actionCamShoulderOffset = 1.0
Functions:UpdateActionCam()
local ownedOriginal = select(1, Guard:GetActionCamOutputOwnership("test_cameraOverShoulder"))
check("phase 16: MCD captures the pre-existing shoulder CVar before taking ownership",
    near(ownedOriginal, 2.25), tostring(ownedOriginal))
check("phase 16: MCD applies its own shoulder while preserving that original",
    near(cvars:Number("test_cameraOverShoulder"), 1.0),
    tostring(cvars:Number("test_cameraOverShoulder")))

-- Disable all MCD ActionCam outputs: the previous values and blocker settings
-- must return instead of being hard-reset to zero.
db.actionCamShoulderInCombat = false
db.actionCamShoulderOutOfCombat = false
db.actionCamPitch = false
Functions:UpdateActionCam()
check("phase 16: disabling MCD restores the previous shoulder value",
    near(cvars:Number("test_cameraOverShoulder"), 2.25),
    tostring(cvars:Number("test_cameraOverShoulder")))
check("phase 16: disabling MCD restores the previous dynamic-pitch value",
    near(cvars:Number("test_cameraDynamicPitch"), 1),
    tostring(cvars:Number("test_cameraDynamicPitch")))
check("phase 16: blocker CVars are restored even when the external shoulder remains active",
    cvars:Number("CameraKeepCharacterCentered") == 1
        and cvars:Number("cameraReduceUnexpectedMovement") == 1,
    tostring(cvars:Number("CameraKeepCharacterCentered")) .. "/"
        .. tostring(cvars:Number("cameraReduceUnexpectedMovement")))

-- If somebody changes the shoulder while MCD owns it, that external request is
-- the new restoration point. MCD may reassert its active view, but must hand the
-- requested value back on disable.
db.actionCamShoulderInCombat = true
db.actionCamShoulderOutOfCombat = true
Functions:UpdateActionCam()
cvars:Set("test_cameraOverShoulder", -3.0)
stub.Fire("CVAR_UPDATE", "test_cameraOverShoulder", "-3")
check("phase 16: MCD reasserts its active shoulder after an external change",
    near(cvars:Number("test_cameraOverShoulder"), 1.0),
    tostring(cvars:Number("test_cameraOverShoulder")))
db.actionCamShoulderInCombat = false
db.actionCamShoulderOutOfCombat = false
Functions:UpdateActionCam()
check("phase 16: the latest external shoulder request is restored on release",
    near(cvars:Number("test_cameraOverShoulder"), -3.0),
    tostring(cvars:Number("test_cameraOverShoulder")))

-- ----------------------------------------- phase 17: clean logout/reload handoff
-- A normal logout/reload should not persist MCD's temporary blocker/output CVars
-- as if they were the player's own client settings. The saved profile remains
-- enabled and will be re-applied on the next world-entry pass.
cvars:Set("test_cameraOverShoulder", 3.5)
cvars:Set("test_cameraDynamicPitch", 0)
cvars:Set("CameraKeepCharacterCentered", 1)
cvars:Set("cameraReduceUnexpectedMovement", 1)
db.actionCamShoulderInCombat = true
db.actionCamShoulderOutOfCombat = true
db.actionCamPitch = true
Functions:UpdateActionCam()
check("phase 17: setup actually owns temporary ActionCam state before logout",
    near(cvars:Number("test_cameraOverShoulder"), 1.0)
        and cvars:Number("CameraKeepCharacterCentered") == 0,
    tostring(cvars:Number("test_cameraOverShoulder")) .. "/"
        .. tostring(cvars:Number("CameraKeepCharacterCentered")))
stub.Fire("PLAYER_LOGOUT")
check("phase 17: logout restores pre-existing ActionCam outputs",
    near(cvars:Number("test_cameraOverShoulder"), 3.5)
        and near(cvars:Number("test_cameraDynamicPitch"), 0),
    tostring(cvars:Number("test_cameraOverShoulder")) .. "/"
        .. tostring(cvars:Number("test_cameraDynamicPitch")))
check("phase 17: logout restores temporary blocker CVars",
    cvars:Number("CameraKeepCharacterCentered") == 1
        and cvars:Number("cameraReduceUnexpectedMovement") == 1,
    tostring(cvars:Number("CameraKeepCharacterCentered")) .. "/"
        .. tostring(cvars:Number("cameraReduceUnexpectedMovement")))
check("phase 17: logout cleanup does not erase the saved ActionCam preference",
    db.actionCamShoulderInCombat == true and db.actionCamShoulderOutOfCombat == true and db.actionCamPitch == true)

print(failures == 0 and "PROBE PASSED" or ("PROBE FAILED (" .. failures .. ")"))
os.exit(failures == 0 and 0 or 1)
