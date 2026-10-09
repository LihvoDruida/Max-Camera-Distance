-- Regression probe for LibCamera cameraZoomSpeed validation.
local writes = {}
local cvars = { cameraZoomSpeed = 20 }
local now = 100
local zoom = 10
local movement = 0

_G.C_CVar = {
    GetCVar = function(name) return tostring(cvars[name]) end,
    SetCVar = function(name, value)
        value = tonumber(value)
        writes[#writes + 1] = { name = name, value = value }
        if name == "cameraZoomSpeed" and (value < 0.002778 or value > 50) then
            error("cameraZoomSpeed out of range: " .. tostring(value))
        end
        cvars[name] = value
    end,
}
_G.GetCVar = function(name) return tostring(cvars[name]) end
_G.SetCVar = function(name, value) return C_CVar.SetCVar(name, value) end
_G.GetCameraZoom = function() return zoom end
_G.GetTime = function() return now end
_G.CameraZoomOut = function(amount) zoom = zoom + amount end
_G.CameraZoomIn = function(amount) zoom = zoom - amount end
_G.MoveViewOutStart = function(speed) movement = speed end
_G.MoveViewInStart = function(speed) movement = -speed end
_G.MoveViewInStop = function() movement = 0 end
_G.MoveViewOutStop = function() movement = 0 end
_G.MoveViewLeftStop = function() end
_G.MoveViewRightStop = function() end
_G.MoveViewUpStop = function() end
_G.MoveViewDownStop = function() end
_G.CreateFrame = function()
    local scripts = {}
    return {
        SetScript = function(_, name, fn) scripts[name] = fn end,
        GetScript = function(_, name) return scripts[name] end,
    }
end

local libs = { ["LibCamera-1.0"] = { external = true } }
_G.LibStub = {
    NewLibrary = function(_, major)
        libs[major] = libs[major] or {}
        return libs[major]
    end,
}

assert(loadfile("libs/LibCamera/LibCamera.lua"))()
local cam = libs["MaxCameraDistance-LibCamera-1.0"]
assert(cam, "LibCamera failed to load")
assert(libs["LibCamera-1.0"].external and not libs["LibCamera-1.0"].SetZoom, "private camera overwrites another addon library")

local callbacks = 0
cam:SetZoomUsingCVar(10, 0.5, function(cancelled)
    assert(cancelled == false, "no-op callback should complete, not cancel")
    callbacks = callbacks + 1
end)
assert(#writes == 0, "no-op zoom must not write cameraZoomSpeed")
assert(callbacks == 1, "no-op zoom should complete callback immediately")

-- Tiny non-zero transition used to generate a speed below the client's minimum.
zoom = 10
cam:SetZoomUsingCVar(10.001, 1000.0)
assert(#writes >= 1, "tiny non-zero zoom should write a temporary speed")
local last = writes[#writes]
assert(last.name == "cameraZoomSpeed", "unexpected CVar write")
assert(last.value >= 0.002778 and last.value <= 50, "temporary speed not clamped to live range")

cam:StopZooming()
_G.C_CVar.SetCVar = function() return false end
cam:SetZoomUsingCVar(20, 0.5)
assert(cam:IsZooming(), "a rejected zoom-speed write must fall back to basic easing")
for tick = 1, 120 do
    local elapsed = 1 / 60
    zoom = zoom + movement * cvars.cameraZoomSpeed * elapsed
    now = now + elapsed
    local update = cam.frame:GetScript("OnUpdate")
    if update then update(cam.frame, elapsed) end
end
assert(math.abs(zoom - 20) <= 0.05, "fallback easing does not reach the target")
assert(not cam:IsZooming(), "fallback easing never releases its update driver")
print("probe_libcamera: PASS (ranges, no-op, private instance, rejected-write fallback)")
