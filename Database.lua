local addonName, ns = ...
local LibStub = _G.LibStub
ns.Database = ns.Database or {}
local Database = ns.Database

-- Resolved lazily for the same reason as the Ace3 libs in Config.lua: the addon
-- that supplies AceDB may load after this one, and a one-shot lookup here
-- silently downgraded the whole session to the fallback store.
local AceDB

local function ResolveAceDB()
    LibStub = LibStub or _G.LibStub
    if LibStub and not AceDB then
        AceDB = LibStub("AceDB-3.0", true)
    end
    return AceDB
end

ResolveAceDB()

local Compat = ns.Compat or {}

local IS_RETAIL = Compat.IS_RETAIL and true or false
local IS_FOREVER = Compat.IS_FOREVER and true or false
local IS_CLASSIC = Compat.IS_CLASSIC and true or false
local USES_MODERN_API = Compat.USES_MODERN_API and true or false
local MAX_YARDS = Compat.MAX_CAMERA_YARDS or (USES_MODERN_API and 39 or 50)
local CONVERSION_RATIO = Compat.CONVERSION_RATIO or (USES_MODERN_API and 15 or 12.5)

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
-- Live (current) CVar value. Only used for one-off migrations, never for defaults.
local function SafeGetCVar(name)
    if Compat.SafeGetCVarNumber then
        return Compat.SafeGetCVarNumber(name)
    end
    return nil
end

-- Client's built-in default for a CVar. Constant for the lifetime of the client.
local function SafeGetCVarDefault(name)
    if Compat.SafeGetCVarNumberDefault then
        return Compat.SafeGetCVarNumberDefault(name)
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
-- !!! DO NOT read these from the LIVE CVar value. !!!
--
-- AceDB-3.0 deletes every profile key whose value equals the default when the
-- player logs out (RegisterDefaults(nil) -> removeDefaults). That is safe only
-- while the defaults are CONSTANT.
--
-- This addon writes cameraYawMoveSpeed, cameraDistanceMaxZoomFactor, etc. itself,
-- so reading the live CVar made the "default" follow the user's own setting:
--   1. user picks 250 -> stored in SavedVariables (250 ~= default 180)
--   2. next launch the live CVar is 250, so the default becomes 250
--   3. profile value == default -> AceDB STRIPS the key on logout
--   4. anything that resets the CVar cache (Config.wtf reset, patch, another PC,
--      logging out in a different camera state) -> the setting is gone for good
-- which is exactly the "Camera Turning Speed resets every launch" symptom.
--
-- GetCVarDefault() returns the client's built-in default and never drifts,
-- so it is a valid SavedVariables default.
local defaultFactor = SafeGetCVarDefault("cameraDistanceMaxZoomFactor")
if not defaultFactor then
    defaultFactor = USES_MODERN_API and 1.9 or 4.0
end

local BLIZZARD_DEFAULT_YARDS = Clamp(defaultFactor * CONVERSION_RATIO, 1, MAX_YARDS)

local defaultYaw        = SafeGetCVarDefault("cameraYawMoveSpeed") or 180
local defaultPitch      = SafeGetCVarDefault("cameraPitchMoveSpeed") or 90
local defaultMoveSpeed  = Clamp(SafeGetCVarDefault("cameraDistanceMoveSpeed") or 50, 20, 50)

-- These exist only on some branches; if missing we store nil and the addon will ignore them.
local defaultSharpen    = SafeGetCVarDefault("resampleAlwaysSharpen")
local defaultSoftTarget = SafeGetCVarDefault("SoftTargetIconGameObject")

local defaultReduceMove = SafeGetCVarDefault("cameraReduceUnexpectedMovement")
local defaultIndirect   = SafeGetCVarDefault("cameraIndirectVisibility")
local defaultIndirectOffset = SafeGetCVarDefault("cameraIndirectOffset")
-- Current 12.1 metadata uses 6.0. GetCVarDefault remains authoritative on every
-- flavor; this number is only the fallback if the client cannot expose defaults
-- during early loading.
defaultIndirectOffset = Clamp(tonumber(defaultIndirectOffset) or 6.0, 0, 10)
local defaultOccludedSilhouette = SafeGetCVarDefault("occludedSilhouettePlayer")

