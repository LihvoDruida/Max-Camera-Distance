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
local IsMounted = IsMounted
local GetShapeshiftForm = GetShapeshiftForm
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local UnitBuff = UnitBuff

-- *** КОНСТАНТИ КОНВЕРТАЦІЇ ***
local IS_RETAIL = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local CONVERSION_RATIO = IS_RETAIL and 15 or 12.5

-- Змінні стану
local currentZoomState = "none" -- "combat", "mount", "none"
local lastStateUpdate = 0
local stateCooldown = 0.5 
local SETTING_CATEGORY_NAME = "Max Camera Distance"

local isInternalUpdate = false

-- *** СПИСКИ ФОРМ ТА БАФІВ (LOOKUP TABLES) ***

-- 1. Форми (Shapeshift Forms) - перевіряються через GetShapeshiftForm
local TRAVEL_FORM_IDS = {
    -- === DRUID ===
    [783]    = true, -- Travel Form (Retail & Classic Base)
    [1066]   = true, -- Aquatic Form (Classic/Cata)
    [33943]  = true, -- Flight Form (Classic/Cata)
    [40120]  = true, -- Swift Flight Form (Classic/Cata)
    [165962] = true, -- Flight Form (Retail)
    [210053] = true, -- Stag Form (Retail)
    [29166]  = true, -- Innervate/Old Flight logic
    -- [24858]  = true, -- Moonkin Form (Base)
    -- [197625] = true, -- Moonkin Form (Retail Glyph)
    
    -- === SHAMAN ===
    [2645]   = true, -- Ghost Wolf
    
    -- === MONK ===
    [125565] = true, -- Zen Flight (Retail)
}

-- 2. Аури (Buffs) - перевіряються через UnitBuff/C_UnitAuras
-- Потрібно для Паладинів, Драктирів та деяких проків
local TRAVEL_BUFF_IDS = {
    -- === PALADIN ===
    [221883] = true, -- Divine Steed (Retail)
    [254474] = true, -- Divine Steed (Legion/BFA variants)
    
    -- === EVOKER (Dracthyr) ===
    [369536] = true, -- Soar (Buff state)
    [359618] = true, -- Soar (Alternative)

    -- === DEMON HUNTER ===
    -- [162264] = true, -- Metamorphosis (Havoc) - Розкоментуйте, якщо хочете зум у метаморфозі
    -- [187827] = true, -- Metamorphosis (Vengeance)
    
    -- === DRUID (Special) ===
    [1850] = true, -- Dash (Optional)
}

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

-- !!! ДОПОМІЖНА ФУНКЦІЯ: Перевірка "швидкої форми" !!!
local function IsInTravelForm()
    -- 1. Якщо гравець на звичайному маунті - це завжди Travel
    if IsMounted() then return true end
    
    -- 2. Перевірка ФОРМ (Shapeshift) - Druid, Shaman, Rogue Stealth
    local formIndex = GetShapeshiftForm()
    if formIndex and formIndex > 0 then
        -- GetShapeshiftFormInfo повертає spellID 4-м аргументом
        local _, _, _, spellID = GetShapeshiftFormInfo(formIndex)
        if spellID and TRAVEL_FORM_IDS[spellID] then 
            return true 
        end
    end
    
    -- 3. Перевірка АУР (Buffs) - Paladin Divine Steed, Evoker Soar
    -- Ця операція трохи важча, тому виконуємо її останньою
    if IS_RETAIL then
        -- Оптимізований метод для Retail (11.0+)
        for i = 1, 40 do
            local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
            if not aura then break end -- Кінець списку
            if TRAVEL_BUFF_IDS[aura.spellId] then return true end
        end
    else
        -- Класичний метод для Era/Cata
        for i = 1, 40 do
            local _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
            if not spellID then break end
            if TRAVEL_BUFF_IDS[spellID] then return true end
        end
    end

    return false
end

