local addonName, ns = ...
ns.Functions = ns.Functions or {}
local Functions = ns.Functions

local L = LibStub("AceLocale-3.0"):GetLocale(addonName) or {}

local LibCamera    = LibStub("LibCamera-1.0", true)
local LibMountInfo = LibStub("LibMountInfo-1.0", true)
local ACD          = LibStub("AceConfigDialog-3.0", true)

-- =====================================================================
-- 1) FAST LOCALS / API
-- =====================================================================
local C_CVar      = C_CVar
local C_Timer     = C_Timer
local C_UnitAuras = C_UnitAuras

local pcall    = pcall
local tonumber = tonumber
local tostring = tostring
local type     = type
local pairs    = pairs
local print    = print

local math_abs = math.abs
local tinsert  = table.insert
local strlower = string.lower

local UnitAffectingCombat   = UnitAffectingCombat
local UnitThreatSituation   = UnitThreatSituation
local IsInInstance          = IsInInstance
local IsMounted             = IsMounted
local GetShapeshiftForm     = GetShapeshiftForm
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local UnitIsAFK             = UnitIsAFK
local MoveViewRightStart    = MoveViewRightStart
local MoveViewRightStop     = MoveViewRightStop
local GetCameraZoom         = GetCameraZoom
local IsEncounterInProgress = IsEncounterInProgress

local IsInRaid             = IsInRaid
local IsInGroup            = IsInGroup
local GetNumGroupMembers   = GetNumGroupMembers
local GetNumSubgroupMembers= GetNumSubgroupMembers

local IS_RETAIL = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local CONVERSION_RATIO = IS_RETAIL and 15 or 12.5

-- =====================================================================
-- 2) STATE
-- =====================================================================
local ZOOM_STATE_NONE   = "none"
local ZOOM_STATE_MOUNT  = "mount"
local ZOOM_STATE_COMBAT = "combat"

local currentZoomState = ZOOM_STATE_NONE

local transitionTimer = nil
local isInternalUpdate = false

-- token that invalidates old delayed transitions (fixes “sticky states”)
local stateToken = 0

-- Throttling (no permanent OnUpdate)
local updatePending = false
local updateFrame = CreateFrame("Frame")
updateFrame:Hide()

-- AFK
local wasAFK = false
local savedYawSpeed = 180
local AFK_YAW_SPEED = 4

-- Frames
local safeExitFrame = CreateFrame("Frame", "MCD_SafeExitFrame", UIParent)
local shoulderHandlerFrame = CreateFrame("Frame")

-- =====================================================================
-- 3) FALLBACK DATA (travel forms / buffs)
-- =====================================================================
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

-- =====================================================================
-- 4) DB helper
-- =====================================================================
local function DB()
    return (ns.Database and ns.Database.db and ns.Database.db.profile) or nil
end

-- =====================================================================
-- 5) LOG
-- =====================================================================
function Functions:logMessage(level, message)
    local db = DB()
    if not (db and db.enableDebugLogging) then return end
    if not (db.debugLevel and db.debugLevel[level]) then return end

    local color = "|cffffffff"
    local prefix = "[D]"
    if level == "error" then color, prefix = "|cffff0000", "[E]"
    elseif level == "warning" then color, prefix = "|cffffff00", "[W]"
    elseif level == "info" then color, prefix = "|cff00ff00", "[I]"
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff0070deMCD|r %s: %s%s|r", prefix, color, tostring(message)))
end

function Functions:SendMessage(message)
    print("|cff0070deMax Camera Distance|r: " .. tostring(message))
end

