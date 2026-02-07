local addonName, ns = ... -- Використовуємо приватний namespace (ns)
local frame = CreateFrame("Frame")

-- Кешуємо глобальні функції для швидкодії
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local InCombatLockdown = InCombatLockdown
local C_CVar = C_CVar 

-- Бібліотеки для Міні-карти
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)
local ACD = LibStub("AceConfigDialog-3.0")

local ENABLE_LOGGING = false

-- *** Логування ***
local function LogEvent(event, ...)
    if not ENABLE_LOGGING then return end
    local msg = string.format("%s: [%s]", addonName, event)
    print(msg, ...)
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

local function IsSafeToAdjustCamera()
    return IsPlayerReady()
end

local function InitMinimapButton()
    if not LDB or not LDBIcon then return end
    if not ns.Database or not ns.Database.db or not ns.Database.db.profile then return end

    if not ns.Database.db.profile.minimap then
        ns.Database.db.profile.minimap = { hide = false }
    end

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

-- *** Обробники подій ***
local eventHandlers = {
    ADDON_LOADED = function(event, loadedAddon)
        if loadedAddon ~= addonName then return end 

        -- 1. Ініціалізація БД
        if ns.Database and ns.Database.InitDB then 
            SafeCall(ns.Database.InitDB, "InitDB", ns.Database) 
        end
        
        -- 2. Ініціалізація Config
        if ns.Config and ns.Config.SetupOptions then 
            SafeCall(ns.Config.SetupOptions, "SetupOptions", ns.Config) 
        end

        -- 3. Ініціалізація кнопки Міні-карти (NEW)
        SafeCall(InitMinimapButton, "InitMinimapButton")
        
        frame:UnregisterEvent("ADDON_LOADED")
    end,

    PLAYER_ENTERING_WORLD = function(event, isLogin, isReload)
        if IsSafeToAdjustCamera() and ns.Functions then
            SafeCall(ns.Functions.AdjustCamera, "AdjustCamera", ns.Functions)
        end
    end,

    -- *** ПОДІЇ СТАНУ (Бій, Маунт, Форма) ***
    PLAYER_REGEN_DISABLED = function(event)
        if ns.Functions and ns.Functions.RequestUpdate then
            ns.Functions:RequestUpdate()
        end
    end,

    PLAYER_REGEN_ENABLED = function(event)
        if ns.Functions and ns.Functions.RequestUpdate then
            ns.Functions:RequestUpdate()
        end
    end,
    
    PLAYER_MOUNT_DISPLAY_CHANGED = function(event)
        if ns.Functions and ns.Functions.RequestUpdate then
            ns.Functions:RequestUpdate()
        end
    end,

    UPDATE_SHAPESHIFT_FORM = function(event)
        if ns.Functions and ns.Functions.RequestUpdate then
            ns.Functions:RequestUpdate()
        end
    end,
    
    TRAIT_CONFIG_UPDATED = function(event)
        if ns.Functions and ns.Functions.RequestUpdate then
            ns.Functions:RequestUpdate()
        end
    end,

    PLAYER_FLAGS_CHANGED = function(event)
        if ns.Functions and ns.Functions.OnPlayerFlagsChanged then
            SafeCall(ns.Functions.OnPlayerFlagsChanged, "OnPlayerFlagsChanged", ns.Functions)
        end
    end,

    CVAR_UPDATE = function(event, cvarName, value)
        if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax" then
            if ns.Functions then
                SafeCall(ns.Functions.OnCVarUpdate, "OnCVarUpdate", ns.Functions, event, cvarName, value)
            end
        end
    end,
}

-- *** Головний обробник ***
frame:SetScript("OnEvent", function(self, event, ...)
    local handler = eventHandlers[event]
    if handler then
        -- LogEvent(event, ...) 
        handler(event, ...)
    end
end)

-- *** Реєстрація подій ***
for event in pairs(eventHandlers) do
    frame:RegisterEvent(event)
end

-- *** Slash команди ***
SLASH_MAXCAMDIST1 = "/mcd"
SlashCmdList["MAXCAMDIST"] = function(msg)
    if ns.Functions and ns.Functions.SlashCmdHandler then
        SafeCall(ns.Functions.SlashCmdHandler, "SlashCmd", ns.Functions, msg)
    else
        print(addonName .. ": Handler not found.")
    end
end