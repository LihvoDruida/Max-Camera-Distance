Functions = {}

local addonName, _ = ...
local settingName = "Max Camera Distance"
local L = LibStub("AceLocale-3.0"):GetLocale(addonName) or {}
local LibCamera = LibStub("LibCamera-1.0")

-- Відстеження бою
local wasInCombat = false
local lastCombatUpdate = 0
local combatCooldown = 1 -- Cooldown у секундах

-- *** Виведення повідомлень у чат ***
function Functions:SendMessage(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff0070deMax Camera Distance|r: " .. message)
end

-- *** Логування ***
function Functions:logMessage(level, message)
    local db = Database and Database.db and Database.db.profile
    if not db or not db.enableDebugLogging or not (db.debugLevel and db.debugLevel[level]) then return end

    local prefix, color
    if level == "error" then
        color, prefix = "|cffff0000", "[E]"
    elseif level == "warning" then
        color, prefix = "|cffffff00", "[W]"
    elseif level == "info" then
        color, prefix = "|cff00ff00", "[I]"
    else
        color, prefix = "|cffffffff", "[D]"
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff0070deMax Camera Distance|r " .. prefix .. ": " .. color .. message .. "|r")
end

-- *** Зміна CVAR ***
local function UpdateCVar(key, value)
    local strValue = tostring(value)
    if C_CVar.GetCVar(key) ~= strValue then
        C_CVar.SetCVar(key, value)
        Functions:logMessage("info", "Updated " .. key .. " to " .. strValue)
    end
end

-- *** Застосування налаштувань камери ***
function Functions:AdjustCamera()
    local db = Database and Database.db and Database.db.profile
    if not db then return end

    if LibCamera then
        LibCamera:SetZoomUsingCVar(db.maxZoomFactor, 0.5)
    else
        C_CVar.SetCVar("cameraDistanceMaxZoomFactor", db.maxZoomFactor)
    end

    UpdateCVar("cameraDistanceMoveSpeed", db.moveViewDistance)
    UpdateCVar("cameraReduceUnexpectedMovement", db.reduceUnexpectedMovement and 1 or 0)
    UpdateCVar("cameraYawMoveSpeed", db.cameraYawMoveSpeed)
    UpdateCVar("cameraPitchMoveSpeed", db.cameraPitchMoveSpeed)
    UpdateCVar("cameraIndirectVisibility", db.cameraIndirectVisibility and 1 or 0)

    Functions:logMessage("info", "All camera settings adjusted.")
end

-- *** Оновлення камери при бою ***
function Functions:UpdateCameraOnCombat(event)
    local db = Database and Database.db and Database.db.profile
    if not db or not db.autoCombatZoom then return end

    local inCombat = UnitAffectingCombat("player") or (event == "PLAYER_REGEN_DISABLED")
    local currentTime = GetTime()

    if (currentTime - lastCombatUpdate) < combatCooldown and inCombat == wasInCombat then return end
    lastCombatUpdate = currentTime

    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "arena" or instanceType == "pvp") then
        inCombat = true
    end

    if inCombat ~= wasInCombat then
        wasInCombat = inCombat
        local targetZoom = inCombat and db.maxZoomFactor or db.minZoomFactor

        C_Timer.After(inCombat and 0 or (db.dismountDelay or 0), function()
                LibCamera:SetZoomUsingCVar(targetZoom, 0.5)
            Functions:logMessage("info", string.format("%s combat: zoom set to %.2f", inCombat and "In" or "Out of", targetZoom))
        end)
    end
end

-- *** Обробка CVAR_UPDATE ***
function Functions:OnCVarUpdate(_, cvarName, value)
    local db = Database and Database.db and Database.db.profile
    if not db then return end

    local handlers = {
        cameraDistanceMaxZoomFactor = function() db.maxZoomFactor = tonumber(value) end,
        cameraDistanceMoveSpeed = function() db.moveViewDistance = tonumber(value) end,
        cameraReduceUnexpectedMovement = function() db.reduceUnexpectedMovement = (tonumber(value) == 1) end,
        cameraYawMoveSpeed = function() db.cameraYawMoveSpeed = tonumber(value) end,
        cameraPitchMoveSpeed = function() db.cameraPitchMoveSpeed = tonumber(value) end,
        cameraIndirectVisibility = function() db.cameraIndirectVisibility = (tonumber(value) == 1) end,
    }

    if handlers[cvarName] then
        handlers[cvarName]()
        Functions:logMessage("info", L["SETTINGS_CHANGED"] or "Settings changed via CVAR.")
    end
end

-- *** Зміна налаштувань камери ***
function Functions:ChangeCameraSetting(key, value, message)
    if not Database or not Database.db then return end
    local profile = Database.db.profile
    if not profile then return end

    profile[key] = value
    self:AdjustCamera()

    if message then
        self:SendMessage(message .. " (" .. key .. " = " .. tostring(value) .. ")")
    end
end

-- *** Профілі ***
function Functions:OnProfileChanged() Functions:AdjustCamera() end
function Functions:OnProfileCopied() Functions:AdjustCamera() end
function Functions:OnProfileReset() Functions:AdjustCamera() end

-- *** Slash-команди ***
function Functions:SlashCmdHandler(msg)
    local command = strlower(msg or "")
    local settings = {
        max = { zoomFactor = 3.5 },
        avg = { zoomFactor = 2.0 },
        min = { zoomFactor = 1.0 }
    }

    local db = Database and Database.db and Database.db.profile
    if not db then 
        Functions:SendMessage(L["DB_NOT_READY"] or "Database not ready yet.")
        return 
    end

    if settings[command] then
        local setting = settings[command]
        db.maxZoomFactor = setting.zoomFactor

        if LibCamera then
            LibCamera:SetZoomUsingCVar(setting.zoomFactor, 0.5, function()
                Functions:logMessage("info", "Settings set to " .. command .. " (smooth zoom).")
            end)
        else
            C_CVar.SetCVar("cameraDistanceMaxZoomFactor", setting.zoomFactor)
            Functions:logMessage("info", "Settings set to " .. command .. ".")
        end
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