-- =====================================================================
-- 6) SAFE CVAR HELPERS (fix SafeGetCVar nil + cross-client)
-- =====================================================================
local function SafeGetCVar(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, val = pcall(C_CVar.GetCVar, name)
        if ok and val ~= nil then
            return tonumber(val)
        end
    end
    if type(_G.GetCVar) == "function" then
        local ok, val = pcall(_G.GetCVar, name)
        if ok and val ~= nil then
            return tonumber(val)
        end
    end
    return nil
end

local function SafeSetCVar(name, value)
    if not (C_CVar and C_CVar.SetCVar) then return false end
    local ok = pcall(C_CVar.SetCVar, name, value)
    return ok and true or false
end

local function UpdateCVar(key, value)
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end

    local currentValue = C_CVar.GetCVar(key)
    if currentValue == nil then return end

    local strValue = tostring(value)

    if type(value) == "number" then
        local numCurrent = tonumber(currentValue)
        if numCurrent and math_abs(numCurrent - value) < 0.005 then
            return
        end
    else
        if currentValue == strValue then return end
    end

    isInternalUpdate = true
    pcall(C_CVar.SetCVar, key, value)
    isInternalUpdate = false
end

-- =====================================================================
-- 7) MOUNT / TRAVEL DETECT
-- =====================================================================
function Functions:IsSkyriding()
    if IsMounted() and LibMountInfo and LibMountInfo.IsSkyriding then
        return LibMountInfo:IsSkyriding()
    end

    if IS_RETAIL and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        if C_UnitAuras.GetPlayerAuraBySpellID(404464) then return true end
        if C_UnitAuras.GetPlayerAuraBySpellID(404468) then return false end
    end

    return false
end

local function IsInTravelForm()
    if LibMountInfo and LibMountInfo.IsMounted then
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
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            for spellID in pairs(TRAVEL_BUFF_IDS) do
                if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then return true end
            end
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

-- =====================================================================
-- 8) TRANSITIONS (fix race conditions)
-- =====================================================================
local function CancelTransition()
    if transitionTimer then
        C_Timer.CancelTimer(transitionTimer)
        transitionTimer = nil
    end
end

local function ApplyZoomTransition(targetYards, transitionTime)
    local targetFactor  = targetYards / CONVERSION_RATIO
    local currentFactor = SafeGetCVar("cameraDistanceMaxZoomFactor") or 0

    -- If we are shrinking max factor, do zoom first then lower cap (prevents snap)
    if targetFactor < currentFactor then
        if LibCamera and LibCamera.SetZoomUsingCVar then
            LibCamera:SetZoomUsingCVar(targetYards, transitionTime)
        end

        local myToken = stateToken
        transitionTimer = C_Timer.After((transitionTime or 0) + 0.05, function()
            -- If state changed since scheduling, ignore (prevents “sticky” normal)
            if myToken ~= stateToken then return end
            UpdateCVar("cameraDistanceMaxZoomFactor", targetFactor)
        end)
    else
        UpdateCVar("cameraDistanceMaxZoomFactor", targetFactor)
        if LibCamera and LibCamera.SetZoomUsingCVar then
            LibCamera:SetZoomUsingCVar(targetYards, transitionTime)
        end
    end
end

-- =====================================================================
-- 9) EVENT THROTTLING
-- =====================================================================
function Functions:RequestUpdate()
    if updatePending then return end
    updatePending = true
    updateFrame:Show()
end

updateFrame:SetScript("OnUpdate", function(self)
    if not updatePending then
        self:Hide()
        return
    end
    updatePending = false
    self:Hide()
    Functions:UpdateSmartZoomState("auto_update")
end)

-- =====================================================================
-- 10) COMBAT DETECT (group-safe)
-- =====================================================================
function Functions:IsGroupInCombat()
    if IsEncounterInProgress() then return true end
    if UnitAffectingCombat("player") then return true end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitAffectingCombat("raid"..i) then
                return true
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            if UnitAffectingCombat("party"..i) then
                return true
            end
        end
    end

    return false
end

local function ShouldActiveCombatZoom()
    local db = DB()
    if not db then return false end

    local inInstance, instanceType = IsInInstance()

    if inInstance then
        if instanceType == "party" and db.zoneParty then return true end
        if instanceType == "raid" and db.zoneRaid then return true end
        if instanceType == "arena" and db.zoneArena then return true end
        if instanceType == "pvp" and db.zoneBg then return true end
        if instanceType == "scenario" and db.zoneScenario then return true end
        return false
    end

    if db.zoneWorldBoss and IsEncounterInProgress() then
        return true
    end

    return false
end