-- WoW: Forever exposes the modern volumetric-fog CVars, but this feature is
-- intentionally Forever-only in Max Camera Distance. Read Blizzard's own
-- client defaults instead of the current values so AceDB defaults never drift
-- with the user's graphics settings. The fallbacks match the current generated
-- CVar metadata and are used only if the beta client does not expose defaults
-- during early addon loading.
local defaultVolumeFog = nil
local defaultVolumeFogInterior = nil
local defaultVolumeFogLevel = nil
local defaultGroundEffectDensity = nil
local defaultGroundEffectDist = nil
local defaultGroundEffectFade = nil
if IS_FOREVER then
    defaultVolumeFog = SafeGetCVarDefault("volumeFog")
    defaultVolumeFogInterior = SafeGetCVarDefault("volumeFogInterior")
    defaultVolumeFogLevel = SafeGetCVarDefault("volumeFogLevel")
    defaultGroundEffectDensity = SafeGetCVarDefault("groundEffectDensity")
    defaultGroundEffectDist = SafeGetCVarDefault("groundEffectDist")
    defaultGroundEffectFade = SafeGetCVarDefault("groundEffectFade")

    if defaultVolumeFog == nil then defaultVolumeFog = 1 end
    if defaultVolumeFogInterior == nil then defaultVolumeFogInterior = 1 end
    defaultVolumeFogLevel = Clamp(tonumber(defaultVolumeFogLevel) or 2, 0, 3)

    -- These are raw engine CVars rather than the 0-9 graphics preset sliders.
    -- Runtime defaults remain authoritative because Forever is still evolving;
    -- fallbacks match current modern-client metadata only when the API cannot
    -- expose a built-in default during early loading.
    defaultGroundEffectDensity = Clamp(tonumber(defaultGroundEffectDensity) or 16, 16, 256)
    defaultGroundEffectDist = Clamp(tonumber(defaultGroundEffectDist) or 70, 32, 600)
    defaultGroundEffectFade = Clamp(tonumber(defaultGroundEffectFade) or 70, 0, 600)
end

-- ============================================================================
-- PUBLIC CONSTANTS (used by Config/Functions)
-- ============================================================================
Database.DEFAULTS = {
    -- Distances are stored in YARDS in the profile
    MAX_POSSIBLE_DISTANCE = MAX_YARDS,
    CONVERSION_RATIO = CONVERSION_RATIO,
    CAMERA_INDIRECT_OFFSET_DEFAULT = defaultIndirectOffset,

    -- Comfortable "normal" zoom when Smart Zoom is ON
    BLIZZARD_DEFAULT_YARDS = BLIZZARD_DEFAULT_YARDS,

    -- Useful flags
    IS_RETAIL = IS_RETAIL,
    IS_FOREVER = IS_FOREVER,
    IS_CLASSIC = IS_CLASSIC,
    USES_MODERN_API = USES_MODERN_API,
}

Database.DEFAULT_DEBUG_LEVEL = {
    error = true,
    warning = true,
    info = false,
    debug = false,
}

if IS_FOREVER then
    Database.DEFAULTS.FOREVER_FOG = {
        volumeFog = (tonumber(defaultVolumeFog) or 0) == 1,
        volumeFogInterior = (tonumber(defaultVolumeFogInterior) or 0) == 1,
        volumeFogLevel = defaultVolumeFogLevel,
    }
    Database.DEFAULTS.FOREVER_ENVIRONMENT = {
        groundEffectDensity = defaultGroundEffectDensity,
        groundEffectDist = defaultGroundEffectDist,
        groundEffectFade = defaultGroundEffectFade,
    }
