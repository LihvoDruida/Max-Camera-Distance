-- Створюємо глобальну таблицю Database
Database = {}
local addonName = "Max_Camera_Distance"

-- Імплементація AceDB
local AceDB = LibStub("AceDB-3.0")
local AceAddon = LibStub("AceAddon-3.0")
local AceEvent = LibStub("AceEvent-3.0")
MKD = AceAddon:NewAddon(addonName, "AceEvent-3.0")


-- Функція для ініціалізації бази даних
function Database:InitDB()
    -- Set up our database
    MKD.db = AceDB:New("MaxCameraDistanceDB", {
        profile = {
            maxZoomFactor = 2.6,
            moveViewDistance = 30000,
            reduceUnexpectedMovement = false,
            resampleAlwaysSharpen = false,
            cameraYawMoveSpeed = 180,
            cameraPitchMoveSpeed = 180,
            cameraIndirectVisibility = false,
        }
    }, true)
    -- Register callback functions for database profile changes
    MKD.db:RegisterCallback("OnProfileChanged", function()
        if Functions and Functions.OnProfileChanged then
            Functions:OnProfileChanged()
        end
    end)
    MKD.db:RegisterCallback("OnProfileCopied", function()
        if Functions and Functions.OnProfileCopied then
            Functions:OnProfileCopied()
        end
    end)
    MKD.db:RegisterCallback("OnProfileReset", function()
        if Functions and Functions.OnProfileReset then
            Functions:OnProfileReset()
        end
    end)
end

-- Функція для перевірки бази даних
function CheckDatabase()
    local data = MKD.db.profile
    print("Profile Settings:")
    for key, value in pairs(data) do
        print(key, value)
    end
end