-- =====================================================================
-- 11) ACTIONCAM SHOULDER (dynamic shoulder offset)
-- =====================================================================
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
shoulderHandlerFrame:SetScript("OnUpdate", function(self)
    local currentZoom = GetCameraZoom()
    if math_abs(self.lastZoom - currentZoom) < 0.01 then return end
    self.lastZoom = currentZoom

    local factor = GetShoulderOffsetZoomFactor(currentZoom)
    local baseOffset = 1.0
    UpdateCVar("test_cameraOverShoulder", baseOffset * factor)
end)
shoulderHandlerFrame:Hide()

function Functions:UpdateActionCam()
    local db = DB()
    if not db then return end

    UpdateCVar("test_cameraDynamicPitch", db.actionCamPitch and 1 or 0)

    if db.actionCamShoulder then
        if type(_G.GetCVar) == "function" and tonumber(_G.GetCVar("CameraKeepCharacterCentered")) == 1 then
            UpdateCVar("CameraKeepCharacterCentered", 0)
            Functions:logMessage("warning", L["CONFLICT_FIX_MSG"] or "ActionCam: Disabled Keep Character Centered to prevent jitter.")
        end
        shoulderHandlerFrame:Show()
    else
        shoulderHandlerFrame:Hide()
        UpdateCVar("test_cameraOverShoulder", 0)
    end
end

-- =====================================================================
-- 12) SMART ZOOM CORE (FIXED: no “sticky” state)
-- =====================================================================
local function ComputeDesiredState(db)
    local inCombat = Functions:IsGroupInCombat()
    local hasThreat = UnitThreatSituation("player")
    local isMounted = IsInTravelForm()

    if db.autoCombatZoom and (inCombat or hasThreat or ShouldActiveCombatZoom()) then
        return ZOOM_STATE_COMBAT, (db.maxZoomFactor or (ns.Database and ns.Database.DEFAULTS and ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE) or 39)
    end

    if db.autoMountZoom and isMounted then
        return ZOOM_STATE_MOUNT, (db.mountZoomFactor or db.maxZoomFactor or 39)
    end

    -- none (normal)
    local normalYards
    if db.autoCombatZoom then
        normalYards = db.minZoomFactor or 15
    else
        normalYards = db.maxZoomFactor or 39
    end

    return ZOOM_STATE_NONE, normalYards
end

function Functions:UpdateSmartZoomState(event)
    local db = DB()
    if not db then return end
    if not db.autoCombatZoom and not db.autoMountZoom then return end

    local newState, targetYards = ComputeDesiredState(db)

    -- If going INTO combat or mount, always cancel pending “zoom-in”
    -- (prevents normal transition from firing after re-enter combat)
    if newState ~= ZOOM_STATE_NONE then
        CancelTransition()
    end

    -- Same state? still might need to “win back” after fast flip.
    -- If we are combat/mount, we allow re-apply on auto_update too.
    local stateSame = (newState == currentZoomState)
    if stateSame and (newState == ZOOM_STATE_NONE) and event ~= "manual_update" then
        return
    end

    -- Any change invalidates old delayed timers
    stateToken = stateToken + 1
    currentZoomState = newState

    local transitionTime = db.zoomTransitionTime or 0.5

    if newState == ZOOM_STATE_NONE and event ~= "manual_update" then
        -- Delay zoom-in after leaving combat/mount
        local delay = db.dismountDelay or 0
        local myToken = stateToken

        CancelTransition()
        transitionTimer = C_Timer.After(delay, function()
            -- Re-check: if state changed since scheduling, do nothing
            if myToken ~= stateToken then return end

            -- Recompute again at fire-time (combat re-enter, mount, etc.)
            local nowState, nowYards = ComputeDesiredState(db)
            if nowState ~= ZOOM_STATE_NONE then
                -- state changed, let next update handle it (or apply immediately)
                return
            end

            ApplyZoomTransition(nowYards, transitionTime)
            Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"] or "Smart Zoom: state=%s, target=%.1f yards", nowState, nowYards))
        end)
    else
        -- Immediate apply for combat/mount, or manual update
        ApplyZoomTransition(targetYards, transitionTime)
        Functions:logMessage("info", string.format(L["SMART_ZOOM_MSG"] or "Smart Zoom: state=%s, target=%.1f yards", newState, targetYards))
    end
