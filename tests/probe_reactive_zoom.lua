-- Standalone regression: native camera control must work on TBC 2.5.5/2.5.6.
local nativeCalls = {}
local zoom = 14
local lastTransition
local stopCount = 0
local simulatedCameraFailure = false
local clock = 100
local fpsSamples = 0
local profile = { reactiveZoom = false }
local frames = {}
local nativeIn = function(increments)
    table.insert(nativeCalls, { action = "in", amount = increments })
    zoom = zoom - (increments == nil and 1 or increments)
end
local nativeOut = function(increments)
    table.insert(nativeCalls, { action = "out", amount = increments })
    zoom = zoom + (increments == nil and 1 or increments)
end
_G.CameraZoomIn, _G.CameraZoomOut = nativeIn, nativeOut
_G.GetCameraZoom = function()
    if simulatedCameraFailure then error("camera unavailable") end
    return zoom
end
_G.GetTime = function() return clock end
_G.GetFramerate = function() fpsSamples = fpsSamples + 1; return 60 end
_G.GetCVar = function(name)
    if name == "cameraDistanceMaxZoomFactor" then return "4" end
    if name == "cameraZoomSpeed" then return "20" end
end
_G.CreateFrame = function()
    local frame = { visible = true }
    function frame:Hide() self.visible = false end
    function frame:Show() self.visible = true end
    function frame:SetScript(name, fn) self[name] = fn end
    frames[#frames+1] = frame
    return frame
end
local mockCamera = {
    IsZooming = function() return false end,
    SetZoom = function(_, target, duration)
        lastTransition = { target = target, duration = duration }
        zoom = target
    end,
    StopZooming = function() stopCount = stopCount + 1 end,
}
_G.LibStub = function(major)
    if major == "MaxCameraDistance-LibCamera-1.0" then return mockCamera end
end
local ns = {
    Database = { db = { profile = profile } },
    Compat = {
        CONVERSION_RATIO = 12.5,
        MAX_CAMERA_YARDS = 50,
        SafeGetCVar = function(name) return GetCVar(name) end,
    },
}
assert(loadfile("ReactiveZoom.lua"))("Max_Camera_Distance", ns)
local rz = ns.ReactiveZoom

rz:Refresh()
assert(CameraZoomIn == nativeIn and CameraZoomOut == nativeOut,
    "disabled profile must not replace native zoom API")
CameraZoomOut() -- native omitted argument
assert(zoom == 15 and nativeCalls[#nativeCalls].amount == nil,
    "default native camera argument must be preserved")

profile.reactiveZoom = true
rz:Refresh()
assert(CameraZoomIn ~= nativeIn and CameraZoomOut ~= nativeOut,
    "enabled profile did not install reactive zoom")
CameraZoomIn() -- omitted argument should count as 1, not 0!
assert(lastTransition and lastTransition.target == 13,
    "reactive zoom ignored optional default argument")
local lastNative = #nativeCalls
CameraZoomOut(5) -- other addon's explicit non-wheel movement must pass through
assert(#nativeCalls == lastNative + 1 and nativeCalls[#nativeCalls].amount == 5,
    "non-wheel movement lost its explicit step")
assert(zoom == 18, "native manual movement was not applied")

profile.reactiveZoom = false
rz:Refresh()
assert(CameraZoomIn == nativeIn and CameraZoomOut == nativeOut,
    "switching off must restore original functions")
assert(stopCount >= 1, "uninstall failed to stop outstanding camera animation")
CameraZoomIn()
assert(zoom == 17, "disabled camera should still support wheel zoom")

-- A camera addon loaded while our feature was off must not get overwritten
-- with the handlers that existed when our Lua file was first evaluated.
local otherIn = function(amount) zoom = zoom - (amount or 1) * 2 end
local otherOut = function(amount) zoom = zoom + (amount or 1) * 2 end
_G.CameraZoomIn, _G.CameraZoomOut = otherIn, otherOut
profile.reactiveZoom = true
rz:Refresh()
profile.reactiveZoom = false
rz:Refresh()
assert(CameraZoomIn == otherIn and CameraZoomOut == otherOut,
    "reactive uninstall clobbered another addon's camera handlers")

-- Regression: an unavailable modern/tainted zoom read must not eat wheel input.
profile.reactiveZoom = true
rz:Refresh()
local zoomBeforeError = zoom
simulatedCameraFailure = true
assert(pcall(CameraZoomIn), "reactive camera read failure escaped to UI")
assert(zoom == zoomBeforeError - 2,
    "camera API failure did not fall back to the preceding zoom handler")
assert(rz:GetStatus().currentZoom == nil,
    "status accessed a broken camera getter without protection")
-- Blizzard can ignore a native zoom at either end-stop. Pending passthrough
-- must stop polling instead of holding its OnUpdate frame for the whole login.
simulatedCameraFailure = false
local watchdog = frames[#frames]
assert(watchdog and watchdog.OnUpdate, "zoom watchdog missing")
assert(watchdog.visible, "native zoom fallback did not start watchdog")
watchdog.OnUpdate(watchdog, 2.05)
assert(not watchdog.visible and not rz:GetStatus().passthrough,
    "stalled native zoom left a permanent per-frame watchdog")

-- Querying frame rate for each rapid wheel notch wasted work under fast wheels.
clock = clock + 1
fpsSamples = 0
CameraZoomIn()
CameraZoomIn()
CameraZoomOut()
assert(fpsSamples == 1,
    "wheel burst queried frame-rate multiple times")
clock = clock + 0.4
CameraZoomIn()
assert(fpsSamples == 2,
    "frame-rate estimate was not refreshed after the sample interval")

-- A non-wheel zoom call during easing must invalidate the old target.
CameraZoomOut(4)
assert(rz:GetStatus().target == nil,
    "native third-party zoom did not clear the reactive target")
profile.reactiveZoom = false
rz:Refresh()
assert(CameraZoomIn == otherIn and CameraZoomOut == otherOut,
    "native handlers were not restored after final toggle")
print("probe_reactive_zoom: PASS (native, default step, safety fallback, watchdog timeout, FPS throttle, coexistence)")
