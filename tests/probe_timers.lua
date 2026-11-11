-- Own timer adapters must retain delays/cancellation without creating globals.
local stub = dofile("tests/wow_stub.lua")
_G.CreateFrame = stub.CreateFrame
local errors = 0
_G.geterrorhandler = function() return function() errors = errors + 1 end end
for _, mode in ipairs({ "native", "after_only", "fallback" }) do
    local nativeQueue, nativeClock = {}, 0
    local function after(delay, callback)
        local token = { due = nativeClock + delay, callback = callback }
        function token:Cancel() self.cancelled = true end
        nativeQueue[#nativeQueue + 1] = token
        return token
    end
    _G.C_Timer = mode ~= "fallback" and { After = after } or nil
    if mode == "native" then C_Timer.NewTimer = after end
    local original = C_Timer
    local ns = {}; assert(loadfile("Timer.lua"))("Max_Camera_Distance", ns)
    local frame, timer = stub.frames[#stub.frames], ns.Timer
    local function tick(dt)
        if mode == "fallback" then
            if frame:IsShown() then frame:GetScript("OnUpdate")(frame, dt) end
        else
            nativeClock = nativeClock + dt
            local queue = nativeQueue; nativeQueue = {}
            for _, entry in ipairs(queue) do
                if not entry.cancelled then
                    if entry.due <= nativeClock then entry.callback()
                    else nativeQueue[#nativeQueue + 1] = entry end
                end
            end
        end
    end
    local calls = 0
    timer.After(1, function() calls = calls + 1 end)
    tick(0.5); assert(calls == 0, "timer fired before its delay")
    tick(0.5); assert(calls == 1, "timer did not fire at the deadline")
    tick(2); assert(calls == 1, "one-shot timer fired again")
    local token = timer.NewTimer(0, function() calls = calls + 100 end)
    timer.CancelTimer(token); tick(1); assert(calls == 1, "cancelled timer ran")
    timer.After(0, function()
        calls = calls + 1
        timer.After(0, function() calls = calls + 1 end)
    end)
    tick(0); assert(calls == 2, "nested zero-delay callback ran in the same pass")
    tick(0); assert(calls == 3, "nested callback was lost")
    timer.After(0, function() error("intentional timer failure") end)
    timer.After(0, function() calls = calls + 1 end)
    tick(0); assert(calls == 4, "failed callback stopped another timer")
    assert(_G.C_Timer == original, "adapter modified the native timer namespace")
    if mode == "fallback" then assert(not frame:IsShown(), "empty scheduler kept polling") end
end
assert(errors == 3, "timer failures were not reported exactly once")
print("probe_timers: PASS (native, After-only, no C_Timer, deadlines, cancellation, reentrancy, errors, sleeping)")