end

function Functions:AdjustCamera(forceNow)
    local db = DB()
    if not db then return end

    Functions:UpdateActionCam()

    if db.autoCombatZoom or db.autoMountZoom then
        if forceNow then
            Functions:UpdateSmartZoomState("manual_update")
        else
            Functions:RequestUpdate()
        end
    else
        -- Manual-only mode
        local maxYards = (ns.Database and ns.Database.DEFAULTS and ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE) or (IS_RETAIL and 39 or 50)
        local targetFactor = maxYards / CONVERSION_RATIO

        UpdateCVar("cameraDistanceMaxZoomFactor", targetFactor)
        if LibCamera and LibCamera.SetZoomUsingCVar then
            LibCamera:SetZoomUsingCVar(db.maxZoomFactor or maxYards, db.zoomTransitionTime or 0.5)
        end

        Functions:logMessage("info", L["SMART_ZOOM_DISABLED_MSG"] or "Smart Zoom is disabled. Using manual max distance settings.")
    end

    -- Always apply other CVars
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
    local db = DB()
    if not db then return end

    if (cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax") then
        if db.autoCombatZoom or db.autoMountZoom then
            return
        end
    end

    local numValue = tonumber(value) or 0

    if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMax" then
        local yards = numValue * CONVERSION_RATIO
        if yards > 1 and db.maxZoomFactor and math_abs(db.maxZoomFactor - yards) > 0.1 then
            db.maxZoomFactor = yards
            Functions:logMessage("info", string.format("DB synced from CVar: %.2f factor -> %.1f yards", numValue, yards))
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

-- =====================================================================
-- 13) AFK (SAFE)
-- =====================================================================
function Functions:OnPlayerFlagsChanged()
    local db = DB()
    if not db or not db.afkMode then return end

    local isAFK = UnitIsAFK("player")

    if isAFK and not wasAFK then
        wasAFK = true
        Functions:logMessage("info", L["AFK_ENTER_MSG"] or "AFK Mode: enabled (cinematic rotation).")

        savedYawSpeed = SafeGetCVar("cameraYawMoveSpeed") or 180
        SafeSetCVar("cameraYawMoveSpeed", AFK_YAW_SPEED)
        MoveViewRightStart()

        local maxYards = (ns.Database and ns.Database.DEFAULTS and ns.Database.DEFAULTS.MAX_POSSIBLE_DISTANCE) or (IS_RETAIL and 39 or 50)
        if LibCamera and LibCamera.SetZoomUsingCVar then
            LibCamera:SetZoomUsingCVar(maxYards, 4.0)
        end

        UIParent:Hide()
        safeExitFrame:Show()

    elseif (not isAFK) and wasAFK then
        wasAFK = false
        Functions:logMessage("info", L["AFK_EXIT_MSG"] or "AFK Mode: disabled (restored UI and camera).")

        MoveViewRightStop()
        SafeSetCVar("cameraYawMoveSpeed", savedYawSpeed)

        UIParent:Show()
        safeExitFrame:Hide()

        Functions:AdjustCamera(true)
    end
end

-- =====================================================================
-- 14) QUEST TRACKER
-- =====================================================================
function Functions:ClearAllQuestTracking()
    if not C_QuestLog or not C_QuestLog.GetNumQuestWatches then
        Functions:SendMessage("Quest tracking API not available in this client.")
        return
    end

    local numWatches = C_QuestLog.GetNumQuestWatches()
    if not numWatches or numWatches <= 0 then
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

-- =====================================================================
-- 15) SLASH
-- =====================================================================
function Functions:SlashCmdHandler(msg)
    local command = strlower(msg or "")

    if not (ns.Database and ns.Database.db) then
        Functions:SendMessage(L["DB_NOT_READY"] or "Database not initialized yet.")
        return
    end

    local db = ns.Database.db.profile

    if command == "config" then
        if ACD and ACD.Open then
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