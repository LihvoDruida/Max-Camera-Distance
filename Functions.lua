Functions = {}

local addonName = "Max_Camera_Distance"
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local CVar = C_CVar

-- Функція для виведення повідомлень в чат
function Functions:SendMessage(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff0070deMax Camera Distance|r: " .. message)
end

-- Функція для зміни налаштувань камери
function Functions:ChangeCameraSetting(key, value, message)
    if IsLoggedIn() then
        local db = Database.db.profile -- Оновлення db з актуальної бази даних
        db[key] = value
        self:AdjustCamera()
        self:SendMessage(message)

        -- Виводимо значення для перевірки
        -- print("Setting changed:", key, value)
    else
        self:SendMessage(L["Cannot change settings while in character edit mode."])
    end
end

-- Функція для налаштування камери
function Functions:AdjustCamera()
    -- Отримання налаштувань з бази даних
    local db = Database.db.profile -- Оновлення db з актуальної бази даних
    if not InCombatLockdown() and IsLoggedIn() then
        -- Налаштування максимального зуму
        if db.maxZoomFactor then
            SetCVar("cameraDistanceMaxZoomFactor", db.maxZoomFactor)
        end

        -- Налаштування дистанції перегляду
        if db.moveViewDistance then
            MoveViewOutStart(db.moveViewDistance)
        end

        -- Налаштування зменшення несподіваних рухів камери
        if db.reduceUnexpectedMovement ~= nil then
            CVar.SetCVar("cameraReduceUnexpectedMovement", db.reduceUnexpectedMovement and "1" or "0")
        end

        -- Налаштування різкості при ресемплінгу
        if db.resampleAlwaysSharpen ~= nil then
            CVar.SetCVar("ResampleAlwaysSharpen", db.resampleAlwaysSharpen and "1" or "0")
        end

        -- Налаштування непрямої видимості камери
        if db.cameraIndirectVisibility ~= nil then
            CVar.SetCVar("cameraIndirectVisibility", db.cameraIndirectVisibility and "1" or "0")

            -- Залежно від cameraIndirectVisibility змінюємо cameraIndirectOffset
            if db.cameraIndirectVisibility then
                SetCVar("cameraIndirectOffset", 1.5)
            else
                SetCVar("cameraIndirectOffset", 10)
            end
        end

        -- Налаштування швидкості повороту (Yaw)
        if db.cameraYawMoveSpeed then
            SetCVar("cameraYawMoveSpeed", db.cameraYawMoveSpeed)
        end

        -- Налаштування швидкості нахилу (Pitch)
        if db.cameraPitchMoveSpeed then
            SetCVar("cameraPitchMoveSpeed", db.cameraPitchMoveSpeed)
        end

        -- print("Adjusting camera with settings:", db)
    end
end

-- Функція для обробки оновлення CVAR
function Functions:OnCVarUpdate(_, cvarName, value)
    local cvarHandlers = {
        ["cameraDistanceMaxZoomFactor"] = function()
            self:ChangeCameraSetting("maxZoomFactor", tonumber(value),
                L["SETTINGS_CHANGED"])
        end,
        ["cameraDistanceMoveSpeed"] = function()
            self:ChangeCameraSetting("moveViewDistance", tonumber(value),
                L["SETTINGS_CHANGED"])
        end,
        ["cameraReduceUnexpectedMovement"] = function()
            self:ChangeCameraSetting("reduceUnexpectedMovement",
                tonumber(value) == 1, L["SETTINGS_CHANGED"])
        end,
        ["cameraYawMoveSpeed"] = function()
            self:ChangeCameraSetting("cameraYawMoveSpeed", tonumber(value),
                L["SETTINGS_CHANGED"])
        end,
        ["cameraPitchMoveSpeed"] = function()
            self:ChangeCameraSetting("cameraPitchMoveSpeed", tonumber(value),
                L["SETTINGS_CHANGED"])
        end,
        ["cameraIndirectVisibility"] = function()
            self:ChangeCameraSetting("cameraIndirectVisibility", tonumber(value) == 1,
                L["SETTINGS_CHANGED"])
        end,
    }

    if cvarHandlers[cvarName] then
        cvarHandlers[cvarName]()
    end
end

-- Функція для обробки Slash команд
function Functions:SlashCmdHandler(msg)
    if not msg then
        self:SendMessage(L["Usage: /maxcamdist max | avg | min | config"])
        return
    end

    local command = strlower(msg)
    local settings = {
        max = { zoomFactor = 2.6, moveDistance = 50000, message = L["SETTINGS_SET_TO_MAX"] },
        avg = { zoomFactor = 2.0, moveDistance = 30000, message = L["SETTINGS_SET_TO_AVERAGE"] },
        min = { zoomFactor = 1.0, moveDistance = 10000, message = L["SETTINGS_SET_TO_MIN"] }
    }

    local setting = settings[command]
    if setting then
        self:ChangeCameraSetting("maxZoomFactor", setting.zoomFactor, setting.message)
        self:ChangeCameraSetting("moveViewDistance", setting.moveDistance, setting.message)
    elseif command == "config" then
        InterfaceOptionsFrame_OpenToCategory(addonName)
    else
        self:SendMessage(L["Usage: /maxcamdist max | avg | min | config"])
    end
end

-- Callback functions
function Functions:OnProfileChanged()
    self:AdjustCamera()
end

function Functions:OnProfileCopied()
    self:AdjustCamera()
end

function Functions:OnProfileReset()
    self:AdjustCamera()
end