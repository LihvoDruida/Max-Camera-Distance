local addonName, ns = ...
ns.Contexts = ns.Contexts or {}
local Contexts = ns.Contexts

local Compat = ns.Compat or {}

local type = type
local pcall = pcall
local ipairs = ipairs

local IsInInstance = IsInInstance
local GetInstanceInfo = GetInstanceInfo
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local UnitIsPVP = UnitIsPVP
local C_PvP = C_PvP
local C_ChallengeMode = C_ChallengeMode

local IsTruthy = Compat.IsTruthy or function(value) return value and true or false end
local Plain = Compat.Plain or function(value) return value end

-- =====================================================================
-- Taxonomy
-- =====================================================================
-- Every combat context owns three profile keys: the manual distance, the preset
-- selector bound to it, and the delay before returning to the normal distance.
-- Database, Functions and Config all derive their tables from this one list, so
-- adding an activity later means editing exactly this file.
--
-- `world` is the "not in any activity" bucket and deliberately keeps its
-- original key names, so existing profiles and existing behaviour are untouched.
Contexts.DEFINITIONS = {
    world = {
        order = 10,
        kind = "neutral",
        distanceKey = "worldCombatZoomFactor",
        presetKey = "worldCombatPreset",
        delayKey = "worldCombatReturnDelay",
        labelKey = "CONTEXT_WORLD",
        defaultLabel = "Open World",
        defaultDelay = 0.4,
    },
    worldpvp = {
        order = 20,
        kind = "pvp",
        distanceKey = "worldPvpCombatZoomFactor",
        presetKey = "worldPvpCombatPreset",
        delayKey = "worldPvpCombatReturnDelay",
        labelKey = "CONTEXT_WORLD_PVP",
        defaultLabel = "World PvP",
        defaultDelay = 0.4,
        -- Seeds taken from the old single pvpCombat* keys on first migration.
        legacyDistanceKey = "pvpCombatZoomFactor",
        legacyPresetKey = "pvpCombatPreset",
    },
    arena = {
        order = 30,
        kind = "pvp",
        distanceKey = "arenaCombatZoomFactor",
        presetKey = "arenaCombatPreset",
        delayKey = "arenaCombatReturnDelay",
        labelKey = "CONTEXT_ARENA",
        defaultLabel = "Arena",
        defaultDelay = 0.4,
        legacyDistanceKey = "pvpCombatZoomFactor",
        legacyPresetKey = "pvpCombatPreset",
    },
    battleground = {
        order = 40,
        kind = "pvp",
        distanceKey = "battlegroundCombatZoomFactor",
        presetKey = "battlegroundCombatPreset",
        delayKey = "battlegroundCombatReturnDelay",
        labelKey = "CONTEXT_BATTLEGROUND",
        defaultLabel = "Battleground",
        defaultDelay = 0.4,
        legacyDistanceKey = "pvpCombatZoomFactor",
        legacyPresetKey = "pvpCombatPreset",
    },
    dungeon = {
        order = 50,
        kind = "pve",
        distanceKey = "dungeonCombatZoomFactor",
        presetKey = "dungeonCombatPreset",
        delayKey = "dungeonCombatReturnDelay",
        labelKey = "CONTEXT_DUNGEON",
        defaultLabel = "Dungeon",
        defaultDelay = 0.8,
        legacyDistanceKey = "partyCombatZoomFactor",
        legacyPresetKey = "partyCombatPreset",
        legacyDelayKey = "partyCombatReturnDelay",
    },
    mythicplus = {
        order = 60,
        kind = "pve",
        distanceKey = "mythicPlusCombatZoomFactor",
        presetKey = "mythicPlusCombatPreset",
        delayKey = "mythicPlusCombatReturnDelay",
        labelKey = "CONTEXT_MYTHIC_PLUS",
        defaultLabel = "Mythic+",
        defaultDelay = 0.8,
        legacyDistanceKey = "partyCombatZoomFactor",
        legacyPresetKey = "partyCombatPreset",
        legacyDelayKey = "partyCombatReturnDelay",
        retailOnly = true,
    },
    raid = {
        order = 70,
        kind = "pve",
        distanceKey = "raidCombatZoomFactor",
        presetKey = "raidCombatPreset",
        delayKey = "raidCombatReturnDelay",
        labelKey = "CONTEXT_RAID",
        defaultLabel = "Raid",
        defaultDelay = 1.2,
    },
    scenario = {
        order = 80,
        kind = "pve",
        distanceKey = "scenarioCombatZoomFactor",
        presetKey = "scenarioCombatPreset",
        delayKey = "scenarioCombatReturnDelay",
        labelKey = "CONTEXT_SCENARIO",
        defaultLabel = "Scenarios & Delves",
        defaultDelay = 0.8,
        legacyDistanceKey = "partyCombatZoomFactor",
        legacyPresetKey = "partyCombatPreset",
        legacyDelayKey = "partyCombatReturnDelay",
    },
}

