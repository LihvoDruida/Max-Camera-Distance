local addonName, ns = ...
ns.Functions = {}
local Functions = ns.Functions
local L = LibStub("AceLocale-3.0"):GetLocale(addonName) or {}
local LibCamera = LibStub("LibCamera-1.0", true)

-- Кешування API
local C_CVar = C_CVar
local C_Timer = C_Timer
local UnitAffectingCombat = UnitAffectingCombat
local IsInInstance = IsInInstance
local GetTime = GetTime

-- *** КОНСТАНТИ КОНВЕРТАЦІЇ ***
local IS_RETAIL = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local CONVERSION_RATIO = IS_RETAIL and 15 or 12.5

-- Змінні стану
local wasInCombat = false
local lastCombatUpdate = 0
local combatCooldown = 1.0 
local SETTING_CATEGORY_NAME = "Max Camera Distance"

-- !!! ВАЖЛИВО: Прапорець для запобігання конфліктам !!!
local isInternalUpdate = false

-- *** Виведення повідомлень ***
function Functions:SendMessage(message)
    print("|cff0070deMax Camera Distance|r: " .. tostring(message))
end

-- *** Логування ***
function Functions:logMessage(level, message)
    if not (ns.Database and ns.Database.db and ns.Database.db.profile and ns.Database.db.profile.enableDebugLogging) then return end
    
    local db = ns.Database.db.profile
    if not (db.debugLevel and db.debugLevel[level]) then return end

    local color = "|cffffffff"
    local prefix = "[D]"
    if level == "error" then color, prefix = "|cffff0000", "[E]"
    elseif level == "warning" then color, prefix = "|cffffff00", "[W]"
    elseif level == "info" then color, prefix = "|cff00ff00", "[I]"
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff0070deMCD|r %s: %s%s|r", prefix, color, message))
end

-- *** Зміна CVAR (Внутрішня функція) ***
local function UpdateCVar(key, value)
    local strValue = tostring(value)
    local currentValue = C_CVar.GetCVar(key)
    
    if currentValue ~= strValue then
        -- Вмикаємо захист: це зміна від аддона, а не від гравця
        isInternalUpdate = true
        
        local success = pcall(C_CVar.SetCVar, key, value)
        
        -- Вимикаємо захист після зміни
        isInternalUpdate = false
        
        if success then
            Functions:logMessage("info", "Updated " .. key .. " to " .. strValue)
        else
            Functions:logMessage("error", "Failed to set CVar: " .. key)
        end
    end
end

function Functions:AdjustCamera()
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile
    local LibCamera = LibStub("LibCamera-1.0", true)

    -- 1. Спочатку завжди розблокуємо МАКСИМАЛЬНИЙ ліміт гри (CVar)
    -- Нам потрібно, щоб "стеля" завжди була високою, інакше в бою камера вперлася б у старий ліміт.
    local limitFactor = db.maxZoomFactor / CONVERSION_RATIO
    UpdateCVar("cameraDistanceMaxZoomFactor", limitFactor)

    -- 2. Визначаємо, куди саме зараз треба зумити камеру (Target Yards)
    local targetYards = db.maxZoomFactor -- За замовчуванням - максимум

    -- Якщо увімкнено "Розумний Зум"
    if db.autoCombatZoom then
        local inCombat = UnitAffectingCombat("player")
        
        -- Також перевіряємо, чи ми в інстансі (де часто краще мати бойовий зум завжди)
        local inInstance, instanceType = IsInInstance()
        local forceCombatMode = inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "arena" or instanceType == "pvp")
        
        if inCombat or forceCombatMode then
            targetYards = db.maxZoomFactor
        else
            -- Якщо ми в мирі (і налаштовуємо аддон), використовуємо Min
            targetYards = db.minZoomFactor or 28.5
        end
    end

    -- 3. Застосовуємо зум через LibCamera
    if LibCamera then
        -- Використовуємо 0.5 сек для плавності, або швидше, якщо це просто оновлення налаштувань
        LibCamera:SetZoomUsingCVar(targetYards, 0.5)
    end

    -- 4. Інші налаштування (швидкість, рух тощо)
    UpdateCVar("cameraDistanceMoveSpeed", db.moveViewDistance)
    UpdateCVar("cameraReduceUnexpectedMovement", db.reduceUnexpectedMovement and 1 or 0)
    UpdateCVar("cameraYawMoveSpeed", db.cameraYawMoveSpeed)
    UpdateCVar("cameraPitchMoveSpeed", db.cameraPitchMoveSpeed)
    UpdateCVar("cameraIndirectVisibility", db.cameraIndirectVisibility and 1 or 0)

    Functions:logMessage("info", string.format("Camera adjusted to %.1f yards (Limit: %.1f)", targetYards, db.maxZoomFactor))
