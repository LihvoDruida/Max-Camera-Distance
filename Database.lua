-- Створюємо глобальну таблицю Database
Database = {}
-- Імплементація AceDB
local AceDB = LibStub("AceDB-3.0")

local yawMoveSpeed = tonumber(GetCVar("cameraYawMoveSpeed"))
local pitchMoveSpeed = tonumber(GetCVar("cameraPitchMoveSpeed"))

-- *** Numeric Values ***
Database.DEFAULT_ZOOM_FACTOR = 2.6
Database.DEFAULT_YAW_MOVE_SPEED = yawMoveSpeed
Database.DEFAULT_PITCH_MOVE_SPEED = pitchMoveSpeed
Database.DISMOUNT_DELAY = 3
Database.MOVE_VIEW_DISTANCE = 30000
Database.MIN_PITCH_YAW_MOVE_SPEED = 90
Database.MAX_ZOOM_FACTOR = 2.6
Database.MAX_PITCH_YAW_MOVE_SPEED = 360
Database.CAMERA_PITCH_MOVE_SPEED = 180

-- *** Boolean Values ***
Database.REDUCE_UNEXPECTED_MOVEMENT = false
Database.RESAMPLE_ALWAYS_SHARPEN = false
Database.CAMERA_INDIRECT_VISIBILITY = true
Database.DEFAULT_ZOOM_MOUNT = false
Database.DEFAULT_ZOOM_FORM = false
Database.DEFAULT_ZOOM_COMBAT = false
Database.ENABLE_DEBUG_LOGGING = false

-- *** Tables ***
Database.DEFAULT_DEBUG_LEVEL = {
    ["error"] = true,
    ["warning"] = true,
    ["info"] = false,
    ["debug"] = false
}

-- Database initialization function
function Database:InitDB()
    -- Define default settings
    local defaultProfile = {
        -- Numeric values
        maxZoomFactor = Database.DEFAULT_ZOOM_FACTOR,
        moveViewDistance = Database.MOVE_VIEW_DISTANCE,
        cameraYawMoveSpeed = Database.DEFAULT_YAW_MOVE_SPEED,
        cameraPitchMoveSpeed = Database.DEFAULT_PITCH_MOVE_SPEED,
        dismountDelay = Database.DISMOUNT_DELAY,

        -- Boolean values
        autoMountZoom = Database.DEFAULT_ZOOM_MOUNT,
        autoFormZoom = Database.DEFAULT_ZOOM_FORM,
        autoCombatZoom = Database.DEFAULT_ZOOM_COMBAT,
        reduceUnexpectedMovement = Database.REDUCE_UNEXPECTED_MOVEMENT,
        resampleAlwaysSharpen = Database.RESAMPLE_ALWAYS_SHARPEN,
        cameraIndirectVisibility = Database.CAMERA_INDIRECT_VISIBILITY,
        enableDebugLogging = Database.ENABLE_DEBUG_LOGGING,

        -- Table values
        debugLevel = Database.DEFAULT_DEBUG_LEVEL  -- Initialize with default debug level
    }

    -- Create or load the database with default settings
    Database.db = AceDB:New("MaxCameraDistanceDB", { profile = defaultProfile }, true)

    -- Register callback functions for database profile changes
    Database.db:RegisterCallback("OnProfileChanged", function()
        if Functions and Functions.OnProfileChanged then
            Functions:OnProfileChanged()
        end
    end)

    Database.db:RegisterCallback("OnProfileCopied", function()
        if Functions and Functions.OnProfileCopied then
            Functions:OnProfileCopied()
        end
    end)

    Database.db:RegisterCallback("OnProfileReset", function()
        if Functions and Functions.OnProfileReset then
            Functions:OnProfileReset()
        end
    end)
end
