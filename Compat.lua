local addonName, ns = ...
ns.Compat = ns.Compat or {}
local Compat = ns.Compat

local type = type
local pcall = pcall
local tonumber = tonumber

local C_CVar = C_CVar
local C_UI = C_UI
local C_AddOns = C_AddOns
local GetCVar = GetCVar
local SetCVar = SetCVar
local ReloadUI = ReloadUI
local GetAddOnMetadata = GetAddOnMetadata

local _, _, _, buildNumber = GetBuildInfo()
Compat.BUILD = tonumber(buildNumber) or 0
Compat.PROJECT_ID = WOW_PROJECT_ID or 0

Compat.IS_RETAIL = (Compat.PROJECT_ID == WOW_PROJECT_MAINLINE) or (Compat.BUILD >= 120000)
Compat.IS_MOP_CLASSIC = (Compat.BUILD >= 50000 and Compat.BUILD < 60000)
Compat.IS_TBC_ANNIVERSARY = (Compat.BUILD >= 20000 and Compat.BUILD < 30000)
Compat.IS_CLASSIC_ERA = (Compat.BUILD >= 10000 and Compat.BUILD < 20000)
Compat.IS_CLASSIC = not Compat.IS_RETAIL

if Compat.IS_RETAIL then
    Compat.CLIENT_TAG = 'Retail'
elseif Compat.IS_MOP_CLASSIC then
    Compat.CLIENT_TAG = 'Mists Classic'
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
