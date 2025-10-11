local addonName, _ = ...
local frame = CreateFrame("Frame")

local ENABLE_LOGGING = false

-- *** Безпечний виклик ***
local function SafeCall(func, name, event, ...)
    if type(func) ~= "function" then
        print(string.format("%s: Missing function: %s (%s)", addonName, tostring(name), event or "No Event"))
        return
    end

    local ok, result1, result2, result3 = pcall(func, ...)
    if not ok then
        print(string.format("%s: Error in %s (%s): %s", addonName, tostring(name), event or "No Event", tostring(result1)))
        return false
    end
    return result1, result2, result3
end

-- *** Перевірка таблиці функцій ***
local function CheckFunctionsAvailable(required)
    if type(Functions) ~= "table" then
        print(addonName .. ": Error: Functions table is missing.")
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

-- *** Перевірка станів гри ***
local function IsPlayerReady()
    return UnitExists("player") and not UnitIsDeadOrGhost("player")
end

local function IsSafeToAdjustCamera()
    return not InCombatLockdown() and IsPlayerReady()
end

-- *** Логування подій ***
local function LogEvent(event, ...)
    if not ENABLE_LOGGING then return end
    local args = { ... }
    for i = 1, #args do args[i] = tostring(args[i] or "nil") end
    print(string.format("%s: [%s] %s", addonName, event, table.concat(args, ", ")))
end

-- *** Ініціалізація аддона ***
local function InitializeAddon()
    if not CheckFunctionsAvailable({
            "AdjustCamera",
            "OnCVarUpdate",
            "UpdateCameraOnCombat",
            "SlashCmdHandler"
        }) then
        return
    end

    if Database and type(Database.InitDB) == "function" then
        SafeCall(Database.InitDB, "Database:InitDB")
    end
    if Config and type(Config.SetupOptions) == "function" then
        SafeCall(Config.SetupOptions, "Config:SetupOptions")
    end

    frame:UnregisterEvent("ADDON_LOADED")
end

-- *** Обробники подій ***
local eventHandlers = {
    ADDON_LOADED = function(event, addon)

            InitializeAddon()

    end,


    PLAYER_ENTERING_WORLD = function(event)
        if IsSafeToAdjustCamera() then
            SafeCall(Functions.AdjustCamera, "AdjustCamera", event)
        else
            print(addonName .. ": Skipped camera adjustment (player not ready).")
        end
    end,

    PLAYER_REGEN_DISABLED = function(event)
        -- Уникаємо заборонених викликів у бою
        if Functions and Functions.UpdateCameraOnCombat then
            SafeCall(Functions.UpdateCameraOnCombat, "UpdateCameraOnCombat (enter combat)", event)
        end
    end,

    PLAYER_REGEN_ENABLED = function(event)
        if IsSafeToAdjustCamera() then
            SafeCall(Functions.UpdateCameraOnCombat, "UpdateCameraOnCombat (leave combat)", event)
        end
    end,

    CVAR_UPDATE = function(event, cvarName, ...)
        if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax" then
            if IsSafeToAdjustCamera() then
                SafeCall(Functions.OnCVarUpdate, "OnCVarUpdate", event, cvarName, ...)
            end
        end
    end,

    UNIT_AURA = function(event, unit)
        if unit == "player" and IsPlayerReady() then
            if Functions and Functions.UpdateCameraOnCombat then
                SafeCall(Functions.UpdateCameraOnCombat, "UpdateCameraOnCombat (UNIT_AURA)", event, unit)
            end
        end
    end
}

-- *** Основний Event Handler ***
local function OnEvent(self, event, ...)
    LogEvent(event, ...)
    local handler = eventHandlers[event]
    if handler then
        SafeCall(handler, "EventHandler: " .. event, event, ...)
    end
end

-- *** Реєстрація подій ***
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("CVAR_UPDATE")
frame:RegisterEvent("UNIT_AURA")

frame:SetScript("OnEvent", OnEvent)

-- *** Slash-команда ***
SLASH_MAXCAMDIST1 = "/mcd"
SlashCmdList["MAXCAMDIST"] = function(msg)
    SafeCall(Functions.SlashCmdHandler, "SlashCmdHandler", "SlashCmd", msg)
end
