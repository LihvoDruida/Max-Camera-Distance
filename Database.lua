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
local UnitName, GetRealmName = UnitName, GetRealmName
local format = string.format


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

local function NormalizeBoolean(value, default)
    if type(value) == "boolean" then
        return value
    end

    if value == 1 or value == "1" or value == "true" then
        return true
    end

    if value == 0 or value == "0" or value == "false" then
        return false
    end

    return default and true or false
end

local function GetCurrentCharacterKey()
    local playerName = UnitName and UnitName("player")
    local realmName = GetRealmName and GetRealmName()

    if not playerName or not realmName then
        return nil
    end

    return format("%s - %s", tostring(playerName), tostring(realmName))
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
local defaultIndirectOffset = SafeGetCVar("cameraIndirectOffset")
local defaultOccludedSilhouette = SafeGetCVar("occludedSilhouettePlayer")

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
    combatZoomOnPlayer = true,
    combatZoomOnGroup = true,
    combatZoomOnThreat = true,
    mountZoomFactor = MAX_YARDS,
    worldCombatZoomFactor = MAX_YARDS,
    partyCombatZoomFactor = MAX_YARDS,
    raidCombatZoomFactor = MAX_YARDS,
    pvpCombatZoomFactor = MAX_YARDS,

    -- return hysteresis (delay before zooming back in after leaving combat)
    worldCombatReturnDelay = 0.4,
    partyCombatReturnDelay = 0.8,
    raidCombatReturnDelay = 1.2,

    -- distance presets (manual keeps the matching slider active)
    manualMaxPreset = "manual",
    normalZoomPreset = "manual",
    mountZoomPreset = "manual",
    worldCombatPreset = "manual",
    partyCombatPreset = "manual",
    raidCombatPreset = "manual",
    pvpCombatPreset = "manual",

    zoneZoomFactor = MAX_YARDS, -- legacy key kept for migration only

    -- advanced (best-effort defaults from client when possible)
    reduceUnexpectedMovement = (defaultReduceMove == 1) or false,
    cameraIndirectVisibility = (defaultIndirect == nil) and true or (defaultIndirect == 1),
    cameraIndirectOffset = Clamp(tonumber(defaultIndirectOffset) or 1.5, 0, 10),
    occludedSilhouettePlayer = (defaultOccludedSilhouette == 1) or false,

    resampleAlwaysSharpen = (defaultSharpen == 1) or false,
    softTargetInteract = (defaultSoftTarget == 1) or false,

    -- actioncam / afk
    actionCamShoulder = false, -- legacy key for migration
    actionCamShoulderInCombat = false,
    actionCamShoulderOutOfCombat = false,
    actionCamPitch = false,
    afkMode = false,


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

    -- Remove obsolete zone-routing settings.
    profile.zoneParty = nil
    profile.zoneRaid = nil
    profile.zoneArena = nil
    profile.zoneBg = nil
    profile.zoneScenario = nil
    profile.zoneWorldBoss = nil

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
    local legacyGroupCombatZoom = Clamp(
        tonumber(profile.groupCombatZoomFactor) or profile.zoneZoomFactor or profile.maxZoomFactor or MAX_YARDS,
        1,
        MAX_YARDS
    )
    profile.partyCombatZoomFactor = Clamp(
        tonumber(profile.partyCombatZoomFactor) or legacyGroupCombatZoom,
        1,
        MAX_YARDS
    )
    profile.raidCombatZoomFactor = Clamp(
        tonumber(profile.raidCombatZoomFactor) or legacyGroupCombatZoom,
        1,
        MAX_YARDS
    )
    profile.pvpCombatZoomFactor = Clamp(
        tonumber(profile.pvpCombatZoomFactor) or profile.zoneZoomFactor or profile.maxZoomFactor or MAX_YARDS,
        1,
        MAX_YARDS
    )

    -- Legacy split is migrated only once; it should not remain in runtime logic.
    profile.groupCombatZoomFactor = nil

    -- move speed is typically 1..50
    profile.moveViewDistance = Clamp(tonumber(profile.moveViewDistance) or defaultMoveSpeed, 1, 50)
    profile.zoomTransitionTime = Clamp(tonumber(profile.zoomTransitionTime) or 0.5, 0, 2)
    profile.dismountDelay = Clamp(tonumber(profile.dismountDelay) or 0, 0, 10)
    profile.worldCombatReturnDelay = Clamp(tonumber(profile.worldCombatReturnDelay) or PROFILE_DEFAULTS.worldCombatReturnDelay, 0, 10)
    profile.partyCombatReturnDelay = Clamp(tonumber(profile.partyCombatReturnDelay) or PROFILE_DEFAULTS.partyCombatReturnDelay, 0, 10)
    profile.raidCombatReturnDelay = Clamp(tonumber(profile.raidCombatReturnDelay) or PROFILE_DEFAULTS.raidCombatReturnDelay, 0, 10)
    profile.cameraYawMoveSpeed = Clamp(tonumber(profile.cameraYawMoveSpeed) or defaultYaw, 1, 360)
    profile.cameraPitchMoveSpeed = Clamp(tonumber(profile.cameraPitchMoveSpeed) or defaultPitch, 1, 360)

    local VALID_PRESETS = {
        manual = true,
        client_default = true,
        close = true,
        balanced = true,
        far = true,
        max = true,
    }

    local function NormalizePreset(value)
        if type(value) ~= "string" or not VALID_PRESETS[value] then
            return "manual"
        end
        return value
    end

    profile.manualMaxPreset = NormalizePreset(profile.manualMaxPreset)
    profile.normalZoomPreset = NormalizePreset(profile.normalZoomPreset)
    profile.mountZoomPreset = NormalizePreset(profile.mountZoomPreset)
    profile.worldCombatPreset = NormalizePreset(profile.worldCombatPreset)
    profile.partyCombatPreset = NormalizePreset(profile.partyCombatPreset)
    profile.raidCombatPreset = NormalizePreset(profile.raidCombatPreset)
    profile.pvpCombatPreset = NormalizePreset(profile.pvpCombatPreset)

    -- Normalize booleans in case SavedVariables contain stale numeric/string values.
    profile.autoCombatZoom = NormalizeBoolean(profile.autoCombatZoom, PROFILE_DEFAULTS.autoCombatZoom)
    profile.autoMountZoom = NormalizeBoolean(profile.autoMountZoom, PROFILE_DEFAULTS.autoMountZoom)
    profile.combatZoomOnPlayer = NormalizeBoolean(profile.combatZoomOnPlayer, PROFILE_DEFAULTS.combatZoomOnPlayer)
    profile.combatZoomOnGroup = NormalizeBoolean(profile.combatZoomOnGroup, PROFILE_DEFAULTS.combatZoomOnGroup)
    profile.combatZoomOnThreat = NormalizeBoolean(profile.combatZoomOnThreat, PROFILE_DEFAULTS.combatZoomOnThreat)
    profile.reduceUnexpectedMovement = NormalizeBoolean(profile.reduceUnexpectedMovement, PROFILE_DEFAULTS.reduceUnexpectedMovement)
    profile.cameraIndirectVisibility = NormalizeBoolean(profile.cameraIndirectVisibility, PROFILE_DEFAULTS.cameraIndirectVisibility)
    profile.cameraIndirectOffset = Clamp(tonumber(profile.cameraIndirectOffset) or PROFILE_DEFAULTS.cameraIndirectOffset, 0, 10)
    profile.occludedSilhouettePlayer = NormalizeBoolean(profile.occludedSilhouettePlayer, PROFILE_DEFAULTS.occludedSilhouettePlayer)
    profile.resampleAlwaysSharpen = NormalizeBoolean(profile.resampleAlwaysSharpen, PROFILE_DEFAULTS.resampleAlwaysSharpen)
    profile.softTargetInteract = NormalizeBoolean(profile.softTargetInteract, PROFILE_DEFAULTS.softTargetInteract)
    profile.actionCamShoulderInCombat = NormalizeBoolean(profile.actionCamShoulderInCombat, PROFILE_DEFAULTS.actionCamShoulderInCombat)
    profile.actionCamShoulderOutOfCombat = NormalizeBoolean(profile.actionCamShoulderOutOfCombat, PROFILE_DEFAULTS.actionCamShoulderOutOfCombat)
    profile.actionCamPitch = NormalizeBoolean(profile.actionCamPitch, PROFILE_DEFAULTS.actionCamPitch)
    profile.afkMode = NormalizeBoolean(profile.afkMode, PROFILE_DEFAULTS.afkMode)
    profile.enableDebugLogging = NormalizeBoolean(profile.enableDebugLogging, PROFILE_DEFAULTS.enableDebugLogging)
    profile.minimap.hide = NormalizeBoolean(profile.minimap.hide, false)

    for level, defaultValue in pairs(Database.DEFAULT_DEBUG_LEVEL) do
        profile.debugLevel[level] = NormalizeBoolean(profile.debugLevel[level], defaultValue)
    end
