local L = LibStub("AceLocale-3.0"):GetLocale("Max_Camera_Distance")
local addonName = "Max_Camera_Distance"
local f = CreateFrame("Frame")
local initialized = false

local MAX_ZOOM_FACTOR = 2.6
local AVERAGE_ZOOM_FACTOR = 2.0
local MIN_ZOOM_FACTOR = 1.0

local MAX_MOVE_DISTANCE = 50000
local AVERAGE_MOVE_DISTANCE = 30000
local MIN_MOVE_DISTANCE = 10000

local function SendMessage(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff0070deMax Camer Distance|r: " .. message)
end

local function AdjustCamera()
	if not InCombatLockdown() then
		SetCVar("cameraDistanceMaxZoomFactor", MAX_ZOOM_FACTOR)
		MoveViewOutStart(MAX_MOVE_DISTANCE)

		if f.Ticker then
			f.Ticker:Cancel()
			f.Ticker = nil
		end
	end
end

local function ChangeCameraSettings(newMaxZoomFactor, newMoveViewDistance, message)
	if not initialized then
		local AceDB = LibStub("AceDB-3.0")
		addonSettings = AceDB:New("MaxCameraDistanceDB", {
			profile = {
				maxZoomFactor = MAX_ZOOM_FACTOR,
				moveViewDistance = MAX_MOVE_DISTANCE,
			},
		}, false)
		initialized = true
	end

	addonSettings.profile.maxZoomFactor = newMaxZoomFactor
	addonSettings.profile.moveViewDistance = newMoveViewDistance

	MAX_ZOOM_FACTOR = newMaxZoomFactor
	MAX_MOVE_DISTANCE = newMoveViewDistance

	AdjustCamera()
	SendMessage(message)
end

if not initialized then
	ChangeCameraSettings(MAX_ZOOM_FACTOR, MAX_MOVE_DISTANCE, L["SETTINGS_SET_TO_DEFAULT"])
end

local function OnAddonLoaded(self, event, loadedAddonName)
	if loadedAddonName == addonName then
		f.Ticker = C_Timer.NewTicker(1, function()
			local currentMaxZoomFactor = tonumber(GetCVar("cameraDistanceMaxZoomFactor"))
			local currentMoveViewDistance = tonumber(GetCVar("cameraDistanceMoveSpeed"))

			if currentMaxZoomFactor ~= MAX_ZOOM_FACTOR or currentMoveViewDistance ~= MAX_MOVE_DISTANCE then
				ChangeCameraSettings(currentMaxZoomFactor, currentMoveViewDistance, L["SETTINGS_CHANGED"])
			end
		end)

		self:UnregisterEvent("ADDON_LOADED")
	end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnAddonLoaded)

SLASH_DIS_MAX1 = "/dis_max"
SLASH_DIS_AVG1 = "/dis_avg"
SLASH_DIS_MIN1 = "/dis_min"

function SlashCmdList.DIS_MAX()
	ChangeCameraSettings(MAX_ZOOM_FACTOR, MAX_MOVE_DISTANCE, L["SETTINGS_SET_TO_MAX"])
end

function SlashCmdList.DIS_AVG()
	ChangeCameraSettings(AVERAGE_ZOOM_FACTOR, AVERAGE_MOVE_DISTANCE, L["SETTINGS_SET_TO_AVERAGE"])
end

function SlashCmdList.DIS_MIN()
	ChangeCameraSettings(MIN_ZOOM_FACTOR, MIN_MOVE_DISTANCE, L["SETTINGS_SET_TO_MIN"])
end
