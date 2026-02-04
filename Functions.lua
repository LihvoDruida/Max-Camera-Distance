local addonName, ns = ...
ns.Functions = {}
local Functions = ns.Functions
local L = LibStub("AceLocale-3.0"):GetLocale(addonName) or {}
local LibCamera = LibStub("LibCamera-1.0", true)
local ACD = LibStub("AceConfigDialog-3.0")

-- Кешування API
local C_CVar = C_CVar
local C_Timer = C_Timer
local UnitAffectingCombat = UnitAffectingCombat
local IsInInstance = IsInInstance
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
local ZOOM_STATE_NONE   = "none"
local ZOOM_STATE_MOUNT  = "mount"
local ZOOM_STATE_COMBAT = "combat"

local transitionTimer = nil

local isInternalUpdate = false

-- ================= TRAVEL / FLIGHT FORMS & BUFFS (ALL VERSIONS) =================
-- Used for checking shapeshift forms and buffs (UNIT_AURA)
-- Covers Classic → TBC → WotLK → Retail → Shadowlands → Dragonflight

local TRAVEL_FORM_IDS = {
    -- === DRUID ===
    [783]    = true,  -- Travel Form (Classic/Retail - Ground / Cheetah)
    [1066]   = true,  -- Aquatic Form (Classic/Era)
    [276012] = true,  -- Aquatic Form (Retail - Passive buff in water)
    [33943]  = true,  -- Flight Form (Classic/TBC/WotLK/Cata)
    [40120]  = true,  -- Swift Flight Form (Classic/TBC/WotLK/Cata)
    [165962] = true,  -- Flight Form (Retail - Unified)
    [210053] = true,  -- Mount Form (Stag/Doe - Retail)
    [232323] = true,  -- Sentinel Form (Glyph - Owl)
    [29166]  = true,  -- Innervate (Legacy, sometimes returned as a form)

    -- === SHAMAN ===
    [2645]   = true,  -- Ghost Wolf
    [292651] = true,  -- Spectral Wolf (Glyph variation)

    -- === MONK ===
    [125565] = true,  -- Zen Flight (Flying Cloud)

    -- === SHADOWLANDS / TOYS ===
    [310143] = true,  -- Soulshape (Night Fae)
    [311648] = true,  -- Soulshape variations
}