end

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
    mountZoomMode = "all",
    dragonRacingRaceFirstPerson = false,
    combatZoomOnPlayer = true,
    combatZoomOnGroup = true,
    combatZoomOnThreat = true,
    mountZoomFactor = MAX_YARDS,

    -- Per-activity combat distances and return delays are generated from
    -- ns.Contexts.DEFINITIONS just below, so the taxonomy lives in exactly one
    -- place. World PvP detection can be switched off for players who are
    -- permanently flagged and do not want a separate distance for it.
    worldPvpZoom = true,

    -- Adaptive combat return. While farming, combat genuinely drops between
    -- mobs and the fixed delay expires in the gap, so the camera pumps in and
    -- out on every pull. When on, the delay stretches to cover the lulls the
    -- player is actually producing. Default on: it only ever makes the camera
    -- calmer, and it collapses back to the configured delay by itself.
    adaptiveCombatReturn = true,
    adaptiveCombatReturnMax = 5,

    -- Reactive Zoom (see ReactiveZoom.lua). Opt-in: it changes how the mouse
    -- wheel feels, so it must not be switched on behind the player's back.
    reactiveZoom = false,
    reactiveZoomAddIncrementsAlways = 1,
    reactiveZoomAddIncrements = 2.5,
    reactiveZoomIncAddDifference = 1.2,
    reactiveZoomMaxZoomTime = 0.25,
    reactiveZoomEasing = "OutQuad",

    -- Smart Zoom restore behavior
    zoomRestoreSetting = "adaptive", -- never / adaptive / always
    respectManualStateZoom = true,

    -- distance presets (manual keeps the matching slider active)
    manualMaxPreset = "manual",
    normalZoomPreset = "manual",
    mountZoomPreset = "manual",

    zoneZoomFactor = MAX_YARDS, -- legacy key kept for migration only

    -- advanced (best-effort defaults from client when possible)
    reduceUnexpectedMovement = (defaultReduceMove == 1) or false,
    cameraIndirectVisibility = (defaultIndirect == nil) and true or (defaultIndirect == 1),
    cameraIndirectOffset = defaultIndirectOffset,
    occludedSilhouettePlayer = (defaultOccludedSilhouette == 1) or false,

    resampleAlwaysSharpen = (defaultSharpen == 1) or false,
    softTargetInteract = (defaultSoftTarget == 1) or false,

    -- actioncam / afk
    actionCamShoulder = false, -- legacy key for migration
    actionCamShoulderInCombat = false,
    actionCamShoulderOutOfCombat = false,
    actionCamPitch = false,

    -- Shoulder shaping. actionCamShoulderOffset is the value that used to be
    -- hardcoded to 1.0 in Functions.lua, i.e. how far the camera sits off the
    -- character's centre line before the zoom fade and the per-model
    -- compensation factor are applied.
    actionCamShoulderOffset = 1.0,
    actionCamShoulderSmartFade = true,
    actionCamShoulderFadeStart = 5.0,
    actionCamShoulderFadeEnd = 2.0,
    actionCamShoulderModelCompensation = true,

    -- gamepad
    -- Default off across the board: the addon must not silently retune
    -- somebody's controller the first time they log in with this build.
    gamePadManageCameraSpeed = false,
    gamePadCameraYawMultiplier = 1.0,
    gamePadCameraPitchMultiplier = 1.0,
    gamePadRelaxFaceMovement = false,
    afkMode = false,
    afkHideUI = true,
    afkDelay = 3,
    afkDirection = "right",
    afkRotationSpeed = 0.5,
    afkSkipMounted = true,
    afkSkipFlying = true,
    afkResumeAfterCombat = true,
    afkZoomOut = true,


    -- localization
    language = "client",

    -- debug
    enableDebugLogging = false,
    debugLevel = CopyTableSafe(Database.DEFAULT_DEBUG_LEVEL),

    -- minimap
    minimap = { hide = false },
}

-- These SavedVariables only exist on WoW: Forever. Keeping them out of the
-- shared defaults prevents Retail/Classic profiles from acquiring settings they
-- can never use.
if IS_FOREVER then
    PROFILE_DEFAULTS.volumeFog = (tonumber(defaultVolumeFog) or 0) == 1
    PROFILE_DEFAULTS.volumeFogInterior = (tonumber(defaultVolumeFogInterior) or 0) == 1
    PROFILE_DEFAULTS.volumeFogLevel = defaultVolumeFogLevel
    PROFILE_DEFAULTS.foreverGroundEffectsOverride = false
    PROFILE_DEFAULTS.groundEffectDensity = defaultGroundEffectDensity
    PROFILE_DEFAULTS.groundEffectDist = defaultGroundEffectDist
    PROFILE_DEFAULTS.groundEffectFade = defaultGroundEffectFade
