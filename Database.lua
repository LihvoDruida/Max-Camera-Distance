local addonName, ns = ...
ns.Database = ns.Database or {}
local Database = ns.Database

local AceDB = LibStub("AceDB-3.0")

-- ============================================================================
-- BUILD / CLIENT DETECTION
-- ============================================================================
local build = select(4, GetBuildInfo()) or 0
local IS_RETAIL  = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) or (build >= 120000)
local IS_CATA    = (build >= 50000 and build < 60000) -- 50502
local IS_CLASSIC = not IS_RETAIL

-- Retail: 39 yards max (2.6 factor)
-- Classic/Cata: commonly 50 yards max (4.0 factor)
local MAX_YARDS = IS_RETAIL and 39 or 50
local CONVERSION_RATIO = IS_RETAIL and 15 or 12.5

-- ============================================================================
-- API CACHE
-- ============================================================================
local tonumber, tostring, pcall, type, pairs, print = tonumber, tostring, pcall, type, pairs, print
local C_CVar = C_CVar
local GetCVar = GetCVar

-- ============================================================================
-- SAFE CVAR HELPERS
-- ============================================================================
local function SafeGetCVar(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, val = pcall(C_CVar.GetCVar, name)
        if ok and val ~= nil then
            return tonumber(val)
        end
    end
    if type(GetCVar) == "function" then
        local ok, val = pcall(GetCVar, name)
        if ok and val ~= nil then
            return tonumber(val)
        end
    end
    return nil
end

local function HasCVar(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, val = pcall(C_CVar.GetCVar, name)
        return ok and val ~= nil
    end
    if type(GetCVar) == "function" then
        local ok, val = pcall(GetCVar, name)
        return ok and val ~= nil
    end
    return false
end

local function CopyTableSafe(src)
    if type(CopyTable) == "function" then
        return CopyTable(src)
    end
    local t = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            t[k] = CopyTableSafe(v)
        else
            t[k] = v
        end
    end
    return t
end

-- ============================================================================
-- REALISTIC "BLIZZARD DEFAULTS"
-- Notes:
-- - cameraDistanceMaxZoomFactor: usually ~1.9 retail, ~4.0 classic
-- - cameraDistanceMoveSpeed: usually around 20 (NOT 30000!)
-- - cameraYawMoveSpeed / cameraPitchMoveSpeed: read from client if possible
-- ============================================================================
local defaultMaxFactor = IS_RETAIL and 1.9 or 4.0
local BLIZZARD_DEFAULT_YARDS = defaultMaxFactor * CONVERSION_RATIO

local defaultYaw = SafeGetCVar("cameraYawMoveSpeed") or 180
local defaultPitch = SafeGetCVar("cameraPitchMoveSpeed") or 90

-- In-game CVar is "cameraDistanceMoveSpeed" and is small (e.g. 20)
local defaultMoveSpeed = SafeGetCVar("cameraDistanceMoveSpeed") or 20

-- Retail-only features: detect by CVars existence
local supportsSharpen = IS_RETAIL and HasCVar("resampleAlwaysSharpen")
local supportsSoftTarget = IS_RETAIL and HasCVar("SoftTargetIconGameObject")
local defaultSharpen = supportsSharpen and (SafeGetCVar("resampleAlwaysSharpen") or 0) or 0
local defaultSoftTarget = supportsSoftTarget and (SafeGetCVar("SoftTargetIconGameObject") or 0) or 0

-- ============================================================================
-- PUBLIC CONSTANTS (used by Config/Functions)
-- ============================================================================
Database.DEFAULTS = {
    MAX_POSSIBLE_DISTANCE = MAX_YARDS,
    CONVERSION_RATIO = CONVERSION_RATIO,
    -- Feature flags you can reuse in Config/Functions if you want
    SUPPORTS_SHARPEN = supportsSharpen,
    SUPPORTS_SOFT_TARGET = supportsSoftTarget,
}

Database.DEFAULT_DEBUG_LEVEL = {
    error = true,
    warning = true,
    info = false,
    debug = false
}

-- ============================================================================
-- DEFAULT PROFILE (keys must match Config.lua & Functions.lua!)
-- ============================================================================
local function BuildDefaultProfile()
    local p = {
        -- Zoom distances stored in YARDS
        maxZoomFactor = MAX_YARDS,
        minZoomFactor = BLIZZARD_DEFAULT_YARDS,

        -- Camera CVars
        moveViewDistance = defaultMoveSpeed,      -- maps to cameraDistanceMoveSpeed
        cameraYawMoveSpeed = defaultYaw,
        cameraPitchMoveSpeed = defaultPitch,

        -- Transitions
        zoomTransitionTime = 0.5,
        dismountDelay = 0,

        -- Smart zoom toggles
        autoCombatZoom = false,
        autoMountZoom = false,
        mountZoomFactor = MAX_YARDS,

        -- Advanced
        reduceUnexpectedMovement = false,
        cameraIndirectVisibility = true,

        -- Retail-only toggles (still stored safely)
        resampleAlwaysSharpen = (defaultSharpen == 1),
        softTargetInteract = (defaultSoftTarget == 1),

        -- ActionCam (may exist on some clients, but ok to store)
        actionCamShoulder = false,
        actionCamPitch = false,

        -- AFK
        afkMode = false,

        -- Zones (scenario is mainly Retail; keep stored but default sensibly)
        zoneParty = true,
        zoneRaid = true,
        zoneArena = true,
        zoneBg = true,
        zoneScenario = IS_RETAIL and true or false,
        zoneWorldBoss = true,

        -- Debug
        enableDebugLogging = false,
        debugLevel = CopyTableSafe(Database.DEFAULT_DEBUG_LEVEL),

        -- Minimap (LibDBIcon)
        minimap = { hide = false },
    }

    -- If a feature doesn't exist on Classic, default it OFF (but keep key)
    if not supportsSharpen then
        p.resampleAlwaysSharpen = false
    end
    if not supportsSoftTarget then
        p.softTargetInteract = false
    end

    return p
end

-- ============================================================================
-- MIGRATION (add missing keys only; never overwrite user's settings)
-- ============================================================================
function Database:ApplyMigrations(profile)
    if not profile then return end
    local defaults = BuildDefaultProfile()

    for k, v in pairs(defaults) do
        if profile[k] == nil then
            profile[k] = (type(v) == "table") and CopyTableSafe(v) or v
        end
    end

    -- debugLevel table safety
    if profile.debugLevel == nil then
        profile.debugLevel = CopyTableSafe(Database.DEFAULT_DEBUG_LEVEL)
    end

    -- minimap table safety
    if profile.minimap == nil then
        profile.minimap = { hide = false }
    elseif profile.minimap.hide == nil then
        profile.minimap.hide = false
    end
end

-- ============================================================================
-- INIT DB
-- ============================================================================
function Database:InitDB()
    local defaultProfile = BuildDefaultProfile()

    self.db = AceDB:New("MaxCameraDistanceDB", { profile = defaultProfile }, true)
    if not self.db then
        print(addonName .. ": DB initialization failed.")
        return
    end

    self:ApplyMigrations(self.db.profile)
    self:RegisterProfileCallbacks()
end

function Database:RegisterProfileCallbacks()
    if not self.db then return end

    local function OnUpdate(event)
        Database:OnProfileUpdate(event)
    end

    self.db:RegisterCallback("OnProfileChanged", OnUpdate)
    self.db:RegisterCallback("OnProfileCopied", OnUpdate)
    self.db:RegisterCallback("OnProfileReset", OnUpdate)
end

function Database:OnProfileUpdate(reason)
    if self.db and self.db.profile then
        self:ApplyMigrations(self.db.profile)
    end

    if ns.Functions and ns.Functions.AdjustCamera then
        ns.Functions:AdjustCamera(true)
    end
end

-- ============================================================================
-- HELPERS
-- ============================================================================
function Database:GetCVarFactor(yards)
    return (tonumber(yards) or 0) / (Database.DEFAULTS.CONVERSION_RATIO or CONVERSION_RATIO)
end

function Database:SetZoomFactor(yards)
    if self.db and self.db.profile then
        self.db.profile.maxZoomFactor = tonumber(yards) or MAX_YARDS
        if ns.Functions and ns.Functions.AdjustCamera then
            ns.Functions:AdjustCamera(true)
        end
    end
end