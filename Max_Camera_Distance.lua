local addonName = "Max_Camera_Distance"

-- *** Функція для безпечного виклику функцій та логування помилок ***
local function SafeCall(func, name, ...)
    if func then
        local status, err = pcall(func, ...)
        if not status then
            print(string.format("%s: Error in %s: %s", addonName, name, err))
        end
    else
        print(string.format("%s: Missing function: %s", addonName, name))
    end
end

-- *** Ініціалізація аддона ***
local function InitializeAddon()
    -- Ініціалізація бази даних
    SafeCall(Database.InitDB, "Database:InitDB")

    -- Налаштування опцій
    SafeCall(Config.SetupOptions, "Config:SetupOptions")

    -- Актуалізація початкових параметрів камери
    SafeCall(Functions.AdjustCamera, "Functions:AdjustCamera")
end

-- *** Обробка подій ***
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == addonName then
            InitializeAddon()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "CVAR_UPDATE" then
        local cvarName, newValue = ...
        SafeCall(Functions.OnCVarUpdate, "Functions:OnCVarUpdate", nil, cvarName, newValue)
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        SafeCall(Functions.AdjustCamera, "Functions:AdjustCamera")
    end
end

-- *** Створення фрейму та реєстрація подій ***
local frame = CreateFrame("Frame")

-- Реєструємо події
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CVAR_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Додаємо обробник подій
frame:SetScript("OnEvent", OnEvent)

-- *** Реєстрація Slash-команд ***
SLASH_MAXCAMDIST1 = "/mcd"
SlashCmdList["MAXCAMDIST"] = function(msg)
    if Functions and Functions.SlashCmdHandler then
        SafeCall(function() Functions:SlashCmdHandler(msg) end, "Functions:SlashCmdHandler")
    else
        print(string.format("%s: Slash command handler not found", addonName))
    end
end