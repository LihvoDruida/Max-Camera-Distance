-- Створюємо глобальну таблицю Database
Database = {}
-- Імплементація AceDB
local AceDB = LibStub("AceDB-3.0")

-- Ініціалізація стандартних значень
local yawMoveSpeed = tonumber(GetCVar("cameraYawMoveSpeed")) or 180
local pitchMoveSpeed = tonumber(GetCVar("cameraPitchMoveSpeed")) or 180

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

-- Ініціалізація бази даних
function Database:InitDB()
    -- Визначаємо стандартний профіль
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
        cameraIndirectVisibility = Database.CAMERA_INDIRECT_VISIBILITY,
        enableDebugLogging = Database.ENABLE_DEBUG_LOGGING,

        debugLevel = Database.DEFAULT_DEBUG_LEVEL
    }

    -- Створюємо або завантажуємо базу даних
    Database.db = AceDB:New("MaxCameraDistanceDB", { profile = defaultProfile }, true)
    if not Database.db then
        print("Max_Camera_Distance: Database initialization failed.")
        return
    end

    -- Реєстрація колбеків для зміни профілів
    self:RegisterProfileCallbacks()
end

-- Реєстрація колбеків для зміни профілів
function Database:RegisterProfileCallbacks()
    Database.db:RegisterCallback("OnProfileChanged", function()
        print("Profile changed. Updating settings...")
        Database:UpdateCameraSettings()
    end)

    Database.db:RegisterCallback("OnProfileReset", function()
        print("Profile reset to defaults.")
        Database:UpdateCameraSettings()
    end)
end

-- Оновлення налаштувань камери
function Database:UpdateCameraSettings()
    -- Оновлюємо налаштування камери з профілю або використовуємо значення за замовчуванням
    SetCVar("cameraYawMoveSpeed", self.db.profile.cameraYawMoveSpeed or defaultValues.DEFAULT_YAW_MOVE_SPEED)
    SetCVar("cameraPitchMoveSpeed", self.db.profile.cameraPitchMoveSpeed or defaultValues.DEFAULT_PITCH_MOVE_SPEED)
    print("Camera settings updated.")
end

-- Функції доступу до значень профілю
function Database:SetZoomFactor(value)
    self.db.profile.maxZoomFactor = value
end

function Database:GetZoomFactor()
    return self.db.profile.maxZoomFactor or defaultValues.DEFAULT_ZOOM_FACTOR
end

-- Логи та налагодження
function Database:Log(level, message)
    if self.db.profile.debugLevel[level] then
        print("Max_Camera_Distance [" .. level:upper() .. "]: " .. message)
    end
end