end

-- Per-activity combat keys. Generated rather than written out so that the set of
-- activities cannot drift between Contexts.lua, Database.lua and Config.lua.
local Contexts = ns.Contexts
if Contexts and Contexts.DEFINITIONS then
    for _, def in pairs(Contexts.DEFINITIONS) do
        PROFILE_DEFAULTS[def.distanceKey] = MAX_YARDS
        PROFILE_DEFAULTS[def.presetKey] = "manual"
        PROFILE_DEFAULTS[def.delayKey] = def.defaultDelay or 0.4
    end
end

Database.PROFILE_DEFAULTS = PROFILE_DEFAULTS

function Database:GetDefaultProfile()
    return CopyTableSafe(PROFILE_DEFAULTS)
end

function Database:ResetCurrentProfile()
    if not self.db then return false end

    if type(self.db.ResetProfile) == "function" then
        local ok = pcall(self.db.ResetProfile, self.db)
        if ok then
            if self.db.profile then
                self:ApplyMigrations(self.db.profile)
            end
            return true
        end
    end

    if self.db.profile then
        local defaults = CopyTableSafe(PROFILE_DEFAULTS)
        for key in pairs(self.db.profile) do
            self.db.profile[key] = nil
        end
        for key, value in pairs(defaults) do
            self.db.profile[key] = value
        end
        self:ApplyMigrations(self.db.profile)
        return true
    end

    return false
