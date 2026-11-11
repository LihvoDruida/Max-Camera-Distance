local addonName, ns = ...
ns.Compat = ns.Compat or {}
local Compat = ns.Compat

local type = type
local pcall = pcall
local tonumber = tonumber
local tostring = tostring

local GetCVar = GetCVar
local GetCVarDefault = GetCVarDefault
local SetCVar = SetCVar
local ReloadUI = ReloadUI
local GetAddOnMetadata = GetAddOnMetadata
local InCombatLockdown = InCombatLockdown

-- Presence and write-policy metadata are immutable for a client session. Cache
-- them once CVars are loaded instead of repeatedly querying C_CVar from config
-- hidden callbacks and managed-CVar writes. Negative presence results are never
-- cached before AreCVarsLoaded() says the table is ready.
local cvarPresenceCache = {}
local cvarWritePolicyCache = {}

-- GetBuildInfo returns (version, build, date, tocversion). The 5th pcall result
-- is tocversion, NOT the build number - every threshold below is an interface
-- version, so this is the value we actually want. It used to be stored as
-- Compat.BUILD, which made /mcd status report a nonsense "build=".
local okBuild, clientVersion, buildNumber, _, tocVersion = pcall(GetBuildInfo)
Compat.VERSION = okBuild and tostring(clientVersion or '') or ''
Compat.VERSION_MAJOR, Compat.VERSION_MINOR, Compat.VERSION_PATCH = Compat.VERSION:match('^(%d+)%.(%d+)%.?(%d*)')
Compat.VERSION_MAJOR = tonumber(Compat.VERSION_MAJOR) or 0
Compat.VERSION_MINOR = tonumber(Compat.VERSION_MINOR) or 0
Compat.VERSION_PATCH = tonumber(Compat.VERSION_PATCH) or 0
Compat.INTERFACE = okBuild and (tonumber(tocVersion) or 0) or 0
Compat.INTERFACE_SOURCE = Compat.INTERFACE > 0 and 'GetBuildInfo' or 'unknown'
if Compat.INTERFACE == 0 and Compat.VERSION_MAJOR > 0 then
    Compat.INTERFACE = Compat.VERSION_MAJOR * 10000 + Compat.VERSION_MINOR * 100 + Compat.VERSION_PATCH
    Compat.INTERFACE_SOURCE = 'version'
end
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
-- A mainline project ID alone is not enough: modified Classic clients can
-- report 1. Conversely, a future Classic expansion must not become Retail
-- merely because its interface number crosses a numeric threshold.
Compat.IS_RETAIL = (not Compat.IS_FOREVER) and Compat.INTERFACE >= 60000
    and (Compat.PROJECT_ID == WOW_PROJECT_MAINLINE_VALUE or Compat.PROJECT_ID == 0)
Compat.USES_MODERN_API = Compat.IS_RETAIL or Compat.IS_FOREVER
Compat.IS_MOP_CLASSIC = (not Compat.IS_FOREVER and not Compat.IS_RETAIL) and (Compat.INTERFACE >= 50000 and Compat.INTERFACE < 60000)
Compat.IS_CATA_CLASSIC = (not Compat.IS_FOREVER and not Compat.IS_RETAIL) and (Compat.INTERFACE >= 40000 and Compat.INTERFACE < 50000)
Compat.IS_TITAN_REFORGED = (not Compat.IS_FOREVER and not Compat.IS_RETAIL)
    and (Compat.VERSION:match('^3%.80%.') ~= nil or (Compat.INTERFACE >= 38000 and Compat.INTERFACE < 39000))
Compat.IS_WRATH_CLASSIC = (not Compat.IS_FOREVER and not Compat.IS_RETAIL) and (Compat.INTERFACE >= 30000 and Compat.INTERFACE < 40000)
Compat.IS_TBC_ANNIVERSARY = (not Compat.IS_FOREVER and not Compat.IS_RETAIL) and (Compat.INTERFACE >= 20000 and Compat.INTERFACE < 30000)
Compat.IS_CLASSIC_ERA = (not Compat.IS_FOREVER and not Compat.IS_RETAIL) and (Compat.INTERFACE >= 10000 and Compat.INTERFACE < 20000)
Compat.IS_CLASSIC = Compat.IS_MOP_CLASSIC or Compat.IS_CATA_CLASSIC or Compat.IS_WRATH_CLASSIC
    or Compat.IS_TBC_ANNIVERSARY or Compat.IS_CLASSIC_ERA
    or (not Compat.IS_FOREVER and not Compat.IS_RETAIL and Compat.PROJECT_ID > 0 and Compat.PROJECT_ID ~= WOW_PROJECT_MAINLINE_VALUE)
