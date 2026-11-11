-- API-shape matrix; models contracts, not client rendering/protection.
local stub = dofile("tests/wow_stub.lua")
_G.CreateFrame = stub.CreateFrame
_G.UIParent = CreateFrame()
_G.WOW_PROJECT_MAINLINE = 1
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "Realm" end
_G.UnitClass = function() return "Druid", "DRUID" end
_G.GetTime = function() return 100 end
_G.GetShapeshiftForm = function() return 0 end
_G.UnitIsUnit = function(a, b) return a == b end
_G.UnitIsAFK = function() return true end
_G.IsMounted = function() return false end
_G.UnitAffectingCombat = function(unit) return unit == "party2" end
_G.IsInInstance = function() return false end
_G.UnitIsPVP = function() return false end
_G.GetCameraZoom = function() return 18 end
local cases = {
    { "Retail", "12.1.0", 120100, 1 }, { "PTR", "12.1.7", 120107, 1 },
    { "Era", "1.15.9", 11509, 2 }, { "TBC", "2.5.6", 20506, 5 },
    { "Wrath", "3.4.5", 30405, 11 }, { "Titan", "3.80.2", 38002, 11 },
    { "Cata", "4.4.2", 40402, 14 }, { "Mists", "5.5.4", 50504, 19 },
    { "Forever", "1.60.1", 16001, 1 }, { "WoD", "6.2.4", 60200, 1 },
    { "Legion", "7.3.5", 70300, 1 }, { "BfA", "8.3.7", 80300, 1 },
    { "Shadowlands", "9.2.7", 90207, 1 }, { "Dragonflight", "10.2.7", 100207, 1 },
    { "TWW", "11.2.0", 110200, 1 },
}
for _, case in ipairs(cases) do
    for _, auraAPI in ipairs({ "spell_id", "indexed", "buff10", "buff11" }) do
        _G.WOW_PROJECT_ID = case[4]
        _G.GetBuildInfo = function() return case[2], "1", "2026", case[3] end
        _G.C_CVar, _G.C_Timer, _G.C_UnitAuras, _G.UnitBuff = nil, nil, nil, nil
        _G.IsInGroup, _G.IsInRaid, _G.GetNumGroupMembers, _G.GetNumSubgroupMembers = nil, nil, nil, nil
        _G.GetNumPartyMembers = function() return 3 end
        _G.GetNumRaidMembers = function() return 0 end
        stub.InstallCVars({ cameraDistanceMaxZoomFactor = 4, cameraDistanceMax = 50 })
        _G.C_CVar = nil -- global CVar API only, with a void-returning setter
        local setter = SetCVar
        _G.SetCVar = function(name, value) setter(name, value) end
        local reads = 0
        if auraAPI == "spell_id" then
            _G.C_UnitAuras = { GetPlayerAuraBySpellID = function(id)
                reads = reads + 1; return id == 783 and { spellId = id } or nil
            end }
        elseif auraAPI == "indexed" then
            _G.C_UnitAuras = { GetAuraDataByIndex = function(_, index)
                reads = reads + 1; return index == 1 and { spellId = 783 } or nil
            end }
        else
            _G.UnitBuff = function(_, index)
                reads = reads + 1
                if index ~= 1 then return nil end
                if auraAPI == "buff11" then return "Travel", "Rank", 1, 1, nil, 0, 0, "player", false, false, 783 end
                return "Travel", 1, 1, nil, 0, 0, "player", false, false, 783
            end
        end
        local ns = {}
        for _, file in ipairs({ "Compat.lua", "Timer.lua", "Contexts.lua", "Database.lua", "CameraStateController.lua", "Functions.lua" }) do
            assert(loadfile(file))("Max_Camera_Distance", ns)
        end
        local c, f = ns.Compat, ns.Functions
        ns.Database.db = { profile = ns.Database:GetDefaultProfile() }
        assert(c.IsInGroup() and not c.IsInRaid() and c.GetNumSubgroupMembers() == 3 and c.GetNumGroupMembers() == 4)
        assert(ns.Contexts:Resolve({}) == "dungeon", "legacy outdoor party was not detected")
        assert(f:IsGroupInCombat(), "legacy party combat was not detected")
        assert(f:IsTravelFormOnlyActive(), case[1] .. "/" .. auraAPI .. " missed travel aura")
        assert(f:IsTravelFormOnlyActive(), "repeat aura lookup lost travel state")
        if auraAPI ~= "spell_id" then assert(reads == 2, "fallback rescanned buffs for every spell ID") end
        f:InvalidateRuntimeCaches(); assert(f:IsTravelFormOnlyActive())
        assert(c.SafeSetCVar("cameraDistanceMax", 29), "legacy void setter failed readback")
        assert(not c.SupportsMythicPlus() or (c.IS_RETAIL and c.INTERFACE >= 70000))
        assert(not c.SupportsSkyriding() or (c.IS_RETAIL and c.INTERFACE >= 100000))
        -- No global timers: AFK start must retain its configured delay.
        local db = ns.Database.db.profile
        db.afkMode, db.afkHideUI, db.afkSkipMounted, db.afkDelay = true, false, false, 1
        local timerFrame
        for _, frame in ipairs(stub.frames) do
            if frame:IsShown() and frame:GetScript("OnUpdate") then timerFrame = frame end
        end
        f:RefreshAfkMode(false); assert(not f:IsAfkModeActive(), "missing C_Timer removed AFK delay")
        -- The Timer frame was created immediately after Compat; locate the sole
        -- shown scheduler before any zoom update frames are queued.
        for _, frame in ipairs(stub.frames) do
            if frame:IsShown() and frame:GetScript("OnUpdate") then timerFrame = frame end
        end
        assert(timerFrame); timerFrame:GetScript("OnUpdate")(timerFrame, 1)
        assert(f:IsAfkModeActive(), "fallback timer failed to start AFK")
        f:ManualExitAfkMode()
        -- Retire old scheduler frames before the next independent test client.
        for _, frame in ipairs(stub.frames) do frame:Hide() end
    end
end
-- Missing TOC metadata, misleading project IDs and future Classic branches.
_G.GetBuildInfo = function() return "12.1.5", "unknown", "2026" end
_G.WOW_PROJECT_ID = 1
local ns = {}; assert(loadfile("Compat.lua"))("Max_Camera_Distance", ns)
assert(ns.Compat.INTERFACE == 120105 and ns.Compat.IS_RETAIL and ns.Compat.INTERFACE_SOURCE == "version")
_G.GetBuildInfo = function() return "3.4.5", "1", "2026", 30405 end
assert(loadfile("Compat.lua"))("Max_Camera_Distance", ns)
assert(ns.Compat.IS_WRATH_CLASSIC and not ns.Compat.IS_RETAIL, "mainline ID misclassified a modified Wrath client")
_G.WOW_PROJECT_ID = 99
_G.GetBuildInfo = function() return "13.0.0", "1", "2026", 130000 end
assert(loadfile("Compat.lua"))("Max_Camera_Distance", ns)
assert(ns.Compat.IS_CLASSIC and not ns.Compat.IS_RETAIL, "unknown Classic project became Retail")
_G.GetBuildInfo = nil; _G.WOW_PROJECT_ID = nil
assert(loadfile("Compat.lua"))("Max_Camera_Distance", ns)
assert(ns.Compat.CLIENT_TAG == "Unknown" and ns.Compat.INTERFACE == 0)
print("probe_cross_client: PASS (15 clients x 4 aura contracts, legacy rosters/CVars, missing native timers, build fallbacks)")