end

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

    -- The four old buckets (world / party / raid / pvp) became eight, split by
    -- PvE and PvP activity. Nobody should have to reconfigure anything: each new
    -- key inherits the value of the old key it was carved out of, declared as
    -- legacyDistanceKey in Contexts.lua. Dungeon, Mythic+ and Scenario all seed
    -- from partyCombat*, while Arena, Battleground and World PvP seed from the
    -- single old pvpCombat*. Once a key exists in the profile this is a no-op,
    -- so it is safe to run on every load.
    if Contexts and Contexts.DEFINITIONS then
        for _, def in pairs(Contexts.DEFINITIONS) do
            local current = tonumber(profile[def.distanceKey])
            if current == nil then
                local legacy = def.legacyDistanceKey and tonumber(profile[def.legacyDistanceKey]) or nil
                current = legacy or legacyGroupCombatZoom
            end
            profile[def.distanceKey] = Clamp(current, 1, MAX_YARDS)

            if profile[def.presetKey] == nil and def.legacyPresetKey then
                profile[def.presetKey] = profile[def.legacyPresetKey]
            end

            if tonumber(profile[def.delayKey]) == nil then
                local legacyDelay = def.legacyDelayKey and tonumber(profile[def.legacyDelayKey]) or nil
                profile[def.delayKey] = legacyDelay or def.defaultDelay or 0.4
            end
            profile[def.delayKey] = Clamp(tonumber(profile[def.delayKey]), 0, 10)
        end
    end

    -- Legacy keys are migrated only once; they should not remain in runtime logic.
    profile.groupCombatZoomFactor = nil
    profile.partyCombatZoomFactor = nil
    profile.pvpCombatZoomFactor = nil
    profile.partyCombatPreset = nil
    profile.pvpCombatPreset = nil
    profile.partyCombatReturnDelay = nil

    profile.worldPvpZoom = (profile.worldPvpZoom ~= false)

    profile.adaptiveCombatReturn = (profile.adaptiveCombatReturn ~= false)
    profile.adaptiveCombatReturnMax = Clamp(tonumber(profile.adaptiveCombatReturnMax) or 5, 1, 15)

    profile.reactiveZoom = (profile.reactiveZoom == true)
    profile.reactiveZoomAddIncrementsAlways = Clamp(tonumber(profile.reactiveZoomAddIncrementsAlways) or 1, 0, 5)
    profile.reactiveZoomAddIncrements = Clamp(tonumber(profile.reactiveZoomAddIncrements) or 2.5, 0, 5)
    profile.reactiveZoomIncAddDifference = Clamp(tonumber(profile.reactiveZoomIncAddDifference) or 1.2, 0, 5)
    profile.reactiveZoomMaxZoomTime = Clamp(tonumber(profile.reactiveZoomMaxZoomTime) or 0.25, 0.05, 1)

    local VALID_EASING = { OutQuad = true, OutCubic = true, InOutQuad = true, Linear = true }
    if not VALID_EASING[profile.reactiveZoomEasing] then
        profile.reactiveZoomEasing = "OutQuad"
    end

    -- manual mouse-wheel zoom speed is intentionally kept responsive (20..50).
    -- Older profiles may have stored very low values that make the wheel feel broken.
    profile.moveViewDistance = Clamp(tonumber(profile.moveViewDistance) or defaultMoveSpeed, 20, 50)
    profile.zoomTransitionTime = Clamp(tonumber(profile.zoomTransitionTime) or 0.5, 0, 2)
    profile.dismountDelay = Clamp(tonumber(profile.dismountDelay) or 0, 0, 10)
    -- Per-activity return delays are clamped in the Contexts loop above.
    profile.cameraYawMoveSpeed = Clamp(tonumber(profile.cameraYawMoveSpeed) or defaultYaw, 1, 360)
    profile.cameraPitchMoveSpeed = Clamp(tonumber(profile.cameraPitchMoveSpeed) or defaultPitch, 1, 360)

    -- Shoulder shaping. test_cameraOverShoulder itself accepts a far wider
    -- range, but past a few units the camera leaves the character entirely, so
    -- the stored value is kept inside a range that still produces a usable view.
    profile.actionCamShoulderOffset = Clamp(tonumber(profile.actionCamShoulderOffset) or 1.0, -5, 5)
    profile.actionCamShoulderSmartFade = NormalizeBoolean(profile.actionCamShoulderSmartFade, PROFILE_DEFAULTS.actionCamShoulderSmartFade)
    profile.actionCamShoulderModelCompensation = NormalizeBoolean(profile.actionCamShoulderModelCompensation, PROFILE_DEFAULTS.actionCamShoulderModelCompensation)
    profile.actionCamShoulderFadeEnd = Clamp(tonumber(profile.actionCamShoulderFadeEnd) or 2.0, 0, 25)
    profile.actionCamShoulderFadeStart = Clamp(tonumber(profile.actionCamShoulderFadeStart) or 5.0, 0, 25)
    -- An inverted window would flip the offset between 0 and full on a single
    -- zoom tick. Push the outer edge out rather than silently disabling fading.
    if profile.actionCamShoulderFadeStart <= profile.actionCamShoulderFadeEnd then
        profile.actionCamShoulderFadeStart = Clamp(profile.actionCamShoulderFadeEnd + 1, 0, 25)
    end

    -- Gamepad camera speed is stored as a multiplier of the client's own
    -- default rather than an absolute value, so it stays meaningful if Blizzard
    -- retunes the defaults or the scale differs between flavours.
    profile.gamePadManageCameraSpeed = NormalizeBoolean(profile.gamePadManageCameraSpeed, PROFILE_DEFAULTS.gamePadManageCameraSpeed)
    profile.gamePadRelaxFaceMovement = NormalizeBoolean(profile.gamePadRelaxFaceMovement, PROFILE_DEFAULTS.gamePadRelaxFaceMovement)
    profile.gamePadCameraYawMultiplier = Clamp(tonumber(profile.gamePadCameraYawMultiplier) or 1.0, 0.1, 4)
    profile.gamePadCameraPitchMultiplier = Clamp(tonumber(profile.gamePadCameraPitchMultiplier) or 1.0, 0.1, 4)

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
    if Contexts and Contexts.DEFINITIONS then
        for _, def in pairs(Contexts.DEFINITIONS) do
            profile[def.presetKey] = NormalizePreset(profile[def.presetKey])
        end
    end

    local VALID_MOUNT_ZOOM_MODES = {
        all = true,
        flying = true,
        skyriding = true,
        forms = true,
    }
    if type(profile.mountZoomMode) ~= "string" or not VALID_MOUNT_ZOOM_MODES[profile.mountZoomMode] then
        profile.mountZoomMode = PROFILE_DEFAULTS.mountZoomMode
    elseif not IS_RETAIL and profile.mountZoomMode == "skyriding" then
        -- A profile copied from Retail should not leave mount zoom permanently
        -- disabled on Forever/Classic through an unavailable Skyriding-only mode.
        profile.mountZoomMode = PROFILE_DEFAULTS.mountZoomMode
    end

    -- Normalize booleans in case SavedVariables contain stale numeric/string values.
    profile.autoCombatZoom = NormalizeBoolean(profile.autoCombatZoom, PROFILE_DEFAULTS.autoCombatZoom)
    profile.autoMountZoom = NormalizeBoolean(profile.autoMountZoom, PROFILE_DEFAULTS.autoMountZoom)
    profile.dragonRacingRaceFirstPerson = NormalizeBoolean(profile.dragonRacingRaceFirstPerson, PROFILE_DEFAULTS.dragonRacingRaceFirstPerson)
    if not IS_RETAIL then
        profile.dragonRacingRaceFirstPerson = false
    end
    profile.combatZoomOnPlayer = NormalizeBoolean(profile.combatZoomOnPlayer, PROFILE_DEFAULTS.combatZoomOnPlayer)
    profile.combatZoomOnGroup = NormalizeBoolean(profile.combatZoomOnGroup, PROFILE_DEFAULTS.combatZoomOnGroup)
    profile.combatZoomOnThreat = NormalizeBoolean(profile.combatZoomOnThreat, PROFILE_DEFAULTS.combatZoomOnThreat)
    profile.reduceUnexpectedMovement = NormalizeBoolean(profile.reduceUnexpectedMovement, PROFILE_DEFAULTS.reduceUnexpectedMovement)
    profile.cameraIndirectVisibility = NormalizeBoolean(profile.cameraIndirectVisibility, PROFILE_DEFAULTS.cameraIndirectVisibility)
    profile.cameraIndirectOffset = Clamp(tonumber(profile.cameraIndirectOffset) or PROFILE_DEFAULTS.cameraIndirectOffset, 0, 10)
    profile.occludedSilhouettePlayer = NormalizeBoolean(profile.occludedSilhouettePlayer, PROFILE_DEFAULTS.occludedSilhouettePlayer)
    profile.resampleAlwaysSharpen = NormalizeBoolean(profile.resampleAlwaysSharpen, PROFILE_DEFAULTS.resampleAlwaysSharpen)
    profile.softTargetInteract = NormalizeBoolean(profile.softTargetInteract, PROFILE_DEFAULTS.softTargetInteract)
    if IS_FOREVER then
        profile.volumeFog = NormalizeBoolean(profile.volumeFog, PROFILE_DEFAULTS.volumeFog)
        profile.volumeFogInterior = NormalizeBoolean(profile.volumeFogInterior, PROFILE_DEFAULTS.volumeFogInterior)
        profile.volumeFogLevel = Clamp(tonumber(profile.volumeFogLevel) or PROFILE_DEFAULTS.volumeFogLevel, 0, 3)
        profile.volumeFogLevel = math.floor(profile.volumeFogLevel + 0.5)
        profile.foreverGroundEffectsOverride = NormalizeBoolean(profile.foreverGroundEffectsOverride, PROFILE_DEFAULTS.foreverGroundEffectsOverride)
        profile.groundEffectDensity = math.floor(Clamp(tonumber(profile.groundEffectDensity) or PROFILE_DEFAULTS.groundEffectDensity, 16, 256) + 0.5)
        profile.groundEffectDist = math.floor(Clamp(tonumber(profile.groundEffectDist) or PROFILE_DEFAULTS.groundEffectDist, 32, 600) + 0.5)
        profile.groundEffectFade = math.floor(Clamp(tonumber(profile.groundEffectFade) or PROFILE_DEFAULTS.groundEffectFade, 0, 600) + 0.5)
    end
    profile.actionCamShoulderInCombat = NormalizeBoolean(profile.actionCamShoulderInCombat, PROFILE_DEFAULTS.actionCamShoulderInCombat)
    profile.actionCamShoulderOutOfCombat = NormalizeBoolean(profile.actionCamShoulderOutOfCombat, PROFILE_DEFAULTS.actionCamShoulderOutOfCombat)
    profile.actionCamPitch = NormalizeBoolean(profile.actionCamPitch, PROFILE_DEFAULTS.actionCamPitch)
    profile.afkMode = NormalizeBoolean(profile.afkMode, PROFILE_DEFAULTS.afkMode)
    profile.afkHideUI = NormalizeBoolean(profile.afkHideUI, PROFILE_DEFAULTS.afkHideUI)
    profile.afkDelay = Clamp(tonumber(profile.afkDelay) or PROFILE_DEFAULTS.afkDelay, 0, 30)
    if type(profile.afkDirection) ~= "string" or (profile.afkDirection ~= "left" and profile.afkDirection ~= "right") then
        profile.afkDirection = PROFILE_DEFAULTS.afkDirection
    end
    profile.afkRotationSpeed = Clamp(tonumber(profile.afkRotationSpeed) or PROFILE_DEFAULTS.afkRotationSpeed, 0.1, 2.0)
    profile.afkRotationSpeed = math.floor(profile.afkRotationSpeed * 10 + 0.5) / 10
    profile.afkSkipMounted = NormalizeBoolean(profile.afkSkipMounted, PROFILE_DEFAULTS.afkSkipMounted)
    profile.afkSkipFlying = NormalizeBoolean(profile.afkSkipFlying, PROFILE_DEFAULTS.afkSkipFlying)
    profile.afkResumeAfterCombat = NormalizeBoolean(profile.afkResumeAfterCombat, PROFILE_DEFAULTS.afkResumeAfterCombat)
    profile.afkZoomOut = NormalizeBoolean(profile.afkZoomOut, PROFILE_DEFAULTS.afkZoomOut)
    profile.enableDebugLogging = NormalizeBoolean(profile.enableDebugLogging, PROFILE_DEFAULTS.enableDebugLogging)
    profile.minimap.hide = NormalizeBoolean(profile.minimap.hide, false)

    local VALID_LANGUAGES = {
        client = true,
        enUS = true,
        deDE = true,
        frFR = true,
        zhCN = true,
        ukUA = true,
    }
    if type(profile.language) ~= "string" or not VALID_LANGUAGES[profile.language] then
        profile.language = "client"
    end

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
-- MIGRATION: rescue settings that the old dynamic defaults silently dropped
-- ============================================================================
-- Before this build the profile defaults were read from the LIVE CVars, so any
-- setting that happened to match the live CVar at logout was removed from
-- SavedVariables by AceDB. Those keys are missing right now but the value the
-- user actually wants is still sitting in the CVar, so copy it back once before
-- AceDB installs the new (static) defaults over it.
local RESCUED_CVAR_KEYS = {
    { key = "cameraYawMoveSpeed",       cvar = "cameraYawMoveSpeed",        min = 1,  max = 360 },
    { key = "cameraPitchMoveSpeed",     cvar = "cameraPitchMoveSpeed",      min = 1,  max = 360 },
    { key = "moveViewDistance",         cvar = "cameraDistanceMoveSpeed",   min = 20, max = 50 },
    { key = "cameraIndirectOffset",     cvar = "cameraIndirectOffset",      min = 0,  max = 10 },
    { key = "reduceUnexpectedMovement", cvar = "cameraReduceUnexpectedMovement", isBoolean = true },
    { key = "cameraIndirectVisibility", cvar = "cameraIndirectVisibility",  isBoolean = true },
    { key = "occludedSilhouettePlayer", cvar = "occludedSilhouettePlayer",  isBoolean = true },
    { key = "resampleAlwaysSharpen",    cvar = "resampleAlwaysSharpen",     isBoolean = true },
    { key = "softTargetInteract",       cvar = "SoftTargetIconGameObject",  isBoolean = true },
}

