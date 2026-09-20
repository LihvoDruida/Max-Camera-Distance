-- PROBE: Ace3 that loads AFTER this addon must still produce a registered
-- options table.
--
-- Regression guarded: the addon captured AceConfig-3.0 / AceDB-3.0 into file
-- locals at file-load time. WoW loads addons in alphabetical folder order and
-- stores the enabled-addon list PER CHARACTER, so on a character whose Ace3
-- provider sorted after "Max_Camera_Distance" those locals stayed nil for the
-- whole session, SetupOptions returned early in silence, and the only symptom
-- was AceConfigDialog:Open() reporting
--   "Max_Camera_Distance isn't registered with AceConfigRegistry".

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

-- ------------------------------------------------------------- WoW globals
_G.CreateFrame = stub.CreateFrame
_G.UnitName = function() return "Hiddenscar" end
_G.GetRealmName = function() return "Tichondrius" end
_G.UnitExists = function() return true end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitClass = function() return "Monk", "MONK", 10 end
_G.UnitRace = function() return "Pandaren", "Pandaren", 24 end
_G.UnitFactionGroup = function() return "Horde", "Horde" end
_G.GetLocale = function() return "enUS" end
_G.GetTime = function() return 0 end
_G.GetCVar = function() return nil end
_G.GetCVarDefault = function() return nil end
_G.SetCVar = function() return true end
_G.GetCVarBool = function() return false end
_G.C_CVar = { GetCVar = function() end, GetCVarDefault = function() end, SetCVar = function() end }
_G.hooksecurefunc = function() end
_G.CopyTable = nil
_G.C_Timer = { After = function(_, fn) end, NewTicker = function() return { Cancel = function() end } end }
_G.SlashCmdList = {}
_G.GetBuildInfo = function() return "12.0.0", "60000", "Sep 1 2026", 120007 end
_G.C_AddOns = {
    GetAddOnMetadata = function(_, key) return key == "Version" and "v7.5.1" or nil end,
    IsAddOnLoaded = function() return false end,
}
_G.print = print
_G.GameTooltip = setmetatable({}, { __index = function() return function() end end })
_G.InCombatLockdown = function() return false end
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

stub.InstallLibStub()

-- ------------------------------------------------------------- load the addon
-- NOTE: Ace3 is deliberately NOT installed yet. This is the broken-character
-- case: a provider whose folder sorts after "Max_Camera_Distance".
local ns = {}
local function LoadFile(path)
    local chunk, err = loadfile(path)
    if not chunk then error("could not load " .. path .. ": " .. tostring(err)) end
    local ok, loadErr = pcall(chunk, "Max_Camera_Distance", ns)
    if not ok then error("error while loading " .. path .. ": " .. tostring(loadErr)) end
end

-- LibCamera indexes LibStub at file scope with no nil guard; LibStub is present
-- here because the new libs/_manifest.xml loads it before LibCamera.
LoadFile("libs/LibCamera/LibCamera.lua")

for _, file in ipairs({
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

print("PROBE late-Ace3 registration")

-- ------------------------------------------------- phase 1: no Ace3 anywhere
stub.Fire("ADDON_LOADED", "Max_Camera_Distance")

check("phase 1: addon still initialises a profile without Ace3",
    ns.Database and ns.Database.db and ns.Database.db.profile ~= nil)
check("phase 1: fallback store is flagged as such",
    ns.Database and ns.Database.usingFallbackDB == true,
    ns.Database and tostring(ns.Database.usingFallbackDB))
check("phase 1: options are correctly reported as NOT registered",
    ns.Config and ns.Config:IsRegistered() == false)

-- The fallback store must still be a real, writable profile so the camera keeps
-- working on a character with no Ace3 at all.
ns.Database.db.profile.maxZoomFactor = 33
check("phase 1: settings written to the fallback survive in SavedVariables",
    _G.MaxCameraDistanceDB
        and _G.MaxCameraDistanceDB.profiles["Hiddenscar - Tichondrius"]
        and _G.MaxCameraDistanceDB.profiles["Hiddenscar - Tichondrius"].maxZoomFactor == 33)

-- ------------------------------ phase 2: a later addon finally supplies Ace3
local ace = stub.InstallAce3()
stub.Fire("PLAYER_LOGIN")

check("phase 2: options table reaches AceConfigRegistry",
    ns.Config:IsRegistered() == true)
check("phase 2: profile store upgraded off the fallback",
    ns.Database.usingFallbackDB == false and ns.Database.db.__isAceDB == true,
    "fallback=" .. tostring(ns.Database.usingFallbackDB))
check("phase 2: the value set while on the fallback survived the upgrade",
    ns.Database.db.profile.maxZoomFactor == 33,
    tostring(ns.Database.db.profile.maxZoomFactor))
check("phase 2: Blizzard options category added exactly once",
    #ace.dialog.blizCategories == 2,
    "categories=" .. #ace.dialog.blizCategories)

-- ---------------------------------------------- phase 3: opening the window
local ok, err = pcall(function() return ns.Config:Open() end)
check("phase 3: Config:Open() no longer raises the AceConfigRegistry error",
    ok and #ace.dialog.opened == 1, err)

-- ------------------------- phase 4: a second PLAYER_LOGIN must be idempotent
stub.Fire("PLAYER_LOGIN")
check("phase 4: re-running init does not duplicate Blizzard categories",
    #ace.dialog.blizCategories == 2,
    "categories=" .. #ace.dialog.blizCategories)

print(failures == 0 and "PROBE PASSED" or ("PROBE FAILED (" .. failures .. ")"))
os.exit(failures == 0 and 0 or 1)
