local addonName, ns = ... -- Використовуємо приватний namespace (ns)
local frame = CreateFrame("Frame")

-- Кешуємо глобальні функції для швидкодії
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local InCombatLockdown = InCombatLockdown
local C_CVar = C_CVar 

local ENABLE_LOGGING = false

-- *** Логування ***
local function LogEvent(event, ...)
    if not ENABLE_LOGGING then return end
    local msg = string.format("%s: [%s]", addonName, event)
    print(msg, ...)
end

-- *** Безпечний виклик (pcall) ***
local function SafeCall(func, name, ...)
    if type(func) ~= "function" then return end
    local ok, err = pcall(func, ...)
    if not ok then
        print(string.format("|cffff0000%s Error in %s:|r %s", addonName, name, tostring(err)))
    end
end

-- *** Перевірка готовності гравця ***
local function IsPlayerReady()
    return UnitExists("player") and not UnitIsDeadOrGhost("player")
end

local function IsSafeToAdjustCamera()
    -- Ми дозволяємо роботу LibCamera навіть у бою, 
    -- тому головна умова - наявність гравця у світі
    return IsPlayerReady()
end

-- *** Обробники подій ***
local eventHandlers = {
    ADDON_LOADED = function(event, loadedAddon)
        if loadedAddon ~= addonName then return end 

        -- Ініціалізація БД
        if ns.Database and ns.Database.InitDB then 
            SafeCall(ns.Database.InitDB, "InitDB", ns.Database) 
        end
        
        -- Ініціалізація Config
        if ns.Config and ns.Config.SetupOptions then 
            SafeCall(ns.Config.SetupOptions, "SetupOptions", ns.Config) 
        end
        
        frame:UnregisterEvent("ADDON_LOADED")
    end,

    PLAYER_ENTERING_WORLD = function(event, isLogin, isReload)
        if IsSafeToAdjustCamera() and ns.Functions then
            SafeCall(ns.Functions.AdjustCamera, "AdjustCamera", ns.Functions)
        end
    end,

    -- *** ПОДІЇ СТАНУ (Бій, Маунт, Форма) ***
    -- Всі вони викликають UpdateSmartZoomState
    
    -- Вхід у бій
    PLAYER_REGEN_DISABLED = function(event)
        if ns.Functions then
            SafeCall(ns.Functions.UpdateSmartZoomState, "SmartZoom-CombatEnter", ns.Functions, event)
        end
    end,

    -- Вихід з бою
    PLAYER_REGEN_ENABLED = function(event)
        if ns.Functions then
            SafeCall(ns.Functions.UpdateSmartZoomState, "SmartZoom-CombatLeave", ns.Functions, event)
        end
    end,
    
    -- Маунти (Сідаємо/Злазимо)
    PLAYER_MOUNT_DISPLAY_CHANGED = function(event)
        if ns.Functions then
            SafeCall(ns.Functions.UpdateSmartZoomState, "SmartZoom-Mount", ns.Functions, event)
        end
    end,

    -- Зміна форми (Друїд, Шаман, Рога, Прист тощо)
    -- Це критично для вашої проблеми з Друїдом!
    UPDATE_SHAPESHIFT_FORM = function(event)
        if ns.Functions then
            SafeCall(ns.Functions.UpdateSmartZoomState, "SmartZoom-Shapeshift", ns.Functions, event)
        end
    end,
    
    -- Опціонально: Зміни талантів (може впливати на Dragonriding)
    TRAIT_CONFIG_UPDATED = function(event)
        if ns.Functions then
            SafeCall(ns.Functions.UpdateSmartZoomState, "SmartZoom-Traits", ns.Functions, event)
        end
    end,

    -- Синхронізація налаштувань, якщо гру змінює інший аддон або консоль
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
        -- LogEvent(event, ...) -- Розкоментувати для дебагу подій
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