-- A newer optional CallbackHandler must not break archival-client startup.
-- wow_stub models initialization/state only, not rendering or protection.
local stub = dofile("tests/wow_stub.lua")
_G.CreateFrame = stub.CreateFrame
_G.UIParent, _G.Minimap = CreateFrame(), CreateFrame()
_G.GetBuildInfo = function() return "6.2.4", "1", "2016", 60200 end
_G.WOW_PROJECT_ID, _G.WOW_PROJECT_MAINLINE = 1, 1
_G.GetCVar = function() return nil end
_G.GetCVarDefault = GetCVar
_G.GetTime = function() return 100 end
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "Realm" end
_G.UnitClass = function() return "Druid", "DRUID" end
_G.GetLocale = function() return "enUS" end
_G.SlashCmdList = {}
_G.securecallfunction = nil
local libs = stub.InstallLibStub()
libs:NewLibrary("CallbackHandler-1.0", 8)
local ace = libs:NewLibrary("AceDB-3.0", 1)
local dbCalls, brokerCalls = 0, 0
ace.New = function() dbCalls = dbCalls + 1; error("new callback helper absent") end
local ldb = libs:NewLibrary("LibDataBroker-1.1", 4)
ldb.NewDataObject = function() brokerCalls = brokerCalls + 1; error("new callback helper absent") end
libs:NewLibrary("LibDBIcon-1.0", 1)
local opened = 0
local ns = { Config = { SetupOptions = function() end, Open = function() opened = opened + 1 end } }
for _, file in ipairs({ "Compat.lua", "Database.lua", "Core.lua" }) do
    assert(loadfile(file))("Max_Camera_Distance", ns)
end
stub.Fire("ADDON_LOADED", "Max_Camera_Distance")
assert(ns.Database.db and dbCalls == 0, "incompatible AceDB callback path was used")
assert(brokerCalls == 0 and ns.Core.basicMinimapButton, "incompatible minimap callback path was used")
local button = ns.Core.basicMinimapButton
button:GetScript("OnClick")(); assert(opened == 1, "basic minimap action disconnected")
ns.Database.db.profile.minimap.hide = true; ns.Core:RefreshMinimapButton()
assert(not button:IsShown())
ns.Database.db.profile.minimap.hide = false; ns.Core:RefreshMinimapButton()
assert(button:IsShown())
assert(_G.securecallfunction == nil, "compatibility installed a global secure-call shim")
print("probe_library_fallback: PASS (optional library ABI mismatch, profile fallback, basic minimap callbacks, no global shim)")
