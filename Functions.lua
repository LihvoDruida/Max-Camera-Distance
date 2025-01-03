Functions = {}

local addonName = "Max_Camera_Distance"
local settingName = "Max Camera Distance"
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local _, playerClass = UnitClass("player")

local savedMaxZoomFactor = nil
local lastExecutionTime = 0
local executionCooldown = 1 -- Cooldown in seconds

-- *** Функція для виведення повідомлень в чат ***
function Functions:SendMessage(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff0070deMax Camera Distance|r: " .. message)
end

-- *** Логування повідомлень ***
function Functions:logMessage(level, message)
    local db = Database.db.profile
    if not db.enableDebugLogging or not db.debugLevel[level] then return end

    local prefix, color
    if level == "error" then
        color = "|cffff0000"
        prefix = "[E]"
    elseif level == "warning" then
        color = "|cffffff00"
        prefix = "[W]"
    elseif level == "info" then
        color = "|cff00ff00"
        prefix = "[I]"
    else
        color = "|cffffffff"
        prefix = "[D]"
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff0070deMax Camera Distance|r " .. prefix .. ": " .. color .. message .. "|r")
end

-- *** Збереження початкового рівня масштабу камери ***
function getSavedMaxZoomFactor()
    if not savedMaxZoomFactor then
        savedMaxZoomFactor = tonumber(C_CVar.GetCVar("cameraDistanceMaxZoomFactor")) or Database.DEFAULT_ZOOM_FACTOR
    end
    return savedMaxZoomFactor
end

function Functions:ChangeCameraSetting(key, value, message)
    local db = Database.db.profile
    db[key] = value
    -- Актуалізуємо камеру
    self:AdjustCamera()
    
    -- Якщо є повідомлення, логуємо його
    if message then
        self:logMessage("info", message)
    end
end

-- *** Логіка для Mount ***
function OnMount()
    getSavedMaxZoomFactor()
    C_CVar.SetCVar("cameraDistanceMaxZoomFactor", Database.MAX_ZOOM_FACTOR)
    Functions:logMessage("info", "Set max zoom factor to " .. Database.MAX_ZOOM_FACTOR .. ".")
end

-- *** Логіка для Dismount ***
function OnDismount()
    local delay = Database.db.profile.dismountDelay or Database.DISMOUNT_DELAY -- Затримка для dismount.
    
    -- Затримка виконання дій після dismount.
    C_Timer.After(delay, function()
        if savedMaxZoomFactor then
            -- Відновлюємо попередній рівень зуму.
            C_CVar.SetCVar("cameraDistanceMaxZoomFactor", savedMaxZoomFactor)
            Functions:logMessage("info", "Restored previous camera zoom factor.")
            savedMaxZoomFactor = nil -- Скидаємо значення після відновлення.
        else
            -- Якщо значення не збережено, виводимо попередження.
            Functions:logMessage("warning", "No saved camera zoom factor to restore.")
        end
    end)
end

-- *** Налаштування параметрів камери ***
function Functions:AdjustCamera()
    local db = Database.db.profile
    -- Перевірка, чи можна змінювати налаштування камери
    if not InCombatLockdown() and IsLoggedIn() then
        -- Оновлюємо параметри камери
        if db.maxZoomFactor then
            C_CVar.SetCVar("cameraDistanceMaxZoomFactor", db.maxZoomFactor)
            self:logMessage("info", "Adjusted max zoom factor to " .. db.maxZoomFactor .. ".")
        end
        if db.moveViewDistance then
            MoveViewOutStart(db.moveViewDistance)
            self:logMessage("info", "Adjusted move view distance to " .. db.moveViewDistance .. ".")
        end
    end
end

-- Function to check if the player is a Druid or Shaman
function Functions:IsDruidOrShaman()
    return playerClass == "DRUID" or playerClass == "SHAMAN"
end

-- *** Логіка для форми Друїда/Шамана ***
function Functions:OnForm()
    if GetTime() - lastExecutionTime < executionCooldown then return end
    lastExecutionTime = GetTime()

    local formID = GetShapeshiftForm()
    if formID > 0 then
        if (formID == 6 or formID == 3) and playerClass == "DRUID" then
            OnMount()
        elseif formID == 1 and playerClass == "SHAMAN" then
            OnMount()
        end
    else
        OnDismount()
    end
end

-- *** Колбеки для зміни профілів ***
function Functions:OnProfileChanged() self:AdjustCamera() end
function Functions:OnProfileCopied() self:AdjustCamera() end
function Functions:OnProfileReset() self:AdjustCamera() end

-- *** Обробка Slash команд ***
function Functions:SlashCmdHandler(msg)
    local command = strlower(msg or "")
    local settings = {
        max = { zoomFactor = 2.6, moveDistance = 50000 },
        avg = { zoomFactor = 2.0, moveDistance = 30000 },
        min = { zoomFactor = 1.0, moveDistance = 10000 }
    }

    if settings[command] then
        local setting = settings[command]
        Database.db.profile.maxZoomFactor = setting.zoomFactor
        Database.db.profile.moveViewDistance = setting.moveDistance
        self:AdjustCamera()
        self:logMessage("info", "Settings set to " .. command .. ".")
    elseif command == "config" then
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(settingName)
        else
            self:logMessage("error", "Unable to open settings. Settings API unavailable.")
        end
    else
        self:SendMessage("Usage: /mcd max | avg | min | config")
    end
end
