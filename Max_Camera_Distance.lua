local addonName = ... -- Назва аддона
local frame = CreateFrame("Frame")

local ENABLE_LOGGING = false -- true для увімкнення логування

-- *** Безпечний виклик з логуванням помилок ***
local function SafeCall(func, name, event, ...)
    if not func then
        print(string.format("%s: Missing function: %s (%s)", addonName, name, event or "No Event"))
        return
    end

    local status, err = pcall(func, ...)
    if not status then
        print(string.format("%s: Error in %s (%s): %s", addonName, name, event or "No Event", err))
    end
end

-- *** Перевірка наявності потрібних функцій ***
local function CheckFunctionsAvailable(required)
    if type(Functions) ~= "table" then
        print(string.format("%s: Error: Functions table is missing.", addonName))
        return false
    end

    for _, name in ipairs(required) do
        if type(Functions[name]) ~= "function" then
            print(string.format("%s: Error: Functions.%s is missing.", addonName, name))
            return false
        end
    end

    return true
end

-- *** Ініціалізація аддона ***
local function InitializeAddon()
    if not CheckFunctionsAvailable({
        "AdjustCamera",
        "OnCVarUpdate",
        "UpdateCameraOnCombat",
        "SlashCmdHandler"
    }) then return end

    SafeCall(Database and Database.InitDB, "Database:InitDB")
    SafeCall(Config and Config.SetupOptions, "Config:SetupOptions")

    frame:UnregisterEvent("ADDON_LOADED")
end

-- *** Логування подій ***
local function LogEvent(event, ...)
    if not ENABLE_LOGGING then return end
    local args = {...}
    for i = 1, #args do
        args[i] = tostring(args[i]) -- перетворення в рядок
    end
    local argsStr = table.concat(args, " ")
    print(string.format("%s: Event %s triggered with arguments: %s", addonName, event, argsStr))
end

-- *** Таблиця обробників подій ***
local eventHandlers = {
    ADDON_LOADED = function(event, addon)
        if addon == addonName then
            InitializeAddon()
        end
    end,

    PLAYER_ENTERING_WORLD = function(event)
        SafeCall(Functions.AdjustCamera, "Functions:AdjustCamera", event)
    end,

    PLAYER_REGEN_DISABLED = function(event)
        SafeCall(Functions.UpdateCameraOnCombat, "Functions:UpdateCameraOnCombat", event)
    end,

    PLAYER_REGEN_ENABLED = function(event)
        SafeCall(Functions.UpdateCameraOnCombat, "Functions:UpdateCameraOnCombat", event)
    end,

    CVAR_UPDATE = function(event, cvarName, newValue)
        SafeCall(Functions.OnCVarUpdate, "Functions:OnCVarUpdate", event, cvarName, newValue)
    end,
}

-- *** Обробка подій ***
local function OnEvent(self, event, ...)
    LogEvent(event, ...)
    local handler = eventHandlers[event]
    if handler then
        handler(event, ...)
    end
end

-- *** Реєстрація подій ***
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("CVAR_UPDATE")

frame:SetScript("OnEvent", OnEvent)

-- *** Slash-команда ***
SLASH_MAXCAMDIST1 = "/mcd"
SlashCmdList["MAXCAMDIST"] = function(msg)
    SafeCall(Functions and Functions.SlashCmdHandler, "Functions:SlashCmdHandler", nil, msg)
end
