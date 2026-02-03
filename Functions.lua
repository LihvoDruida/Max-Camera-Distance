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
-- UnitBuff видалено з локальних змінних, бо його немає в Retail

-- *** КОНСТАНТИ КОНВЕРТАЦІЇ ***
local IS_RETAIL = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local CONVERSION_RATIO = IS_RETAIL and 15 or 12.5

-- Змінні стану
local currentZoomState = "none" -- "combat", "mount", "none"
local SETTING_CATEGORY_NAME = "Max Camera Distance"

local isInternalUpdate = false
local updateTimerHandle = nil -- Для таймера оновлення (Debounce)

-- *** СПИСКИ ФОРМ ТА БАФІВ ***
local TRAVEL_FORM_IDS = {
    -- === DRUID (Classic -> Retail) ===
    [783]    = true, -- Travel Form (Ground)
    [1066]   = true, -- Aquatic Form
    [33943]  = true, -- Flight Form (Classic/TBC/WotLK)
    [40120]  = true, -- Swift Flight Form (Classic/TBC/WotLK)
    [165962] = true, -- Flight Form (Retail - All in one)
    [210053] = true, -- Stag Form (Glyph/Book)
    
    -- === SHAMAN ===
    [2645]   = true, -- Ghost Wolf
    
    -- === MONK ===
    [125565] = true, -- Zen Flight
}

local TRAVEL_BUFF_IDS = {
    -- === EVOKER (Dracthyr Soar / Skyriding) ===
    -- Це расова здібність польоту (не маунт), тому потрібен ID
    [369536] = true, -- Soar (General)
    [359618] = true, -- Soar (Cast/Buff phase)
    [375087] = true, -- Dragonriding Check (Іноді висить як прихована аура)

    -- === PALADIN (Divine Steed - "Konyk") ===
    [221883] = true, -- Divine Steed (Generic)
    [254474] = true, -- Divine Steed (Protection)
    [254471] = true, -- Divine Steed (Holy)
    [254472] = true, -- Divine Steed (Retribution)
    [254473] = true, -- Divine Steed (Glyph)

    -- === WORGEN ===
    [87840]  = true, -- Running Wild (Біг на чотирьох лапах)

    -- === DRUID (Backup for Buffs) ===
    [783]    = true, -- Travel Form aura
    [165962] = true, -- Flight Form aura
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

-- *** Зміна CVAR ***
local function UpdateCVar(key, value)
    local strValue = tostring(value)
    local currentValue = C_CVar.GetCVar(key)
    if currentValue ~= strValue then
        isInternalUpdate = true
        pcall(C_CVar.SetCVar, key, value)
        isInternalUpdate = false
        if Functions.logMessage then Functions:logMessage("info", "Updated " .. key .. " to " .. strValue) end
    end
end

local function IsInTravelForm()
    -- 1. Звичайний маунт
    if IsMounted() then
        return true
    end

    -- 2. Shapeshift-форми (друїд, шаман, монах)
    local formIndex = GetShapeshiftForm()
    if formIndex and formIndex > 0 then
        local _, _, _, spellID = GetShapeshiftFormInfo(formIndex)
        if spellID and TRAVEL_FORM_IDS[spellID] then
            return true
        end
    end

    -- 3. Бафи / аури
    if IS_RETAIL then
        -- ✅ Retail-safe метод (10.x / 11.x)
        -- Без unitID, без перебору, без private aura проблем
        for spellID in pairs(TRAVEL_BUFF_IDS) do
            if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
                return true
            end
        end
    else
        -- ✅ Classic метод
        local UnitBuff = _G.UnitBuff
        if UnitBuff then
            for i = 1, 40 do
                local _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
                if not spellID then break end
                if TRAVEL_BUFF_IDS[spellID] then
                    return true
                end
            end
        end
    end

    return false
end


-- *** UpdateSmartZoomState ***
function Functions:UpdateSmartZoomState(event)
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile
    
    if not db.autoCombatZoom and not db.autoMountZoom then return end

    local isManual = (event == "manual_update")
    
    if updateTimerHandle then C_Timer.CancelTimer(updateTimerHandle) end

    updateTimerHandle = C_Timer.After(0.05, function()
        local newState = "none"
        local targetYards = db.minZoomFactor or 28.5
        
        local inCombat = UnitAffectingCombat("player")
        local inInstance, instanceType = IsInInstance()
        local forceCombatMode = inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "arena" or instanceType == "pvp")

        if db.autoCombatZoom and (inCombat or forceCombatMode) then
            newState = "combat"
            targetYards = db.maxZoomFactor
        elseif db.autoMountZoom and IsInTravelForm() then
            newState = "mount"
            targetYards = db.mountZoomFactor or 39
        else
            newState = "none"
        end

        if not isManual and newState == currentZoomState then return end

        local isRestoring = (newState == "none")
        local delay = (not isManual and isRestoring) and (db.dismountDelay or 0) or 0

        currentZoomState = newState

        C_Timer.After(delay, function()
            local reCheckCombat = UnitAffectingCombat("player") or forceCombatMode
            local reCheckMount = IsInTravelForm()
            
            local validatedState = "none"
            if db.autoCombatZoom and reCheckCombat then validatedState = "combat"
            elseif db.autoMountZoom and reCheckMount then validatedState = "mount"
            end

            if validatedState == newState or isManual then
                 local requiredLimit = math.max(targetYards, db.maxZoomFactor)
                 local limitFactor = requiredLimit / CONVERSION_RATIO
                 UpdateCVar("cameraDistanceMaxZoomFactor", limitFactor)

                 if LibCamera then
                     LibCamera:SetZoomUsingCVar(targetYards, db.zoomTransitionTime or 0.5)
                 end
                 
                 Functions:logMessage("info", string.format("Smart Zoom [%s]: %.1f yards", newState, targetYards))
            else
                currentZoomState = validatedState
                Functions:logMessage("debug", "State changed during delay, skipping zoom.")
            end
        end)
    end)
