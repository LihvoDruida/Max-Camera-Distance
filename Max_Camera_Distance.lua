local addonName, _ = ...
local frame = CreateFrame("Frame")

local ENABLE_LOGGING = false -- true для увімкнення логування

-- *** Безпечний виклик з логуванням помилок ***
local function SafeCall(func, name, event, ...)
    if type(func) ~= "function" then
        print(string.format("%s: Missing function: %s (%s)", addonName, tostring(name), event or "No Event"))
        return
    end

    local status = pcall(func, ...) -- Повертаємо усі значення, отримані з func
    if not status then
        local err = select(1, ...) -- Помилка знаходиться в першому поверненому значенні
        print(string.format("%s: Error in %s (%s): %s", addonName, tostring(name), event or "No Event", tostring(err)))
        return false -- Повертаємо false при помилці
    end

    return ... -- Повертаємо результат виклику
end

-- *** Перевірка наявності потрібних функцій ***
-- (Логіка правильна, залишаємо без змін)
local function CheckFunctionsAvailable(required)
    -- Functions повинен бути глобальним або визначеним тут (у цьому прикладі вважаємо, що він глобальний після завантаження іншого файлу)
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

-- *** Логування подій ***
local function LogEvent(event, ...)
    if not ENABLE_LOGGING then return end
    local args = {...}
    local strArgs = {}
    for i = 1, #args do
        -- Перетворюємо аргументи в рядок, безпечно обробляючи nil
        strArgs[i] = tostring(args[i] or "nil")
    end
    print(string.format("%s: Event %s triggered with args: %s", addonName, event, table.concat(strArgs, ", ")))
end

-- *** Ініціалізація аддона ***
local function InitializeAddon()
    -- Якщо Functions ще не завантажено, CheckFunctionsAvailable не спрацює правильно.
    -- У WoW аддонах, зазвичай, залежні файли завантажуються *перед* викликом ADDON_LOADED.
    -- Якщо Functions визначено в іншому файлі, який завантажується перед цим, це окей.
    if not CheckFunctionsAvailable({
        "AdjustCamera",
        "OnCVarUpdate",
        "UpdateCameraOnCombat",
        "SlashCmdHandler"
    }) then return end

    if Database and type(Database.InitDB) == "function" then
        SafeCall(Database.InitDB, "Database:InitDB")
    end
    if Config and type(Config.SetupOptions) == "function" then
        SafeCall(Config.SetupOptions, "Config:SetupOptions")
    end

    -- Не реєструємо FRAME:UnregisterEvent("ADDON_LOADED") тут, бо ми можемо
    -- мати багато аддонів, і цей ADDON_LOADED викликається тільки для нашого.
    -- Якщо ми тут, наш аддон вже завантажено.
    -- Залишаємо реєстрацію на ADDON_LOADED, щоб спрацювало один раз.
    frame:UnregisterEvent("ADDON_LOADED")
end


-- *** Таблиця обробників подій ***
local eventHandlers = {
    ADDON_LOADED = function(event, addon)
        if addon == addonName then
            InitializeAddon()
        end
    end,

    PLAYER_ENTERING_WORLD = function(event)
        SafeCall(Functions and Functions.AdjustCamera, "Functions:AdjustCamera", event, event)
    end,

    PLAYER_REGEN_DISABLED = function(event)
        SafeCall(Functions and Functions.UpdateCameraOnCombat, "Functions:UpdateCameraOnCombat", event, event)
    end,

    PLAYER_REGEN_ENABLED = function(event)
        SafeCall(Functions and Functions.UpdateCameraOnCombat, "Functions:UpdateCameraOnCombat", event, event)
    end,

    -- CVAR_UPDATE отримує cvarName як перший аргумент після event
    CVAR_UPDATE = function(event, cvarName, ...)
        SafeCall(Functions and Functions.OnCVarUpdate, "Functions:OnCVarUpdate", event, event, cvarName, ...)
    end,
}

-- *** Обробка подій ***
local function OnEvent(self, event, ...)
    LogEvent(event, ...)
    local handler = eventHandlers[event]
    if handler then
        -- Передаємо усі аргументи далі
        SafeCall(handler, "Event Handler: " .. event, event, event, ...)
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
    -- Передаємо nil як event, щоб SafeCall не виводив зайвої інформації
    SafeCall(Functions and Functions.SlashCmdHandler, "Functions:SlashCmdHandler", "SlashCmd", msg)
end