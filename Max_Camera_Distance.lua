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
	MAX_ZOOM_FACTOR = 2.6
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
		if db.profile.maxZoomFactor then
			SetCVar("cameraDistanceMaxZoomFactor", db.profile.maxZoomFactor)
		end
		if db.profile.moveViewDistance then
			MoveViewOutStart(db.profile.moveViewDistance)
		end
		if db.profile.reduceUnexpectedMovement ~= nil then
			CVar.SetCVar("cameraReduceUnexpectedMovement", db.profile.reduceUnexpectedMovement and "1" or "0")
		end
		if db.profile.resampleAlwaysSharpen ~= nil then
			CVar.SetCVar("ResampleAlwaysSharpen", db.profile.resampleAlwaysSharpen and "1" or "0")
		end
		if db.profile.cameraIndirectVisibility ~= nil then
			CVar.SetCVar("cameraIndirectVisibility", db.profile.cameraIndirectVisibility and "1" or "0")
		end
		if db.profile.cameraYawMoveSpeed then
			SetCVar("cameraYawMoveSpeed", db.profile.cameraYawMoveSpeed)
		end
		if db.profile.cameraPitchMoveSpeed then
			SetCVar("cameraPitchMoveSpeed", db.profile.cameraPitchMoveSpeed)
		end
	end
end

local function ChangeCameraSetting(key, value, message)
	if IsLoggedIn() then
		db.profile[key] = value
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
						ChangeCameraSetting("maxZoomFactor", value, L["SETTINGS_CHANGED"])
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
						ChangeCameraSetting("moveViewDistance", value, L["SETTINGS_CHANGED"])
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
						ChangeCameraSetting("cameraYawMoveSpeed", value, L["SETTINGS_CHANGED"])
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
						ChangeCameraSetting("cameraPitchMoveSpeed", value, L["SETTINGS_CHANGED"])
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
						ChangeCameraSetting("reduceUnexpectedMovement", value, L["SETTINGS_CHANGED"])
					end,
					order = 1,
				},
				resampleAlwaysSharpen = {
					type = "toggle",
					name = L["RESAMPLE_ALWAYS_SHARPEN"],
					desc = L["RESAMPLE_ALWAYS_SHARPEN_DESC"],
					get = function() return db.profile.resampleAlwaysSharpen end,
					set = function(_, value)
						ChangeCameraSetting("resampleAlwaysSharpen", value, L["SETTINGS_CHANGED"])
					end,
					order = 2,
				},
				cameraIndirectVisibility = {
					type = "toggle",
					name = L["INDIRECT_VISIBILITY"],
					desc = L["INDIRECT_VISIBILITY_DESC"],
					get = function() return db.profile.cameraIndirectVisibility end,
					set = function(_, value)
						ChangeCameraSetting("cameraIndirectVisibility", value, L["SETTINGS_CHANGED"])
					end,
					order = 3,
				}
			},
		},
	},
}

-- Register AceConfig options and add to Blizzard options
AceConfig:RegisterOptionsTable(addonName, options)
AceConfigDialog:AddToBlizOptions(addonName, "Max Camera Distance")

local function OnCVarUpdate(_, cvarName, value)
	-- Check if any relevant CVars are updated
	if cvarName == "cameraDistanceMaxZoomFactor" or cvarName == "cameraDistanceMoveSpeed" or cvarName == "cameraReduceUnexpectedMovement" or cvarName == "cameraYawMoveSpeed" or cvarName == "cameraPitchMoveSpeed" or cvarName == "cameraIndirectVisibility" then
		local currentMaxZoomFactor = tonumber(GetCVar("cameraDistanceMaxZoomFactor"))
		local currentMoveViewDistance = tonumber(GetCVar("cameraDistanceMoveSpeed"))
		local currentReduceMovementValue = tonumber(GetCVar("cameraReduceUnexpectedMovement"))
		local currentYawSpeed = tonumber(GetCVar("cameraYawMoveSpeed"))
		local currentPitchSpeed = tonumber(GetCVar("cameraPitchMoveSpeed"))
		local currentIndirectVisibility = tonumber(GetCVar("cameraIndirectVisibility"))

		-- Only change settings if any value is different
		if currentMaxZoomFactor ~= db.profile.maxZoomFactor then
			ChangeCameraSetting("maxZoomFactor", currentMaxZoomFactor, L["SETTINGS_CHANGED"])
		end
		if currentMoveViewDistance ~= db.profile.moveViewDistance then
			ChangeCameraSetting("moveViewDistance", currentMoveViewDistance, L["SETTINGS_CHANGED"])
		end
		if currentReduceMovementValue ~= db.profile.reduceUnexpectedMovement then
			ChangeCameraSetting("reduceUnexpectedMovement", currentReduceMovementValue, L["SETTINGS_CHANGED"])
		end
		if currentYawSpeed ~= db.profile.cameraYawMoveSpeed then
			ChangeCameraSetting("cameraYawMoveSpeed", currentYawSpeed, L["SETTINGS_CHANGED"])
		end
		if currentPitchSpeed ~= db.profile.cameraPitchMoveSpeed then
			ChangeCameraSetting("cameraPitchMoveSpeed", currentPitchSpeed, L["SETTINGS_CHANGED"])
		end
		if currentIndirectVisibility ~= db.profile.cameraIndirectVisibility then
			ChangeCameraSetting("cameraIndirectVisibility", currentIndirectVisibility, L["SETTINGS_CHANGED"])
		end
	end
