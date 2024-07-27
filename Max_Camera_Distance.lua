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
elseif wowtocversion >= 20000 and wowtocversion < 90000 then
	WoWClassicTBC = true
elseif wowtocversion >= 90000 then
	WoWRetail = true
end

local MAX_ZOOM_FACTOR

if WoWClassicEra or WoWClassicTBC then
	MAX_ZOOM_FACTOR = 3.34
elseif WoWRetail then
	MAX_ZOOM_FACTOR = 2.6 -- Значення за замовчуванням для WoWRetail
end

local AVERAGE_ZOOM_FACTOR = 2.0
local MIN_ZOOM_FACTOR = 1.0
local MAX_MOVE_DISTANCE = 50000
local AVERAGE_MOVE_DISTANCE = 30000
local MIN_MOVE_DISTANCE = 10000

local MAX_YAW_SPEED = 500
local MIN_YAW_SPEED = 10
local AVERAGE_YAW_SPEED = 250

local MAX_PITCH_SPEED = 500
local MIN_PITCH_SPEED = 10
local AVERAGE_PITCH_SPEED = 250

local function SendMessage(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff0070deMax Camera Distance|r: " .. message)
end

local function AdjustCamera()
	if not InCombatLockdown() and IsLoggedIn() then
		SetCVar("cameraDistanceMaxZoomFactor", db.profile.maxZoomFactor)
		MoveViewOutStart(db.profile.moveViewDistance)
		CVar.SetCVar("cameraReduceUnexpectedMovement", db.profile.reduceUnexpectedMovement and "1" or "0")
		CVar.SetCVar("renderscale", 0.999)
		CVar.SetCVar("ResampleAlwaysSharpen", db.profile.resampleAlwaysSharpen and "1" or "0")

		-- Налаштування швидкостей обертання yaw та pitch
		SetCVar("cameraYawMoveSpeed", db.profile.cameraYawMoveSpeed)
		SetCVar("cameraPitchMoveSpeed", db.profile.cameraPitchMoveSpeed)
	end
end

local function ChangeCameraSettings(newMaxZoomFactor, newMoveViewDistance, newReduceMovementValue, newResampleValue,
									newCameraYawSpeed, newCameraPitchSpeed, message)
	if IsLoggedIn() then
		db.profile.maxZoomFactor = newMaxZoomFactor
		db.profile.moveViewDistance = newMoveViewDistance
		db.profile.reduceUnexpectedMovement = newReduceMovementValue
		db.profile.resampleAlwaysSharpen = newResampleValue
		db.profile.cameraYawMoveSpeed = newCameraYawSpeed
		db.profile.cameraPitchMoveSpeed = newCameraPitchSpeed
		AdjustCamera()
		SendMessage(message)
	else
		SendMessage("Cannot change settings while in character edit mode.")
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
							db.profile.reduceUnexpectedMovement, db.profile.resampleAlwaysSharpen,
							db.profile.cameraYawMoveSpeed, db.profile.cameraPitchMoveSpeed,
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
							db.profile.cameraYawMoveSpeed, db.profile.cameraPitchMoveSpeed,
							L["SETTINGS_CHANGED"])
					end,
					order = 2,
				},
				cameraYawMoveSpeed = {
					type = "range",
					name = L["YAW_MOVE_SPEED"],
					desc = L["YAW_MOVE_SPEED_DESC"],
					min = MIN_YAW_SPEED,
					max = MAX_YAW_SPEED,
					step = 10,
					get = function() return db.profile.cameraYawMoveSpeed end,
					set = function(_, value)
						db.profile.cameraYawMoveSpeed = value
						ChangeCameraSettings(db.profile.maxZoomFactor, db.profile.moveViewDistance,
							db.profile.reduceUnexpectedMovement, db.profile.resampleAlwaysSharpen,
							db.profile.cameraYawMoveSpeed, db.profile.cameraPitchMoveSpeed,
							L["SETTINGS_CHANGED"])
					end,
					order = 3,
				},
				cameraPitchMoveSpeed = {
					type = "range",
					name = L["PITCH_MOVE_SPEED"],
					desc = L["PITCH_MOVE_SPEED_DESC"],
					min = MIN_PITCH_SPEED,
					max = MAX_PITCH_SPEED,
					step = 10,
					get = function() return db.profile.cameraPitchMoveSpeed end,
					set = function(_, value)
						db.profile.cameraPitchMoveSpeed = value
						ChangeCameraSettings(db.profile.maxZoomFactor, db.profile.moveViewDistance,
							db.profile.reduceUnexpectedMovement, db.profile.resampleAlwaysSharpen,
							db.profile.cameraYawMoveSpeed, db.profile.cameraPitchMoveSpeed,
							L["SETTINGS_CHANGED"])
					end,
					order = 4,
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
							db.profile.reduceUnexpectedMovement, db.profile.resampleAlwaysSharpen,
							db.profile.cameraYawMoveSpeed, db.profile.cameraPitchMoveSpeed,
							L["SETTINGS_CHANGED"])
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
							db.profile.reduceUnexpectedMovement, db.profile.resampleAlwaysSharpen,
							db.profile.cameraYawMoveSpeed, db.profile.cameraPitchMoveSpeed,
							L["SETTINGS_CHANGED"])
					end,
					order = 2,
				},
			},
		},
	},
}

