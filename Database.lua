local addonName, ns = ...
ns.Database = ns.Database or {}
local Database = ns.Database

local AceDB = LibStub("AceDB-3.0")
local Compat = ns.Compat or {}

local IS_RETAIL = Compat.IS_RETAIL and true or false
local IS_CLASSIC = Compat.IS_CLASSIC and true or false
local MAX_YARDS = Compat.MAX_CAMERA_YARDS or (IS_RETAIL and 39 or 50)
local CONVERSION_RATIO = Compat.CONVERSION_RATIO or (IS_RETAIL and 15 or 12.5)

-- ============================================================================
-- FAST LOCALS
-- ============================================================================
local type, tonumber, tostring = type, tonumber, tostring
local pcall, pairs, print = pcall, pairs, print


-- ============================================================================
-- SAFE HELPERS
-- ============================================================================
local function SafeGetCVar(name)
    if Compat.SafeGetCVarNumber then
        return Compat.SafeGetCVarNumber(name)
    end
    return nil
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

local function Clamp(num, minv, maxv)
    if num == nil then return minv end
    if num < minv then return minv end
    if num > maxv then return maxv end
    return num
end

-- ============================================================================
-- READ GAME DEFAULTS (best-effort, per client)
-- ============================================================================
-- cameraDistanceMaxZoomFactor default is usually ~1.9 (Retail). Classic varies by branch.
-- We always try to read it from the client; fallbacks are only for safety.
local defaultFactor = SafeGetCVar("cameraDistanceMaxZoomFactor")
if not defaultFactor then
    defaultFactor = IS_RETAIL and 1.9 or 4.0
end

local BLIZZARD_DEFAULT_YARDS = Clamp(defaultFactor * CONVERSION_RATIO, 1, MAX_YARDS)

local defaultYaw        = SafeGetCVar("cameraYawMoveSpeed") or 180
local defaultPitch      = SafeGetCVar("cameraPitchMoveSpeed") or 90
local defaultMoveSpeed  = SafeGetCVar("cameraDistanceMoveSpeed") or 20

-- These exist only on some branches; if missing we store nil and the addon will ignore them.
local defaultSharpen    = SafeGetCVar("resampleAlwaysSharpen")
local defaultSoftTarget = SafeGetCVar("SoftTargetIconGameObject")

local defaultReduceMove = SafeGetCVar("cameraReduceUnexpectedMovement")
local defaultIndirect   = SafeGetCVar("cameraIndirectVisibility")

-- ============================================================================
-- PUBLIC CONSTANTS (used by Config/Functions)
-- ============================================================================
Database.DEFAULTS = {
    -- Distances are stored in YARDS in the profile
    MAX_POSSIBLE_DISTANCE = MAX_YARDS,
    CONVERSION_RATIO = CONVERSION_RATIO,

    -- Comfortable "normal" zoom when Smart Zoom is ON
    BLIZZARD_DEFAULT_YARDS = BLIZZARD_DEFAULT_YARDS,

    -- Useful flags
    IS_RETAIL = IS_RETAIL,
    IS_CLASSIC = IS_CLASSIC,
}

Database.DEFAULT_DEBUG_LEVEL = {
    error = true,
    warning = true,
    info = false,
    debug = false,
}

-- ============================================================================
-- PROFILE DEFAULTS (REAL DB KEYS)
-- ============================================================================
local PROFILE_DEFAULTS = {
    -- core zoom
    maxZoomFactor = MAX_YARDS,
    minZoomFactor = BLIZZARD_DEFAULT_YARDS,

    -- camera
    moveViewDistance = defaultMoveSpeed,
    cameraYawMoveSpeed = defaultYaw,
    cameraPitchMoveSpeed = defaultPitch,
    dismountDelay = 0,
    zoomTransitionTime = 0.5,

    -- systems
    autoCombatZoom = false,
    autoMountZoom = false,
    mountZoomFactor = MAX_YARDS,
    worldCombatZoomFactor = MAX_YARDS,
    groupCombatZoomFactor = MAX_YARDS,
    pvpCombatZoomFactor = MAX_YARDS,
    zoneZoomFactor = MAX_YARDS, -- legacy key kept for migration only

    -- advanced (best-effort defaults from client when possible)
    reduceUnexpectedMovement = (defaultReduceMove == 1) or false,
    cameraIndirectVisibility = (defaultIndirect == nil) and true or (defaultIndirect == 1),

    resampleAlwaysSharpen = (defaultSharpen == 1) or false,
    softTargetInteract = (defaultSoftTarget == 1) or false,

    -- actioncam / afk
    actionCamShoulder = false, -- legacy key for migration
    actionCamShoulderInCombat = false,
    actionCamShoulderOutOfCombat = false,
    actionCamPitch = false,
    afkMode = false,

    -- zones
    zoneParty = true,
    zoneRaid = true,
    zoneArena = true,
    zoneBg = true,
    zoneScenario = (Compat.SupportsScenarioZone and Compat.SupportsScenarioZone()) or IS_RETAIL,
    zoneWorldBoss = true,

    -- debug
    enableDebugLogging = false,
    debugLevel = CopyTableSafe(Database.DEFAULT_DEBUG_LEVEL),

    -- minimap
    minimap = { hide = false },
}

