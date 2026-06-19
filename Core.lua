local addonName, ns = ...
local LibStub = _G.LibStub
ns.Core = ns.Core or {}
local Core = ns.Core
local frame = CreateFrame("Frame")
local Compat = ns.Compat or {}
local L = setmetatable({}, {
    __index = function(_, key)
        if ns.Locale and ns.Locale.Get then
            return ns.Locale:Get(key)
        end
        local aceLocale = (LibStub and LibStub("AceLocale-3.0", true))
        local tbl = aceLocale and aceLocale:GetLocale(addonName, true)
        local value = tbl and tbl[key]
        if value ~= nil then
            return value
        end
        return key
    end,
})

local IS_RETAIL = Compat.IS_RETAIL and true or false

-- Cached globals
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local C_Timer = C_Timer
local pcall = pcall

-- Minimap libs
local LDB = (LibStub and LibStub("LibDataBroker-1.1", true))
local LDBIcon = (LibStub and LibStub("LibDBIcon-1.0", true))
local ACD = (LibStub and LibStub("AceConfigDialog-3.0", true))

local ENABLE_LOGGING = false
local minimapInited = false

-- Logging
local function LogEvent(event, ...)
    if not ENABLE_LOGGING then return end
    print(string.format("%s: [%s]", addonName, event), ...)
end

local function SafeCall(func, name, ...)
    if type(func) ~= "function" then return end
    local ok, err = pcall(func, ...)
    if not ok then
        print(string.format("|cffff0000%s Error in %s:|r %s", addonName, name, tostring(err)))
    end
end

local function IsDeadOrGhostSafe(unit)
    if type(UnitIsDeadOrGhost) == "function" then
        local ok, result = pcall(UnitIsDeadOrGhost, unit)
        if ok then return result and true or false end
    end
    if type(UnitIsDead) == "function" then
        local ok, result = pcall(UnitIsDead, unit)
        if ok and result then return true end
    end
    if type(UnitIsGhost) == "function" then
        local ok, result = pcall(UnitIsGhost, unit)
        if ok and result then return true end
    end
    return false
end

local function IsPlayerReady()
    if type(UnitExists) ~= "function" then return false end
    local ok, exists = pcall(UnitExists, "player")
    return ok and exists and not IsDeadOrGhostSafe("player")
end

local function SafeRegisterEvent(targetFrame, eventName)
    local ok = pcall(targetFrame.RegisterEvent, targetFrame, eventName)
    if not ok and ENABLE_LOGGING then
        print(string.format("%s: skipped unsupported event %s", addonName, tostring(eventName)))
    end
end

-- One-liner updater for many events
local function RequestSmartUpdate()
    if ns.Functions and ns.Functions.RequestUpdate then
        ns.Functions:RequestUpdate()
    end
end

local function InvalidateRuntimeCaches()
    if ns.Functions and ns.Functions.InvalidateRuntimeCaches then
        SafeCall(ns.Functions.InvalidateRuntimeCaches, "InvalidateRuntimeCaches", ns.Functions)
    end
end

local function RefreshAfkRelevantState()
    if ns.Functions and ns.Functions.OnAfkRelevantStateChanged then
        SafeCall(ns.Functions.OnAfkRelevantStateChanged, "OnAfkRelevantStateChanged", ns.Functions)
    end
end

local function ForceSmartUpdate()
    InvalidateRuntimeCaches()
    if ns.Functions and ns.Functions.AdjustCamera then
        SafeCall(ns.Functions.AdjustCamera, "AdjustCamera", ns.Functions, true)
    end
end

local function RequestShoulderRefresh()
    if ns.Functions and ns.Functions.RequestShoulderRefresh then
        SafeCall(ns.Functions.RequestShoulderRefresh, "RequestShoulderRefresh", ns.Functions)
    end
end

local function InvalidateMountCache()
    if ns.Functions and ns.Functions.InvalidateMountCache then
        SafeCall(ns.Functions.InvalidateMountCache, "InvalidateMountCache", ns.Functions)
    end
end

local startupRefreshToken = 0
local cameraViewHooksInstalled = false

local function InstallCameraViewHooks()
    if cameraViewHooksInstalled then return end
    cameraViewHooksInstalled = true

    if type(hooksecurefunc) ~= "function" then return end

    local function ScheduleViewRestoreRefresh()
        if ns.Functions and ns.Functions.ScheduleStabilizedUpdate then
            SafeCall(ns.Functions.ScheduleStabilizedUpdate, "ScheduleStabilizedUpdate", ns.Functions, { 0, 0.10, 0.35 }, true)
        elseif ns.Functions and ns.Functions.RequestUpdate then
            SafeCall(ns.Functions.RequestUpdate, "RequestUpdate", ns.Functions)
        end
    end

    if type(_G.SetView) == "function" then
        pcall(hooksecurefunc, "SetView", ScheduleViewRestoreRefresh)
    end
    if type(_G.ResetView) == "function" then
        pcall(hooksecurefunc, "ResetView", ScheduleViewRestoreRefresh)
    end
end