Contexts.ORDER = {}
for id in pairs(Contexts.DEFINITIONS) do
    Contexts.ORDER[#Contexts.ORDER + 1] = id
end
table.sort(Contexts.ORDER, function(a, b)
    return Contexts.DEFINITIONS[a].order < Contexts.DEFINITIONS[b].order
end)

Contexts.DEFAULT = "world"

function Contexts:Get(context)
    return self.DEFINITIONS[context] or self.DEFINITIONS[self.DEFAULT]
end

function Contexts:GetDistanceKey(context)
    return self:Get(context).distanceKey
end

function Contexts:GetPresetKey(context)
    return self:Get(context).presetKey
end

function Contexts:GetDelayKey(context)
    return self:Get(context).delayKey
end

function Contexts:IsValid(context)
    return self.DEFINITIONS[context] ~= nil
end

-- Contexts that cannot occur on the running client are hidden from the options
-- panel rather than shown as dead controls (no Mythic+ outside Retail).
function Contexts:IsSupported(context)
    local def = self.DEFINITIONS[context]
    if not def then return false end
    if def.retailOnly and not Compat.IS_RETAIL then return false end
    return true
end

-- =====================================================================
-- Detection
-- =====================================================================
local function SafeInstanceInfo()
    if type(IsInInstance) ~= "function" then
        return false, nil, nil
    end

    local ok, inInstance, instanceType = pcall(IsInInstance)
    if not ok then
        return false, nil, nil
    end

    local difficultyID = nil
    if type(GetInstanceInfo) == "function" then
        local okInfo, _, _, diff = pcall(GetInstanceInfo)
        if okInfo then
            difficultyID = tonumber(Plain(diff))
        end
    end

    return IsTruthy(inInstance), instanceType, difficultyID
end

-- Difficulty 8 is Mythic Keystone. C_ChallengeMode.IsChallengeModeActive is the
-- authoritative answer but only exists on Retail, so the difficulty ID acts as
-- the fallback (and covers the brief window before the timer starts).
local function IsMythicPlusActive(difficultyID)
    if C_ChallengeMode and type(C_ChallengeMode.IsChallengeModeActive) == "function" then
        local ok, active = pcall(C_ChallengeMode.IsChallengeModeActive)
        if ok and IsTruthy(active) then
            return true
        end
    end

    return difficultyID == 8
end

-- World PvP is deliberately conservative: being outdoors is not enough, the
-- player must actually be participating. War Mode is the Retail signal; the PvP
-- flag covers Classic, PvP realms, and Retail players who flagged themselves
-- without War Mode. UnitIsPVP is conditionally secret in 12.1, so it is screened
-- rather than compared directly.
function Contexts:IsWorldPvPActive()
    if C_PvP and type(C_PvP.IsWarModeActive) == "function" then
        local ok, active = pcall(C_PvP.IsWarModeActive)
        if ok and IsTruthy(active) then
            return true
        end
    end

    if type(UnitIsPVP) == "function" then
        local ok, flagged = pcall(UnitIsPVP, "player")
        if ok and IsTruthy(flagged) then
            return true
        end
    end

    return false
end

-- Resolves the activity the player is currently in.
--
-- Instanced content is authoritative and checked first, because the instance
-- type tells us exactly which activity this is. Only when we are not inside
-- anything do the outdoor rules apply.
function Contexts:Resolve(db)
    local inInstance, instanceType, difficultyID = SafeInstanceInfo()

    if inInstance then
        if instanceType == "arena" then
            return "arena"
        end

        if instanceType == "pvp" then
            return "battleground"
        end

        if instanceType == "raid" then
            return "raid"
        end

        if instanceType == "party" then
            if self:IsSupported("mythicplus") and IsMythicPlusActive(difficultyID) then
                return "mythicplus"
            end
            return "dungeon"
        end

        if instanceType == "scenario" then
            return "scenario"
        end
    end

    -- Outdoors. World PvP outranks group size: a flagged player fighting other
    -- players wants their PvP distance whether or not they are grouped.
    if (db == nil or db.worldPvpZoom ~= false) and self:IsWorldPvPActive() then
        return "worldpvp"
    end

    -- Preserved from the previous behaviour: an outdoor raid group is how world
    -- bosses present themselves, and that used to resolve to the raid context.
    -- Changing it here would silently move world-boss users onto their open
    -- world distance, so it stays.
    if IsTruthy(IsInRaid and IsInRaid()) then
        return "raid"
    end

    if IsTruthy(IsInGroup and IsInGroup()) then
        return "dungeon"
    end

    return "world"
end