-- ============================================================================
-- MIGRATIONS (fills missing keys, never overwrites user's choices)
-- ============================================================================
function Database:ApplyMigrations(profile)
    if not profile then return end

    local legacyShoulder = profile.actionCamShoulder
    local missingShoulderInCombat = (profile.actionCamShoulderInCombat == nil)
    local missingShoulderOutOfCombat = (profile.actionCamShoulderOutOfCombat == nil)

    for k, v in pairs(PROFILE_DEFAULTS) do
        if profile[k] == nil then
            profile[k] = (type(v) == "table") and CopyTableSafe(v) or v
        end
    end

    if legacyShoulder ~= nil then
        if missingShoulderInCombat then
            profile.actionCamShoulderInCombat = legacyShoulder
        end
        if missingShoulderOutOfCombat then
            profile.actionCamShoulderOutOfCombat = legacyShoulder
        end
    end

    if profile.debugLevel == nil then
        profile.debugLevel = CopyTableSafe(Database.DEFAULT_DEBUG_LEVEL)
    end

    if profile.minimap == nil then
        profile.minimap = { hide = false }
    elseif profile.minimap.hide == nil then
        profile.minimap.hide = false
    end

    -- Small fixups for upgrades:
    -- Ensure distances stay within per-client limits
    profile.maxZoomFactor = Clamp(tonumber(profile.maxZoomFactor) or MAX_YARDS, 1, MAX_YARDS)
    profile.minZoomFactor = Clamp(tonumber(profile.minZoomFactor) or BLIZZARD_DEFAULT_YARDS, 1, MAX_YARDS)
    profile.mountZoomFactor = Clamp(tonumber(profile.mountZoomFactor) or MAX_YARDS, 1, MAX_YARDS)
    profile.zoneZoomFactor = Clamp(tonumber(profile.zoneZoomFactor) or profile.maxZoomFactor or MAX_YARDS, 1, MAX_YARDS)

    -- Combat distance split migration:
    -- old profile used maxZoomFactor for regular combat and zoneZoomFactor for raid/dungeon/pvp zones.
    profile.worldCombatZoomFactor = Clamp(
        tonumber(profile.worldCombatZoomFactor) or profile.maxZoomFactor or MAX_YARDS,
        1,
        MAX_YARDS
    )
    profile.groupCombatZoomFactor = Clamp(
        tonumber(profile.groupCombatZoomFactor) or profile.zoneZoomFactor or profile.maxZoomFactor or MAX_YARDS,
        1,
        MAX_YARDS
    )
    profile.pvpCombatZoomFactor = Clamp(
        tonumber(profile.pvpCombatZoomFactor) or profile.zoneZoomFactor or profile.maxZoomFactor or MAX_YARDS,
        1,
        MAX_YARDS
    )

    -- move speed is typically 1..50
    profile.moveViewDistance = Clamp(tonumber(profile.moveViewDistance) or defaultMoveSpeed, 1, 50)
end

-- ============================================================================
-- INIT DB
-- ============================================================================
function Database:InitDB()
    local defaultsWrapper = { profile = CopyTableSafe(PROFILE_DEFAULTS) }

    self.db = AceDB:New("MaxCameraDistanceDB", defaultsWrapper, true)

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

    if ns.Functions and ns.Functions.logMessage then
        ns.Functions:logMessage("info", tostring(reason) .. ". Re-applying settings...")
    end

    if ns.Functions and ns.Functions.AdjustCamera then
        ns.Functions:AdjustCamera(true)
    end
end

-- ============================================================================
-- HELPERS
-- ============================================================================
function Database:GetCVarFactor(yards)
    return (tonumber(yards) or 0) / CONVERSION_RATIO
end

function Database:SetZoomFactor(yards)
    if self.db and self.db.profile then
        self.db.profile.maxZoomFactor = Clamp(tonumber(yards) or MAX_YARDS, 1, MAX_YARDS)
        if ns.Functions and ns.Functions.AdjustCamera then
            ns.Functions:AdjustCamera(true)
        end
    end
end