local function ScheduleStartupCameraRefresh()
    if not C_Timer or not C_Timer.After then
        ForceSmartUpdate()
        return
    end

    startupRefreshToken = startupRefreshToken + 1
    local myToken = startupRefreshToken

    -- Login/load can briefly report stale combat, mount, zone or CVar state.
    -- Re-apply Smart Zoom a few times so the final state settles to the
    -- correct Normal/Mount/Combat target instead of sometimes staying at max.
    local delays = { 0.10, 0.50, 1.50, 3.0, 6.0, 9.0 }
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if myToken ~= startupRefreshToken then return end
            if not IsPlayerReady() then return end
            ForceSmartUpdate()
        end)
    end
end

function Core:RefreshMinimapButton()
    if not LDBIcon or not ns.Database or not ns.Database.db or not ns.Database.db.profile then return end

    ns.Database.db.profile.minimap = ns.Database.db.profile.minimap or { hide = false }

    if LDBIcon.Refresh then
        LDBIcon:Refresh(addonName, ns.Database.db.profile.minimap)
    end

    if ns.Database.db.profile.minimap.hide then
        LDBIcon:Hide(addonName)
    else
        LDBIcon:Show(addonName)
    end
end

local function InitMinimapButton()
    if minimapInited then return end
    minimapInited = true

    if not LDB or not LDBIcon then return end
    if not ns.Database or not ns.Database.db or not ns.Database.db.profile then return end

    ns.Database.db.profile.minimap = ns.Database.db.profile.minimap or { hide = false }

    local myIcon = "Interface\\AddOns\\" .. addonName .. "\\assets\\icon"
    local minimapDataObj = LDB:NewDataObject(addonName, {
        type = "launcher",
        icon = myIcon,
        label = L["ADDON_TITLE"] or "Max Camera Distance",

        OnClick = function(_, button)
            if ACD and ACD.Open then
                local ok, err = pcall(ACD.Open, ACD, addonName)
                if not ok then
                    print(addonName .. ": settings window failed: " .. tostring(err))
                end
            else
                print(addonName .. ": AceConfigDialog not found.")
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cFF87CEFA" .. (L["ADDON_TITLE"] or "Max Camera Distance") .. "|r")
            tooltip:AddLine(L["MINIMAP_TOOLTIP_OPEN_SETTINGS"] or "Click to open settings")
        end,
    })

    if minimapDataObj then
        LDBIcon:Register(addonName, minimapDataObj, ns.Database.db.profile.minimap)
        Core:RefreshMinimapButton()
    end
end

local watchedCVars = {
    cameraDistanceMaxZoomFactor = true,
    cameraDistanceMax = true,
    cameraDistanceMoveSpeed = true,
    cameraYawMoveSpeed = true,
    cameraPitchMoveSpeed = true,
    CameraKeepCharacterCentered = true,
    cameraReduceUnexpectedMovement = true,
    CameraReduceUnexpectedMovement = true,
    cameraIndirectVisibility = true,
    cameraIndirectOffset = true,
    cameraView = true,
}

if Compat.HasCVar and Compat.HasCVar("test_cameraOverShoulder") then
    watchedCVars.test_cameraOverShoulder = true
end
if Compat.HasCVar and Compat.HasCVar("test_cameraDynamicPitch") then
    watchedCVars.test_cameraDynamicPitch = true
end
if Compat.HasCVar and Compat.HasCVar("occludedSilhouettePlayer") then
    watchedCVars.occludedSilhouettePlayer = true
end
if Compat.HasCVar and Compat.HasCVar("resampleAlwaysSharpen") then
    watchedCVars.resampleAlwaysSharpen = true
end
if Compat.HasCVar and Compat.HasCVar("SoftTargetIconGameObject") then
    watchedCVars.SoftTargetIconGameObject = true
end

-- Event handlers
local eventHandlers = {}

eventHandlers.ADDON_LOADED = function(event, loadedAddon)
    if loadedAddon ~= addonName then return end

    if ns.Database and ns.Database.InitDB then
        SafeCall(ns.Database.InitDB, "InitDB", ns.Database)
    end

    if ns.Config and ns.Config.SetupOptions then
        SafeCall(ns.Config.SetupOptions, "SetupOptions", ns.Config)
    end

    local guard = ns.CVarGuard or ns.CVarMonitor
    if guard and guard.Init then
        SafeCall(guard.Init, "CVarGuard.Init", guard)
    end

    SafeCall(InstallCameraViewHooks, "InstallCameraViewHooks")
    SafeCall(InitMinimapButton, "InitMinimapButton")

    frame:UnregisterEvent("ADDON_LOADED")
end

eventHandlers.PLAYER_ENTERING_WORLD = function(event, isLogin, isReload)
    InvalidateMountCache()
    InvalidateRuntimeCaches()
    if not IsPlayerReady() then return end
    if not (ns.Functions and ns.Functions.AdjustCamera) then return end

    if isLogin or isReload then
        ScheduleStartupCameraRefresh()
    else
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if not IsPlayerReady() then return end
                ForceSmartUpdate()
            end)
        else
            ForceSmartUpdate()
        end
    end

    RefreshAfkRelevantState()
