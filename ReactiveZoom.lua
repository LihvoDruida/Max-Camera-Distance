local addonName, ns = ...
ns.ReactiveZoom = ns.ReactiveZoom or {}
local ReactiveZoom = ns.ReactiveZoom

-- =====================================================================
-- REACTIVE ZOOM
-- =====================================================================
-- Ported from DynamicCam (MIT, mpstark / LudiusMaximus), whose MouseZoom
-- module this follows closely. The algorithm is theirs; the profile plumbing,
-- flavour guards and cap handling are adapted to this addon.
--
-- Why this exists here: the addon's "zoom speed" slider writes the
-- cameraDistanceMoveSpeed CVar, which no longer exists in the 12.0.7 or 12.1
-- CVar tables (nor in the Classic ones). That slider has been a no-op. The
-- modern way to make the wheel feel fast is not a CVar at all: keep a target
-- zoom of your own, grow the step while the wheel is still spinning, and ease
-- the camera towards it with LibCamera.
--
-- The core idea: WoW routes every mouse wheel notch through the global
-- CameraZoomIn / CameraZoomOut with increments == 1. By replacing those globals
-- we can accumulate a target instead of stepping one notch at a time, so a fast
-- spin covers far more distance than the same number of slow notches.

local LibStub = _G.LibStub
local LibCamera = LibStub and LibStub("LibCamera-1.0", true)

local Compat = ns.Compat or {}
local CONVERSION_RATIO = Compat.CONVERSION_RATIO or 15

local math_abs, math_min, math_max = math.abs, math.min, math.max
local GetFramerate = GetFramerate
local GetCameraZoom = GetCameraZoom

local function DB()
    return (ns.Database and ns.Database.db and ns.Database.db.profile) or nil
end

local function GetCVarNumber(name)
    if ns.Compat and ns.Compat.SafeGetCVar then
        return tonumber(ns.Compat.SafeGetCVar(name))
    end
    local ok, value = pcall(GetCVar, name)
    return ok and tonumber(value) or nil
end

-- Originals, captured once. Never call the global from inside the replacement
-- or the hook recurses.
local OriginalCameraZoomIn = _G.CameraZoomIn
local OriginalCameraZoomOut = _G.CameraZoomOut

local installed = false
local reactiveZoomTarget = nil

-- Forward declaration: HandleWheel below wakes this frame, and it is
-- created further down. Without this the reference would compile to a
-- global lookup and error the first time the wheel is turned.
local watchdog

local passthroughPending = false
local passthroughActive = false
local passthroughStartZoom = nil
local lastWatchedZoom = nil

-- =====================================================================
-- Frame timing
-- =====================================================================
-- A rolling estimate of how long one frame takes. If the requested zoom would
-- finish inside a single frame there is nothing to ease, so we hand the notch
-- straight to Blizzard instead of paying for a LibCamera OnUpdate.
local secondsPerFrame = 1 / 60

local function RefreshFrameTimeEstimate()
    if type(GetFramerate) ~= "function" then return end
    local ok, fps = pcall(GetFramerate)
    fps = ok and tonumber(fps) or nil
    if not fps or fps <= 0 then return end

    -- Ignore pathological telemetry spikes while preserving genuinely low FPS;
    -- this value is only used to decide whether a sub-frame easing is pointless.
    fps = math_min(360, math_max(10, fps))
    secondsPerFrame = 1 / fps
end

-- =====================================================================
-- Settings
-- =====================================================================
local DEFAULTS = {
    reactiveZoomAddIncrementsAlways = 1,
    reactiveZoomAddIncrements = 2.5,
    reactiveZoomIncAddDifference = 1.2,
    reactiveZoomMaxZoomTime = 0.25,
}

-- =====================================================================
-- Easing
-- =====================================================================
-- LibCamera falls back to easeInOutQuad, which ramps up slowly at the start.
-- On a mouse wheel that reads as input lag: you turn the wheel and the camera
-- takes a moment to get going. OutQuad leaves immediately and decelerates into
-- the target, which is why DynamicCam defaults its reactive zoom to it.
--
-- Signature matches LibCamera/LibEasing: (time, begin, change, duration).
local EASING = {}

EASING.OutQuad = function(t, b, c, d)
    t = t / d
    return -c * t * (t - 2) + b
end

EASING.InOutQuad = function(t, b, c, d)
    t = t / (d / 2)
    if t < 1 then
        return c / 2 * t * t + b
    end
    t = t - 1
    return -c / 2 * (t * (t - 2) - 1) + b
end

EASING.Linear = function(t, b, c, d)
    return c * t / d + b
end

