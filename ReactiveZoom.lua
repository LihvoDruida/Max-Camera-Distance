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
local GetTime = GetTime
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

-- =====================================================================
-- Frame timing
-- =====================================================================
-- A rolling estimate of how long one frame takes. If the requested zoom would
-- finish inside a single frame there is nothing to ease, so we hand the notch
-- straight to Blizzard instead of paying for a LibCamera OnUpdate.
local secondsPerFrame = 1 / 60
local frameTimeAccum, frameTimeCount = 0, 0

local function TrackFrameTime(elapsed)
    if not elapsed or elapsed <= 0 then return end
    frameTimeAccum = frameTimeAccum + elapsed
    frameTimeCount = frameTimeCount + 1
    if frameTimeCount >= 30 then
        secondsPerFrame = frameTimeAccum / frameTimeCount
        frameTimeAccum, frameTimeCount = 0, 0
    end
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

-- Blizzard emits a zero-increment call after each wheel notch; forwarding it
-- would reset the easing for no reason.
local function PassThrough(zoomIn, increments)
    if zoomIn then
        if OriginalCameraZoomIn then OriginalCameraZoomIn(increments) end
    else
        if OriginalCameraZoomOut then OriginalCameraZoomOut(increments) end
    end
end

local function HandleWheel(zoomIn, increments)
    local db = DB()
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

    local ok = pcall(LibCamera.SetZoom, LibCamera, reactiveZoomTarget, zoomTime)
    if not ok then
        reactiveZoomTarget = nil
        PassThrough(zoomIn, increments)
    end
end

-- =====================================================================
-- Correction watchdog
-- =====================================================================
-- If anything moves the camera behind our back (a view change, an addon, the
-- cap shrinking under us), the stored target goes stale. While no easing is in
-- progress, keep it pinned to reality.
local watchdog = CreateFrame("Frame")
watchdog:Hide()
watchdog:SetScript("OnUpdate", function(_, elapsed)
    TrackFrameTime(elapsed)

    if reactiveZoomTarget == nil then return end
    if LibCamera and LibCamera.IsZooming and LibCamera:IsZooming() then return end

    local currentZoom = GetCameraZoom and GetCameraZoom()
    if type(currentZoom) == "number" and reactiveZoomTarget ~= currentZoom then
        reactiveZoomTarget = currentZoom
    end
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
    watchdog:Show()
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
        secondsPerFrame = secondsPerFrame,
        libCamera = LibCamera ~= nil,
    }
end
