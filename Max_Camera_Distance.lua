local addonName = "Max_Camera_Distance"
local f = CreateFrame("Frame")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Max_Camera_Distance")
local CVar = C_CVar

local db
local WoWClassicEra, WoWClassicTBC, WoWRetail
local wowtocversion = select(4, GetBuildInfo())
if wowtocversion < 20000 then
	WoWClassicEra = true
elseif wowtocversion > 19999 and wowtocversion < 90000 then
	WoWClassicTBC = true
elseif wowtocversion > 89999 then
	WoWRetail = true
end

local MAX_ZOOM_FACTOR

if WoWClassicEra and WoWClassicTBC then
	MAX_ZOOM_FACTOR = 3.34
elseif WoWRetail then
	MAX_ZOOM_FACTOR = 2.6 -- Default value for WoWRetail
end

local AVERAGE_ZOOM_FACTOR = 2.0
local MIN_ZOOM_FACTOR = 1.0
local MAX_MOVE_DISTANCE = 50000
local AVERAGE_MOVE_DISTANCE = 30000
local MIN_MOVE_DISTANCE = 10000

local function SendMessage(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff0070deMax Camera Distance|r: " .. message)
end

local function AdjustCamera()
	if not InCombatLockdown() then
		SetCVar("cameraDistanceMaxZoomFactor", db.profile.maxZoomFactor)
		MoveViewOutStart(db.profile.moveViewDistance)
		CVar.SetCVar("cameraReduceUnexpectedMovement", db.profile.reduceUnexpectedMovement and "1" or "0")
		C_CVar.SetCVar("renderscale", 0.999)
		C_CVar.SetCVar("ResampleAlwaysSharpen", db.profile.resampleAlwaysSharpen and "1" or "0")
	end
end

local function ChangeCameraSettings(newMaxZoomFactor, newMoveViewDistance, newReduceMovementValue, newResampleValue,
									message)
	db.profile.maxZoomFactor = newMaxZoomFactor
	db.profile.moveViewDistance = newMoveViewDistance
	db.profile.reduceUnexpectedMovement = newReduceMovementValue
	db.profile.resampleAlwaysSharpen = newResampleValue
	AdjustCamera()
	SendMessage(message)
end

local function OnAddonLoaded(self, event, loadedAddonName)
	if loadedAddonName == addonName then
		db = AceDB:New("MaxCameraDistanceDB", { profile = defaults }, true)

		-- Встановлення початкових налаштувань камери на основі значень, збережених у базі даних
		AdjustCamera()

		-- Реєстрація функції зворотнього виклику для налаштування камери при зміні налаштувань
		db.RegisterCallback(self, "MaxCameraDistance_SettingsChanged", AdjustCamera)

		-- Відміна реєстрації прослуховувача подій після завантаження додатка
		self:UnregisterEvent("ADDON_LOADED")
	end
end

local function OnCVarUpdate(_, cvarName, value)
	-- Якщо змінено будь-який з параметрів камери, змінюємо відповідні налаштування
	if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMoveSpeed" or cvarName == "cameraReduceUnexpectedMovement" then
		local currentMaxZoomFactor = tonumber(GetCVar("cameraDistanceMaxZoomFactor"))
		local currentMoveViewDistance = tonumber(GetCVar("cameraDistanceMoveSpeed"))
		local currentReduceMovementValue = tonumber(GetCVar("cameraReduceUnexpectedMovement"))

		if currentMaxZoomFactor ~= db.profile.maxZoomFactor or currentMoveViewDistance ~= db.profile.moveViewDistance or currentReduceMovementValue ~= db.profile.reduceUnexpectedMovement then
			ChangeCameraSettings(currentMaxZoomFactor, currentMoveViewDistance,
				currentReduceMovementValue, db.profile.resampleAlwaysSharpen, L["SETTINGS_CHANGED"])
		end
	end
end

-- Реєстрація подій для відстеження змін у налаштуваннях камери
f:RegisterEvent("CVAR_UPDATE")
f:SetScript("OnEvent", OnCVarUpdate)

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
							db.profile.reduceUnexpectedMovement, db.profile.resampleAlwaysSharpen,
							L["SETTINGS_SET_TO_MAX"])
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
							db.profile.reduceUnexpectedMovement, db.profile.resampleAlwaysSharpen,
							L["SETTINGS_SET_TO_MAX"])
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
							db.profile.reduceUnexpectedMovement, db.profile.resampleAlwaysSharpen, L["SETTINGS_CHANGED"])
					end,
					order = 1,
				},
				resampleAlwaysSharpen = {
					type = "toggle",
					name = L["RESAMPLE_ALWAYS_SHARPEN"],
					desc = L["RESAMPLE_ALWAYS_SHARPEN_DESC"],
					get = function() return db.profile.resampleAlwaysSharpen end,
					set = function(_, value)
						db.profile.resampleAlwaysSharpen = value
						ChangeCameraSettings(db.profile.maxZoomFactor, db.profile.moveViewDistance,
							db.profile.reduceUnexpectedMovement, db.profile.resampleAlwaysSharpen, L["SETTINGS_CHANGED"])
					end,
					order = 2,
				},
			},
		},
	},
}

AceConfig:RegisterOptionsTable(addonName, options)
AceConfigDialog:AddToBlizOptions(addonName, "Max Camera Distance")

SLASH_MAXCAMDIST1 = "/maxcamdist"
SlashCmdList["MAXCAMDIST"] = function()
	InterfaceOptionsFrame_OpenToCategory(addonName)
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnAddonLoaded)

SLASH_DIS_MAX1 = "/dis_max"
SLASH_DIS_AVG1 = "/dis_avg"
SLASH_DIS_MIN1 = "/dis_min"

function SlashCmdList.DIS_MAX()
	ChangeCameraSettings(MAX_ZOOM_FACTOR, MAX_MOVE_DISTANCE, db.profile.reduceUnexpectedMovement,
		db.profile.ResampleAlwaysSharpen, L["SETTINGS_SET_TO_MAX"])
end

function SlashCmdList.DIS_AVG()
	ChangeCameraSettings(AVERAGE_ZOOM_FACTOR, AVERAGE_MOVE_DISTANCE, db.profile.reduceUnexpectedMovement,
		db.profile.ResampleAlwaysSharpen, L["SETTINGS_SET_TO_AVERAGE"])
end

function SlashCmdList.DIS_MIN()
	ChangeCameraSettings(MIN_ZOOM_FACTOR, MIN_MOVE_DISTANCE, db.profile.reduceUnexpectedMovement,
		db.profile.ResampleAlwaysSharpen, L["SETTINGS_SET_TO_MIN"])
end