end

-- Register CVAR_UPDATE event
f:RegisterEvent("CVAR_UPDATE")
f:SetScript("OnEvent", OnCVarUpdate)

-- Slash command handler
local function SlashCmdHandler(msg, editBox)
	local command = strlower(msg)
	if command == "max" then
		ChangeCameraSetting("maxZoomFactor", MAX_ZOOM_FACTOR, L["SETTINGS_SET_TO_MAX"])
		ChangeCameraSetting("moveViewDistance", MAX_MOVE_DISTANCE, L["SETTINGS_SET_TO_MAX"])
		ChangeCameraSetting("cameraYawMoveSpeed", MAX_YAW_SPEED, L["SETTINGS_SET_TO_MAX"])
		ChangeCameraSetting("cameraPitchMoveSpeed", MAX_PITCH_SPEED, L["SETTINGS_SET_TO_MAX"])
	elseif command == "avg" then
		ChangeCameraSetting("maxZoomFactor", AVERAGE_ZOOM_FACTOR, L["SETTINGS_SET_TO_AVERAGE"])
		ChangeCameraSetting("moveViewDistance", AVERAGE_MOVE_DISTANCE, L["SETTINGS_SET_TO_AVERAGE"])
		ChangeCameraSetting("cameraYawMoveSpeed", AVERAGE_YAW_SPEED, L["SETTINGS_SET_TO_AVERAGE"])
		ChangeCameraSetting("cameraPitchMoveSpeed", AVERAGE_PITCH_SPEED, L["SETTINGS_SET_TO_AVERAGE"])
	elseif command == "min" then
		ChangeCameraSetting("maxZoomFactor", MIN_ZOOM_FACTOR, L["SETTINGS_SET_TO_MIN"])
		ChangeCameraSetting("moveViewDistance", MIN_MOVE_DISTANCE, L["SETTINGS_SET_TO_MIN"])
		ChangeCameraSetting("cameraYawMoveSpeed", MIN_YAW_SPEED, L["SETTINGS_SET_TO_MIN"])
		ChangeCameraSetting("cameraPitchMoveSpeed", MIN_PITCH_SPEED, L["SETTINGS_SET_TO_MIN"])
	elseif command == "config" then
		InterfaceOptionsFrame_OpenToCategory("Max Camera Distance")
	else
		print("Usage: /maxcamdist max | avg | min | config")
	end
end

-- Register Slash commands
SLASH_MAXCAMDIST1 = "/maxcamdist"
SlashCmdList["MAXCAMDIST"] = SlashCmdHandler

-- ADDON_LOADED event handler
local function OnAddonLoaded(self, event, loadedAddonName)
	if loadedAddonName == addonName then
		db = AceDB:New("MaxCameraDistanceDB",
			{ profile = { maxZoomFactor = MAX_ZOOM_FACTOR, moveViewDistance = AVERAGE_MOVE_DISTANCE, reduceUnexpectedMovement = false, resampleAlwaysSharpen = false, cameraYawMoveSpeed = AVERAGE_YAW_SPEED, cameraPitchMoveSpeed = AVERAGE_PITCH_SPEED, cameraIndirectVisibility = false } },
			true)

		-- Apply initial camera settings
		AdjustCamera()

		-- Register callback functions for database profile changes
		db.RegisterCallback(self, "OnProfileChanged", AdjustCamera)
		db.RegisterCallback(self, "OnProfileCopied", AdjustCamera)
		db.RegisterCallback(self, "OnProfileReset", AdjustCamera)

		-- Unregister event handler after the addon is loaded
		self:UnregisterEvent("ADDON_LOADED")
	end
end

-- Register ADDON_LOADED event
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnAddonLoaded)
