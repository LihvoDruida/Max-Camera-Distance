Functions = {}

local addonName = "Max_Camera_Distance"
local settingName = "Max Camera Distance"
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local CVar = C_CVar
local _, playerClass = UnitClass("player")

local savedMaxZoomFactor = nil
local lastExecutionTime = 0
local executionCooldown = 1 -- Cooldown in seconds

-- Функція для виведення повідомлень в чат
function Functions:SendMessage(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff0070deMax Camera Distance|r: " .. message)
end

-- Функція логування для відображення повідомлень у різних кольорах залежно від рівня важливості
function Functions:logMessage(level, message)
        local db = Database.db.profile
        if not db.enableDebugLogging then return end -- Skip if debugging is disabled
    
        -- Check if the current level is enabled
        if not db.debugLevel[level] then return end
    
        local prefix
        local color
    
        if level == "error" then
            color = "|cffff0000"  -- Red for errors
            prefix = "|cff0070deMax Camera Distance|r [E]: "  -- Prefix with 'E' for errors
        elseif level == "warning" then
            color = "|cffffff00"  -- Yellow for warnings
            prefix = "|cff0070deMax Camera Distance|r [W]: "  -- Prefix with 'W' for warnings
        elseif level == "info" then
            color = "|cff00ff00"  -- Green for info
            prefix = "|cff0070deMax Camera Distance|r [I]: "  -- Prefix with 'I' for info
        else
            color = "|cffffffff"  -- White for debug and others
            prefix = "|cff0070deMax Camera Distance|r [D]: "  -- Prefix with 'D' for debug
        end
    
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. color .. message .. "|r")
    end
    
    
function getSavedMaxZoomFactor()
    if savedMaxZoomFactor == nil then
        -- Якщо змінна ще не встановлена, задаємо її значення
        savedMaxZoomFactor = tonumber(GetCVar("cameraDistanceMaxZoomFactor")) or Database.DEFAULT_ZOOM_FACTOR
        self:logMessage("info", "Saved current camera zoom level.")
    end
    return savedMaxZoomFactor  -- Повертаємо значення
end

-- Function to check if the player is a Druid or Shaman
function Functions:IsDruidOrShaman()
    return playerClass == "DRUID" or playerClass == "SHAMAN"
end

-- Функція для зміни налаштувань камери
function Functions:ChangeCameraSetting(key, value, message)
    if IsLoggedIn() then
        local db = Database.db.profile -- Оновлення db з актуальної бази даних
        db[key] = value
        self:AdjustCamera()
        self:logMessage("info", message)
    else
        self:logMessage("warning", "Cannot change settings while in character edit mode.")
    end
end

-- Function to handle when the player mounts up
local function OnMount()
    getSavedMaxZoomFactor()

    local maxCameraZoom = Database.MAX_ZOOM_FACTOR
    SetCVar("cameraDistanceMaxZoomFactor", maxCameraZoom)
    self:logMessage("info", "Set max zoom factor to " .. maxCameraZoom .. ".")
end

-- Function to handle when the player dismounts
local function OnDismount()
    local db = Database.db.profile
    local delay = db.dismountDelay or Database.DISMOUNT_DELAY
    C_Timer.After(delay, function()
        if savedMaxZoomFactor then
            SetCVar("cameraDistanceMaxZoomFactor", savedMaxZoomFactor)
            self:logMessage("info", "Restored previous camera zoom factor.")
            savedMaxZoomFactor = nil
        else
            self:logMessage("warning", "No saved camera zoom factor to restore.")
        end
    end)
end

-- Функція для налаштування камери
function Functions:AdjustCamera()
    local db = Database.db.profile
    if not InCombatLockdown() and IsLoggedIn() then
        if db.maxZoomFactor then
            SetCVar("cameraDistanceMaxZoomFactor", db.maxZoomFactor)
            self:logMessage("info", "Adjusted max zoom factor to " .. db.maxZoomFactor .. ".")
        end

        if db.moveViewDistance then
            MoveViewOutStart(db.moveViewDistance)
            self:logMessage("info", "Adjusted move view distance to " .. db.moveViewDistance .. ".")
        end

        if db.reduceUnexpectedMovement ~= nil then
            CVar.SetCVar("cameraReduceUnexpectedMovement", db.reduceUnexpectedMovement and "1" or "0")
            self:logMessage("info", "Set reduce unexpected movement to " .. tostring(db.reduceUnexpectedMovement) .. ".")
        end

        if db.resampleAlwaysSharpen ~= nil then
            CVar.SetCVar("ResampleAlwaysSharpen", db.resampleAlwaysSharpen and "1" or "0")
            self:logMessage("info", "Set resample always sharpen to " .. tostring(db.resampleAlwaysSharpen) .. ".")
        end

        if db.cameraIndirectVisibility ~= nil then
            CVar.SetCVar("cameraIndirectVisibility", db.cameraIndirectVisibility and "1" or "0")
            self:logMessage("info", "Set camera indirect visibility to " .. tostring(db.cameraIndirectVisibility) .. ".")

            if db.cameraIndirectVisibility then
                SetCVar("cameraIndirectOffset", 1.5)
            else
                SetCVar("cameraIndirectOffset", 10)
            end
            self:logMessage("info", "Set camera indirect offset based on visibility.")
        end

        if db.cameraYawMoveSpeed then
            SetCVar("cameraYawMoveSpeed", db.cameraYawMoveSpeed)
            self:logMessage("info", "Adjusted yaw move speed to " .. db.cameraYawMoveSpeed .. ".")
        end

        if db.cameraPitchMoveSpeed then
            SetCVar("cameraPitchMoveSpeed", db.cameraPitchMoveSpeed)
            self:logMessage("info", "Adjusted pitch move speed to " .. db.cameraPitchMoveSpeed .. ".")
        end
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
        self:logMessage(" ", "Usage: /mcd max | avg | min | config ")
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
        InterfaceOptionsFrame_OpenToCategory(settingName)
    else
        self:logMessage(" ", "Usage: /mcd max | avg | min | config ")
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

function Functions:OnEnterCombat()
    local db = Database.db.profile

    -- Check if automatic combat zoom is enabled
    if db.autoCombatZoom then
        OnMount()
    end
end

function Functions:OnExitCombat()
    local db = Database.db.profile

    -- Check if automatic combat zoom is enabled
    if db.autoCombatZoom then
        OnDismount()
    end
end

-- Function to get the current shapeshift form ID
function Functions:getForm()
    local formID = GetShapeshiftForm()
    local numForms = GetNumShapeshiftForms()

    -- Check if the formID is valid
    if formID and formID < numForms then
        return formID
    else
        return 0
    end
end

-- Function to handle shapeshift form changes
function Functions:OnForm()
    local db = Database.db.profile
    -- Check if automatic form zoom is enabled
    if db.autoFormZoom then
        local currentTime = GetTime() -- Get the current time
        if currentTime - lastExecutionTime < executionCooldown then
            -- If the cooldown period has not passed, return early
            return
        end

        -- Update the last execution time
        lastExecutionTime = currentTime


        local formID = Functions:getForm()


        -- Handle form-specific logic
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
end

function Functions:OnMounted()
    local db = Database.db.profile

    -- Check if automatic mount zoom is enabled
    if db.autoMountZoom then
        -- Apply mount or dismount logic based on the player's mount status
        if IsMounted() then
            OnMount()
        else
            OnDismount()
        end
    end
end
