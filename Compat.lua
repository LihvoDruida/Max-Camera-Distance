local addonName, ns = ...
ns.Compat = ns.Compat or {}
local Compat = ns.Compat

local type = type
local pcall = pcall
local tonumber = tonumber
local tostring = tostring

local C_CVar = C_CVar
local C_UI = C_UI
local C_AddOns = C_AddOns
local GetCVar = GetCVar
local GetCVarDefault = GetCVarDefault
local SetCVar = SetCVar
local ReloadUI = ReloadUI
local GetAddOnMetadata = GetAddOnMetadata

-- GetBuildInfo returns (version, build, date, tocversion). The 5th pcall result
-- is tocversion, NOT the build number - every threshold below is an interface
-- version, so this is the value we actually want. It used to be stored as
-- Compat.BUILD, which made /mcd status report a nonsense "build=".
local okBuild, clientVersion, buildNumber, _, tocVersion = pcall(GetBuildInfo)
Compat.INTERFACE = okBuild and (tonumber(tocVersion) or 0) or 0
Compat.VERSION = okBuild and tostring(clientVersion or '') or ''
Compat.BUILD_NUMBER = okBuild and (tonumber(buildNumber) or 0) or 0
Compat.BUILD = Compat.INTERFACE -- kept for backwards compatibility
Compat.PROJECT_ID = WOW_PROJECT_ID or 0

local WOW_PROJECT_MAINLINE_VALUE = WOW_PROJECT_MAINLINE or 1

-- Retail interface versions have been >= 100000 since Dragonflight. The old
-- >= 120000 fallback would have misclassified an 11.x client if WOW_PROJECT_ID
-- were ever unavailable.
Compat.IS_RETAIL = (Compat.PROJECT_ID == WOW_PROJECT_MAINLINE_VALUE) or (Compat.INTERFACE >= 100000)
Compat.IS_MOP_CLASSIC = (Compat.INTERFACE >= 50000 and Compat.INTERFACE < 60000)
Compat.IS_CATA_CLASSIC = (Compat.INTERFACE >= 40000 and Compat.INTERFACE < 50000)
Compat.IS_WRATH_CLASSIC = (Compat.INTERFACE >= 30000 and Compat.INTERFACE < 40000)
Compat.IS_TBC_ANNIVERSARY = (Compat.INTERFACE >= 20000 and Compat.INTERFACE < 30000)
Compat.IS_CLASSIC_ERA = (Compat.INTERFACE >= 10000 and Compat.INTERFACE < 20000)
Compat.IS_CLASSIC = not Compat.IS_RETAIL

if Compat.IS_RETAIL then
    Compat.CLIENT_TAG = 'Retail'
elseif Compat.IS_MOP_CLASSIC then
    Compat.CLIENT_TAG = 'Mists Classic'
elseif Compat.IS_CATA_CLASSIC then
    Compat.CLIENT_TAG = 'Cataclysm Classic'
elseif Compat.IS_WRATH_CLASSIC then
    Compat.CLIENT_TAG = 'Wrath Classic'
elseif Compat.IS_TBC_ANNIVERSARY then
    Compat.CLIENT_TAG = 'TBC Anniversary'
elseif Compat.IS_CLASSIC_ERA then
    Compat.CLIENT_TAG = 'Classic Era'
else
    Compat.CLIENT_TAG = Compat.IS_CLASSIC and 'Classic' or 'Unknown'
end

Compat.MAX_CAMERA_YARDS = Compat.IS_RETAIL and 39 or 50
Compat.CONVERSION_RATIO = Compat.IS_RETAIL and 15 or 12.5

function Compat.SafeGetCVar(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, val = pcall(C_CVar.GetCVar, name)
        if ok and val ~= nil then
            return val
        end
    end

    if type(GetCVar) == 'function' then
        local ok, val = pcall(GetCVar, name)
        if ok and val ~= nil then
            return val
        end
    end

    return nil
end

function Compat.SafeGetCVarNumber(name)
    local value = Compat.SafeGetCVar(name)
    return value ~= nil and tonumber(value) or nil
end

function Compat.SafeGetCVarDefault(name)
    if C_CVar and C_CVar.GetCVarDefault then
        local ok, val = pcall(C_CVar.GetCVarDefault, name)
        if ok and val ~= nil then
            return val
        end
    end

    if type(GetCVarDefault) == 'function' then
        local ok, val = pcall(GetCVarDefault, name)
        if ok and val ~= nil then
            return val
        end
    end

    return nil
end

-- Returns the CLIENT'S BUILT-IN default for a CVar as a number.
-- Unlike SafeGetCVarNumber this value never drifts, so it is safe to use as a
-- SavedVariables default (see the note in Database.lua about AceDB default stripping).
function Compat.SafeGetCVarNumberDefault(name)
    local value = Compat.SafeGetCVarDefault(name)
    return value ~= nil and tonumber(value) or nil
end

function Compat.SafeGetCVarNumberAny(names)
    if type(names) == 'string' then
        return Compat.SafeGetCVarNumber(names), names
    end

    if type(names) ~= 'table' then
        return nil, nil
    end

    for _, name in ipairs(names) do
        local value = Compat.SafeGetCVarNumber(name)
        if value ~= nil then
            return value, name
        end
    end

    return nil, nil
end

function Compat.SafeSetCVarAny(names, value)
    if type(names) == 'string' then
        if not Compat.HasCVar(names) then
            return false, nil
        end
        return Compat.SafeSetCVar(names, value), names
    end

    if type(names) ~= 'table' then
        return false, nil
    end

    for _, name in ipairs(names) do
        if Compat.HasCVar(name) then
            return Compat.SafeSetCVar(name, value), name
        end
    end

    -- Do not try to create/write unsupported CVars on older clients.
    -- Some Classic branches error or taint noisily when a Retail-only CVar is written.
    return false, nil
end

function Compat.SafeCall(func, ...)
    if type(func) ~= 'function' then
        return false, nil
    end

    return pcall(func, ...)
end

function Compat.SafeSetCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        local ok = pcall(C_CVar.SetCVar, name, value)
        if ok then
            return true
        end
    end

    if type(SetCVar) == 'function' then
        local ok = pcall(SetCVar, name, value)
        if ok then
            return true
        end
    end

    return false
end

function Compat.HasCVar(name)
    return Compat.SafeGetCVar(name) ~= nil
end

function Compat.SupportsFSRSharpen()
    return Compat.IS_RETAIL and Compat.HasCVar('resampleAlwaysSharpen')
end

function Compat.SupportsSoftTargetIcons()
    return Compat.IS_RETAIL and Compat.HasCVar('SoftTargetIconGameObject')
end

function Compat.SupportsActionCam()
    return Compat.HasCVar('test_cameraOverShoulder') or Compat.HasCVar('test_cameraDynamicPitch')
end

function Compat.SupportsScenarioZone()
    return Compat.IS_RETAIL or Compat.IS_MOP_CLASSIC
end

function Compat.GetAddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, 'Version') or 'Dev'
    end

    if GetAddOnMetadata then
        return GetAddOnMetadata(addonName, 'Version') or 'Dev'
    end

    return 'Dev'
end

function Compat.SafeReload()
    if C_UI and C_UI.Reload then
        C_UI.Reload()
    elseif ReloadUI then
        ReloadUI()
    end
end
