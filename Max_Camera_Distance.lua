local addonName = "Max_Camera_Distance"
local f = CreateFrame("Frame")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Max_Camera_Distance")
local CVar = C_CVar

local db
local MAX_ZOOM_FACTOR = 2.6
local AVERAGE_ZOOM_FACTOR = 2.0
local MIN_ZOOM_FACTOR = 1.0
local MAX_MOVE_DISTANCE = 50000
local AVERAGE_MOVE_DISTANCE = 30000
local MIN_MOVE_DISTANCE = 10000

local defaults = {
	profile = {
		maxZoomFactor = MAX_ZOOM_FACTOR,
		moveViewDistance = MAX_MOVE_DISTANCE,
		reduceUnexpectedMovement = true, -- Додано значення за замовчуванням
	},
}

local function SendMessage(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff0070deMax Camera Distance|r: " .. message)
end

local function AdjustCamera()
	if not InCombatLockdown() then
		SetCVar("cameraDistanceMaxZoomFactor", db.profile.maxZoomFactor)
		MoveViewOutStart(db.profile.moveViewDistance)
		-- Встановлює значення cameraReduceUnexpectedMovement
		CVar.SetCVar("cameraReduceUnexpectedMovement", db.profile.reduceUnexpectedMovement and "1" or "0")

		if f.Ticker then
			f.Ticker:Cancel()
			f.Ticker = nil
		end
	end
end

local function ChangeCameraSettings(newMaxZoomFactor, newMoveViewDistance, newReduceMovementValue, message)
	db.profile.maxZoomFactor = newMaxZoomFactor
	db.profile.moveViewDistance = newMoveViewDistance
	db.profile.reduceUnexpectedMovement = newReduceMovementValue
	AdjustCamera()
	SendMessage(message)
end

local function OnAddonLoaded(self, event, loadedAddonName)
	if loadedAddonName == addonName then
		db = AceDB:New("MaxCameraDistanceDB", defaults, true)

		f.Ticker = C_Timer.NewTicker(1, function()
			local currentMaxZoomFactor = tonumber(GetCVar("cameraDistanceMaxZoomFactor"))
			local currentMoveViewDistance = tonumber(GetCVar("cameraDistanceMoveSpeed"))
			local currentReduceMovementValue = tonumber(GetCVar("cameraReduceUnexpectedMovement"))

			if currentMaxZoomFactor ~= db.profile.maxZoomFactor or currentMoveViewDistance ~= db.profile.moveViewDistance or currentReduceMovementValue ~= db.profile.reduceUnexpectedMovement then
				ChangeCameraSettings(db.profile.maxZoomFactor, db.profile.moveViewDistance,
					db.profile.reduceUnexpectedMovement, L["SETTINGS_CHANGED"])
			end
		end)

		self:UnregisterEvent("ADDON_LOADED")
	end
end

local options = {
	name = "Max Camera Distance",
	type = "group",
	args = {
		generalSettings = {
			type = "group",
			name = "General Settings",
			inline = true,
			order = 1,
			args = {
				maxZoomFactor = {
					type = "range",
					name = L["MAX_ZOOM_FACTOR"],
					desc = L["MAX_ZOOM_FACTOR_DESC"],
					min = MIN_ZOOM_FACTOR,
					max = MAX_ZOOM_FACTOR,
					step = 0.1,
					get = function() return db.profile.maxZoomFactor end,
					set = function(_, value)
						db.profile.maxZoomFactor = value
						ChangeCameraSettings(db.profile.maxZoomFactor, db.profile.moveViewDistance,
							db.profile.reduceUnexpectedMovement, L["SETTINGS_SET_TO_MAX"])
					end,
					order = 1,
				},
				moveViewDistance = {
					type = "range",
					name = L["MOVE_VIDEO_DISTANCE"],
					desc = L["MOVE_VIDEO_DISTANCE_DESC"],
					min = MIN_MOVE_DISTANCE,
					max = MAX_MOVE_DISTANCE,
					step = 1000,
					get = function() return db.profile.moveViewDistance end,
					set = function(_, value)
						db.profile.moveViewDistance = value
						ChangeCameraSettings(db.profile.maxZoomFactor, db.profile.moveViewDistance,
							db.profile.reduceUnexpectedMovement, L["SETTINGS_SET_TO_MAX"])
					end,
					order = 2,
				},
			},
		},
		advancedSettings = {
			type = "group",
			name = "Advanced Settings",
			inline = true,
			order = 2,
			args = {
				reduceUnexpectedMovement = {
					type = "toggle",
					name = L["REDUCE_UNEXPECTED_MOVEMENT"],
					desc = L["REDUCE_UNEXPECTED_MOVEMENT_DESC"],
					get = function() return db.profile.reduceUnexpectedMovement end,
					set = function(_, value)
						db.profile.reduceUnexpectedMovement = value
						ChangeCameraSettings(db.profile.maxZoomFactor, db.profile.moveViewDistance,
							db.profile.reduceUnexpectedMovement, L["SETTINGS_CHANGED"])
					end,
					order = 1,
				},
			},
		},
	},
}

AceConfig:RegisterOptionsTable(addonName, options)
AceConfigDialog:AddToBlizOptions(addonName, "Max Camera Distance")

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnAddonLoaded)

SLASH_DIS_MAX1 = "/dis_max"
SLASH_DIS_AVG1 = "/dis_avg"
SLASH_DIS_MIN1 = "/dis_min"

function SlashCmdList.DIS_MAX()
	ChangeCameraSettings(MAX_ZOOM_FACTOR, MAX_MOVE_DISTANCE, db.profile.reduceUnexpectedMovement,
		L["SETTINGS_SET_TO_MAX"])
end

function SlashCmdList.DIS_AVG()
	ChangeCameraSettings(AVERAGE_ZOOM_FACTOR, AVERAGE_MOVE_DISTANCE, db.profile.reduceUnexpectedMovement,
		L["SETTINGS_SET_TO_AVERAGE"])
end

function SlashCmdList.DIS_MIN()
	ChangeCameraSettings(MIN_ZOOM_FACTOR, MIN_MOVE_DISTANCE, db.profile.reduceUnexpectedMovement,
		L["SETTINGS_SET_TO_MIN"])
end