local TRAVEL_BUFF_IDS = {
    -- === EVOKER / DRAGONRIDING ===
    [369536] = true,  -- Soar (General)
    [359618] = true,  -- Soar (Cast / Lift-off)
    [375087] = true,  -- Dragonriding check (Hidden aura)
    [375088] = true,  -- Dragonriding hidden lift-off
    [462245] = true,  -- Skyriding toggle (TWW / DF zones)

    -- === PALADIN DIVINE STEED ===
    [221883] = true,  -- Generic / Retail/BFA+
    [254471] = true,  -- Holy
    [254472] = true,  -- Protection
    [254473] = true,  -- Retribution
    [254474] = true,  -- Glyph of the Trusted Steed
    [221885] = true,  -- Valorous (Legion)
    [221886] = true,  -- Golden / Prot (Legion)
    [221887] = true,  -- Vengeful / Ret (Legion)

    -- === Worgen racial ===
    [87840]  = true,  -- Running Wild

    -- === Tauren racial ===
    [392376] = true,  -- Plainsrunning (SoD / Classic)

    -- === DRUID backup auras ===
    [783]    = true,  -- Travel Form aura
    [165962] = true,  -- Flight Form aura
    [276029] = true,  -- Aquatic Form passive buff
    [232323] = true,  -- Sentinel Form (Glyph Owl)

    -- === SHAMAN backup auras ===
    [2645]   = true,  -- Ghost Wolf
    [292651] = true,  -- Spectral Wolf (Glyph)
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

local function CancelTransition()
    if transitionTimer then
        C_Timer.CancelTimer(transitionTimer)
        transitionTimer = nil
    end
end

local function ApplyZoomTransition(targetYards, transitionTime)
    local targetFactor  = targetYards / CONVERSION_RATIO
    local currentFactor = tonumber(C_CVar.GetCVar("cameraDistanceMaxZoomFactor")) or 0

    if targetFactor < currentFactor then
        if LibCamera then
            LibCamera:SetZoomUsingCVar(targetYards, transitionTime)
        end

        transitionTimer = C_Timer.After(transitionTime + 0.05, function()
            UpdateCVar("cameraDistanceMaxZoomFactor", targetFactor)
        end)
    else
        UpdateCVar("cameraDistanceMaxZoomFactor", targetFactor)

        if LibCamera then
            LibCamera:SetZoomUsingCVar(targetYards, transitionTime)
        end
    end
end

function Functions:UpdateSmartZoomState(event)
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile

    if not db.autoCombatZoom and not db.autoMountZoom then return end

    local inCombat = UnitAffectingCombat("player")
    local inInstance, instanceType = IsInInstance()
    local forceCombat = inInstance and (
        instanceType == "party" or
        instanceType == "raid"  or
        instanceType == "arena" or
        instanceType == "pvp"
    )

    local isMounted = IsInTravelForm()

    local newState = ZOOM_STATE_NONE
    local targetYards = db.minZoomFactor or 15

    if db.autoCombatZoom and (inCombat or forceCombat) then
        newState = ZOOM_STATE_COMBAT
        targetYards = db.maxZoomFactor
    elseif db.autoMountZoom and isMounted then
        newState = ZOOM_STATE_MOUNT
        targetYards = db.mountZoomFactor
    end

    if newState == currentZoomState and event ~= "manual_update" then
        return
    end

    CancelTransition()
    currentZoomState = newState

    local transitionTime = db.zoomTransitionTime or 0.5

    if newState == ZOOM_STATE_NONE and event ~= "manual_update" then
        local delay = db.dismountDelay or 0
        transitionTimer = C_Timer.After(delay, function()
            ApplyZoomTransition(targetYards, transitionTime)
        end)
    else
        ApplyZoomTransition(targetYards, transitionTime)
    end

    Functions:logMessage(
        "info",
        string.format(
            "Smart Zoom → %s (%.1f yards)",
            newState,
            targetYards
        )
    )
end

function Functions:AdjustCamera()
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile
    local LibCamera = LibStub("LibCamera-1.0", true)

    if db.autoCombatZoom and db.autoMountZoom or db.autoCombatZoom then
        Functions:UpdateSmartZoomState("manual_update")

        UpdateCVar("cameraDistanceMoveSpeed", db.moveViewDistance)
        UpdateCVar("cameraReduceUnexpectedMovement", db.reduceUnexpectedMovement and 1 or 0)
        return
    end

    local targetYards  = db.maxZoomFactor
    local targetFactor = targetYards / CONVERSION_RATIO

    UpdateCVar("cameraDistanceMaxZoomFactor", targetFactor)

    if LibCamera then
        LibCamera:SetZoomUsingCVar(targetYards, db.zoomTransitionTime or 0.5)
    end

    Functions:logMessage("info", "Smart zoom disabled, applying fixed max distance.")

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

    if (cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax") then
        if db.autoCombatZoom or db.autoMountZoom then 
            return 
        end
    end

    local numValue = tonumber(value) or 0

    if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax" then
        local yards = numValue * CONVERSION_RATIO
        if yards > 1 and math.abs(db.maxZoomFactor - yards) > 0.1 then
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

    if not (ns.Database and ns.Database.db) then 
        Functions:SendMessage(L["DB_NOT_READY"] or "Database not ready.")
        return 
    end
    
    local db = ns.Database.db.profile

    if command == "config" then
        -- Відкриття налаштувань через AceConfigDialog
        if ACD then
            ACD:Open(addonName) 
        else
            Functions:SendMessage("Error: AceConfigDialog not found. Cannot open settings.")
        end

    elseif command == "autozoom" then
        -- Перемикач Combat Zoom
        db.autoCombatZoom = not db.autoCombatZoom
        Functions:AdjustCamera() -- Застосовуємо зміни одразу
        
        local state = db.autoCombatZoom and (L["ENABLED"] or "|cff00ff00Enabled|r") or (L["DISABLED"] or "|cffff0000Disabled|r")
        Functions:SendMessage("Auto Combat Zoom: " .. state)

    elseif command == "automount" then
        -- Перемикач Mount Zoom
        db.autoMountZoom = not db.autoMountZoom
        Functions:AdjustCamera() -- Застосовуємо зміни одразу
        
        local state = db.autoMountZoom and (L["ENABLED"] or "|cff00ff00Enabled|r") or (L["DISABLED"] or "|cffff0000Disabled|r")
        Functions:SendMessage("Auto Mount Zoom: " .. state)

    else
        -- Оновлена довідка
        Functions:SendMessage(L["CMD_USAGE"] or "Usage: /mcd config | autozoom | automount")
    end
end