function Database:MigrateDynamicCVarDefaults()
    local rawDb = _G.MaxCameraDistanceDB
    if type(rawDb) ~= "table" or type(rawDb.profiles) ~= "table" then return end

    rawDb.__migrations = rawDb.__migrations or {}
    if rawDb.__migrations.staticCVarDefaults then return end
    rawDb.__migrations.staticCVarDefaults = true

    for _, profile in pairs(rawDb.profiles) do
        if type(profile) == "table" then
            for _, entry in ipairs(RESCUED_CVAR_KEYS) do
                if profile[entry.key] == nil then
                    local live = SafeGetCVar(entry.cvar)
                    if live ~= nil then
                        if entry.isBoolean then
                            profile[entry.key] = (live == 1)
                        else
                            profile[entry.key] = Clamp(live, entry.min, entry.max)
                        end
                    end
                end
            end

            -- minZoomFactor is deliberately NOT restored from the live CVar: this
            -- addon pins cameraDistanceMaxZoomFactor to whatever state was active at
            -- logout (mount / combat / normal), so the live value is not the user's
            -- "Normal zoom" choice. Fall back to the real client default instead.
            if profile.minZoomFactor == nil then
                profile.minZoomFactor = BLIZZARD_DEFAULT_YARDS
            end
        end
    end
