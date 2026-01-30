local addonName, ns = ...
ns.Database = {} 
local Database = ns.Database

local AceDB = LibStub("AceDB-3.0")
local C_CVar = C_CVar 

-- Отримуємо поточні значення безпечно
local function GetCVarDefault(name, default)
    local success, val = pcall(C_CVar.GetCVar, name)
    if success and val then
        return tonumber(val) or default
    end
    return default
end

local yawMoveSpeed = GetCVarDefault("cameraYawMoveSpeed", 180)
local pitchMoveSpeed = GetCVarDefault("cameraPitchMoveSpeed", 180)
local resampleSharpenDefault = GetCVarDefault("resampleAlwaysSharpen", 0)
local softTargetDefault = GetCVarDefault("SoftTargetIconGameObject", 0)

-- *** КОНСТАНТИ (YARDS) ***
-- Retail: 39 ярдів = 2.6 factor (39 / 2.6 = 15)
-- Classic: 50 ярдів = 4.0 factor (50 / 4.0 = 12.5)
local IS_RETAIL = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local MAX_YARDS = IS_RETAIL and 39 or 50
local CONVERSION_RATIO = IS_RETAIL and 15 or 12.5
-- 1.9 (Blizzard Default) * 15 = 28.5 Yards
local BLIZZARD_DEFAULT_YARDS = 28.5

Database.DEFAULTS = {
    -- Тепер тут зберігаємо ЯРДИ
    ZOOM_DISTANCE = MAX_YARDS,
    -- "Мінімальна" дистанція для Smart Zoom (наприклад, коли виходиш з бою).
    MIN_ZOOM_DISTANCE = BLIZZARD_DEFAULT_YARDS,
    
    YAW_MOVE_SPEED = yawMoveSpeed,
    PITCH_MOVE_SPEED = pitchMoveSpeed,
    DISMOUNT_DELAY = 0,
    MOVE_VIEW_DISTANCE = 30000,
    ZOOM_TRANSITION_TIME = 0.5,

    -- Константи для слайдерів у Config
    MAX_POSSIBLE_DISTANCE = MAX_YARDS,
    CONVERSION_RATIO = CONVERSION_RATIO,

    -- Boolean
    REDUCE_UNEXPECTED_MOVEMENT = false,
    CAMERA_INDIRECT_VISIBILITY = true,
    AUTO_COMBAT_ZOOM = false,
    AUTO_MOUNT_ZOOM = false,
    MOUNT_ZOOM_FACTOR = MAX_YARDS,
    ENABLE_DEBUG_LOGGING = false,
    RESAMPLE_ALWAYS_SHARPEN = (resampleSharpenDefault == 1),
    SOFT_TARGET_INTERACT = (softTargetDefault == 1)
}

Database.DEFAULT_DEBUG_LEVEL = {
    ["error"] = true, ["warning"] = true, ["info"] = false, ["debug"] = false
}

function Database:InitDB()
    -- Запобіжник self
    if not self or type(self) ~= "table" then self = Database end

    local defaultProfile = {
        maxZoomFactor = Database.DEFAULTS.ZOOM_DISTANCE,
        minZoomFactor = Database.DEFAULTS.MIN_ZOOM_DISTANCE,
        
        moveViewDistance = Database.DEFAULTS.MOVE_VIEW_DISTANCE,
        cameraYawMoveSpeed = Database.DEFAULTS.YAW_MOVE_SPEED,
        cameraPitchMoveSpeed = Database.DEFAULTS.PITCH_MOVE_SPEED,
        dismountDelay = Database.DEFAULTS.DISMOUNT_DELAY,
        zoomTransitionTime = Database.DEFAULTS.ZOOM_TRANSITION_TIME,

        autoCombatZoom = Database.DEFAULTS.AUTO_COMBAT_ZOOM,
        autoMountZoom = Database.DEFAULTS.AUTO_MOUNT_ZOOM,
        mountZoomFactor = Database.DEFAULTS.MOUNT_ZOOM_FACTOR,
        reduceUnexpectedMovement = Database.DEFAULTS.REDUCE_UNEXPECTED_MOVEMENT,
        cameraIndirectVisibility = Database.DEFAULTS.CAMERA_INDIRECT_VISIBILITY,
        resampleAlwaysSharpen = Database.DEFAULTS.RESAMPLE_ALWAYS_SHARPEN,
        softTargetInteract = Database.DEFAULTS.SOFT_TARGET_INTERACT,

        enableDebugLogging = Database.DEFAULTS.ENABLE_DEBUG_LOGGING,
        debugLevel = CopyTable(Database.DEFAULT_DEBUG_LEVEL)
    }

    self.db = AceDB:New("MaxCameraDistanceDB", { profile = defaultProfile }, true)
    
    if not self.db then
        print(addonName .. ": Database initialization failed.")
        return
    end

    self:RegisterProfileCallbacks()
end

function Database:RegisterProfileCallbacks()
    if not self or not self.db then return end
    
    local updateFunc = function(event)
        Database:OnProfileUpdate(event)
    end

    self.db:RegisterCallback("OnProfileChanged", updateFunc)
    self.db:RegisterCallback("OnProfileCopied", updateFunc)
    self.db:RegisterCallback("OnProfileReset", updateFunc)
end

function Database:OnProfileUpdate(reason)
    if ns.Functions and ns.Functions.logMessage then
        ns.Functions:logMessage("info", reason .. ". Re-applying settings...")
    end
    if ns.Functions and ns.Functions.AdjustCamera then
        ns.Functions:AdjustCamera()
    end
end

-- *** Helper: Отримати значення для CVar ***
function Database:GetCVarFactor(yards)
    return yards / Database.DEFAULTS.CONVERSION_RATIO
end

-- *** Setters/Getters ***
function Database:SetZoomFactor(yards)
    local dbObj = (self and self.db) and self or Database
    if dbObj.db and dbObj.db.profile then
        dbObj.db.profile.maxZoomFactor = tonumber(yards) or Database.DEFAULTS.ZOOM_DISTANCE
        if ns.Functions and ns.Functions.AdjustCamera then ns.Functions:AdjustCamera() end
    end
end