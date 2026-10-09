-- Native schema + UI controls, with no AceConfig/AceGUI registered anywhere.
local stub = dofile("tests/ui_stub.lua")
_G.CreateFrame = stub.CreateFrame
_G.UIParent = CreateFrame("Frame", "UIParent"); UIParent:SetSize(1920, 1080)
_G.UISpecialFrames = {}
_G.GetTime = function() return 0 end
_G.GetLocale = function() return "enUS" end
local cases = {
    retail = { "12.1.0", 120100, 1 }, ptr = { "12.1.5", 120105, 1 },
    era = { "1.15.9", 11509, 2 }, tbc = { "2.5.6", 20506, 5 },
    wrath = { "3.4.5", 30405, 11 }, titan = { "3.80.2", 38002, 11 },
    cata = { "4.4.2", 40402, 14 }, mists = { "5.5.4", 50504, 19 },
    forever = { "1.60.1", 16001, 1 },
}
local selected = cases[arg[1] or "retail"]
assert(selected, "unknown test flavor")
_G.GetBuildInfo = function() return selected[1], "69933", "2026", selected[2] end
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "Realm" end
_G.UnitClass = function() return "Druid", "DRUID" end
_G.UnitRace = function() return "Night Elf", "NightElf" end
_G.GetCameraZoom = function() return 18 end
_G.WOW_PROJECT_ID, _G.WOW_PROJECT_MAINLINE = selected[3], 1
_G.UnitNameUnmodified = UnitName
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetCurrentRegionName = function() return "EU" end
_G.GetCurrentRegion = function() return 3 end
_G.strlenutf8 = function(s) return #s end
_G.securecallfunction = function(fn, ...) return fn(...) end
local cvars = { cameraDistanceMaxZoomFactor = "2.6", cameraYawMoveSpeed = "180", cameraPitchMoveSpeed = "90",
    test_cameraOverShoulder = "0", test_cameraDynamicPitch = "0", CameraKeepCharacterCentered = "1" }
_G.GetCVar = function(name) return cvars[name] end
_G.GetCVarDefault = GetCVar
_G.SetCVar = function(name, value) cvars[name] = tostring(value); return true end
_G.InCombatLockdown = function() return false end
_G.ReloadUI = function() end
_G.C_AddOns = { GetAddOnMetadata = function() return "v11.0.0" end }
local ns = {}
local function load(path) assert(loadfile(path))("Max_Camera_Distance", ns) end
if arg[2] == "embedded" then
    for _, path in ipairs({ "Compatibility.lua", "libs/LibStub/LibStub.lua",
        "libs/CallbackHandler-1.0/CallbackHandler-1.0.lua", "libs/AceDB-3.0/AceDB-3.0.lua" }) do load(path) end
end
for _, path in ipairs({ "Compatibility.lua", "locale/enUS.lua", "locale/ukUA.lua", "Locales.lua", "Compat.lua",
    "Contexts.lua", "Database.lua", "Config.lua", "SettingsWindow.lua" }) do load(path) end
ns.Database:InitDB()
assert(ns.Config:SetupOptions())
assert(ns.Config:Open(), "standalone native UI does not open")
local ui = ns.SettingsWindow
assert(#ui:GetPages() >= 7, "visible pages were lost")
assert(LibStub("AceConfigDialog-3.0", true) == nil, "test must not borrow AceGUI")
assert(ui.window:GetName() == UISpecialFrames[1])

-- Every page and all scrollbar positions exercise actual row creation/binding.
for _, page in ipairs(ui:GetPages()) do
    ui:SelectPage(page.key)
    local range = ui.scroll:GetVerticalScrollRange()
    for offset = 0, range + 467, 220 do ui.scroll:SetVerticalScroll(offset) end
    for kind, pool in pairs(ui.pools) do
        assert(#pool < 30, "virtualization creates too many " .. kind .. " widgets")
    end
end
local search = ui:CollectRows("overview", "MAX CAMERA DISTANCE")
assert(#search > 0, "global search does not find non-overview settings")
ns.Database.db.profile.language = "ukUA"
ns.Config.options = nil; ns.Config:SetupOptions()
assert(#ui:CollectRows("overview", "МАКСИМАЛЬНА") > 0, "uppercase Ukrainian search fails")
assert(#ui:CollectRows("overview", "impossible-search-no-match") == 0)
ui:SelectPage("generalSettings")
local sliderRow
for _, row in ipairs(ui.rows) do if row.option.type == "range" and not row.disabled then sliderRow = row; break end end
assert(sliderRow)
ui:Apply(sliderRow, sliderRow.option.min)
assert(sliderRow.option.get(sliderRow.info) == sliderRow.option.min, "range setter disconnected")
local before = sliderRow.option.get(sliderRow.info)
sliderRow.disabled = true; ui:Apply(sliderRow, sliderRow.option.max)
assert(sliderRow.option.get(sliderRow.info) == before, "disabled setting still writes")

ui:SelectPage("profiles")
local p = ns.Config.options.args.profiles.args
local create = { option = p.create, info = { "profiles", "create" }, name = "Create", desc = "" }
ui:Apply(create, "My test profile")
assert(ns.Database.db:GetCurrentProfile() == "My test profile")
ns.Database.db.profile.maxZoomFactor = 31
local original = "Tester - Realm"
ns.Database.db:SetProfile(original)
local copy = { option = p.copy, info = { "profiles", "copy" }, name = "Copy", desc = "" }
ui:Apply(copy, "My test profile")
assert(ui.confirm:IsShown(), "destructive profile copy lacks confirmation")
assert(ns.Database.db.profile.maxZoomFactor ~= 31, "copy runs before confirmation")
local commit = ui.confirm.callback; ui.confirm:Hide(); commit()
assert(ns.Database.db.profile.maxZoomFactor == 31)
ns.Database.db.profile.maxZoomFactor = 25
assert(ns.Database.db.profiles["My test profile"].maxZoomFactor == 31, "copy aliases source data")
local reset = { option = p.reset, info = { "profiles", "reset" }, name = "Reset", desc = "" }
ui:Apply(reset); assert(ui.confirm:IsShown())
commit = ui.confirm.callback; ui.confirm:Hide(); commit()
assert(ns.Database.db.profile.maxZoomFactor == ns.Database:GetDefaultProfile().maxZoomFactor)
local choose = { option = p.choose, info = { "profiles", "choose" }, name = "Choose", desc = "" }
ui:ShowChoices(choose)
assert(ui.choices:IsShown() and #ui.choices.buttons >= 2)
ui:CloseChoices()

-- Small screens keep the entire window inside the available UI rectangle.
UIParent:SetSize(900, 600); ui:FitScreen()
assert(ui.window.scale * 1060 <= 900 and ui.window.scale * 670 <= 600)
local count = #stub.objects
for i = 1, 12 do ns.Config:Open(); ui.window:Hide() end
assert(#stub.objects == count, "reopening grows frame count")
print("probe_native_settings: PASS " .. (arg[1] or "retail") .. "/" .. (arg[2] or "fallback") .. " (strict controls, pages, search, profiles, pooling)")
