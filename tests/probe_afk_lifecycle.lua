-- Lifecycle regressions: event bursts, one restore animation, camera history,
-- cap ownership, profile/activity changes and hidden-UI ownership.
local stub = dofile("tests/wow_stub.lua")
_G.CreateFrame = stub.CreateFrame
_G.UIParent = CreateFrame()
_G.WOW_PROJECT_MAINLINE = 1
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "Realm" end
_G.UnitClass = function() return "Druid", "DRUID" end
_G.GetTime = function() return 100 end
local afk, mounted, combat, zoom, instanceType = false, false, false, 18, nil
_G.UnitIsAFK = function() return afk end
_G.IsMounted = function() return mounted end
_G.UnitAffectingCombat = function() return combat end
_G.GetCameraZoom = function() return zoom end
_G.IsInInstance = function() return instanceType ~= nil, instanceType end
_G.GetInstanceInfo = function() return "Test", instanceType, 0 end
local timers, calls, stops = {}, {}, 0
_G.C_Timer = {
    After = function(_, callback) timers[#timers + 1] = callback end,
    NewTimer = function(_, callback)
        local timer = { cancelled = false }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = function() if not timer.cancelled then callback() end end
        return timer
    end,
}
local function flush()
    local queue = timers; timers = {}
    for _, callback in ipairs(queue) do callback() end
end
_G.LibStub = function(name)
    if name == "MaxCameraDistance-LibCamera-1.0" then return {
        StopZooming = function() stops = stops + 1 end,
        SetZoomUsingCVar = function(_, target) calls[#calls + 1] = target; zoom = target end,
    } end
end
for _, case in ipairs({ { "Retail", "12.1.0", 120100, 1 },
    { "PTR", "12.1.7", 120107, 1 }, { "Era", "1.15.9", 11509, 2 },
    { "TBC", "2.5.6", 20506, 5 }, { "Wrath", "3.4.5", 30405, 11 },
    { "Titan", "3.80.2", 38002, 11 }, { "Cata", "4.4.2", 40402, 14 },
    { "Mists", "5.5.4", 50504, 19 }, { "Forever", "1.60.1", 16001, 1 } }) do
    afk, mounted, combat, zoom, timers, calls, instanceType = false, false, false, 18, {}, {}, nil
    _G.WOW_PROJECT_ID = case[4]
    _G.GetBuildInfo = function() return case[2], "1", "2026", case[3] end
    local cvars = stub.InstallCVars({ cameraDistanceMaxZoomFactor = 4, cameraDistanceMax = 50 })
    local ns = {}
    for _, file in ipairs({ "Compat.lua", "Contexts.lua", "Database.lua", "CameraStateController.lua", "Functions.lua" }) do
        assert(loadfile(file))("Max_Camera_Distance", ns)
    end
    local f, db = ns.Functions, ns.Database:GetDefaultProfile()
    ns.Database.db = { profile = db }
    db.afkMode, db.afkHideUI, db.afkDelay = true, false, 0
    db.afkSkipMounted, db.afkSkipFlying = false, false
    db.afkZoomDistance, db.maxZoomFactor, db.minZoomFactor = 4, 30, 25
    db.autoCombatZoom, db.autoMountZoom, db.zoomRestoreSetting = true, false, "always"
    local function enter()
        afk = true; f:RefreshAfkMode(false); assert(f:IsAfkModeActive())
    end
    local function leave()
        afk = false; f:RefreshAfkMode(false); assert(not f:IsAfkModeActive())
    end

    -- Flag/model/aura bursts should share one AFK countdown, not postpone it.
    db.afkDelay = 3; afk = true
    f:RefreshAfkMode(false)
    local pending = #timers
    for i = 1, 6 do f:RefreshAfkMode(false) end
    assert(#timers == pending and not f:IsAfkModeActive(), "AFK countdown restarted by an event burst")
    afk = false; f:RefreshAfkMode(false); flush()
    assert(not f:IsAfkModeActive(), "cancelled countdown entered AFK")
    afk = true; f:RefreshAfkMode(false)
    db.afkDelay = 5; f:RefreshAfkMode(true)
    flush(); assert(f:IsAfkModeActive(), "edited countdown failed to enter")
    leave(); flush(); db.afkDelay = 0

    f:AdjustCamera(true); flush(); zoom = 18
    enter()
    local count, stopped = #calls, stops
    for i = 1, 4 do f:AdjustCamera(true); f:RefreshAfkMode(true) end
    assert(#calls == count and stops == stopped, "unchanged AFK settings restarted the camera")
    leave()
    assert(#calls == count + 1 and zoom == 18, "AFK exit did not use exactly one restore animation")
    count = #calls
    f:UpdateSmartZoomState("queued_event_before_cap")
    assert(#calls == count and zoom == 18, "queued event replaced an unfinished restore")
    flush()
    assert(cvars:Number("cameraDistanceMax") == 25, "saved zoom incorrectly reduced the allowed wheel range")
    f:UpdateSmartZoomState("queued_event_after_cap")
    assert(#calls == count and zoom == 18, "restored zoom was reapplied at the preset distance")

    -- Manual camera restores must also animate once and restore the normal cap.
    db.autoCombatZoom = false; db.afkZoomDistance = 32
    f:AdjustCamera(true); zoom = 18; enter(); count = #calls
    leave()
    assert(#calls == count + 1 and zoom == 18, "manual restore started multiple camera transitions")
    count = #calls
    local capBefore = cvars:Number("cameraDistanceMax")
    f:AdjustCamera(true)
    assert(#calls == count and cvars:Number("cameraDistanceMax") == capBefore,
        "queued manual refresh lowered the cap before the restore finished")
    flush(); assert(cvars:Number("cameraDistanceMax") == 30, "manual camera cap was not restored")
    db.afkZoomDistance, db.autoCombatZoom = 4, true

    f:AdjustCamera(true); flush(); zoom = 0; enter(); count = #calls; leave(); flush()
    assert(#calls == count + 1 and zoom == 0 and cvars:Number("cameraDistanceMax") == 25,
        "smart first-person restore changed zoom or wheel range")

    -- A changed normal distance or profile supersedes a stale AFK snapshot.
    f:AdjustCamera(true); flush(); zoom = 18; enter()
    db.minZoomFactor = 20; count = #calls; leave()
    assert(#calls == count + 1 and zoom == 20, "normal distance edit was overwritten by the entry snapshot")
    flush(); zoom = 16; enter()
    local replacement = ns.Database:GetDefaultProfile()
    replacement.autoCombatZoom, replacement.autoMountZoom, replacement.minZoomFactor = true, false, 22
    replacement.afkMode = false
    ns.Database.db.profile = replacement; count = #calls
    leave(); assert(#calls == count + 1 and zoom == 22, "profile change revived the old zoom")
    flush(); ns.Database.db.profile = db; db.minZoomFactor = 25

    f:AdjustCamera(true); flush(); zoom = 18; enter(); instanceType = "party"; count = #calls
    leave(); assert(#calls == count + 1 and zoom == 25, "activity change revived the old normal zoom")
    flush(); instanceType = nil; f:InvalidateRuntimeCaches()

    -- Mounting while AFK must not record the AFK close-up as the normal zoom.
    db.autoMountZoom, db.afkSkipMounted, db.mountZoomFactor = true, true, 30
    f:AdjustCamera(true); flush(); zoom = 18; enter()
    mounted = true; f:RefreshAfkMode(false)
    assert(not f:IsAfkModeActive() and zoom == 30, "mount camera did not take over")
    afk = false; f:RefreshAfkMode(false)
    mounted = false; f:InvalidateRuntimeCaches(); f:UpdateSmartZoomState("dismount")
    flush(); flush()
    assert(zoom == 18, "AFK distance polluted normal-state zoom history")
    db.autoMountZoom, db.afkSkipMounted = false, false

    -- Show only UI that this AFK session actually hid.
    db.afkHideUI = true; UIParent:Hide(); enter(); f:RefreshAfkMode(true); leave(); flush()
    assert(not UIParent:IsShown(), "AFK exit showed UI that was already hidden")
    UIParent:Show(); enter(); f:RefreshAfkMode(true)
    assert(not UIParent:IsShown(), "AFK failed to hide visible UI")
    local overlay
    for _, frame in ipairs(stub.frames) do if frame:GetScript("OnKeyDown") then overlay = frame end end
    assert(overlay, "safe exit handler missing")
    local propagated
    overlay.SetPropagateKeyboardInput = function(_, value) propagated = value end
    overlay:GetScript("OnKeyDown")(overlay, "W")
    assert(propagated == true, "AFK overlay swallowed a movement key")
    overlay:GetScript("OnKeyDown")(overlay, "ESCAPE")
    assert(propagated == false and not f:IsAfkModeActive() and UIParent:IsShown(), "Escape failed to exit AFK safely")
    afk = false; f:RefreshAfkMode(false); flush()
    -- Combat interrupts AFK immediately; the resume preference controls reentry.
    db.afkHideUI, db.afkResumeAfterCombat = false, false
    enter(); combat = true; f:RefreshAfkMode(false)
    assert(not f:IsAfkModeActive(), "combat failed to interrupt AFK")
    combat = false; f:RefreshAfkMode(false); flush()
    assert(not f:IsAfkModeActive(), "resume-off automatically reentered AFK")
    afk = false; f:RefreshAfkMode(false); db.afkResumeAfterCombat = true
    enter(); combat = true; f:RefreshAfkMode(false)
    combat = false; f:RefreshAfkMode(false)
    assert(f:IsAfkModeActive(), "resume-on did not reenter AFK")
    leave(); flush()
    print(case[1] .. ": AFK lifecycle PASS")
end
print("probe_afk_lifecycle: PASS (9 clients, event bursts, single restore, caps, history, profiles, UI ownership, keyboard)")