end

function Functions:AdjustCamera()
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile
    local LibCamera = LibStub("LibCamera-1.0", true)

    local limitFactor = db.maxZoomFactor / CONVERSION_RATIO
    UpdateCVar("cameraDistanceMaxZoomFactor", limitFactor)

    if db.autoCombatZoom or db.autoMountZoom then
        Functions:UpdateSmartZoomState("manual_update")
    else
        if LibCamera then
            LibCamera:SetZoomUsingCVar(db.maxZoomFactor, db.zoomTransitionTime or 0.5)
        end
        Functions:logMessage("info", "Smart zoom disabled, applying max distance.")
    end

    UpdateCVar("cameraDistanceMoveSpeed", db.moveViewDistance)
    UpdateCVar("cameraReduceUnexpectedMovement", db.reduceUnexpectedMovement and 1 or 0)
    UpdateCVar("cameraYawMoveSpeed", db.cameraYawMoveSpeed)
    UpdateCVar("cameraPitchMoveSpeed", db.cameraPitchMoveSpeed)
    UpdateCVar("cameraIndirectVisibility", db.cameraIndirectVisibility and 1 or 0)
    UpdateCVar("resampleAlwaysSharpen", db.resampleAlwaysSharpen and 1 or 0)
    UpdateCVar("SoftTargetIconGameObject", db.softTargetInteract and 1 or 0)
end

function Functions:OnCVarUpdate(_, cvarName, value)
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
        Functions:SendMessage(L["QUEST_TRACKER_EMPTY"] or "Quest tracker is already empty.")
        return
    end
    for i = numWatches, 1, -1 do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID then
            C_QuestLog.RemoveQuestWatch(questID)
        end
    end
    Functions:SendMessage(string.format(L["QUEST_TRACKER_CLEARED"] or "Stopped tracking %d quests.", numWatches))
end

function Functions:SlashCmdHandler(msg)
    local command = strlower(msg or "")
    local settings = { max = IS_RETAIL and 39 or 50, avg = 20, min = 5 }

    if not (ns.Database and ns.Database.db) then 
        Functions:SendMessage(L["DB_NOT_READY"] or "Database not ready.")
        return 
    end
    
    local db = ns.Database.db.profile

    if settings[command] then
        local yards = settings[command]
        db.maxZoomFactor = yards
        Functions:AdjustCamera()
        local msgFormat = L["ZOOM_SET_MESSAGE"] or "Zoom set to %s (%.1f yards)"
        Functions:SendMessage(string.format(msgFormat, command, yards))
    elseif command == "config" then
        if Settings and Settings.OpenToCategory then
            local categoryID = Settings.GetCategoryID and Settings.GetCategoryID(SETTING_CATEGORY_NAME)
            if categoryID then Settings.OpenToCategory(categoryID)
            else Settings.OpenToCategory(SETTING_CATEGORY_NAME) end
        else
            Functions:SendMessage("Error: Settings API not available.")
        end
    else
        Functions:SendMessage(L["CMD_USAGE"] or "Usage: /mcd max | avg | min | config")
    end
end