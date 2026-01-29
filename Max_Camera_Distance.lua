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
    -- "..." тут передає аргументи у функцію. 
    -- Для методів (:) першим аргументом має бути таблиця (self).
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
    return not InCombatLockdown() and IsPlayerReady()
end

-- *** Обробники подій ***
local eventHandlers = {
    ADDON_LOADED = function(event, loadedAddon)
        if loadedAddon ~= addonName then return end 

        -- !!! ВИПРАВЛЕННЯ ТУТ !!!
        -- Ми передаємо ns.Database третім аргументом. Він стає 'self' всередині InitDB.
        if ns.Database and ns.Database.InitDB then 
            SafeCall(ns.Database.InitDB, "InitDB", ns.Database) 
        end
        
        -- Те саме для Config
        if ns.Config and ns.Config.SetupOptions then 
            SafeCall(ns.Config.SetupOptions, "SetupOptions", ns.Config) 
        end
        
        frame:UnregisterEvent("ADDON_LOADED")
    end,

    PLAYER_ENTERING_WORLD = function(event, isLogin, isReload)
        if IsSafeToAdjustCamera() and ns.Functions then
            -- Передаємо ns.Functions як self
            SafeCall(ns.Functions.AdjustCamera, "AdjustCamera", ns.Functions, event)
        end
    end,

    PLAYER_REGEN_DISABLED = function(event)
        if ns.Functions then
            SafeCall(ns.Functions.UpdateCameraOnCombat, "EnterCombat", ns.Functions, event)
        end
    end,

    PLAYER_REGEN_ENABLED = function(event)
        if IsSafeToAdjustCamera() and ns.Functions then
            SafeCall(ns.Functions.UpdateCameraOnCombat, "LeaveCombat", ns.Functions, event)
        end
    end,

    CVAR_UPDATE = function(event, cvarName, value)
        if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax" then
            if IsSafeToAdjustCamera() and ns.Functions then
                SafeCall(ns.Functions.OnCVarUpdate, "OnCVarUpdate", ns.Functions, event, cvarName, value)
            end
        end
    end,
    
    UNIT_AURA = function(event, unit, updateInfo)
        if unit ~= "player" then return end
        
        local isFullUpdate = updateInfo == nil or updateInfo.isFullUpdate
        if isFullUpdate or (updateInfo.addedAuras or updateInfo.removedAuras) then
             if IsPlayerReady() and ns.Functions then
                SafeCall(ns.Functions.UpdateCameraOnCombat, "UnitAura", ns.Functions, event, unit)
            end
        end
    end
}

-- *** Головний обробник ***
frame:SetScript("OnEvent", function(self, event, ...)
    local handler = eventHandlers[event]
    if handler then
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
        -- Тут теж передаємо ns.Functions
        SafeCall(ns.Functions.SlashCmdHandler, "SlashCmd", ns.Functions, msg)
    else
        print(addonName .. ": Handler not found.")
    end
end