end

local function CreateFallbackDB(defaultsWrapper)
    local rawDb = _G.MaxCameraDistanceDB
    if type(rawDb) ~= "table" then
        rawDb = {}
        _G.MaxCameraDistanceDB = rawDb
    end

    rawDb.profiles = rawDb.profiles or {}
    rawDb.profileKeys = rawDb.profileKeys or {}

    local characterKey = GetCurrentCharacterKey() or "Default"
    local profileKey = rawDb.profileKeys[characterKey] or characterKey
    rawDb.profileKeys[characterKey] = profileKey

    if type(rawDb.profiles[profileKey]) ~= "table" then
        rawDb.profiles[profileKey] = CopyTableSafe(defaultsWrapper.profile or PROFILE_DEFAULTS)
    end

    local fallback = {
        profile = rawDb.profiles[profileKey],
        profiles = rawDb.profiles,
        profileKeys = rawDb.profileKeys,
        RegisterCallback = function() end,
    }

    function fallback:ResetProfile()
        rawDb.profiles[profileKey] = CopyTableSafe(defaultsWrapper.profile or PROFILE_DEFAULTS)
        self.profile = rawDb.profiles[profileKey]
    end

    return fallback
end

-- ============================================================================
-- INIT DB
-- ============================================================================
function Database:InitDB()
    local defaultsWrapper = { profile = CopyTableSafe(PROFILE_DEFAULTS) }

    self:MigrateToPerCharacterProfiles()
    -- Must run on the RAW SavedVariables table, before AceDB attaches its
    -- defaults metatable (afterwards a stripped key is indistinguishable from
    -- a key that legitimately holds the default value).
    self:MigrateDynamicCVarDefaults()

    ResolveAceDB()

    if AceDB and AceDB.New then
        self.db = AceDB:New("MaxCameraDistanceDB", defaultsWrapper)
        self.usingFallbackDB = false
    else
        self.db = CreateFallbackDB(defaultsWrapper)
        self.usingFallbackDB = true
        print(addonName .. ": AceDB-3.0 is not available yet. Using basic saved-variable storage for now; profile UI is unavailable.")
    end

    if not self.db then
        print(addonName .. ": DB initialization failed.")
        return
    end

    self:ApplyMigrations(self.db.profile)
    self:RegisterProfileCallbacks()
end

-- Called once at PLAYER_LOGIN, when every addon has finished loading. If AceDB
-- only showed up after us, swap the fallback store out for the real thing.
-- Safe because the fallback writes into MaxCameraDistanceDB.profiles[key] using
-- exactly the layout AceDB expects, so the values are adopted as-is.
function Database:UpgradeFallbackDB()
    if not self.usingFallbackDB then return false end
    if not ResolveAceDB() then return false end
    if not (AceDB and AceDB.New) then return false end

    self.db = nil
    self.usingFallbackDB = false
    self:InitDB()

    if not self.db then return false end

    self:OnProfileUpdate("AceDB became available")
    return true
end

function Database:RegisterProfileCallbacks()
    if not self.db then return end

    local function OnUpdate(event)
        Database:OnProfileUpdate(event)
    end

    if type(self.db.RegisterCallback) ~= "function" then return end

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

    if ns.Locale and ns.Locale.GetActiveLocale then
        ns.Locale:GetActiveLocale()
    end

    if ns.Core and ns.Core.RefreshMinimapButton then
        ns.Core:RefreshMinimapButton()
    end

    if ns.Config and ns.Config.NotifyChange then
        ns.Config:NotifyChange()
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