EASING.OutCubic = function(t, b, c, d)
    t = t / d - 1
    return c * (t * t * t + 1) + b
end

ReactiveZoom.EASING_ORDER = { "OutQuad", "OutCubic", "InOutQuad", "Linear" }

local function ResolveEasing(db)
    local name = db and db.reactiveZoomEasing
    return EASING[name] or EASING.OutQuad
end

local function Setting(db, key)
    local value = db and tonumber(db[key])
    if value == nil then return DEFAULTS[key] end
    return value
end

function ReactiveZoom:IsEnabled()
    local db = DB()
    if not db or db.reactiveZoom ~= true then return false end
    return LibCamera ~= nil and type(GetCameraZoom) == "function"
end

-- =====================================================================
-- Target bookkeeping
-- =====================================================================
-- The target must be dropped whenever something other than the wheel moves the
-- camera - a situation change, SetView, or this addon applying a new cap.
-- Otherwise the next notch would ease back to a target that is no longer where
-- the player is looking.
function ReactiveZoom:ResetTarget()
    reactiveZoomTarget = nil
    passthroughPending, passthroughActive = false, false
    passthroughStartZoom, lastWatchedZoom = nil, nil
    if watchdog then watchdog:Hide() end
end

-- The furthest the camera can currently go, in the same units GetCameraZoom
-- reports. This addon rewrites cameraDistanceMaxZoomFactor per activity, so the
-- ceiling moves at runtime and cannot be cached.
local function CurrentMaxZoom()
    local factor = GetCVarNumber("cameraDistanceMaxZoomFactor")
    if not factor then
        return Compat.MAX_CAMERA_YARDS or 39
    end
    return factor * CONVERSION_RATIO
end

-- =====================================================================
-- Passthrough tracking
-- =====================================================================
-- When we hand a notch back to Blizzard, the client animates it over SEVERAL
-- frames. During those frames LibCamera reports "not zooming", so a naive
-- watchdog would see target ~= currentZoom and helpfully "correct" the target
-- to wherever the camera happens to be mid-flight - wiping out the very
-- accumulation this feature exists for. The state machine below marks that
-- window so the watchdog stays out of it.
--
-- Detection is indirect because the client offers no "zoom finished" signal:
-- the zoom has STARTED once the camera leaves the value it had when we handed
-- the notch over, and has FINISHED once the camera stops changing between
-- frames.
local function PassThrough(zoomIn, increments)
    passthroughPending = true
    passthroughActive = false
    passthroughStartZoom = GetCameraZoom and GetCameraZoom() or nil
    if watchdog then watchdog:Show() end

    if zoomIn then
        if OriginalCameraZoomIn then OriginalCameraZoomIn(increments) end
    else
        if OriginalCameraZoomOut then OriginalCameraZoomOut(increments) end
    end
end

local function HandleWheel(zoomIn, increments)
    local db = DB()
    RefreshFrameTimeEstimate()
    local currentZoom = GetCameraZoom()
    if type(currentZoom) ~= "number" then
        PassThrough(zoomIn, increments)
        return
    end

    local addAlways = Setting(db, "reactiveZoomAddIncrementsAlways")
    local addExtra = Setting(db, "reactiveZoomAddIncrements")
    local addThreshold = Setting(db, "reactiveZoomIncAddDifference")
    local maxZoomTime = Setting(db, "reactiveZoomMaxZoomTime")

    increments = increments + addAlways

    -- The heart of it: if the camera has not caught up with the target yet, the
    -- player is still spinning the wheel, so make this notch bigger. That is
    -- what turns a fast spin into a long travel instead of many small ones.
    if reactiveZoomTarget and math_abs(reactiveZoomTarget - currentZoom) > addThreshold then
        increments = increments + addExtra
    end

    -- Reversing direction invalidates the accumulated target.
    if reactiveZoomTarget then
        if zoomIn and reactiveZoomTarget > currentZoom then
            reactiveZoomTarget = nil
        elseif not zoomIn and reactiveZoomTarget < currentZoom then
            reactiveZoomTarget = nil
        end
    end

    reactiveZoomTarget = reactiveZoomTarget or currentZoom
    watchdog:Show()

    local maxZoom = CurrentMaxZoom()

    if zoomIn then
        if reactiveZoomTarget - increments < 0 then
            -- Stepping into first person. Hand Blizzard the real remaining
            -- distance, otherwise a short raw increment stops just shy of 0.
            if reactiveZoomTarget > 0 then
                increments = currentZoom
            end
            reactiveZoomTarget = 0
        else
            reactiveZoomTarget = reactiveZoomTarget - increments
        end
    else
        if currentZoom == 0 then
            -- Leaving first person: go to the closest third person view without
            -- easing, which is what the unmodified client does.
            reactiveZoomTarget = nil
            PassThrough(false, 0.05)
            return
        end
        reactiveZoomTarget = math_min(maxZoom, reactiveZoomTarget + increments)
    end

    -- Already pinned at either end; nothing to do.
    if (reactiveZoomTarget >= maxZoom and currentZoom >= maxZoom)
        or (reactiveZoomTarget == 0 and currentZoom == 0) then
        return
    end

    local zoomSpeed = GetCVarNumber("cameraZoomSpeed") or 20
    if zoomSpeed <= 0 then zoomSpeed = 20 end

    local distance = math_abs(reactiveZoomTarget - currentZoom)
    local zoomTime = math_min(maxZoomTime, distance / zoomSpeed)

    if zoomTime < secondsPerFrame then
        -- Too short to ease; a single Blizzard step is smoother than one frame
        -- of interpolation.
        PassThrough(zoomIn, increments)
        return
    end

    local ok = pcall(LibCamera.SetZoom, LibCamera, reactiveZoomTarget, zoomTime, ResolveEasing(db))
    if not ok then
        reactiveZoomTarget = nil
        PassThrough(zoomIn, increments)
    end
