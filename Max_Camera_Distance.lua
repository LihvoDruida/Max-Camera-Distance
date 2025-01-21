local addonName = "Max_Camera_Distance"

-- *** Функція для безпечного виклику функцій та логування помилок ***
local function SafeCall(func, name)
    if func then
        local status, err = pcall(func)
        if not status then
            print(addonName .. ": Error in " .. name .. ": " .. err)
        end
    else
        print(addonName .. ": Missing function: " .. name)
    end
end

-- *** Ініціалізація аддона ***
local function InitializeAddon()
    -- Ініціалізація бази даних
    SafeCall(function() Database:InitDB() end, "Database:InitDB")

    -- Налаштування опцій
    SafeCall(function() Config:SetupOptions() end, "Config:SetupOptions")

    -- Актуалізація початкових параметрів камери
    SafeCall(function() Functions:AdjustCamera() end, "Functions:AdjustCamera")
end

-- *** Обробка подій ***
local function OnEvent(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitializeAddon()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "CVAR_UPDATE" then
        local cvarName, newValue = ...
        SafeCall(function() Functions:OnCVarUpdate(_, cvarName, newValue) end, "Functions:OnCVarUpdate")
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        -- Об'єднано виклики AdjustCamera для цих подій
        SafeCall(function() Functions:AdjustCamera() end, "Functions:AdjustCamera")
    end
end


-- *** Створення фрейму та реєстрація подій ***
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CVAR_UPDATE")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Додавання скрипта для обробки подій
f:SetScript("OnEvent", OnEvent)

-- *** Реєстрація Slash-команд ***
SLASH_MAXCAMDIST1 = "/mcd"
SlashCmdList["MAXCAMDIST"] = function(msg)
    if Functions and Functions.SlashCmdHandler then
        SafeCall(function() Functions:SlashCmdHandler(msg) end, "Functions:SlashCmdHandler")
    else
        print(addonName .. ": Slash command handler not found")
    end
end
