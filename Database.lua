-- Створюємо глобальну таблицю Database
Database = {}
-- Імплементація AceDB
local AceDB = LibStub("AceDB-3.0")

local yawMoveSpeed = tonumber(GetCVar("cameraYawMoveSpeed"))
local pitchMoveSpeed = tonumber(GetCVar("cameraPitchMoveSpeed"))

Database.DEFAULT_ZOOM_FACTOR = 1.9
Database.DEFAULT_YAW_MOVE_SPEED = yawMoveSpeed
Database.DEFAULT_PITCH_MOVE_SPEED = pitchMoveSpeed
Database.DISMOUNT_DELAY = 3
Database.MOVE_VIEW_DISTANCE = 30000

Database.MIN_PITCH_YAW_MOVE_SPEED = 90

Database.MAX_ZOOM_FACTOR = 2.6
Database.MAX_PITCH_YAW_MOVE_SPEED = 360



--- Boolean
Database.REDUCE_UNEXPECTED_MOVEMENT = false
Database.RESAMPLE_ALWAYS_SHARPEN = false
Database.CAMERA_INDIRECT_VISIBILITY = true
Database.DEFAULT_ZOOM_MOUNT = true
Database.DEFAULT_ZOOM_FORM = true
Database.DEFAULT_ZOOM_COMBAT = true

Database.CAMERA_PITCH_MOVE_SPEED = 180

-- Database initialization function
function Database:InitDB()
    -- Define default settings
    local defaultProfile = {
        maxZoomFactor = Database.DEFAULT_ZOOM_FACTOR,
        moveViewDistance = Database.MOVE_VIEW_DISTANCE,
        cameraYawMoveSpeed = Database.DEFAULT_YAW_MOVE_SPEED,
        cameraPitchMoveSpeed = Database.DEFAULT_PITCH_MOVE_SPEED,
        dismountDelay = Database.DISMOUNT_DELAY,
        autoMountZoom = Database.DEFAULT_ZOOM_MOUNT,
        autoFormZoom = Database.DEFAULT_ZOOM_FORM,
        autoCombatZoom = Database.DEFAULT_ZOOM_COMBAT,
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
