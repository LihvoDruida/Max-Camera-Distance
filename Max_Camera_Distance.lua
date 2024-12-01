local addonName = "Max_Camera_Distance"

-- Ініціалізація налаштувань аддона
local function InitializeAddon()
    if Database and Database.InitDB then
        Database:InitDB()
    end

    if Config and Config.SetupOptions then
        Config:SetupOptions()
    end

    if Functions and Functions.AdjustCamera then
        Functions:AdjustCamera()
    else
        print(addonName .. ": Error initializing Functions.AdjustCamera")
    end
end

-- Обробка подій
local function OnEvent(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitializeAddon()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "CVAR_UPDATE" and Functions and Functions.OnCVarUpdate then
        local cvarName, newValue = ...
        Functions:OnCVarUpdate(_, cvarName, newValue)
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" and Functions and Functions.OnMounted then
        Functions:OnMounted()
    elseif event == "PLAYER_REGEN_DISABLED" and Functions and Functions.OnEnterCombat then
        Functions:OnEnterCombat()
    elseif event == "PLAYER_REGEN_ENABLED" and Functions and Functions.OnExitCombat then
        Functions:OnExitCombat()
    elseif event == "UPDATE_SHAPESHIFT_FORM" and Functions and Functions.OnForm then
        if Functions:IsDruidOrShaman() then
            Functions:OnForm()
        end
    end
end

-- Створення фрейму для обробки подій
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CVAR_UPDATE")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

-- Додавання скрипта для обробки подій
f:SetScript("OnEvent", OnEvent)

-- Реєстрація Slash-команд
SLASH_MAXCAMDIST1 = "/mcd"
SlashCmdList["MAXCAMDIST"] = function(msg)
    if Functions and Functions.SlashCmdHandler then
        Functions:SlashCmdHandler(msg)
    else
        print(addonName .. ": Slash command handler not found")
    end
end
