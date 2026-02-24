local addonName, ns = ...
local frame = CreateFrame("Frame")

-- Version flags
local IS_RETAIL  = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local IS_CLASSIC = not IS_RETAIL

-- Cached globals
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local C_Timer = C_Timer

-- Minimap libs
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)
local ACD = LibStub("AceConfigDialog-3.0")

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

local function IsPlayerReady()
    return UnitExists("player") and not UnitIsDeadOrGhost("player")
end

-- One-liner updater for many events
local function RequestSmartUpdate()
    if ns.Functions and ns.Functions.RequestUpdate then
        ns.Functions:RequestUpdate()
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
        label = "Max Camera Distance",

        OnClick = function(_, button)
            if ACD then
                ACD:Open(addonName)
            else
                print(addonName .. ": AceConfigDialog not found.")
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cFF87CEFA" .. "Max Camera Distance" .. "|r")
            tooltip:AddLine("|cffffffffClick|r to open settings")
        end,
    })

    if minimapDataObj then
        LDBIcon:Register(addonName, minimapDataObj, ns.Database.db.profile.minimap)
    end
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

    SafeCall(InitMinimapButton, "InitMinimapButton")

    frame:UnregisterEvent("ADDON_LOADED")
end

eventHandlers.PLAYER_ENTERING_WORLD = function(event, isLogin, isReload)
    if not IsPlayerReady() then return end
    if not (ns.Functions and ns.Functions.AdjustCamera) then return end

    -- Small defer avoids early-load race on some clients
    C_Timer.After(0, function()
        if not IsPlayerReady() then return end
        SafeCall(ns.Functions.AdjustCamera, "AdjustCamera", ns.Functions)
    end)
end

-- State events (combat/mount/form/death-res)
eventHandlers.PLAYER_REGEN_DISABLED = RequestSmartUpdate
eventHandlers.PLAYER_REGEN_ENABLED  = RequestSmartUpdate
eventHandlers.PLAYER_DEAD           = RequestSmartUpdate
eventHandlers.PLAYER_ALIVE          = RequestSmartUpdate
eventHandlers.PLAYER_UNGHOST        = RequestSmartUpdate
eventHandlers.PLAYER_MOUNT_DISPLAY_CHANGED = RequestSmartUpdate
eventHandlers.UPDATE_SHAPESHIFT_FORM = RequestSmartUpdate

-- Retail-only (talents UI)
if IS_RETAIL then
    eventHandlers.TRAIT_CONFIG_UPDATED = RequestSmartUpdate
end

eventHandlers.PLAYER_FLAGS_CHANGED = function(event)
    if ns.Functions and ns.Functions.OnPlayerFlagsChanged then
        SafeCall(ns.Functions.OnPlayerFlagsChanged, "OnPlayerFlagsChanged", ns.Functions)
    end
end

eventHandlers.CVAR_UPDATE = function(event, cvarName, value)
    if cvarName ~= "cameraDistanceMaxZoomFactor" and cvarName ~= "cameraDistanceMax" then return end
    if not (ns.Functions and ns.Functions.OnCVarUpdate) then return end
    SafeCall(ns.Functions.OnCVarUpdate, "OnCVarUpdate", ns.Functions, event, cvarName, value)
end

-- Main dispatcher
frame:SetScript("OnEvent", function(self, event, ...)
    local handler = eventHandlers[event]
    if handler then
        -- LogEvent(event, ...)
        handler(event, ...)
    end
end)

-- Register events
for event in pairs(eventHandlers) do
    frame:RegisterEvent(event)
end

-- Slash commands
SLASH_MAXCAMDIST1 = "/mcd"
SlashCmdList["MAXCAMDIST"] = function(msg)
    if ns.Functions and ns.Functions.SlashCmdHandler then
        SafeCall(ns.Functions.SlashCmdHandler, "SlashCmd", ns.Functions, msg)
    else
        print(addonName .. ": Handler not found.")
    end
end