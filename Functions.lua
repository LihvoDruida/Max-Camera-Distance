Functions = {}

local addonName = "Max_Camera_Distance"
local settingName = "Max Camera Distance"
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local _, playerClass = UnitClass("player")
local UnitAffectingCombat = UnitAffectingCombat

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

function Functions:ChangeCameraSetting(key, value, message)
    local db = Database.db.profile
    db[key] = value
    -- Актуалізуємо камеру
    Functions:AdjustCamera()  -- Використовуємо правильний виклик функції без `self`
    
    -- Якщо є повідомлення, логуємо його
    if message then
        Functions:logMessage("info", message)  -- Використовуємо правильний виклик функції без `self`
    end
end

local function UpdateCVar(key, value)
    if C_CVar.GetCVar(key) ~= tostring(value) then
        C_CVar.SetCVar(key, value)
        Functions:logMessage("info", "Updated " .. key .. " to " .. value)
    end
end

-- *** Обробка оновлення параметрів CVAR ***
function Functions:OnCVarUpdate(_, cvarName, value)
    local cvarHandlers = {
        ["cameraDistanceMaxZoomFactor"] = function()
            Functions:ChangeCameraSetting("maxZoomFactor", tonumber(value), L["SETTINGS_CHANGED"])
        end,
        ["cameraDistanceMoveSpeed"] = function()
            Functions:ChangeCameraSetting("moveViewDistance", tonumber(value), L["SETTINGS_CHANGED"])
        end,
        ["cameraReduceUnexpectedMovement"] = function()
            Functions:ChangeCameraSetting("reduceUnexpectedMovement", tonumber(value) == 1, L["SETTINGS_CHANGED"])
        end,
        ["cameraYawMoveSpeed"] = function()
            Functions:ChangeCameraSetting("cameraYawMoveSpeed", tonumber(value), L["SETTINGS_CHANGED"])
        end,
        ["cameraPitchMoveSpeed"] = function()
            Functions:ChangeCameraSetting("cameraPitchMoveSpeed", tonumber(value), L["SETTINGS_CHANGED"])
        end,
        ["cameraIndirectVisibility"] = function()
            Functions:ChangeCameraSetting("cameraIndirectVisibility", tonumber(value) == 1, L["SETTINGS_CHANGED"])
        end,
    }

    -- Викликаємо обробник для відповідного CVar
    if cvarHandlers[cvarName] then
        cvarHandlers[cvarName]()
    end
end

-- *** Функція для зміни налаштувань камери залежно від бою ***
function Functions:UpdateCameraOnCombat()
    local db = Database.db.profile
    local inCombat = UnitAffectingCombat("player")  

    -- Перевіряємо, чи гравець в данжі або рейді
    local inInstance, instanceType = IsInInstance()

    -- Встановлюємо inCombat як true, якщо гравець в данжі або рейді
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        inCombat = true
    end
        
    -- Перевіряємо, чи змінився стан бою
    if inCombat ~= wasInCombat then
        if inCombat then
            -- Якщо в бою: встановлюємо максимальне наближення
            UpdateCVar("cameraDistanceMaxZoomFactor", db.maxZoomFactor)
            Functions:logMessage("info", "In combat: max zoom factor set to " .. db.maxZoomFactor .. ".")
        else
            -- Якщо поза боєм: встановлюємо мінімальне наближення із затримкою
            C_Timer.After(db.dismountDelay or 0, function()
                UpdateCVar("cameraDistanceMaxZoomFactor", db.minZoomFactor)
                Functions:logMessage("info", "Out of combat: max zoom factor set to " .. db.minZoomFactor .. " after delay.")
            end)
        end

        -- Оновлюємо попередній стан бою
        wasInCombat = inCombat
    end
end


-- *** Налаштування параметрів камери ***
function Functions:AdjustCamera()
    local db = Database.db.profile
    -- Перевірка, чи можна змінювати налаштування камери
    if not InCombatLockdown() and IsLoggedIn() then
        -- Оновлюємо параметри камери
        if db.autoCombatZoom then
            Functions:UpdateCameraOnCombat()  -- Використовуємо правильний виклик функції без `self`
        elseif db.maxZoomFactor then
            UpdateCVar("cameraDistanceMaxZoomFactor", db.maxZoomFactor)
            Functions:logMessage("info", "Adjusted max zoom factor to " .. db.maxZoomFactor .. ".")
        end
        if db.moveViewDistance then
            MoveViewOutStart(db.moveViewDistance)
            Functions:logMessage("info", "Adjusted move view distance to " .. db.moveViewDistance .. ".")
        end
    end
end

-- *** Колбеки для зміни профілів ***
function Functions:OnProfileChanged() Functions:AdjustCamera() end
function Functions:OnProfileCopied() Functions:AdjustCamera() end
function Functions:OnProfileReset() Functions:AdjustCamera() end

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
        Functions:AdjustCamera()  -- Використовуємо правильний виклик функції без `self`
        Functions:logMessage("info", "Settings set to " .. command .. ".")
    elseif command == "config" then
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(settingName)
        else
            Functions:logMessage("error", "Unable to open settings. Settings API unavailable.")
        end
    else
        Functions:SendMessage("Usage: /mcd max | avg | min | config")
    end
end
