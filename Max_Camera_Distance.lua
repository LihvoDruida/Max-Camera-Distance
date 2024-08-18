local addonName = "Max_Camera_Distance"
local f = CreateFrame("Frame")

-- Ініціалізація налаштувань аддона
local function InitializeAddon()
	Database:InitDB()
	-- Реєструємо налаштування через Config.lua
	Config:SetupOptions()
	-- Налаштовуємо камеру на основі збережених значень
	Functions:AdjustCamera()
end

-- Реєстрація подій
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CVAR_UPDATE")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
f:RegisterEvent("UNIT_ENTERED_VEHICLE")
f:RegisterEvent("UNIT_EXITED_VEHICLE")

-- Обробка подій
local function OnEvent(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		-- Завантаження та застосування налаштувань після завантаження аддона
		InitializeAddon()

		-- Відписуємось від події після ініціалізації
		self:UnregisterEvent("ADDON_LOADED")
	end
	if event == "CVAR_UPDATE" then
		-- Обробка оновлення CVAR
		Functions:OnCVarUpdate(_, arg1, GetCVar(arg1))
	end
	if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
		Functions:OnMounted()
	end
	if event == "PLAYER_REGEN_DISABLED" then
		-- Гравець вступає в бій
		Functions:OnCombat()
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- Гравець виходить із бою
		Functions:OnCombat()
	end
	if Functions:IsDruidOrShaman() then
		if event == "UPDATE_SHAPESHIFT_FORM" then
			local formID = GetShapeshiftForm()
			if formID > 0 then
				Functions:OnEnterForm()
			else
				Functions:OnExitForm()
			end
		end

		if event == "UNIT_ENTERED_VEHICLE" and arg1 == "player" then
			Functions:OnEnterForm()
		end

		if event == "UNIT_EXITED_VEHICLE" and arg1 == "player" then
			Functions:OnExitForm()
		end
	end
end

-- Set the script for event handling
f:SetScript("OnEvent", OnEvent)

-- Реєстрація Slash команд
SLASH_MAXCAMDIST1 = "/mcd"
SlashCmdList["MAXCAMDIST"] = function(msg)
	Functions:SlashCmdHandler(msg)
end

-- Першочергові дії при завантаженні аддона
print("|cff0070deMax Camera Distance|r loaded! Type /mcd for options.")