end

-- =====================================================================
-- Correction watchdog
-- =====================================================================
-- If anything moves the camera behind our back (a view change, an addon, the
-- cap shrinking under us), the stored target can go stale. Keep the watchdog
-- alive only while a wheel/lib-camera movement is actually in flight.
watchdog = CreateFrame("Frame")
watchdog:Hide()
watchdog:SetScript("OnUpdate", function()
    -- This frame exists only while a wheel/lib-camera movement is in flight.
    -- Idling with Reactive Zoom enabled must cost zero per-frame work.
    if reactiveZoomTarget == nil and not passthroughPending and not passthroughActive then
        watchdog:Hide()
        return
    end

    local currentZoom = GetCameraZoom and GetCameraZoom()
    if type(currentZoom) ~= "number" then
        ReactiveZoom:ResetTarget()
        return
    end

    if passthroughPending and passthroughStartZoom ~= currentZoom then
        passthroughPending = false
        passthroughActive = true
    elseif passthroughActive and lastWatchedZoom == currentZoom then
        passthroughActive = false
    end

    lastWatchedZoom = currentZoom

    if passthroughPending or passthroughActive then return end
    if LibCamera and LibCamera.IsZooming and LibCamera:IsZooming() then return end

    -- No animation owns the camera anymore. A future wheel notch starts from the
    -- real camera position, so keeping an idle target/watchdog buys nothing.
    reactiveZoomTarget = nil
    lastWatchedZoom = nil
    watchdog:Hide()
end)

-- =====================================================================
-- Install / uninstall
-- =====================================================================
-- The globals are replaced rather than hooksecurefunc'd because the point is to
-- SUPPRESS Blizzard's own stepping and substitute our own. hooksecurefunc would
-- run ours in addition to theirs and the camera would move twice.
function ReactiveZoom:Install()
    if installed then return end
    if type(OriginalCameraZoomIn) ~= "function" or type(OriginalCameraZoomOut) ~= "function" then
        return
    end

    _G.CameraZoomIn = function(increments, ...)
        increments = tonumber(increments) or 0
        if increments == 0 then return end

        if not ReactiveZoom:IsEnabled() or increments ~= 1 then
            -- increments ~= 1 means this came from LibCamera or another addon,
            -- not from a wheel notch. Never re-enter the reactive path there.
            return OriginalCameraZoomIn(increments, ...)
        end

        HandleWheel(true, increments)
    end

    _G.CameraZoomOut = function(increments, ...)
        increments = tonumber(increments) or 0
        if increments == 0 then return end

        if not ReactiveZoom:IsEnabled() or increments ~= 1 then
            return OriginalCameraZoomOut(increments, ...)
        end

        HandleWheel(false, increments)
    end

    installed = true
end

function ReactiveZoom:Refresh()
    self:ResetTarget()
    if self:IsEnabled() then
        self:Install()
    end
end

function ReactiveZoom:GetStatus()
    return {
        enabled = self:IsEnabled(),
        installed = installed,
        target = reactiveZoomTarget,
        currentZoom = GetCameraZoom and GetCameraZoom() or nil,
        maxZoom = CurrentMaxZoom(),
        secondsPerFrame = secondsPerFrame,
        easing = (DB() and DB().reactiveZoomEasing) or "OutQuad",
        passthrough = passthroughPending or passthroughActive,
        libCamera = LibCamera ~= nil,
    }
end
