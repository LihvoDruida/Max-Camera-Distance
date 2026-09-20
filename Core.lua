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

local USES_MODERN_API = Compat.USES_MODERN_API and true or false

-- Cached globals
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local C_Timer = C_Timer
local GetTime = GetTime
local pcall = pcall

-- Minimap libs
-- Resolved lazily: a provider addon can finish loading after this file, in which
-- case a one-shot LibStub lookup at load time would leave these nil forever.
local LDB, LDBIcon, ACD

local function ResolveOptionalLibs()
    if not LibStub then return end
    LDB = LDB or LibStub("LibDataBroker-1.1", true)
    LDBIcon = LDBIcon or LibStub("LibDBIcon-1.0", true)
    ACD = ACD or LibStub("AceConfigDialog-3.0", true)
end

ResolveOptionalLibs()

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
    local truthy = Compat.IsTruthy or function(value) return value and true or false end
    if type(UnitIsDeadOrGhost) == "function" then
        local ok, result = pcall(UnitIsDeadOrGhost, unit)
        if ok then return truthy(result) end
    end
    if type(UnitIsDead) == "function" then
        local ok, result = pcall(UnitIsDead, unit)
        if ok and truthy(result) then return true end
    end
    if type(UnitIsGhost) == "function" then
        local ok, result = pcall(UnitIsGhost, unit)
        if ok and truthy(result) then return true end
    end
    return false
end

local function IsPlayerReady()
    if type(UnitExists) ~= "function" then return false end
    local ok, exists = pcall(UnitExists, "player")
    local truthy = Compat.IsTruthy or function(value) return value and true or false end
    return ok and truthy(exists) and not IsDeadOrGhostSafe("player")
end

-- Events that only ever matter for the player. Registering them globally means
-- the handler is invoked for EVERY unit in the group: in a 40-man raid
-- UNIT_AURA and other unit-scoped events can fire at high frequency in groups.
-- RegisterUnitEvent lets the client discard non-player traffic before Lua sees it.
-- RegisterUnitEvent makes the client filter them for us.
local PLAYER_ONLY_EVENTS = {
    UNIT_AURA = true,
    UNIT_MODEL_CHANGED = true,
    UNIT_ENTERING_VEHICLE = true,
    UNIT_EXITING_VEHICLE = true,
}

local function SafeRegisterEvent(targetFrame, eventName)
    local ok = false

    if PLAYER_ONLY_EVENTS[eventName] and type(targetFrame.RegisterUnitEvent) == "function" then
        ok = pcall(targetFrame.RegisterUnitEvent, targetFrame, eventName, "player")
    end

    if not ok then
        ok = pcall(targetFrame.RegisterEvent, targetFrame, eventName)
    end

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

local function InvalidateRuntimeCaches(scope)
    if ns.Functions and ns.Functions.InvalidateRuntimeCaches then
        SafeCall(ns.Functions.InvalidateRuntimeCaches, "InvalidateRuntimeCaches", ns.Functions, scope)
    end
end