-- Реєстрація параметрів з AceConfig та додавання до опцій Blizzard
AceConfig:RegisterOptionsTable(addonName, options)
AceConfigDialog:AddToBlizOptions(addonName, "Max Camera Distance")

local function OnCVarUpdate(_, cvarName, value)
	-- Якщо змінено будь-який з параметрів камери, змінюємо відповідні налаштування
	if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMoveSpeed" or cvarName == "cameraReduceUnexpectedMovement" or cvarName == "cameraYawMoveSpeed" or cvarName == "cameraPitchMoveSpeed" then
		local currentMaxZoomFactor = tonumber(GetCVar("cameraDistanceMaxZoomFactor"))
		local currentMoveViewDistance = tonumber(GetCVar("cameraDistanceMoveSpeed"))
		local currentReduceMovementValue = tonumber(GetCVar("cameraReduceUnexpectedMovement"))
		local currentYawSpeed = tonumber(GetCVar("cameraYawMoveSpeed"))
		local currentPitchSpeed = tonumber(GetCVar("cameraPitchMoveSpeed"))

		if currentMaxZoomFactor ~= db.profile.maxZoomFactor or currentMoveViewDistance ~= db.profile.moveViewDistance or currentReduceMovementValue ~= db.profile.reduceUnexpectedMovement or currentYawSpeed ~= db.profile.cameraYawMoveSpeed or currentPitchSpeed ~= db.profile.cameraPitchMoveSpeed then
			ChangeCameraSettings(currentMaxZoomFactor, currentMoveViewDistance,
				currentReduceMovementValue, db.profile.resampleAlwaysSharpen,
				currentYawSpeed, currentPitchSpeed, L["SETTINGS_CHANGED"])
		end
	end
end

-- Реєстрація подій для відстеження змін у налаштуваннях камери
f:RegisterEvent("CVAR_UPDATE")
f:SetScript("OnEvent", OnCVarUpdate)

-- Обробник команд Slash
local function SlashCmdHandler(msg, editBox)
	local command = strlower(msg)
	if command == "max" then
		ChangeCameraSettings(MAX_ZOOM_FACTOR, MAX_MOVE_DISTANCE, db.profile.reduceUnexpectedMovement,
			db.profile.resampleAlwaysSharpen, MAX_YAW_SPEED, MAX_PITCH_SPEED, L["SETTINGS_SET_TO_MAX"])
	elseif command == "avg" then
		ChangeCameraSettings(AVERAGE_ZOOM_FACTOR, AVERAGE_MOVE_DISTANCE, db.profile.reduceUnexpectedMovement,
			db.profile.resampleAlwaysSharpen, AVERAGE_YAW_SPEED, AVERAGE_PITCH_SPEED, L["SETTINGS_SET_TO_AVERAGE"])
	elseif command == "min" then
		ChangeCameraSettings(MIN_ZOOM_FACTOR, MIN_MOVE_DISTANCE, db.profile.reduceUnexpectedMovement,
			db.profile.resampleAlwaysSharpen, MIN_YAW_SPEED, MIN_PITCH_SPEED, L["SETTINGS_SET_TO_MIN"])
	elseif command == "config" then
		InterfaceOptionsFrame_OpenToCategory("Max Camera Distance")
	else
		print("Usage: /maxcamdist max | avg | min | config")
	end
end

-- Реєстрація Slash команд
SLASH_MAXCAMDIST1 = "/maxcamdist"
SlashCmdList["MAXCAMDIST"] = SlashCmdHandler

-- Обробник подій для ADDON_LOADED
local function OnAddonLoaded(self, event, loadedAddonName)
	if loadedAddonName == addonName then
		db = AceDB:New("MaxCameraDistanceDB",
			{ profile = { maxZoomFactor = MAX_ZOOM_FACTOR, moveViewDistance = AVERAGE_MOVE_DISTANCE, reduceUnexpectedMovement = false, resampleAlwaysSharpen = false, cameraYawMoveSpeed = AVERAGE_YAW_SPEED, cameraPitchMoveSpeed = AVERAGE_PITCH_SPEED } },
			true)

		-- Встановлення початкових налаштувань камери на основі значень, збережених у базі даних
		AdjustCamera()

		-- Реєстрація функції зворотного виклику для налаштування камери при зміні налаштувань
		db.RegisterCallback(self, "OnProfileChanged", AdjustCamera)
		db.RegisterCallback(self, "OnProfileCopied", AdjustCamera)
		db.RegisterCallback(self, "OnProfileReset", AdjustCamera)

		-- Відміна реєстрації прослуховувача подій після завантаження додатка
		self:UnregisterEvent("ADDON_LOADED")
	end
end

-- Реєстрація події ADDON_LOADED
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnAddonLoaded)