-- Legacy aggregate kept for callers that need actual Classic products.
-- Forever deliberately stays outside this family even though it shares modern APIs.
Compat.IS_CLASSIC_FAMILY = Compat.IS_CLASSIC

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
elseif Compat.IS_TITAN_REFORGED then
    Compat.CLIENT_TAG = 'Titan Reforged'
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
Compat.USES_MODERN_CAMERA = Compat.IS_FOREVER or (Compat.IS_RETAIL and Compat.INTERFACE >= 70000)
Compat.MAX_CAMERA_YARDS = Compat.USES_MODERN_CAMERA and 39 or 50
Compat.CONVERSION_RATIO = Compat.USES_MODERN_CAMERA and 15 or 12.5

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
    -- IMPORTANT: issecretvalue() must be the first operation on a potentially
    -- secret value. Even `value == nil` is a comparison and raises on boolean
    -- secrets in tainted addon code.
    if Compat.IsSecret(value) then
        return false
    end
    if value == nil then
        return false
    end
    local ok, result = pcall(function() return value and true or false end)
    return ok and result and true or false
end

-- Returns value only when it is a plain, readable value; nil otherwise. Use for
-- anything that will be compared or used as a table key.
function Compat.Plain(value)
    -- Same ordering rule as IsTruthy: never compare first and ask whether the
    -- value was secret afterwards.
    if Compat.IsSecret(value) then
        return nil
    end
    if value == nil then
        return nil
    end
    return value
end

-- 12.1 added C_CVar.AreCVarsLoaded, but Forever 1.60.x and several Classic
-- branches do not expose it even though their CVar/console tables are still
-- incomplete before VARIABLES_LOADED. Track that event ourselves instead of
-- treating a missing AreCVarsLoaded API as proof that enumeration is ready.
local variablesLoadedSeen = false

function Compat.MarkCVarsLoaded()
    if variablesLoadedSeen then return end
    variablesLoadedSeen = true
    Compat.InvalidateCVarCaches()
end

function Compat.AreCVarsLoaded()
    if C_CVar and C_CVar.AreCVarsLoaded then
        local ok, result = pcall(C_CVar.AreCVarsLoaded)
        if ok then
            return result and true or false
        end
    end
    return variablesLoadedSeen
end

