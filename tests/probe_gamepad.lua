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

_G.CreateFrame = stub.CreateFrame
_G.UnitName = function() return "Hiddenscar" end
_G.GetRealmName = function() return "Tichondrius" end
_G.UnitExists = function() return true end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitClass = function() return "Monk", "MONK", 10 end
_G.UnitRace = function() return "Pandaren", "Pandaren", 24 end
_G.UnitSex = function() return 2 end
_G.UnitGUID = function() return nil end
_G.UnitInVehicle = function() return false end
_G.UnitOnTaxi = function() return false end
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
_G.GetBuildInfo = function() return "1.60.0", "61000", "Sep 1 2026", 16001 end
_G.C_AddOns = {
    GetAddOnMetadata = function(_, key) return key == "Version" and "v10.3" or nil end,
    IsAddOnLoaded = function() return false end,
}
_G.print = print
_G.GameTooltip = setmetatable({}, { __index = function() return function() end end })
_G.InCombatLockdown = function() return inCombat end
_G.IsInInstance = function() return false, "none" end
_G.IsInGroup = function() return false end
_G.IsInRaid = function() return false end
_G.UnitAffectingCombat = function() return false end
_G.IsMounted = function() return false end
_G.GetShapeshiftFormID = function() return nil end
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

    GamePadEnable = 0,
    GamePadCameraYawSpeed = 180,
    GamePadCameraPitchSpeed = 90,
    GamePadCameraStick = 2,
    GamePadMoveStick = 1,
    GamePadCursorStick = 0,
    GamePadFaceMovement = 1,
})
cvars:SetDefault("GamePadCameraYawSpeed", 180)
cvars:SetDefault("GamePadCameraPitchSpeed", 90)
cvars:SetDefault("cameraYawMoveSpeed", 180)
cvars:SetDefault("cameraPitchMoveSpeed", 90)
cvars:SetDefault("cameraDistanceMaxZoomFactor", 2.6)

-- No gamepad device API on this client: GamePadEnable is the only signal, which
-- is also the path a Classic-family build would take.
_G.C_GamePad = nil

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

stub.InstallAce3()
stub.Fire("ADDON_LOADED", "Max_Camera_Distance")
stub.Fire("PLAYER_LOGIN")

local db = ns.Database.db.profile
local Functions = ns.Functions
local Guard = ns.CVarGuard
local GamePad = ns.GamePad

print("PROBE gamepad + shoulder offset")

-- ------------------------------------------- phase 1: the offset is settable
db.actionCamShoulderInCombat = true
db.actionCamShoulderOutOfCombat = true
db.actionCamShoulderModelCompensation = false
db.actionCamShoulderSmartFade = false
db.actionCamShoulderOffset = 1.0

cameraZoom = 12
Functions:UpdateActionCam()

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

-- ------------------------------------------------- phase 5: gamepad plumbing
check("phase 5: the gamepad module reports support from the CVar alone",
    GamePad:IsSupported() == true)
check("phase 5: an off GamePadEnable means no active gamepad",
    GamePad:IsActive() == false)

cvars:Set("GamePadEnable", 1)
GamePad:Invalidate()
check("phase 5: turning GamePadEnable on is detected",
    GamePad:IsActive() == true)

-- Opted out by default: nothing is written until the player asks for it.
cvars:ResetCounters()
GamePad:ApplyCameraSpeeds(true)
check("phase 5: gamepad speeds are left alone while the option is off",
    cvars.writes == 0,
    "writes=" .. cvars.writes .. " " .. table.concat(cvars.writeLog, ","))

db.gamePadManageCameraSpeed = true
db.gamePadCameraYawMultiplier = 1.5
db.gamePadCameraPitchMultiplier = 0.5
GamePad:ApplyCameraSpeeds(true)

check("phase 5: the yaw multiplier scales the client's own default",
    near(cvars:Number("GamePadCameraYawSpeed"), 270),
    tostring(cvars:Number("GamePadCameraYawSpeed")))