end

-- *** Оновлення камери при бою ***
function Functions:UpdateCameraOnCombat(event)
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile
    
    if not db.autoCombatZoom then return end

    local currentTime = GetTime()
    if (currentTime - lastCombatUpdate) < combatCooldown then return end
    lastCombatUpdate = currentTime

    local realCombatState = UnitAffectingCombat("player")
    local inInstance, instanceType = IsInInstance()
    local forceCombatMode = inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "arena" or instanceType == "pvp")
    local effectiveCombatState = realCombatState or forceCombatMode

    if effectiveCombatState ~= wasInCombat then
        wasInCombat = effectiveCombatState
        
        -- Цільова дистанція (в ярдах)
        -- Якщо minZoomFactor не задано (nil), беремо 28.5 як страховку
        local safeMin = db.minZoomFactor or 28.5
        local targetYards = effectiveCombatState and db.maxZoomFactor or safeMin
        
        local delay = effectiveCombatState and 0 or (db.dismountDelay or 0)

        C_Timer.After(delay, function()
            local currentCombatState = UnitAffectingCombat("player") or forceCombatMode
            
            if currentCombatState == effectiveCombatState then
                -- !!! ВИПРАВЛЕННЯ ЛОГІКИ !!!
                -- Ми НЕ змінюємо CVar limit до targetYards. Ми залишаємо CVar на максимумі (щоб гравець міг сам віддалити потім).
                -- Ми змінюємо лише поточну позицію камери через LibCamera.
                
                -- Переконуємось, що ліміт стоїть на Максимумі (на випадок, якщо щось збилось)
                local maxFactor = db.maxZoomFactor / CONVERSION_RATIO
                UpdateCVar("cameraDistanceMaxZoomFactor", maxFactor)

                -- Зумимо камеру до потрібної точки (ближче або далі)
                if LibCamera then
                    LibCamera:SetZoomUsingCVar(targetYards, 0.5)
                end
                
                Functions:logMessage("info", string.format("Combat zoom: %.1f yards", targetYards))
            end
        end)
    end
end

-- *** Обробка CVAR_UPDATE (Синхронізація зворотнього боку) ***
function Functions:OnCVarUpdate(_, cvarName, value)
    -- !!! БЛОКУВАННЯ !!!
    -- Якщо ми самі змінюємо CVar через код (UpdateCVar), ігноруємо цю подію.
    if isInternalUpdate then return end

    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile
    
    local numValue = tonumber(value) or 0

    if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax" then
        local yards = numValue * CONVERSION_RATIO
        
        -- Оновлюємо базу тільки якщо це РЕАЛЬНА зміна від гравця (через консоль/інші аддони)
        if math.abs(db.maxZoomFactor - yards) > 0.1 then
            db.maxZoomFactor = yards
            Functions:logMessage("info", string.format("DB synced from CVar: %.1f factor -> %.1f yards", numValue, yards))
        end

    elseif cvarName == "cameraDistanceMoveSpeed" then
        db.moveViewDistance = numValue
    elseif cvarName == "cameraYawMoveSpeed" then
        db.cameraYawMoveSpeed = numValue
    elseif cvarName == "cameraPitchMoveSpeed" then
        db.cameraPitchMoveSpeed = numValue
    elseif cvarName == "cameraReduceUnexpectedMovement" then
        db.reduceUnexpectedMovement = (numValue == 1)
    elseif cvarName == "cameraIndirectVisibility" then
        db.cameraIndirectVisibility = (numValue == 1)
    end
end

-- *** Slash-команди ***
function Functions:SlashCmdHandler(msg)
    local command = strlower(msg or "")
    
    local settings = {
        max = IS_RETAIL and 39 or 50,
        avg = 20,
        min = 5
    }

    if not (ns.Database and ns.Database.db) then 
        Functions:SendMessage(L["DB_NOT_READY"] or "Database not ready.")
        return 
    end
    
    local db = ns.Database.db.profile

    if settings[command] then
        local yards = settings[command]
        db.maxZoomFactor = yards
        Functions:AdjustCamera()
        Functions:SendMessage(string.format("Zoom set to %s (%.1f yards)", command, yards))
        
    elseif command == "config" then
        if Settings and Settings.OpenToCategory then
            local categoryID = Settings.GetCategoryID and Settings.GetCategoryID(SETTING_CATEGORY_NAME)
            if categoryID then
                 Settings.OpenToCategory(categoryID)
            else
                 Settings.OpenToCategory(SETTING_CATEGORY_NAME)
            end
        else
            Functions:SendMessage("Error: Settings API not available.")
        end
    else
        Functions:SendMessage("Usage: /mcd max | avg | min | config")
    end
end