function Compat.SafeGetCVar(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, val = pcall(C_CVar.GetCVar, name)
        if ok then
            if Compat.IsSecret(val) then return nil end
            if val ~= nil then return val end
        end
    end

    if type(GetCVar) == 'function' then
        local ok, val = pcall(GetCVar, name)
        if ok then
            if Compat.IsSecret(val) then return nil end
            if val ~= nil then return val end
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
        if ok and not Compat.IsSecret(val) and val ~= nil then
            return val
        end
    end

    if type(GetCVarDefault) == 'function' then
        local ok, val = pcall(GetCVarDefault, name)
        if ok and not Compat.IsSecret(val) and val ~= nil then
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

local function GetCVarWritePolicy(name)
    if type(name) ~= 'string' then return nil end

    local cached = cvarWritePolicyCache[name]
    if cached then return cached end
    if not Compat.AreCVarsLoaded() then return nil end

    if C_CVar and C_CVar.GetCVarInfo then
        local ok, value, _, _, _, isLockedFromUser, isSecure, isReadOnly = pcall(C_CVar.GetCVarInfo, name)
        if ok and not Compat.IsSecret(value) and value ~= nil then
            cached = {
                locked = isLockedFromUser and true or false,
                secure = isSecure and true or false,
                readOnly = isReadOnly and true or false,
            }
            cvarWritePolicyCache[name] = cached
            return cached
        end
    end

    return nil
end

function Compat.CanSetCVar(name)
    local policy = GetCVarWritePolicy(name)
    if policy then
        if policy.locked or policy.readOnly then
            return false
        end
        if policy.secure and type(InCombatLockdown) == 'function' then
            local ok, inCombat = pcall(InCombatLockdown)
            if ok and inCombat then
                return false
            end
        end
    end
    return true
end

function Compat.SafeSetCVar(name, value)
    if not Compat.CanSetCVar(name) then
        return false
    end

    if type(name) ~= 'string' or Compat.IsSecret(value) then return false end
    if not Compat.HasCVar(name) then return false end
    if C_CVar and type(C_CVar.SetCVar) == 'function' then
        local ok, result = pcall(C_CVar.SetCVar, name, value)
        -- Explicit failure is final; do not retry a protected write through an
        -- alias. Some backported namespaces return nil on a successful write.
        if not ok or Compat.IsSecret(result) or result == false then return false end
        if result == true then return true end
        local actual = Compat.SafeGetCVar(name)
        if actual == nil then return false end
        local expectedNumber, actualNumber = tonumber(value), tonumber(actual)
        if expectedNumber and actualNumber then
            return math.abs(expectedNumber - actualNumber) < 0.00001
        end
        return tostring(actual) == tostring(value)
    end
    if type(SetCVar) == 'function' then
        local ok, result = pcall(SetCVar, name, value)
        -- Old native setters have no return; verify those writes by readback.
        if not ok or Compat.IsSecret(result) or result == false then return false end
        if result == true then return true end
        local actual = Compat.SafeGetCVar(name)
        if actual == nil then return false end
        local expectedNumber, actualNumber = tonumber(value), tonumber(actual)
        if expectedNumber and actualNumber then
            return math.abs(expectedNumber - actualNumber) < 0.00001
        end
        return tostring(actual) == tostring(value)
    end

    return false
end

function Compat.HasCVar(name)
    if type(name) ~= 'string' then return false end

    local cached = cvarPresenceCache[name]
    if cached ~= nil then
        return cached
    end

    local exists = Compat.SafeGetCVar(name) ~= nil
    if exists then
        cvarPresenceCache[name] = true
    elseif Compat.AreCVarsLoaded() then
        cvarPresenceCache[name] = false
    end
    return exists
end

function Compat.InvalidateCVarCaches()
    for key in pairs(cvarPresenceCache) do
        cvarPresenceCache[key] = nil
    end
    for key in pairs(cvarWritePolicyCache) do
        cvarWritePolicyCache[key] = nil
    end
end

function Compat.SupportsFSRSharpen()
    return Compat.HasCVar('resampleAlwaysSharpen')
end

function Compat.SupportsSoftTargetIcons()
    return Compat.HasCVar('SoftTargetIconGameObject')
end

function Compat.SupportsActionCam()
    return Compat.HasCVar('test_cameraOverShoulder') or Compat.HasCVar('test_cameraDynamicPitch')
end

function Compat.SupportsFlyingMountMode()
    local journal = _G.C_MountJournal
    return not Compat.IS_CLASSIC_ERA and type(journal) == "table"
        and type(journal.GetMountIDs) == "function"
        and type(journal.GetMountInfoByID) == "function"
        and type(journal.GetMountInfoExtraByID) == "function"
end

function Compat.SupportsScenarioZone()
    return (Compat.IS_RETAIL or Compat.IS_CLASSIC) and Compat.INTERFACE >= 50000
end

function Compat.SupportsMythicPlus()
    return Compat.IS_RETAIL and Compat.INTERFACE >= 70000
end

function Compat.SupportsSkyriding()
    return Compat.IS_RETAIL and Compat.INTERFACE >= 100000
end

-- Prefer the running client's group APIs; old clients use two separate roster
-- counters. Keep these adapters local to this addon, never install globals.
local function ReadCount(modern, legacy, limit)
    local fn = _G[modern] or _G[legacy]
    if type(fn) ~= 'function' then return 0 end
    local ok, value = pcall(fn)
    if not ok then return 0 end
    value = tonumber(Compat.Plain(value))
    if not value or value ~= value then return 0 end
    return math.max(0, math.min(limit, math.floor(value)))
end

function Compat.IsInRaid()
    if type(_G.IsInRaid) == 'function' then
        local ok, value = pcall(_G.IsInRaid)
        return ok and Compat.IsTruthy(value)
    end
    return ReadCount('GetNumRaidMembers', 'GetNumRaidMembers', 40) > 0
end

function Compat.IsInGroup()
    if type(_G.IsInGroup) == 'function' then
        local ok, value = pcall(_G.IsInGroup)
        return ok and Compat.IsTruthy(value)
    end
    return Compat.IsInRaid() or ReadCount('GetNumPartyMembers', 'GetNumPartyMembers', 4) > 0
end

function Compat.GetNumSubgroupMembers()
    return ReadCount('GetNumSubgroupMembers', 'GetNumPartyMembers', 4)
end

function Compat.GetNumGroupMembers()
    if type(_G.GetNumGroupMembers) == 'function' or Compat.IsInRaid() then
        return ReadCount('GetNumGroupMembers', 'GetNumRaidMembers', 40)
    end
    local party = Compat.GetNumSubgroupMembers()
    return party > 0 and party + 1 or 0
end

-- CallbackHandler 8+ calls a native helper absent from archival clients.
-- Fall back to our own profile store/minimap button rather than defining a
-- global secure-call shim or letting an optional dependency stop startup.
function Compat.CanUseCallbackLibraries()
    if type(_G.securecallfunction) == 'function' then return true end
    if not _G.LibStub then return true end
    local ok, library, minor = pcall(_G.LibStub, 'CallbackHandler-1.0', true)
    return not ok or not library or (tonumber(minor) or 0) < 8
end

-- Region and UI language are independent: e.g. an EU account can use zhCN.
-- Never infer the account region from GetLocale(), realm names or spell text.
function Compat.GetRegion()
    if type(_G.GetCurrentRegion) == 'function' then
        local ok, value = pcall(_G.GetCurrentRegion)
        if ok then
            value = Compat.Plain(value)
            local region = ({ [1] = 'US', [2] = 'KR', [3] = 'EU', [4] = 'TW', [5] = 'CN' })[value]
            if region then return region end
        end
    end
    if type(_G.GetCurrentRegionName) == 'function' then
        local ok, value = pcall(_G.GetCurrentRegionName)
        value = ok and Compat.Plain(value) or nil
        if type(value) == 'string' then
            value = value:upper()
            if value == 'US' or value == 'EU' or value == 'KR' or value == 'TW' or value == 'CN' then return value end
        end
    end
    return 'UNKNOWN'
end

function Compat.GetRegionSupport()
    local matrix = ns.ClientSupport or {}
    local region = Compat.GetRegion()
    local info = { region = region, status = 'unlisted-interface', verifiedDate = matrix.verified_date or 'unknown' }
    if type(_G.GetLocale) == 'function' then
        local ok, locale = pcall(_G.GetLocale)
        if ok then info.locale = Compat.Plain(locale) end
    end
    info.locale = type(info.locale) == 'string' and info.locale or 'enUS'
    for _, product in ipairs(matrix.products or {}) do
        local matched = product.interface == Compat.INTERFACE
        local test = false
        if not matched then
            for _, interface in ipairs(product.test_interfaces or {}) do
                if interface == Compat.INTERFACE then matched, test = true, true; break end
            end
        end
        if matched then
            info.product, info.name = product.key, product.name
            info.status = test and 'official-test-interface' or 'official-live-interface'
            if region ~= 'UNKNOWN' then
                info.regionListed = false
                for _, allowed in ipairs(product.regions) do
                    if allowed == region then info.regionListed = true; break end
                end
            end
            info.interfaceStatus = info.status
            if region == 'UNKNOWN' then info.status = 'region-unknown'
            elseif not info.regionListed then info.status = 'unlisted-region' end
            info.observedBuild = not test and product.builds[region] or nil
            -- Build numbers can differ during regional hotfix rollout. This is
            -- diagnostics, never a gate that disables the camera on another build.
            return info
        end
    end
    return info
end

function Compat.GetAddonVersion()
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == 'function' then
        local ok, version = pcall(C_AddOns.GetAddOnMetadata, addonName, 'Version')
        if ok and not Compat.IsSecret(version) and type(version) == 'string' then
            return version
        end
    end

    if type(GetAddOnMetadata) == 'function' then
        local ok, version = pcall(GetAddOnMetadata, addonName, 'Version')
        if ok and not Compat.IsSecret(version) and type(version) == 'string' then
            return version
        end
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

-- Shared policy for bundled LibCamera without replacing global camera APIs.
if _G.MaxCameraDistanceCompat then _G.MaxCameraDistanceCompat.runtime = Compat end
