local addonName, ns = ...
ns.Functions = {}
local Functions = ns.Functions
local L = LibStub("AceLocale-3.0"):GetLocale(addonName) or {}
local LibCamera = LibStub("LibCamera-1.0", true)
local LibMountInfo = LibStub("LibMountInfo-1.0", true)
local ACD = LibStub("AceConfigDialog-3.0")

-- ============================================================================
-- 1. API CACHE & CONSTANTS
-- ============================================================================
local C_CVar = C_CVar
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local UnitAffectingCombat = UnitAffectingCombat
local UnitThreatSituation = UnitThreatSituation -- ДОДАНО: Для перевірки агро
local IsInInstance = IsInInstance
local IsMounted = IsMounted
local GetShapeshiftForm = GetShapeshiftForm
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local UnitIsAFK = UnitIsAFK
local MoveViewRightStart = MoveViewRightStart
local MoveViewRightStop = MoveViewRightStop
local GetCameraZoom = GetCameraZoom
local IsEncounterInProgress = IsEncounterInProgress

local IS_RETAIL = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local CONVERSION_RATIO = IS_RETAIL and 15 or 12.5

-- ============================================================================
-- 2. STATE VARIABLES
-- ============================================================================
local currentZoomState = "none"
local ZOOM_STATE_NONE   = "none"
local ZOOM_STATE_MOUNT  = "mount"
local ZOOM_STATE_COMBAT = "combat"

local transitionTimer = nil
local isInternalUpdate = false

-- Throttling
local updatePending = false
local updateFrame = CreateFrame("Frame")

-- AFK Variables
local wasAFK = false
local savedYawSpeed = 180
local AFK_YAW_SPEED = 4

-- FRAMES
local safeExitFrame = CreateFrame("Frame", "MCD_SafeExitFrame", UIParent)
local shoulderHandlerFrame = CreateFrame("Frame")

-- ============================================================================
-- 3. DATA TABLES (FALLBACK)
-- ============================================================================
local TRAVEL_FORM_IDS = {
    [783]=true, [1066]=true, [276012]=true, [33943]=true, [40120]=true, 
    [165962]=true, [210053]=true, [232323]=true, [29166]=true,
    [2645]=true, [292651]=true, [125565]=true, [310143]=true, [311648]=true
}

local TRAVEL_BUFF_IDS = {
    [369536]=true, [359618]=true, [375087]=true, [375088]=true, [462245]=true,
    [221883]=true, [254471]=true, [254472]=true, [254473]=true, [254474]=true,
    [221885]=true, [221886]=true, [221887]=true, [87840]=true, [392376]=true,
    [783]=true, [165962]=true, [276029]=true, [232323]=true, [2645]=true, [292651]=true
}

-- ============================================================================
-- 4. UTILITY FUNCTIONS
-- ============================================================================

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

function Functions:SendMessage(message)
    print("|cff0070deMax Camera Distance|r: " .. tostring(message))
end

local function UpdateCVar(key, value)
    local strValue = tostring(value)
    local currentValue = C_CVar.GetCVar(key)
    
    if not currentValue then return end

    if type(value) == "number" then
        local numCurrent = tonumber(currentValue)
        if numCurrent and math.abs(numCurrent - value) < 0.005 then
            return 
        end
    elseif currentValue == strValue then
        return
    end

    isInternalUpdate = true
    pcall(C_CVar.SetCVar, key, value)
    isInternalUpdate = false
end

function Functions:IsSkyriding()
    if IsMounted() and LibMountInfo then
        return LibMountInfo:IsSkyriding()
    end

    if IS_RETAIL then
        if C_UnitAuras.GetPlayerAuraBySpellID(404464) then return true end
        if C_UnitAuras.GetPlayerAuraBySpellID(404468) then return false end
    end
    return true
end

local function IsInTravelForm()
    if LibMountInfo then
        if LibMountInfo:IsMounted() then return true end
    else
        if IsMounted() then return true end
    end

    local formIndex = GetShapeshiftForm()
    if formIndex and formIndex > 0 then
        local _, _, _, spellID = GetShapeshiftFormInfo(formIndex)
        if spellID and TRAVEL_FORM_IDS[spellID] then return true end
    end

    if IS_RETAIL then
        for spellID in pairs(TRAVEL_BUFF_IDS) do
            if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then return true end
        end
    else
        local UnitBuff = _G.UnitBuff
        if UnitBuff then
            for i = 1, 40 do
                local _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
                if not spellID then break end
                if TRAVEL_BUFF_IDS[spellID] then return true end
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