check("phase 5: the pitch multiplier scales the client's own default",
    near(cvars:Number("GamePadCameraPitchSpeed"), 45),
    tostring(cvars:Number("GamePadCameraPitchSpeed")))
check("phase 5: the mouse camera CVars are untouched by gamepad settings",
    cvars:Number("cameraYawMoveSpeed") == 180 and cvars:Number("cameraPitchMoveSpeed") == 90,
    tostring(cvars:Number("cameraYawMoveSpeed")) .. "/" .. tostring(cvars:Number("cameraPitchMoveSpeed")))

GamePad:RestoreCameraSpeeds()
check("phase 5: switching the option off hands the CVars back to the client",
    near(cvars:Number("GamePadCameraYawSpeed"), 180) and near(cvars:Number("GamePadCameraPitchSpeed"), 90),
    tostring(cvars:Number("GamePadCameraYawSpeed")) .. "/" .. tostring(cvars:Number("GamePadCameraPitchSpeed")))

-- --------------------------------- phase 6: face-movement is opt-in and safe
db.gamePadRelaxFaceMovement = false
GamePad:RefreshFaceMovement()
check("phase 6: face-movement is untouched while the option is off",
    cvars:Number("GamePadFaceMovement") == 1,
    tostring(cvars:Number("GamePadFaceMovement")))

db.gamePadRelaxFaceMovement = true
GamePad:RefreshFaceMovement()
check("phase 6: face-movement is suspended while the shoulder camera is on",
    cvars:Number("GamePadFaceMovement") == 0,
    tostring(cvars:Number("GamePadFaceMovement")))

db.actionCamShoulderInCombat = false
db.actionCamShoulderOutOfCombat = false
Functions:UpdateActionCam()
GamePad:RefreshFaceMovement()
check("phase 6: the player's face-movement value is restored, not clobbered",
    cvars:Number("GamePadFaceMovement") == 1,
    tostring(cvars:Number("GamePadFaceMovement")))

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
cvars:Set("GamePadEnable", 0)
GamePad:Refresh(true)
cvars:Set("GamePadEnable", 1)
GamePad:Refresh(true)
check("phase 9: enabling the gamepad opens the panel once",
    opened == 1,
    "opened=" .. opened)

cvars:Set("GamePadEnable", 0)
GamePad:Refresh(true)
cvars:Set("GamePadEnable", 1)
GamePad:Refresh(true)
check("phase 9: it does not open again on the next toggle",
    opened == 1,
    "opened=" .. opened)

-- Combat must never be interrupted by a settings window.
db.gamePadPanelShown = false
inCombat = true
cvars:Set("GamePadEnable", 0)
GamePad:Refresh(true)
cvars:Set("GamePadEnable", 1)
GamePad:Refresh(true)
check("phase 9: the panel never opens in combat",
    opened == 1,
    "opened=" .. opened)
inCombat = false

-- Turning the toggle back on re-arms it rather than leaving it spent.
db.gamePadPanelShown = true
GamePad:OnOptionChanged("gamePadAutoOpenConfig", true)
check("phase 9: re-enabling the option re-arms the one-time panel",
    db.gamePadPanelShown == false,
    tostring(db.gamePadPanelShown))

-- And the opt-out is honoured.
db.gamePadAutoOpenConfig = false
db.gamePadPanelShown = false
cvars:Set("GamePadEnable", 0)
GamePad:Refresh(true)
cvars:Set("GamePadEnable", 1)
GamePad:Refresh(true)
check("phase 9: the opt-out is respected",
    opened == 1,
    "opened=" .. opened)

ns.Config.OpenGamePadPanel = originalOpen

print(failures == 0 and "PROBE PASSED" or ("PROBE FAILED (" .. failures .. ")"))
os.exit(failures == 0 and 0 or 1)
