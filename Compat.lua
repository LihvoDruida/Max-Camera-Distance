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

-- WoW: Forever (codename Camelot) is a separate product/flavor, but its
-- interface/runtime is forked from the modern client and currently reports the
-- mainline project ID. A WOW_PROJECT_ID check therefore cannot distinguish it
-- from Retail. The authoritative signal is the dedicated Camelot TOC, which
-- loads Forever.lua before this file. The build/interface fallback only keeps
-- source copies functional when the marker file is accidentally omitted.
local clientFlavor = ns.ClientFlavor or {}
local versionLooksForever = Compat.VERSION:match('^1%.60%.') ~= nil
local interfaceLooksForever = Compat.INTERFACE >= 16000 and Compat.INTERFACE < 17000
Compat.IS_FOREVER = (clientFlavor.FOREVER == true) or (versionLooksForever and interfaceLooksForever)
Compat.FOREVER_MARKER_SOURCE = clientFlavor.SOURCE

-- Keep product identity and API-family identity separate. Forever is NOT Retail
-- and NOT Classic Era, but it does use the modern UI/API/CVar family. This split
-- prevents Classic-only gameplay features from being mixed with modern API
-- compatibility shims.
Compat.IS_RETAIL = (not Compat.IS_FOREVER) and ((Compat.PROJECT_ID == WOW_PROJECT_MAINLINE_VALUE) or (Compat.INTERFACE >= 100000))
Compat.USES_MODERN_API = Compat.IS_RETAIL or Compat.IS_FOREVER
Compat.IS_MOP_CLASSIC = (not Compat.IS_FOREVER) and (Compat.INTERFACE >= 50000 and Compat.INTERFACE < 60000)
Compat.IS_CATA_CLASSIC = (not Compat.IS_FOREVER) and (Compat.INTERFACE >= 40000 and Compat.INTERFACE < 50000)
Compat.IS_WRATH_CLASSIC = (not Compat.IS_FOREVER) and (Compat.INTERFACE >= 30000 and Compat.INTERFACE < 40000)
Compat.IS_TBC_ANNIVERSARY = (not Compat.IS_FOREVER) and (Compat.INTERFACE >= 20000 and Compat.INTERFACE < 30000)
Compat.IS_CLASSIC_ERA = (not Compat.IS_FOREVER) and (Compat.INTERFACE >= 10000 and Compat.INTERFACE < 20000)
Compat.IS_CLASSIC = Compat.IS_MOP_CLASSIC or Compat.IS_CATA_CLASSIC or Compat.IS_WRATH_CLASSIC
    or Compat.IS_TBC_ANNIVERSARY or Compat.IS_CLASSIC_ERA
Compat.IS_CLASSIC_FAMILY = Compat.IS_CLASSIC or Compat.IS_FOREVER

-- Midnight (12.0) introduced Secret Values; 12.1 tightened them considerably.
-- Forever may expose some of the same modern helpers because it shares the
-- modern runtime, so secret handling itself remains feature-detected below.
Compat.IS_MIDNIGHT = Compat.IS_RETAIL and Compat.INTERFACE >= 120000
Compat.IS_12_1_OR_LATER = Compat.IS_RETAIL and Compat.INTERFACE >= 120100
Compat.HAS_SECRET_VALUES = type(_G.issecretvalue) == 'function'

if Compat.IS_FOREVER then
    Compat.CLIENT_TAG = 'Forever'
elseif Compat.IS_RETAIL then
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

-- Forever's 1.60.x client uses the modern camera/CVar family, so it follows the
-- modern camera units/cap rather than Classic Era's 12.5/50-yard model.
Compat.MAX_CAMERA_YARDS = Compat.USES_MODERN_API and 39 or 50
Compat.CONVERSION_RATIO = Compat.USES_MODERN_API and 15 or 12.5

-- ---------------------------------------------------------------------
-- Secret value helpers (Midnight 12.0+, tightened in 12.1)
-- ---------------------------------------------------------------------
-- Tainted code may STORE and PASS secret values freely, but evaluating one in a
-- condition, comparison or table index is an immediate Lua error. Every value
-- that can come back from a unit/aura API therefore has to be screened before
-- it is used, not merely wrapped in pcall at the call site.
local issecretvalue = _G.issecretvalue
local canaccessvalue = _G.canaccessvalue
local canaccesstable = _G.canaccesstable

function Compat.IsSecret(value)
    if type(issecretvalue) ~= 'function' then
        return false
    end
    local ok, result = pcall(issecretvalue, value)
    return ok and result and true or false
end

-- True when the current execution context is allowed to operate on secrets at
-- all. Untainted code can; addon code generally cannot.
function Compat.CanAccessSecrets(value)
    if type(canaccessvalue) ~= 'function' then
        return true
    end
    local ok, result = pcall(canaccessvalue, value)
    return ok and result and true or false
end

function Compat.CanAccessTable(value)
    if type(value) ~= 'table' then
        return false
    end
    if type(canaccesstable) ~= 'function' then
        return true
    end
    local ok, result = pcall(canaccesstable, value)
    return ok and result and true or false
end

-- Secret-safe truthiness. Returns false for secrets instead of erroring, which
-- is the correct fallback everywhere in this addon: an unreadable aura or combat
-- flag simply means "do not switch camera state on account of it".
function Compat.IsTruthy(value)
    if value == nil then
        return false
    end
    if Compat.IsSecret(value) then
        return false
    end
    local ok, result = pcall(function() return value and true or false end)
    return ok and result and true or false
end

-- Returns value only when it is a plain, readable value; nil otherwise. Use for
-- anything that will be compared or used as a table key.
function Compat.Plain(value)
    if value == nil or Compat.IsSecret(value) then
        return nil
    end
    return value
end

-- 12.1 added C_CVar.AreCVarsLoaded. Probing CVars before they exist reports
-- "unsupported" and would permanently disable feature-gated options, so treat an
-- unavailable API as "loaded" and only ever return false when we truly know.
function Compat.AreCVarsLoaded()
    if C_CVar and C_CVar.AreCVarsLoaded then
        local ok, result = pcall(C_CVar.AreCVarsLoaded)
        if ok then
            return result and true or false
        end
    end
    return true
end

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
    return Compat.USES_MODERN_API and Compat.HasCVar('resampleAlwaysSharpen')
end

function Compat.SupportsSoftTargetIcons()
    return Compat.USES_MODERN_API and Compat.HasCVar('SoftTargetIconGameObject')
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
