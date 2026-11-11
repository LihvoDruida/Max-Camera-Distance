-- AFK camera ownership, restoration and settings migration across camera models.
local stub = dofile("tests/wow_stub.lua")
_G.CreateFrame = stub.CreateFrame
_G.UIParent = CreateFrame()
_G.WOW_PROJECT_MAINLINE = 1
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "Realm" end
_G.UnitClass = function() return "Druid", "DRUID" end
_G.GetTime = function() return 100 end
local afk, combat, mounted, zoom, brokenRead = false, false, false, 18, false
_G.UnitIsAFK = function() return afk end
_G.UnitAffectingCombat = function() return combat end
_G.IsMounted = function() return mounted end
_G.GetCameraZoom = function() if brokenRead then error("unavailable") end; return zoom end
local timers = {}
_G.C_Timer = { After = function(delay, fn) timers[#timers + 1] = fn end,
    NewTimer = function(delay, fn)
        local timer = { cancelled = false }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = function() if not timer.cancelled then fn() end end
        return timer
    end }
local function flush()
    local queue = timers; timers = {}
    for _, fn in ipairs(queue) do fn() end
end
local calls = {}
_G.LibStub = function(name)
    if name == "MaxCameraDistance-LibCamera-1.0" then return {
        StopZooming = function() end,
        SetZoomUsingCVar = function(_, target) calls[#calls + 1] = target; zoom = target end,
    } end
end
for _, case in ipairs({ { "Retail", "12.1.0", 120100, 1 },
    { "TBC", "2.5.6", 20506, 5 }, { "Forever", "1.60.1", 16001, 1 } }) do
    _G.WOW_PROJECT_ID = case[4]
    _G.GetBuildInfo = function() return case[2], "1", "2026", case[3] end
    local cvars = stub.InstallCVars({ cameraDistanceMaxZoomFactor = 4, cameraDistanceMax = 50 })
    local ns = {}
    for _, file in ipairs({ "Compat.lua", "Contexts.lua", "Database.lua", "CameraStateController.lua", "Functions.lua" }) do
        assert(loadfile(file))("Max_Camera_Distance", ns)
    end
    local db = ns.Database:GetDefaultProfile()
    ns.Database.db = { profile = db }
    local f = ns.Functions
    db.afkMode, db.afkHideUI, db.afkDelay = true, false, 0
    db.autoCombatZoom, db.autoMountZoom = false, false
    db.afkZoomDistance, db.maxZoomFactor = 4, 30
    db.afkSkipMounted, db.afkSkipFlying = false, false
    local function enter()
        afk = true; f:RefreshAfkMode(true)
        assert(f:IsAfkModeActive())
    end
    local function leave()
        afk = false; f:RefreshAfkMode(false); flush()
        assert(not f:IsAfkModeActive())
    end
    for _, smart in ipairs({ false, true }) do
        db.autoCombatZoom = smart
        db.minZoomFactor = 25
        db.zoomRestoreSetting = "never" -- AFK restoration is independent
        afk, combat, mounted, zoom = false, false, false, 18
        enter(); assert(zoom == 4, case[1] .. " close-up")
        local count = #calls
        f:UpdateSmartZoomState("queued_event"); flush()
        assert(zoom == 4 and #calls == count, "queued Smart Zoom overrode AFK")
        f:AdjustCamera(true); assert(zoom == 4, "settings refresh overrode AFK")
        db.afkZoomDistance = 7; f:RefreshAfkMode(true)
        assert(zoom == 7, "live slider change ignored")
        leave(); assert(zoom == 18, "entry zoom was not restored")
        f:AdjustCamera(false); flush()
        assert(zoom == 18, "later update overwrote restored zoom")
        db.afkZoomDistance = 4
    end
    db.autoCombatZoom = false
    zoom = 0; enter(); leave(); assert(zoom == 0, "first-person entry was lost")
    zoom = 16; enter(); db.afkZoomOut = false; f:RefreshAfkMode(true)
    assert(zoom == 16, "disabling AFK zoom did not restore entry zoom")
    db.afkZoomOut = true; f:RefreshAfkMode(true); assert(zoom == 4)
    leave(); assert(zoom == 16, "AFK settings edit overwrote snapshot")
    db.afkZoomOut = false; zoom = 14; local count = #calls
    enter(); leave(); assert(zoom == 14 and #calls == count, "disabled AFK zoom moved camera")
    db.autoCombatZoom = true; f:AdjustCamera(true); zoom = 13; count = #calls
    enter(); leave(); assert(zoom == 13 and #calls == count, "disabled AFK zoom moved smart camera")
    db.afkZoomOut, db.autoCombatZoom = true, true
    zoom = 17; enter(); combat = true; f:InvalidateRuntimeCaches(); f:RefreshAfkMode(false)
    assert(not f:IsAfkModeActive() and zoom == db.worldCombatZoomFactor, "AFK restore overrode combat")
    combat, afk = false, false; f:RefreshAfkMode(false); flush()
    -- A delayed normal return must be cancelled on AFK entry.
    combat = true; f:AdjustCamera(true)
    combat = false; f:InvalidateRuntimeCaches(); f:UpdateSmartZoomState("combat_end")
    enter(); flush(); assert(zoom == 4, "delayed return overrode AFK")
    f:ManualExitAfkMode(); local restored = zoom
    f:RefreshAfkMode(true); assert(not f:IsAfkModeActive() and zoom == restored, "manual exit immediately reentered AFK")
    afk = false; f:RefreshAfkMode(false)
    brokenRead = true; enter(); brokenRead = false; leave() -- unavailable snapshot is optional
    local old = { afkZoomOut = false }
    ns.Database:ApplyMigrations(old)
    assert(old.afkZoomOut == false and old.afkZoomDistance == ns.Compat.MAX_CAMERA_YARDS, "legacy preference changed")
    for _, invalid in ipairs({ -3, 0/0, 10000 }) do
        old.afkZoomDistance = invalid; ns.Database:ApplyMigrations(old)
        assert(old.afkZoomDistance >= 1 and old.afkZoomDistance <= ns.Compat.MAX_CAMERA_YARDS)
    end
    assert(db.maxZoomFactor == 30, "AFK changed normal zoom setting")
end
print("probe_afk_zoom: PASS (manual/smart restore, first person, close-up, live edits, opt-out, combat, timers, migration)")
