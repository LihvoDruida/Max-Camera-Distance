local addonName, ns = ...
ns.Locale = ns.Locale or {}
local Locale = ns.Locale

Locale.tables = ns.LocaleData or Locale.tables or {}
ns.LocaleData = Locale.tables
Locale.supported = Locale.supported or {
    enUS = true,
    deDE = true,
    frFR = true,
    zhCN = true,
    ukUA = true,
}
Locale.order = Locale.order or { "client", "enUS", "ukUA", "deDE", "frFR", "zhCN" }
Locale.nativeNames = Locale.nativeNames or {
    enUS = "English",
    deDE = "Deutsch",
    frFR = "Français",
    zhCN = "简体中文",
    ukUA = "Українська",
}

local type = type
local tostring = tostring
local format = string.format
local GetLocale = GetLocale

function Locale:RegisterLocale(localeCode, localeTable)
    if type(localeCode) ~= "string" or type(localeTable) ~= "table" then return end
    self.tables[localeCode] = localeTable
end

function Locale:IsSupported(localeCode)
    return type(localeCode) == "string" and self.supported[localeCode] == true
end

function Locale:GetClientLocale()
    local clientLocale = GetLocale and GetLocale() or "enUS"
    if self:IsSupported(clientLocale) then
        return clientLocale
    end
    return "enUS"
end

function Locale:GetOverride()
    local db = ns.Database and ns.Database.db and ns.Database.db.profile
    local value = db and db.language or "client"
    if value == "client" then
        return value
    end
    if self:IsSupported(value) then
        return value
    end
    return "client"
end

function Locale:GetActiveLocale()
    local override = self:GetOverride()
    if override == "client" then
        return self:GetClientLocale()
    end
    if self:IsSupported(override) then
        return override
    end
    return "enUS"
end

function Locale:GetTable(localeCode)
    local resolved = localeCode
    if resolved == nil or resolved == "client" then
        resolved = self:GetActiveLocale()
    end
    return self.tables[resolved] or self.tables.enUS or {}
end

function Locale:Get(key)
    local activeTable = self:GetTable(self:GetActiveLocale())
    local value = activeTable and activeTable[key]
    if value ~= nil then
        return value
    end

    local fallbackTable = self.tables.enUS or {}
    value = fallbackTable[key]
    if value ~= nil then
        return value
    end

    return key
end

function Locale:SetOverride(localeCode)
    local db = ns.Database and ns.Database.db and ns.Database.db.profile
    if not db then return end

    if localeCode == "client" or self:IsSupported(localeCode) then
        db.language = localeCode
    else
        db.language = "client"
    end
end

function Locale:GetNativeLanguageName(localeCode)
    if localeCode == "client" then
        local clientLocale = self:GetClientLocale()
        local baseLabel = self:Get("LANGUAGE_CLIENT_DEFAULT") or "Client Default"
        local clientLabel = self.nativeNames[clientLocale] or tostring(clientLocale)
        return format("%s (%s)", baseLabel, clientLabel)
    end

    return self.nativeNames[localeCode] or tostring(localeCode)
end

function Locale:GetOptionsValues()
    local values = {}
    for _, localeCode in ipairs(self.order) do
        values[localeCode] = self:GetNativeLanguageName(localeCode)
    end
    return values
end