function Functions:FixSettingsAlpha(ignore)
    if GameMenuFrame then GameMenuFrame:SetIgnoreParentAlpha(ignore) end
    if SettingsPanel then SettingsPanel:SetIgnoreParentAlpha(ignore) end
    
    local aceGUI = LibStub("AceGUI-3.0", true)
    if aceGUI then
        for i = 1, aceGUI:GetNextWidgetNum("Dropdown-Pullout") do
            local pullout = _G["AceGUI30Pullout" .. i]
            if pullout then pullout:SetIgnoreParentAlpha(ignore) end
        end
    end
end

-- ============================================================================
-- 5. EVENT THROTTLING
-- ============================================================================
function Functions:RequestUpdate()
    updatePending = true
end

updateFrame:SetScript("OnUpdate", function()
    if updatePending then
        updatePending = false
        Functions:UpdateSmartZoomState("auto_update")
    end
end)

-- ============================================================================
-- 6. LOGIC HELPERS (ZONE CHECK)
-- ============================================================================
local function ShouldActiveCombatZoom()
    if not (ns.Database and ns.Database.db) then return false end
    local db = ns.Database.db.profile

    local inInstance, instanceType = IsInInstance()
    -- instanceType values: "none", "pvp", "arena", "party", "raid", "scenario"

    if inInstance then
        if instanceType == "party" and db.zoneParty then return true end
        if instanceType == "raid" and db.zoneRaid then return true end
        if instanceType == "arena" and db.zoneArena then return true end
        if instanceType == "pvp" and db.zoneBg then return true end -- Battlegrounds
        if instanceType == "scenario" and db.zoneScenario then return true end -- Delves, Torghast
        return false
    end

    -- Якщо ми у відкритому світі, перевіряємо, чи це бій з босом
    if db.zoneWorldBoss and IsEncounterInProgress() then
        return true
    end

    return false
end

-- ============================================================================
-- 7. DYNAMIC FEATURES
-- ============================================================================

tinsert(UISpecialFrames, safeExitFrame:GetName())
safeExitFrame:Hide() 

safeExitFrame:SetScript("OnHide", function()
    if wasAFK then
        Functions:OnPlayerFlagsChanged() 
    end
end)

local function GetShoulderOffsetZoomFactor(zoomLevel)
    local startOffset = 5.0
    local endOffset = 2.0  

    if zoomLevel < endOffset then
        return 0 
    elseif zoomLevel > startOffset then
        return 1 
    else
        return (zoomLevel - endOffset) / (startOffset - endOffset)
    end
end

shoulderHandlerFrame.lastZoom = -1
shoulderHandlerFrame:SetScript("OnUpdate", function(self, elapsed)
    local currentZoom = GetCameraZoom()
    if math.abs(self.lastZoom - currentZoom) < 0.01 then return end
    self.lastZoom = currentZoom

    local factor = GetShoulderOffsetZoomFactor(currentZoom)
    local baseOffset = 1.0 
    local finalOffset = baseOffset * factor
    
    UpdateCVar("test_cameraOverShoulder", finalOffset)
end)
shoulderHandlerFrame:Hide()

-- ============================================================================
-- 8. CORE LOGIC
-- ============================================================================

function Functions:UpdateActionCam()
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile

    if db.actionCamPitch then
        UpdateCVar("test_cameraDynamicPitch", 1)
    else
        UpdateCVar("test_cameraDynamicPitch", 0)
    end

    if db.actionCamShoulder then
        if tonumber(GetCVar("CameraKeepCharacterCentered")) == 1 then
            UpdateCVar("CameraKeepCharacterCentered", 0)
            Functions:logMessage("warning", L["CONFLICT_FIX_MSG"])
        end
        shoulderHandlerFrame:Show()
    else
        shoulderHandlerFrame:Hide()
        UpdateCVar("test_cameraOverShoulder", 0)
    end
end

function Functions:UpdateSmartZoomState(event)
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile

    if not db.autoCombatZoom and not db.autoMountZoom then return end

    local inCombat = UnitAffectingCombat("player")
    -- FIX: Додаємо перевірку агро (UnitThreatSituation)
    -- Якщо повертає не nil, значить ми у когось в таргеті/маємо агро, навіть якщо прапорець бою ще не з'явився
    local hasThreat = UnitThreatSituation("player")
    
    local isMounted = IsInTravelForm()

    local newState = ZOOM_STATE_NONE
    local targetYards
    
    if db.autoCombatZoom then
         targetYards = db.minZoomFactor or 15
    else
         targetYards = db.maxZoomFactor or 39
    end

    -- 1. COMBAT CHECK
    -- Враховуємо: Бій (API) АБО Агро (API) АБО Примусову зону (Інсти/Рейди)
    -- Якщо ми в Інсті, ShouldActiveCombatZoom поверне true, і зум спрацює.
    -- Якщо ми в Світі, ShouldActiveCombatZoom false, але спрацює inCombat або hasThreat.
    if db.autoCombatZoom and (inCombat or hasThreat or ShouldActiveCombatZoom()) then
        newState = ZOOM_STATE_COMBAT
        targetYards = db.maxZoomFactor
        
    -- 2. MOUNT CHECK
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

    Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"], newState, targetYards))
