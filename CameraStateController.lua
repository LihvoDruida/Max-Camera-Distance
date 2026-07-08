local addonName, ns = ...
ns.CameraStateController = ns.CameraStateController or {}
local Controller = ns.CameraStateController

local tonumber = tonumber
local tostring = tostring
local GetTime = GetTime

local Compat = ns.Compat or {}
local CONVERSION_RATIO = Compat.CONVERSION_RATIO or 15

Controller.STATES = Controller.STATES or {
    AFK = "afk",
    DRAGON_RACE_FIRST_PERSON = "dragonrace_first_person",
    COMBAT = "combat",
    MOUNT = "mount",
    NORMAL = "normal",
    MANUAL = "manual",
}

Controller.priority = Controller.priority or {
    afk = 100,
    dragonrace_first_person = 90,
    combat = 80,
    mount = 70,
    normal = 10,
    manual = 0,
}

Controller.currentState = Controller.currentState or Controller.STATES.NORMAL
Controller.previousState = Controller.previousState or nil
Controller.stateToken = Controller.stateToken or 0
Controller.transitionToken = Controller.transitionToken or 0
Controller.pendingReturnTimer = Controller.pendingReturnTimer or nil
Controller.pendingReturnInfo = Controller.pendingReturnInfo or nil
Controller.targetYards = Controller.targetYards or nil
Controller.targetCVarFactor = Controller.targetCVarFactor or nil
Controller.sourceEvent = Controller.sourceEvent or "init"
Controller.resolvedContext = Controller.resolvedContext or "world"
Controller.lastAppliedAt = Controller.lastAppliedAt or 0

function Controller:NormalizeState(state)
    if state == nil or state == "none" then
        return self.STATES.NORMAL
    end
    if self.priority[state] ~= nil then
        return state
    end
    return self.STATES.NORMAL
end

function Controller:GetPriority(state)
    return self.priority[self:NormalizeState(state)] or 0
end

function Controller:SetState(state, targetYards, context, sourceEvent)
    state = self:NormalizeState(state)
    local previous = self.currentState or self.STATES.NORMAL
    local changed = previous ~= state

    if changed then
        self.previousState = previous
        self.currentState = state
        self.stateToken = (self.stateToken or 0) + 1
        self.transitionToken = (self.transitionToken or 0) + 1
    end

    self.targetYards = tonumber(targetYards) or self.targetYards
    self.targetCVarFactor = self.targetYards and (self.targetYards / CONVERSION_RATIO) or nil
    self.resolvedContext = context or self.resolvedContext or "world"
    self.sourceEvent = sourceEvent or self.sourceEvent or "unknown"
    self.lastAppliedAt = GetTime and GetTime() or 0

    return state, changed, self.stateToken
end

function Controller:GetState()
    return self.currentState or self.STATES.NORMAL
end

function Controller:GetPreviousState()
    return self.previousState
end

function Controller:GetStateToken()
    return self.stateToken or 0
end

function Controller:TouchTransition()
    self.transitionToken = (self.transitionToken or 0) + 1
    return self.transitionToken
end

function Controller:GetTransitionToken()
    return self.transitionToken or 0
end

function Controller:SetPendingReturn(info)
    self.pendingReturnInfo = info
end

function Controller:ClearPendingReturn()
    self.pendingReturnInfo = nil
end

function Controller:GetPendingReturn()
    return self.pendingReturnInfo
end

function Controller:GetSnapshot()
    return {
        currentState = self.currentState,
        previousState = self.previousState,
        stateToken = self.stateToken,
        transitionToken = self.transitionToken,
        pendingReturnInfo = self.pendingReturnInfo,
        targetYards = self.targetYards,
        targetCVarFactor = self.targetCVarFactor,
        sourceEvent = self.sourceEvent,
        resolvedContext = self.resolvedContext,
        lastAppliedAt = self.lastAppliedAt,
    }
end