local function AuraAffectsSmartZoom()
    local db = ns.Database and ns.Database.db and ns.Database.db.profile
    return db and (db.autoMountZoom or db.dragonRacingRaceFirstPerson) and true or false
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
        -- SetView / ResetView teleport the camera. Reactive Zoom's accumulated
        -- target refers to the old position and must go.
        if ns.ReactiveZoom and ns.ReactiveZoom.ResetTarget then
            ns.ReactiveZoom:ResetTarget()
        end

        if ns.Functions and ns.Functions.ScheduleStabilizedUpdate then
            SafeCall(ns.Functions.ScheduleStabilizedUpdate, "ScheduleStabilizedUpdate", ns.Functions, { 0, 0.10, 0.35, 0.75 }, true)
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
    if type(_G.SaveView) == "function" then
        pcall(hooksecurefunc, "SaveView", ScheduleViewRestoreRefresh)
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
    local delays = { 0, 0.10, 0.35, 0.75, 1.50, 3.0, 6.0, 9.0 }
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

    ResolveOptionalLibs()
    if not LDB or not LDBIcon then return end
    if not ns.Database or not ns.Database.db or not ns.Database.db.profile then return end

    minimapInited = true

    ns.Database.db.profile.minimap = ns.Database.db.profile.minimap or { hide = false }

    local myIcon = "Interface\\AddOns\\" .. addonName .. "\\assets\\icon"
    local minimapDataObj = LDB:NewDataObject(addonName, {
        type = "launcher",
        icon = myIcon,
        label = L["ADDON_TITLE"] or "Max Camera Distance",

        OnClick = function(_, button)
            if ns.Config and ns.Config.Open then
                ns.Config:Open()
                return
            end

            ResolveOptionalLibs()
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

-- Matched case-insensitively below: the client registers several of these with
-- different capitalisation than the addon uses (e.g. "ResampleAlwaysSharpen"),
-- and CVAR_UPDATE reports the CLIENT's spelling.
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

    -- These used to be added only after a HasCVar() probe at file-load time.
    -- That probe runs before the addon is fully loaded, and 12.1's new
    -- C_CVar.AreCVarsLoaded exists precisely because CVars are not guaranteed to
    -- be readable that early: a false negative silently dropped the CVar from
    -- the watch list for the whole session. CVAR_UPDATE only ever fires for
    -- CVars the client actually has, so listing them unconditionally is both
    -- cheaper and correct on every flavor.
    test_cameraOverShoulder = true,
    test_cameraDynamicPitch = true,
    occludedSilhouettePlayer = true,
    resampleAlwaysSharpen = true,
    SoftTargetIconGameObject = true,
}

-- The gamepad module owns these; listing them here is what turns a change made
-- in Blizzard's own gamepad panel into something the addon can react to.
local gamePadWatchedLower = {}
if ns.GamePad and ns.GamePad.WATCHED_CVARS then
    for _, name in ipairs(ns.GamePad.WATCHED_CVARS) do
        watchedCVars[name] = true
        gamePadWatchedLower[name:lower()] = true
    end
end

if Compat.IS_FOREVER then
    watchedCVars.volumeFog = true
    watchedCVars.volumeFogInterior = true
    watchedCVars.volumeFogLevel = true
    watchedCVars.groundEffectDensity = true
    watchedCVars.groundEffectDist = true
    watchedCVars.groundEffectFade = true
end

local watchedCVarsLower = {}
for name in pairs(watchedCVars) do
    watchedCVarsLower[name:lower()] = true
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

    -- Reactive Zoom replaces the CameraZoomIn/Out globals. Install once, after
    -- the profile exists, so the replacement can read its own settings. The
    -- replacement is inert while the option is off, so installing it here does
    -- not commit the player to anything.
    if ns.ReactiveZoom and ns.ReactiveZoom.Install then
        SafeCall(ns.ReactiveZoom.Install, "ReactiveZoom.Install", ns.ReactiveZoom)
    end

    frame:UnregisterEvent("ADDON_LOADED")
end

-- Every addon has finished loading by the time PLAYER_LOGIN fires, so this is
-- the first moment at which a library provider that sorts AFTER
-- "Max_Camera_Distance" alphabetically is guaranteed to be visible in LibStub.
-- ADDON_LOADED is too early for that, and because WoW stores the enabled addon
-- list per character, whether it was early enough differed from character to
-- character - which is what made this look like a per-toon bug.
eventHandlers.PLAYER_LOGIN = function()
    ResolveOptionalLibs()

    if ns.Database and ns.Database.UpgradeFallbackDB then
        SafeCall(ns.Database.UpgradeFallbackDB, "UpgradeFallbackDB", ns.Database)
    end

    if ns.Database and not ns.Database.db and ns.Database.InitDB then
        SafeCall(ns.Database.InitDB, "InitDB", ns.Database)
    end

    if ns.Config and ns.Config.EnsureRegistered then
        SafeCall(ns.Config.EnsureRegistered, "EnsureRegistered", ns.Config)
    end

    SafeCall(InitMinimapButton, "InitMinimapButton")

    if ns.ReactiveZoom and ns.ReactiveZoom.Install then
        SafeCall(ns.ReactiveZoom.Install, "ReactiveZoom.Install", ns.ReactiveZoom)
    end
end

eventHandlers.PLAYER_ENTERING_WORLD = function(event, isLogin, isReload)
    InvalidateMountCache()
    InvalidateRuntimeCaches()

    if isLogin or isReload then
        SafeCall(InitMinimapButton, "InitMinimapButton")
    end

    -- Turning/pitch speed and the other non-zoom CVars must be restored on EVERY
    -- world entry, including logins where the player is dead or a ghost and the
    -- Smart Zoom path below bails out.
    if ns.Functions and ns.Functions.ApplyManagedCVars then
        SafeCall(ns.Functions.ApplyManagedCVars, "ApplyManagedCVars", ns.Functions)
    end

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
    -- CVarGuard may have deferred restoring a secure CVar while combat was
    -- locked down. Force reconciliation here, but do NOT blindly re-apply every
    -- managed CVar: doing so would briefly re-enable motion-sickness CVars while
    -- an in-combat shoulder mode is still transitioning out.
    local guard = ns.CVarGuard or ns.CVarMonitor
    if guard and guard.Refresh then
        SafeCall(guard.Refresh, "CVarGuard.RefreshAfterCombat", guard, true)
    end
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
end

-- UNIT_AURA on the player still fires constantly in combat, and each one used to
-- wipe the runtime caches and queue a full mount/aura/group rescan. Auras only
-- matter here for travel-form and race detection, which cannot change faster
-- than this throttle.
local UNIT_AURA_THROTTLE = 0.1
local lastAuraHandledAt = 0

eventHandlers.UNIT_AURA = function(event, unit)
    if unit ~= "player" then return end

    local now = (GetTime and GetTime()) or 0
    if now > 0 and (now - lastAuraHandledAt) < UNIT_AURA_THROTTLE then return end
    lastAuraHandledAt = now

    -- Deliberately NOT InvalidateMountCache(). Which mount journal entry is
    -- active cannot change because of an aura - that needs
    -- PLAYER_MOUNT_DISPLAY_CHANGED, a vehicle event or a shapeshift, all of
    -- which invalidate it below. Clearing it here meant that skyriding, where
    -- vigor churns UNIT_AURA constantly, forced a full journal rescan up to ten
    -- times a second. Aura-derived signals are still dropped, so travel-form
    -- detection stays as responsive as before.
    local affectsSmartZoom = AuraAffectsSmartZoom()
    if affectsSmartZoom then
        -- Aura changes invalidate travel/race-derived signals, but they do not
        -- change which group members are in combat. Preserve the group-combat
        -- cache so raid aura churn cannot trigger repeated roster scans.
        InvalidateRuntimeCaches("combat-only")
    end

    RequestShoulderRefresh()

    -- Combat-only and plain-distance profiles consume no aura-derived state.
    if affectsSmartZoom then
        RequestSmartUpdate()
    end
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

eventHandlers.LOADING_SCREEN_DISABLED = function()
    InvalidateMountCache()
    RequestShoulderRefresh()
    if ns.Functions and ns.Functions.ScheduleStabilizedUpdate then
        SafeCall(ns.Functions.ScheduleStabilizedUpdate, "ScheduleStabilizedUpdate", ns.Functions, { 0, 0.10, 0.35, 0.75 }, true)
    end
end
eventHandlers.PLAYER_CONTROL_GAINED = ForceSmartUpdate
eventHandlers.GROUP_ROSTER_UPDATE = RequestSmartUpdate
eventHandlers.ENCOUNTER_START = ForceSmartUpdate
eventHandlers.ENCOUNTER_END = ForceSmartUpdate
eventHandlers.ZONE_CHANGED_NEW_AREA = ForceSmartUpdate
eventHandlers.PLAYER_DIFFICULTY_CHANGED = ForceSmartUpdate

if USES_MODERN_API then
    eventHandlers.TRAIT_CONFIG_UPDATED = RequestSmartUpdate
end

eventHandlers.PLAYER_FLAGS_CHANGED = function(event)
    if ns.Functions and ns.Functions.OnPlayerFlagsChanged then
        SafeCall(ns.Functions.OnPlayerFlagsChanged, "OnPlayerFlagsChanged", ns.Functions)
    end
end

eventHandlers.CVAR_UPDATE = function(event, cvarName, value)
    if type(cvarName) ~= "string" then return end

    local lowered = cvarName:lower()

    if gamePadWatchedLower[lowered] then
        if ns.GamePad and ns.GamePad.OnCVarUpdate then
            SafeCall(ns.GamePad.OnCVarUpdate, "GamePad.OnCVarUpdate", ns.GamePad, cvarName)
        end
        return
    end

    if not (ns.Functions and ns.Functions.OnCVarUpdate) then return end
    if watchedCVarsLower[lowered] then
        SafeCall(ns.Functions.OnCVarUpdate, "OnCVarUpdate", ns.Functions, event, cvarName, value)
    end
end

-- GAME_PAD_ACTIVE_CHANGED / CONNECTED / DISCONNECTED / CONFIGS_CHANGED.
-- Registered from the module's own list so the set cannot drift between files;
-- SafeRegisterEvent quietly skips any of them on a client that has no gamepad
-- support at all.
local function OnGamePadEvent()
    if ns.GamePad and ns.GamePad.Refresh then
        SafeCall(ns.GamePad.Refresh, "GamePad.Refresh", ns.GamePad, true)
    end
    -- Enabling the gamepad can move CameraKeepCharacterCentered underneath the
    -- ActionCam, so re-assert the addon's own camera state as well.
    if ns.Functions and ns.Functions.UpdateActionCam then
        SafeCall(ns.Functions.UpdateActionCam, "UpdateActionCam", ns.Functions)
    end
end

if ns.GamePad and ns.GamePad.EVENTS then
    for _, eventName in ipairs(ns.GamePad.EVENTS) do
        eventHandlers[eventName] = OnGamePadEvent
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
