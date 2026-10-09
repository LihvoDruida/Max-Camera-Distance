-- Actual activity resolution and journal-based mount detection across flavors.
local stub = dofile("tests/wow_stub.lua")
_G.CreateFrame = stub.CreateFrame
_G.WOW_PROJECT_MAINLINE = 1
_G.GetCVar = function() return "1" end
_G.GetCVarDefault = GetCVar
_G.SetCVar = function() return true end
_G.GetTime = function() return 1 end
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "Realm" end
_G.UnitClass = function() return "Druid", "DRUID" end
_G.IsMounted = function() return true end
local instanceType, difficulty, raid, group, flagged = nil, 0, false, false, false
local failGroup = false
local secret = {}
_G.issecretvalue = function(v) return v == secret end
_G.IsInInstance = function() return instanceType ~= nil, instanceType end
_G.GetInstanceInfo = function() return "Test", instanceType, difficulty end
_G.IsInRaid = function() if failGroup then error("unavailable") end; return raid end
_G.IsInGroup = function() if failGroup then error("unavailable") end; return group end
_G.UnitIsPVP = function() return flagged end
local activeID, mountType, journalCalls = 2, 242, 0
_G.C_MountJournal = {
    GetMountIDs = function() journalCalls = journalCalls + 1; return { 1, 2 } end,
    GetMountInfoByID = function(id) return "Mount", 123, "icon", id == activeID end,
    GetMountInfoExtraByID = function() return nil, nil, nil, nil, mountType end,
}
for _, case in ipairs({
    { "Retail", "12.1.0", 120100, 1, true, true },
    { "Era", "1.15.9", 11509, 2, false, false },
    { "TBC", "2.5.6", 20506, 5, true, false },
    { "Wrath", "3.4.5", 30405, 11, true, false },
    { "Titan", "3.80.2", 38002, 11, true, false },
    { "Cata", "4.4.2", 40402, 14, true, false },
    { "Mists", "5.5.4", 50504, 19, true, true },
    { "Forever", "1.60.1", 16001, 1, true, false },
}) do
    _G.GetBuildInfo = function() return case[2], "1", "2026", case[3] end
    _G.WOW_PROJECT_ID = case[4]
    local ns = {}
    for _, file in ipairs({ "Compat.lua", "Contexts.lua", "Database.lua", "Functions.lua" }) do
        assert(loadfile(file))("Max_Camera_Distance", ns)
    end
    local ctx, compat = ns.Contexts, ns.Compat
    assert(ctx:IsSupported("arena") == case[5], case[1] .. " arena capability")
    assert(ctx:IsSupported("scenario") == case[6], case[1] .. " scenario capability")
    assert(compat.SupportsFlyingMountMode() == (case[1] ~= "Era"))
    assert(compat.SupportsFSRSharpen() and compat.SupportsSoftTargetIcons(), "existing CVar gated by product")
    if case[1] == "Titan" then assert(compat.CLIENT_TAG == "Titan Reforged") end
    instanceType, difficulty, raid, group, flagged, failGroup = "party", 8, false, false, false, false
    assert(ctx:Resolve({}) == (case[1] == "Retail" and "mythicplus" or "dungeon"))
    instanceType = "raid"; assert(ctx:Resolve({}) == "raid")
    instanceType = "pvp"; assert(ctx:Resolve({}) == "battleground")
    instanceType, flagged, group = nil, true, true
    assert(ctx:Resolve({}) == "worldpvp")
    assert(ctx:Resolve({ worldPvpZoom = false }) == "dungeon")
    flagged, group, failGroup = secret, false, true
    assert(ctx:Resolve({}) == "world", "unreadable PvP/group signals break resolution")
    instanceType, difficulty, failGroup = secret, secret, false
    assert(ctx:Resolve({}) == "world", "unreadable instance type/difficulty is compared")
    instanceType, flagged = nil, false
    mountType = 242; ns.Functions:InvalidateMountCache()
    local flying, kind, id = ns.Functions:IsFlyingMountActive()
    assert(flying and kind == 242 and id == activeID, case[1] .. " mount journal ignored")
    local scans = journalCalls
    assert(ns.Functions:IsFlyingMountActive() and journalCalls == scans, "cache rescans the entire journal")
    mountType = 230; ns.Functions:InvalidateMountCache()
    assert(not ns.Functions:IsFlyingMountActive(), "ground mount detected as flying")
    local old = setmetatable({ partyCombatZoomFactor = 21, partyCombatPreset = "far",
        partyCombatReturnDelay = 2.3, pvpCombatZoomFactor = 25, pvpCombatPreset = "close",
        dungeonCombatZoomFactor = 19 }, { __index = ns.Database:GetDefaultProfile() })
    ns.Database:ApplyMigrations(old)
    assert(old.dungeonCombatZoomFactor == 19 and old.mythicPlusCombatZoomFactor == 21,
        "legacy distances lost or existing activity overwritten by defaults")
    assert(old.dungeonCombatPreset == "far" and old.dungeonCombatReturnDelay == 2.3)
    assert(old.arenaCombatZoomFactor == 25 and old.arenaCombatPreset == "close")
    old.arenaCombatZoomFactor = 22; ns.Database:ApplyMigrations(old)
    assert(old.arenaCombatZoomFactor == 22 and old.partyCombatZoomFactor == nil,
        "legacy migration repeats over user changes")
    local damaged = { maxZoomFactor = 0/0, debugLevel = "bad", minimap = false }
    ns.Database:ApplyMigrations(damaged)
    assert(damaged.maxZoomFactor == damaged.maxZoomFactor and type(damaged.debugLevel) == "table"
        and type(damaged.minimap) == "table", "invalid profile values break migration")
    local profile = ns.Database:GetDefaultProfile()
    profile.mountZoomMode = "flying"; ns.Database:ApplyMigrations(profile)
    assert(profile.mountZoomMode == (case[1] == "Era" and "all" or "flying"), "mount profile migration")
end
print("probe_context_mounts: PASS (8 flavors, contexts, secrets, mount journal, cache, profile migration)")
