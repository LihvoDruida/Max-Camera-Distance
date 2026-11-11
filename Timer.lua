-- Addon-owned timer facade: native C_Timer when available, a sleeping frame
-- scheduler otherwise. Does not replace or add any global C_Timer functions.
local _, ns = ...
local Timer = {}
ns.Timer = Timer
local native = _G.C_Timer
local queue, snapshot, clock = {}, {}, 0
local frame = CreateFrame("Frame")
frame:Hide()

local function Run(callback)
    local ok, err = pcall(callback)
    if not ok then
        local handler = type(geterrorhandler) == "function" and geterrorhandler()
        if type(handler) == "function" then pcall(handler, err) end
    end
end

local function Delay(value)
    value = tonumber(value)
    if not value or value ~= value then return 0 end
    return math.max(0, math.min(value, 86400))
end

local function NewToken(callback)
    assert(type(callback) == "function", "timer callback must be a function")
    local token = { callback = callback, cancelled = false }
    function token:Cancel()
        self.cancelled = true
        self.callback = nil
        queue[self] = nil
        if self.native and type(self.native.Cancel) == "function" then self.native:Cancel() end
        if next(queue) == nil then frame:Hide() end
    end
    function token:IsCancelled() return self.cancelled end
    return token
end

function Timer.NewTimer(delay, callback)
    local token = NewToken(callback)
    local function Fire()
        if token.cancelled then return end
        local fn = token.callback
        token.callback, token.cancelled = nil, true
        if fn then Run(fn) end
    end
    delay = Delay(delay)
    if native and type(native.NewTimer) == "function" then
        token.native = native.NewTimer(delay, Fire)
    elseif native and type(native.After) == "function" then
        native.After(delay, Fire)
    else
        token.due, token.fire = clock + delay, Fire
        queue[token] = true
        frame:Show()
    end
    return token
end

function Timer.After(delay, callback) Timer.NewTimer(delay, callback) end
function Timer.CancelTimer(token)
    if token and type(token.Cancel) == "function" then token:Cancel() end
end

frame:SetScript("OnUpdate", function(_, elapsed)
    clock = clock + math.max(0, tonumber(elapsed) or 0)
    -- Snapshot only due timers: callbacks may cancel or create other timers.
    -- A zero-delay callback created during this pass runs on the next frame.
    for token in pairs(queue) do
        if token.due <= clock then snapshot[#snapshot + 1] = token end
    end
    for i = 1, #snapshot do
        local token = snapshot[i]
        snapshot[i] = nil
        if queue[token] then queue[token] = nil; token.fire() end
    end
    if next(queue) == nil then frame:Hide() end
end)