end

eventHandlers.PLAYER_REGEN_DISABLED = function(event)
    RequestSmartUpdate(event)
    RefreshAfkRelevantState()
end
eventHandlers.PLAYER_REGEN_ENABLED = function(event)
    RequestSmartUpdate(event)
    RefreshAfkRelevantState()
end
eventHandlers.PLAYER_DEAD = function(event)
    RequestSmartUpdate(event)
    RefreshAfkRelevantState()
end
eventHandlers.PLAYER_ALIVE = function(event)
    RequestSmartUpdate(event)
    RefreshAfkRelevantState()
end
eventHandlers.PLAYER_UNGHOST = function(event)
    RequestSmartUpdate(event)
    RefreshAfkRelevantState()
end
eventHandlers.PLAYER_MOUNT_DISPLAY_CHANGED = function(event)
    InvalidateMountCache()
    InvalidateRuntimeCaches()
    RequestSmartUpdate(event)
    RefreshAfkRelevantState()
end
eventHandlers.UPDATE_SHAPESHIFT_FORM = function(event)
    InvalidateMountCache()
    InvalidateRuntimeCaches()
    RequestSmartUpdate(event)
    RefreshAfkRelevantState()
end
eventHandlers.UNIT_MODEL_CHANGED = function(event, unit)
    if unit ~= "player" then return end
    RequestShoulderRefresh()
    RequestSmartUpdate()
end

eventHandlers.UNIT_AURA = function(event, unit)
    if unit ~= "player" then return end
    InvalidateMountCache()
    InvalidateRuntimeCaches()
    RequestShoulderRefresh()
    -- Travel forms, skyriding/race auras and temporary vehicle-style buffs do not
    -- always flip PLAYER_MOUNT_DISPLAY_CHANGED immediately. Coalesced RequestUpdate
    -- keeps reaction fast without running permanent OnUpdate work.
    RequestSmartUpdate()
end

eventHandlers.UNIT_ENTERING_VEHICLE = function(event, unit)
    if unit ~= "player" then return end
    InvalidateMountCache()
    RequestShoulderRefresh()
    RequestSmartUpdate()
end

eventHandlers.UNIT_EXITING_VEHICLE = function(event, unit)
    if unit ~= "player" then return end
    InvalidateMountCache()
    RequestShoulderRefresh()
    RequestSmartUpdate()
end

eventHandlers.UNIT_SPELLCAST_SUCCEEDED = function(event, unit)
    if unit ~= "player" then return end
    RequestShoulderRefresh()
end

eventHandlers.LOADING_SCREEN_DISABLED = function()
    InvalidateMountCache()
    RequestShoulderRefresh()
    if ns.Functions and ns.Functions.ScheduleStabilizedUpdate then
        SafeCall(ns.Functions.ScheduleStabilizedUpdate, "ScheduleStabilizedUpdate", ns.Functions, { 0, 0.15, 0.75 }, true)
    end
end
eventHandlers.PLAYER_CONTROL_GAINED = ForceSmartUpdate
eventHandlers.GROUP_ROSTER_UPDATE = RequestSmartUpdate
eventHandlers.ENCOUNTER_START = ForceSmartUpdate
eventHandlers.ENCOUNTER_END = ForceSmartUpdate
eventHandlers.ZONE_CHANGED_NEW_AREA = ForceSmartUpdate
eventHandlers.PLAYER_DIFFICULTY_CHANGED = ForceSmartUpdate

if IS_RETAIL then
    eventHandlers.TRAIT_CONFIG_UPDATED = RequestSmartUpdate
end

eventHandlers.PLAYER_FLAGS_CHANGED = function(event)
    if ns.Functions and ns.Functions.OnPlayerFlagsChanged then
        SafeCall(ns.Functions.OnPlayerFlagsChanged, "OnPlayerFlagsChanged", ns.Functions)
    end
end

eventHandlers.CVAR_UPDATE = function(event, cvarName, value)
    if not (ns.Functions and ns.Functions.OnCVarUpdate) then return end
    if watchedCVars[cvarName] then
        SafeCall(ns.Functions.OnCVarUpdate, "OnCVarUpdate", ns.Functions, event, cvarName, value)
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    local handler = eventHandlers[event]
    if handler then
        -- LogEvent(event, ...)
        local ok, err = pcall(handler, event, ...)
        if not ok then
            print(string.format("|cffff0000%s Error in event %s:|r %s", addonName, tostring(event), tostring(err)))
        end
    end
end)

for event in pairs(eventHandlers) do
    SafeRegisterEvent(frame, event)
end

SLASH_MAXCAMDIST1 = "/mcd"
SlashCmdList["MAXCAMDIST"] = function(msg)
    if ns.Functions and ns.Functions.SlashCmdHandler then
        SafeCall(ns.Functions.SlashCmdHandler, "SlashCmd", ns.Functions, msg)
    else
        print(addonName .. ": Handler not found.")
    end
end