-- !!! ПЕРЕПИСАНА ФУНКЦІЯ: Розумний Зум (Бій + Маунт) !!!
function Functions:UpdateSmartZoomState(event)
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile
    
    -- Якщо обидві функції вимкнені — виходимо
    if not db.autoCombatZoom and not db.autoMountZoom then return end

    local currentTime = GetTime()
    if (currentTime - lastStateUpdate) < 0.1 then return end
    lastStateUpdate = currentTime

    -- 1. Визначаємо поточний стан (ПРІОРИТЕТИ)
    local newState = "none"
    local targetYards = db.minZoomFactor or 28.5
    
    local inCombat = UnitAffectingCombat("player")
    local inInstance, instanceType = IsInInstance()
    local forceCombatMode = inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "arena" or instanceType == "pvp")

    -- ПРІОРИТЕТ 1: Бій (Combat) - Найвищий пріоритет
    if db.autoCombatZoom and (inCombat or forceCombatMode) then
        newState = "combat"
        targetYards = db.maxZoomFactor -- Combat Max (він же загальний Max)
        
    -- ПРІОРИТЕТ 2: Маунт / Подорож (Mount) - Середній пріоритет
    -- Працює тільки якщо ми НЕ в бою
    elseif db.autoMountZoom and IsInTravelForm() then
        newState = "mount"
        targetYards = db.mountZoomFactor
        
    -- ПРІОРИТЕТ 3: Спокій (None) - Низький пріоритет
    else
        newState = "none"
        -- targetYards вже встановлено на minZoomFactor
    end

    -- 2. Якщо стан не змінився — нічого не робимо
    if newState == currentZoomState then return end

    -- 3. Логіка затримки (Dismount Delay)
    -- Затримка потрібна, коли ми виходимо зі стану "далеко" в стан "близько"
    local isZoomingOut = (newState == "combat") or (newState == "mount")
    local delay = isZoomingOut and 0 or (db.dismountDelay or 0)

    -- Оновлюємо змінну стану
    currentZoomState = newState

    C_Timer.After(delay, function()
        -- Повторна перевірка стану після затримки
        local reCheckCombat = UnitAffectingCombat("player") or forceCombatMode
        local reCheckMount = IsInTravelForm()
        
        local validatedState = "none"
        if db.autoCombatZoom and reCheckCombat then validatedState = "combat"
        elseif db.autoMountZoom and reCheckMount then validatedState = "mount"
        end

        if validatedState == newState then
             -- Переконуємось, що ліміт CVar дозволяє цей зум
             local requiredLimit = math.max(targetYards, db.maxZoomFactor)
             local limitFactor = requiredLimit / CONVERSION_RATIO
             UpdateCVar("cameraDistanceMaxZoomFactor", limitFactor)

             if LibCamera then
                 LibCamera:SetZoomUsingCVar(targetYards, 0.5)
             end
             
             Functions:logMessage("info", string.format("Smart Zoom [%s]: %.1f yards", newState, targetYards))
        else
            Functions:logMessage("debug", "State changed during delay, skipping zoom.")
            currentZoomState = validatedState
        end
    end)
end

function Functions:AdjustCamera()
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile
    local LibCamera = LibStub("LibCamera-1.0", true)

    -- 1. Спочатку завжди розблокуємо МАКСИМАЛЬНИЙ ліміт гри (CVar)
    local limitFactor = db.maxZoomFactor / CONVERSION_RATIO
    UpdateCVar("cameraDistanceMaxZoomFactor", limitFactor)

    -- 2. Викликаємо нашу нову логіку, щоб вона сама вирішила, який зум ставити
    -- Передаємо "manual_update", щоб функція знала, що це примусовий виклик
    Functions:UpdateSmartZoomState("manual_update")

    -- 3. Інші налаштування
    UpdateCVar("cameraDistanceMoveSpeed", db.moveViewDistance)
    UpdateCVar("cameraReduceUnexpectedMovement", db.reduceUnexpectedMovement and 1 or 0)
    UpdateCVar("cameraYawMoveSpeed", db.cameraYawMoveSpeed)
    UpdateCVar("cameraPitchMoveSpeed", db.cameraPitchMoveSpeed)
    UpdateCVar("cameraIndirectVisibility", db.cameraIndirectVisibility and 1 or 0)
    UpdateCVar("resampleAlwaysSharpen", db.resampleAlwaysSharpen and 1 or 0)
    UpdateCVar("SoftTargetIconGameObject", db.softTargetInteract and 1 or 0)

    Functions:logMessage("info", "Settings applied manually.")
end

-- *** Обробка CVAR_UPDATE (Синхронізація зворотнього боку) ***
function Functions:OnCVarUpdate(_, cvarName, value)
    -- !!! БЛОКУВАННЯ !!!
    if isInternalUpdate then return end

    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile
    
    local numValue = tonumber(value) or 0

    if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax" then
        local yards = numValue * CONVERSION_RATIO
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
    elseif cvarName == "resampleAlwaysSharpen" then
        db.resampleAlwaysSharpen = (numValue == 1)
    elseif cvarName == "SoftTargetIconGameObject" then
        db.softTargetInteract = (numValue == 1)
    end
end

function Functions:ClearAllQuestTracking()
    local numWatches = C_QuestLog.GetNumQuestWatches()
    if numWatches == 0 then
        Functions:SendMessage("Quest tracker is already empty.")
        return
    end

    -- Видаляємо у зворотньому порядку, щоб не порушити індексацію
    for i = numWatches, 1, -1 do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID then
            C_QuestLog.RemoveQuestWatch(questID)
        end
    end
    Functions:SendMessage("Stopped tracking " .. numWatches .. " quests.")
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