end

function Functions:AdjustCamera(forceNow)
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile
    local LibCamera = LibStub("LibCamera-1.0", true)
    
    Functions:UpdateActionCam()
    
    if db.autoCombatZoom or db.autoMountZoom then
        if forceNow then
            Functions:UpdateSmartZoomState("manual_update")
        else
            Functions:RequestUpdate()
        end
    else
        local targetYards = ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE
        local targetFactor = targetYards / CONVERSION_RATIO

        UpdateCVar("cameraDistanceMaxZoomFactor", targetFactor)

        if LibCamera then
            LibCamera:SetZoomUsingCVar(db.maxZoomFactor, db.zoomTransitionTime or 0.5)
        end

        Functions:logMessage("info", L["SMART_ZOOM_DISABLED_MSG"])
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

-- ============================================================================
-- 9. AFK HANDLER (SAFE MODE)
-- ============================================================================

function Functions:OnPlayerFlagsChanged()
    if not (ns.Database and ns.Database.db) then return end
    local db = ns.Database.db.profile

    if not db.afkMode then return end

    local isAFK = UnitIsAFK("player")
    local LibCamera = LibStub("LibCamera-1.0", true)

    if isAFK and not wasAFK then
        wasAFK = true
        Functions:logMessage("info", L["AFK_ENTER_MSG"])

        savedYawSpeed = tonumber(C_CVar.GetCVar("cameraYawMoveSpeed")) or 180
        C_CVar.SetCVar("cameraYawMoveSpeed", AFK_YAW_SPEED) 
        MoveViewRightStart()
        
        local maxYards = ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE
        if LibCamera then
            LibCamera:SetZoomUsingCVar(maxYards, 4.0) 
        end
        
        UIParent:Hide()
        Functions:FixSettingsAlpha(true)
        safeExitFrame:Show() 
        
    elseif not isAFK and wasAFK then
        wasAFK = false
        Functions:logMessage("info", L["AFK_EXIT_MSG"])
        
        MoveViewRightStop()
        C_CVar.SetCVar("cameraYawMoveSpeed", savedYawSpeed)
        
        UIParent:Show()
        Functions:FixSettingsAlpha(false)
        safeExitFrame:Hide()
        
        Functions:AdjustCamera(true)
    end
end

function Functions:ClearAllQuestTracking()
    local numWatches = C_QuestLog.GetNumQuestWatches()
    if numWatches == 0 then
        Functions:SendMessage(L["QUEST_TRACKER_EMPTY"])
        return
    end
    for i = numWatches, 1, -1 do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID then
            C_QuestLog.RemoveQuestWatch(questID)
        end
    end
    Functions:SendMessage(string.format(L["QUEST_TRACKER_CLEARED"], numWatches))
end

-- ============================================================================
-- 10. SLASH COMMANDS
-- ============================================================================

function Functions:SlashCmdHandler(msg)
    local command = strlower(msg or "")

    if not (ns.Database and ns.Database.db) then 
        Functions:SendMessage(L["DB_NOT_READY"])
        return 
    end
    
    local db = ns.Database.db.profile

    if command == "config" then
        if ACD then
            ACD:Open(addonName) 
        else
            Functions:SendMessage("Error: AceConfigDialog not found. Cannot open settings.")
        end

    elseif command == "autozoom" then
        db.autoCombatZoom = not db.autoCombatZoom
        Functions:AdjustCamera(true) 
        local state = db.autoCombatZoom and (L["ENABLED"] or "|cff00ff00Enabled|r") or (L["DISABLED"] or "|cffff0000Disabled|r")
        Functions:SendMessage("Auto Combat Zoom: " .. state)

    elseif command == "automount" then
        db.autoMountZoom = not db.autoMountZoom
        Functions:AdjustCamera(true) 
        local state = db.autoMountZoom and (L["ENABLED"] or "|cff00ff00Enabled|r") or (L["DISABLED"] or "|cffff0000Disabled|r")
        Functions:SendMessage("Auto Mount Zoom: " .. state)

    else
        Functions:SendMessage(L["CMD_USAGE"] or "Usage: /mcd config | autozoom | automount")
    end
end