-- Створюємо глобальну таблицю Database
Database = {}
-- Імплементація AceDB
local AceDB = LibStub("AceDB-3.0")

Database.DEFAULT_ZOOM_FACTOR = 1.9

Database.DEFAULT_YAW_MOVE_SPEED = 180
Database.DEFAULT_PITCH_MOVE_SPEED = 90

Database.MIN_PITCH_YAW_MOVE_SPEED = 90
Database.MAX_ZOOM_FACTOR = 2.6
Database.MAX_PITCH_YAW_MOVE_SPEED = 360

Database.MOVE_VIEW_DISTANCE = 30000

--- Boolean
Database.REDUCE_UNEXPECTED_MOVEMENT = false
Database.RESAMPLE_ALWAYS_SHARPEN = false
Database.CAMERA_INDIRECT_VISIBILITY = false

Database.CAMERA_PITCH_MOVE_SPEED = 180

-- Database initialization function
function Database:InitDB()
    -- Define default settings
    local defaultProfile = {
        maxZoomFactor = Database.DEFAULT_ZOOM_FACTOR,
        moveViewDistance = Database.MOVE_VIEW_DISTANCE,
        cameraYawMoveSpeed = Database.DEFAULT_YAW_MOVE_SPEED,
        cameraPitchMoveSpeed = Database.DEFAULT_PITCH_MOVE_SPEED,
        reduceUnexpectedMovement = Database.REDUCE_UNEXPECTED_MOVEMENT,
        resampleAlwaysSharpen = Database.RESAMPLE_ALWAYS_SHARPEN,
        cameraIndirectVisibility = Database.CAMERA_INDIRECT_VISIBILITY
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
