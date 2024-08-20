local addonName = "Max_Camera_Distance"

-- Ініціалізація налаштувань аддона
local function InitializeAddon()
	Database:InitDB()
	-- Реєструємо налаштування через Config.lua
	Config:SetupOptions()
	-- Налаштовуємо камеру на основі збережених значень
	Functions:AdjustCamera()
end

-- Function to handle events
local function OnEvent(self, event, arg1)
	-- Initialize addon when it is loaded
	if event == "ADDON_LOADED" and arg1 == addonName then
		InitializeAddon()
		self:UnregisterEvent("ADDON_LOADED")
	end

	-- Handle CVAR update events
	if event == "CVAR_UPDATE" then
		Functions:OnCVarUpdate(_, arg1, GetCVar(arg1))
	end

	-- Handle mount display changes
	if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
		Functions:OnMounted()
	end

	-- Handle combat status changes
	if event == "PLAYER_REGEN_DISABLED" then
		Functions:OnEnterCombat()
	elseif event == "PLAYER_REGEN_ENABLED" then
		Functions:OnExitCombat()
	end

	-- Handle shapeshift form changes
	if Functions:IsDruidOrShaman() then
		if event == "UPDATE_SHAPESHIFT_FORM" then
			Functions:OnForm()
		end
	end
end

-- Create a frame for event handling
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CVAR_UPDATE")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

-- Set the script for event handling
f:SetScript("OnEvent", OnEvent)

-- Реєстрація Slash команд
SLASH_MAXCAMDIST1 = "/mcd"
SlashCmdList["MAXCAMDIST"] = function(msg)
	Functions:SlashCmdHandler(msg)
end

-- Першочергові дії при завантаженні аддона
print("|cff0070deMax Camera Distance|r loaded! Type /mcd config for options.")