end

-- ============================================================================
-- PROFILE MIGRATION: shared Default -> per-character profile
-- ============================================================================
function Database:MigrateToPerCharacterProfiles()
    local rawDb = _G.MaxCameraDistanceDB
    if type(rawDb) ~= "table" then return end

    local characterKey = GetCurrentCharacterKey()
    if not characterKey then return end

    rawDb.profiles = rawDb.profiles or {}
    rawDb.profileKeys = rawDb.profileKeys or {}
    rawDb.__migrations = rawDb.__migrations or {}
    rawDb.__migrations.perCharacterProfiles = rawDb.__migrations.perCharacterProfiles or {}

    if rawDb.__migrations.perCharacterProfiles[characterKey] then
        return
    end

    local currentProfileKey = rawDb.profileKeys[characterKey]
    local sharedDefaultProfile = rawDb.profiles.Default
    local characterProfile = rawDb.profiles[characterKey]

    local shouldCopySharedDefault =
        type(sharedDefaultProfile) == "table"
        and characterProfile == nil
        and (currentProfileKey == nil or currentProfileKey == "Default")

    if shouldCopySharedDefault then
        rawDb.profiles[characterKey] = CopyTableSafe(sharedDefaultProfile)
    end

    if currentProfileKey == nil or currentProfileKey == "Default" then
        rawDb.profileKeys[characterKey] = characterKey
        rawDb.__migrations.perCharacterProfiles[characterKey] = true
    end
end

-- ============================================================================
-- INIT DB
-- ============================================================================
function Database:InitDB()
    local defaultsWrapper = { profile = CopyTableSafe(PROFILE_DEFAULTS) }

    self:MigrateToPerCharacterProfiles()
    self.db = AceDB:New("MaxCameraDistanceDB", defaultsWrapper)

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

    if ns.Core and ns.Core.RefreshMinimapButton then
        ns.Core:RefreshMinimapButton()
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
