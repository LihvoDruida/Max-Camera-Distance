-- Combat camera regressions from the 2026-11-19 audit:
--  * a party member entering/leaving combat while the player stays out of it
--    must move the APPLIED controller state, not only a fresh status read;
--  * a routine re-evaluation during the return delay must not cut it short;
--  * "shoulder out of combat only" must be off in combat (all 8 combinations);
--  * the shoulder toggle must edit the checkbox of the context that applies.
-- The stub models API answers and a controllable clock, not the live client.
local stub = dofile("tests/wow_stub.lua")
local frames = {}
_G.CreateFrame = function(...)
    local frame = stub.CreateFrame(...)
    frames[#frames + 1] = frame
    return frame
end
local function RunFrames()
    for _, frame in ipairs(frames) do
        local onUpdate = frame:GetScript("OnUpdate")
        if onUpdate and frame:IsShown() then onUpdate(frame, 0.016) end
    end
end

_G.UIParent = CreateFrame()
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "Realm" end
_G.UnitClass = function() return "Priest", "PRIEST" end
local clock = 100
_G.GetTime = function() return clock end

local combat = {}
local inGroup, partySize = false, 0
_G.UnitAffectingCombat = function(unit) return combat[unit] and true or false end
_G.UnitIsUnit = function(a, b) return a == b end
_G.IsInGroup = function() return inGroup end
_G.IsInRaid = function() return false end
_G.GetNumSubgroupMembers = function() return partySize end
_G.GetNumGroupMembers = function() return inGroup and (partySize + 1) or 0 end
_G.IsEncounterInProgress = function() return false end
_G.IsMounted = function() return false end
_G.UnitIsAFK = function() return false end
local zoom = 25
_G.GetCameraZoom = function() return zoom end
_G.IsInInstance = function() return false, "none" end
_G.GetInstanceInfo = function() return "World", "none", 0 end

local timers = {}
local function Schedule(delay, callback)
    local timer = { due = clock + (tonumber(delay) or 0), cancelled = false, callback = callback }
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end
_G.C_Timer = {
    After = function(delay, callback) Schedule(delay, callback) end,
    NewTimer = function(delay, callback) return Schedule(delay, callback) end,
}
local function RunDueTimers()
    local queue = timers; timers = {}
    for _, timer in ipairs(queue) do
        if timer.cancelled then
            -- dropped
        elseif timer.due <= clock then
            timer.callback()
        else
            timers[#timers + 1] = timer
        end
    end
end

local animations = {}
_G.LibStub = function(name)
    if name == "MaxCameraDistance-LibCamera-1.0" then return {
        StopZooming = function() end,
        SetZoomUsingCVar = function(_, target) animations[#animations + 1] = target; zoom = target end,
    } end
end

for _, case in ipairs({ { "Retail", "12.1.0", 120100, 1 }, { "Forever", "1.60.1", 16001, 1 } }) do
    _G.WOW_PROJECT_ID = case[4]
    _G.WOW_PROJECT_MAINLINE = 1
    _G.GetBuildInfo = function() return case[2], "1", "2026", case[3] end
    stub.InstallCVars({ cameraDistanceMaxZoomFactor = 4, cameraDistanceMax = 50 })
    combat, inGroup, partySize, zoom, timers, animations, clock = {}, false, 0, 25, {}, {}, 100
    local ns = {}
    for _, file in ipairs({ "Timer.lua", "Compat.lua", "Contexts.lua", "Database.lua", "CameraStateController.lua", "Functions.lua" }) do
        assert(loadfile(file))("Max_Camera_Distance", ns)
    end
    local f, db = ns.Functions, ns.Database:GetDefaultProfile()
    local controller = ns.CameraStateController
    ns.Database.db = { profile = db }
    db.autoCombatZoom, db.autoMountZoom = true, false
    db.combatZoomOnPlayer, db.combatZoomOnGroup, db.combatZoomOnThreat = true, true, false
    db.minZoomFactor, db.maxZoomFactor = 25, 25
    db.adaptiveCombatReturn = false
    db.zoomRestoreSetting = "never"
    for key, value in pairs(db) do
        if type(key) == "string" and key:match("CombatZoomFactor$") then db[key] = 35 end
        if type(key) == "string" and key:match("CombatReturnDelay$") then db[key] = 3 end
        if type(key) == "string" and key:match("Preset$") and type(value) == "string" then db[key] = "manual" end
    end
    local label = case[1] .. ": "
    -- Real events go through RequestUpdate(), which drops the short signal cache.
    local function Pass(event)
        f:InvalidateRuntimeCaches()
        f:UpdateSmartZoomState(event)
    end

    f:AdjustCamera(true); RunDueTimers()

    -- 1) Premature return: one routine pass 0.11 s after leaving combat used to
    --    apply the normal distance immediately and drop the 3 s delay.
    combat.player = true
    Pass("probe_enter")
    assert(controller:GetState() == "combat", label .. "did not enter combat: " .. tostring(controller:GetState()) .. " " .. tostring(f:GetStatusSnapshot().state))
    combat.player = false
    Pass("probe_leave")
    local snapshot = f:GetStatusSnapshot()
    assert(snapshot.pendingReturnActive and math.abs(snapshot.pendingReturnRemaining - 3) < 0.01,
        label .. "return delay not scheduled")
    local before = #animations
    clock = clock + 0.11
    Pass("auto_update")
    RunDueTimers()
    assert(#animations == before and f:GetStatusSnapshot().pendingReturnActive,
        label .. "routine re-evaluation cut the return delay short")
    clock = clock + 2.9
    RunDueTimers()
    assert(#animations == before + 1 and animations[#animations] == 25,
        label .. "return did not fire once at the deadline")

    -- A new pull inside the delay cancels it; the stale callback never animates.
    combat.player = true; Pass("probe_enter")
    combat.player = false; Pass("probe_leave")
    clock = clock + 1
    combat.player = true; Pass("probe_repull")
    before = #animations
    clock = clock + 5
    RunDueTimers()
    assert(controller:GetState() == "combat" and #animations == before,
        label .. "stale return timer changed the new pull's camera")
    combat.player = false; Pass("probe_leave")
    clock = clock + 5; RunDueTimers()

    -- 2) Group combat without personal aggro or roster change.
    inGroup, partySize = true, 4
    f:AdjustCamera(true); RunDueTimers(); RunFrames()
    assert(controller:GetState() == "normal", label .. "group setup not normal")
    combat.party1 = true
    assert(f:OnGroupUnitFlags("party1") == true, label .. "member combat change not detected") -- UNIT_FLAGS
    assert(f:OnGroupUnitFlags("party1") == false, label .. "unchanged member flags re-scanned the group")
    RunFrames()
    assert(controller:GetState() == "combat",
        label .. "applied state stayed normal while a party member fought")
    combat.party1 = false
    clock = clock + 0.6
    RunDueTimers() -- bounded fallback poll, no UNIT_FLAGS this time
    RunFrames()
    assert(f:GetStatusSnapshot().pendingReturnActive or controller:GetState() == "normal",
        label .. "member leaving combat was not noticed by the fallback poll")
    clock = clock + 5; RunDueTimers(); RunFrames()
    assert(controller:GetState() == "normal", label .. "camera stuck in combat after the group left combat")

    inGroup, partySize = false, 0
    clock = clock + 1; RunDueTimers()
    assert(not f._groupWatch.running, label .. "group poll kept running solo")

    -- 3) Shoulder: all 8 combinations of (in, out, combat). On Forever the
    --    shoulder camera belongs to the Gamepad UI and must stay off without it.
    local gamePadActive = false
    ns.GamePad = {
        IsSupported = function() return true end,
        IsActive = function() return gamePadActive end,
    }
    if case[1] == "Forever" then
        db.actionCamShoulderInCombat, db.actionCamShoulderOutOfCombat = true, true
        assert(f:ShouldEnableShoulderNow() == false, label .. "shoulder active without Gamepad UI")
    end
    gamePadActive = true
    for _, inFlag in ipairs({ false, true }) do
        for _, outFlag in ipairs({ false, true }) do
            for _, fighting in ipairs({ false, true }) do
                db.actionCamShoulderInCombat, db.actionCamShoulderOutOfCombat = inFlag, outFlag
                combat.player = fighting
                f:InvalidateRuntimeCaches()
                local expected = fighting and inFlag or (not fighting and outFlag)
                assert(f:ShouldEnableShoulderNow() == expected,
                    label .. string.format("shoulder in=%s out=%s combat=%s", tostring(inFlag), tostring(outFlag), tostring(fighting)))
            end
        end
    end

    -- 4) Toggle edits the context that is actually applied (group-only combat).
    combat.player = false
    inGroup, partySize, combat.party1 = true, 4, true
    db.actionCamShoulderInCombat, db.actionCamShoulderOutOfCombat = true, false
    f:InvalidateRuntimeCaches()
    assert(f:ShouldEnableShoulderNow() == true, label .. "group combat did not enable the in-combat shoulder")
    f:ToggleActionCamShoulderForCurrentContext()
    assert(db.actionCamShoulderInCombat == false and db.actionCamShoulderOutOfCombat == false,
        label .. "toggle edited the out-of-combat checkbox during group combat")
    f:InvalidateRuntimeCaches()
    assert(f:ShouldEnableShoulderNow() == false, label .. "toggle left the shoulder active")
    combat.party1, inGroup, partySize = false, false, 0
end

print("probe_combat_transitions: PASS (group combat watch, return deadline, stale timer, shoulder matrix, shoulder toggle)")
