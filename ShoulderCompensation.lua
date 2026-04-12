local addonName, ns = ...
ns.ShoulderCompensation = ns.ShoulderCompensation or {}
local Shoulder = ns.ShoulderCompensation

local Compat = ns.Compat or {}

local CreateFrame = CreateFrame
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local UnitRace = UnitRace
local UnitSex = UnitSex
local UnitInVehicle = UnitInVehicle
local UnitGUID = UnitGUID
local UnitOnTaxi = UnitOnTaxi
local IsMounted = IsMounted
local tonumber = tonumber
local type = type
local pairs = pairs
local strsplit = strsplit

local C_MountJournal = _G.C_MountJournal
local C_UnitAuras = _G.C_UnitAuras
local GetShapeshiftFormID = _G.GetShapeshiftFormID

local modelFrame = CreateFrame and CreateFrame("PlayerModel") or nil

local function SafeAuraSpellIdAtIndex(unit, index)
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        local aura = C_UnitAuras.GetBuffDataByIndex(unit, index)
        if aura and aura.spellId and (not issecretvalue or not issecretvalue(aura.spellId)) then
            return aura.spellId
        end
        return nil
    end

    if UnitBuff then
        local _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index)
        return spellId
    end

    return nil
end

local function HasAuraSpell(unit, wantedSpellId)
    for i = 1, 40 do
        local spellId = SafeAuraSpellIdAtIndex(unit, i)
        if spellId == wantedSpellId then
            return true
        end
    end
    return false
end

-- Imported and adapted from CameraOverShoulderFix.
Shoulder.playerModelOffsetFactors = {

  -- Alliance core races
  [1011653] = 1.26,   -- Human male                 - 2019-12-29
  [1000764] = 1.458,  -- Human female               - 2020-01-03
  [878772]  = 1.15,   -- Dwarf male                 - 2020-01-01
  [950080]  = 1.428,  -- Dwarf female               - 2020-01-03
  [974343]  = 1.20,   -- NightElf male              - 2020-01-04
  [921844]  = 1.38,   -- NightElf female            - 2019-12-29
  [900914]  = 1.392,  -- Gnome male                 - 2020-01-04
  [940356]  = 1.403,  -- Gnome female               - 2020-01-04
  [1005887] = 0.962,  -- Draenei male               - 2020-03-17
  [1022598] = 1.28,   -- Draenei female             - 2020-01-01
  [307454]  = 0.936,  -- Worgen male                - 2020-04-24
  [307453]  = 1.182,  -- Worgen female              - 2020-04-24

  -- Alliance allied races
  [1734034] = 1.337,  -- VoidElf male               - 2020-01-03
  [1733758] = 1.41,   -- VoidElf female             - 2020-01-03
  [1620605] = 0.965,  -- LightforgedDraenei male    - 2020-03-16
  [1593999] = 1.28,   -- LightforgedDraenei female  - 2020-03-16
  [1890765] = 1.14,   -- DarkIronDwarf male         - 2020-03-16
  [1890763] = 1.45,   -- DarkIronDwarf female       - 2020-03-16
  [1721003] = 0.999,  -- KulTiran male              - 2020-03-17
  [1886724] = 1.2,    -- KulTiran female            - 2020-03-17
  [2622502] = 1.421,  -- Mechagnome male            - 2020-03-17
  [2564806] = 1.453,  -- Mechagnome female          - 2020-03-17

  -- Horde core races
  [1968587] = 1.00,   -- (Maghar)Orc male (upright) - 2020-01-01
  [917116]  = 0.975,  -- (Maghar)Orc male (hunched) - 2020-01-01
  [949470]  = 1.229,  -- (Maghar)Orc female         - 2020-01-02
  [959310]  = 1.22,   -- Scourge male               - 2020-01-01
  [997378]  = 1.362,  -- Scourge female             - 2020-01-01
  [968705]  = 0.9,    -- Tauren male                - 2020-01-01
  [986648]  = 1.1,    -- Tauren female              - 2020-01-02
  [1022938] = 0.98,   -- Troll male                 - 2020-01-02
  [1018060] = 1.25,   -- Troll female               - 2020-01-02
  [1100087] = 1.337,  -- BloodElf male              - 2020-01-01
  [1100258] = 1.41,   -- BloodElf female            - 2020-01-02
  [119376]  = 1.31,   -- Goblin male                - 2020-01-02
  [119369]  = 1.3,    -- Goblin female              - 2020-01-02

  -- Horde allied races
  [1814471] = 1.198,  -- Nightborne male            - 2020-03-17
  [1810676] = 1.267,  -- Nightborne female          - 2020-03-17
  [1630218] = 0.9,    -- HighmountainTauren male    - 2020-03-17
  [1630402] = 1.1,    -- HighmountainTauren female  - 2020-03-17
                      -- MagharOrc male (same as Orc)
                      -- MagharOrc female (same as Orc)
  [1630447] = 1.046,  -- ZandalariTroll male        - 2020-04-24
  [1662187] = 1.077,  -- ZandalariTroll female      - 2020-04-24
  [1890761] = 1.21,   -- Vulpera male               - 2020-04-24
  [1890759] = 1.21,   -- Vulpera female             - 2020-04-24


  -- Pandaren
  [535052]  = 0.95,   -- Pandaren male              - 2020-01-01
  [589715]  = 1.07,   -- Pandaren female            - 2020-01-01
  
  -- Dracthyr
  -- [4207724] = 0.875,      -- Dracthyr male/female       - 2022-12-10  (matched with Albino Drake)
  [4207724] = 0.721,      -- Dracthyr male/female       - 2022-12-10  (matched with visage form)
  
  
  
  [4220448] = 1.455,      -- Dracthyr visage female     - 2022-12-10
  [4395382] = 1.33,      -- Dracthyr visage male       - 2022-12-10

}
Shoulder.raceAndGenderToModelId = {
  -- race                      male           female
  ["Human"]              = {  [2] = 1011653,  [3] = 1000764  },
  ["Dwarf"]              = {  [2] = 878772,   [3] = 950080   },
  ["NightElf"]           = {  [2] = 974343,   [3] = 921844   },
  ["Gnome"]              = {  [2] = 900914,   [3] = 940356   },
  ["Draenei"]            = {  [2] = 1005887,  [3] = 1022598  },
  ["Worgen"]             = {  [2] = 307454,   [3] = 307453   },

  ["VoidElf"]            = {  [2] = 1734034,  [3] = 1733758  },
  ["LightforgedDraenei"] = {  [2] = 1620605,  [3] = 1593999  },
  ["DarkIronDwarf"]      = {  [2] = 1890765,  [3] = 1890763  },
  ["KulTiran"]           = {  [2] = 1721003,  [3] = 1886724  },
  ["Mechagnome"]         = {  [2] = 2622502,  [3] = 2564806  },


  ["Orc"]                = {  [2] = 1968587,  [3] = 949470   },
  ["Scourge"]            = {  [2] = 959310,   [3] = 997378   },
  ["Tauren"]             = {  [2] = 968705,   [3] = 986648   },
  ["Troll"]              = {  [2] = 1022938,  [3] = 1018060  },
  ["BloodElf"]           = {  [2] = 1100087,  [3] = 1100258  },
  ["Goblin"]             = {  [2] = 119376,   [3] = 119369   },

  ["Nightborne"]         = {  [2] = 1814471,  [3] = 1810676  },
  ["HighmountainTauren"] = {  [2] = 1630218,  [3] = 1630402  },
  ["MagharOrc"]          = {  [2] = 1968587,  [3] = 949470   },   -- Same as Orc
  ["ZandalariTroll"]     = {  [2] = 1630447,  [3] = 1662187  },
  ["Vulpera"]            = {  [2] = 1890761,  [3] = 1890759  },
  ["Dracthyr"]           = {  [2] = 4207724,  [3] = 4207724  },  -- Dragon form (shared model)


  ["Pandaren"]           = {  [2] = 535052,   [3] = 589715  },

};
Shoulder.hardcodedOffsetFactors = {

  ["mountId"] = {

          [6] = 7.74,  -- Brown Horse                  - 2019-12-19
         [17] = 7.6,   -- Felsteed
         [19] = 6.0,   -- Dire Wolf
         [71] = 4.7,   -- Gray Kodo
         [72] = 4.7,   -- Brown Kodo
         [76] = 4.3,   -- Black War Kodo
        [101] = 4.3,   -- Great White Kodo
        [102] = 4.3,   -- Great Gray Kodo
        [103] = 4.3,   -- Great Brown Kodo
        [152] = 6.45,  -- Red Hawkstryder
        [157] = 6.45,  -- Purple Hawkstryder
        [158] = 6.45,  -- Blue Hawkstryder
        [159] = 6.45,  -- Black Hawkstryder
        [203] = 5.71,  -- Cenarion War Hippogryph      - 2019-12-19
        [268] = 2.5,   -- Albino Drake
        [309] = 4.7,   -- White Kodo
        [310] = 6.1,   -- Black Wolf
        [435] = 7.6,   -- Mountain Horse
        [547] = 5.7,   -- Hearthsteed
        [651] = 5.6,   -- Warlord's Deathwheel
        [780] = 5.4,   -- Felsaber
        [934] = 5.75,  -- Swift Spectral Hippogryph

  },
  
  ["vehicleId"] = {

      [35129] = 0.38,  -- Reprogrammed Shredder (Azshara)
      [40854] = 0.20,  -- River Boat (Thousand Needles)

     [113042] = 1.0,   -- Illidan Stormrage (Ravencrest Scenario)
     [113101] = 1.0,   -- Illidan Stormrage (Temple Summit Scenario)

     [114281] = 1.0,   -- Flight Master's Mount (Flight Master's Whistle)

     [235294] = 1.0,   -- Soul Conduit transport (Windrunner Spire Dungeon)

  },
  
  
  -- Non-player models.
  ["modelId"] = {

     [118653] = 1.03,  -- Dragonmaw Fel Orc male (Dragonmaw Illusion in BC Shadowmoon Valley)
     [124118] = 0.87,  -- Furbolg Form (Stave of Fur and Claw)
     [124640] = 1.0,   -- Soul Conduit transport visual (Windrunner Spire Dungeon)
    [1113034] = 1.2,   -- Murloc Costume

  },

};
Shoulder.druidFormIdToShoulderOffsetFactor = {

  ["Tauren"] = {
    [2] = {   -- male
      [1]   = 0.862,   -- Cat
      [2]   = 0.78,    -- Tree of Life
      [3]   = 0.888,   -- Travel
      [4]   = 0.71,    -- Aquatic
      [5]   = 0.83,    -- Bear
      [27]  = 0.532,   -- Swift Flight
      [29]  = 0.545,   -- Flight
      [31]  = 0.933,   -- Moonkin
    },
    [3] = {   -- female
      [1]   = 0.788,   -- Cat
      [2]   = 0.715,   -- Tree of Life
      [3]   = 0.815,   -- Travel
      [4]   = 0.651,   -- Aquatic
      [5]   = 0.76,    -- Bear
      [27]  = 0.49,    -- Swift Flight
      [29]  = 0.49,    -- Flight     -- TODO
      [31]  = 0.853,   -- Moonkin
    },
  },

  ["Troll"] = {
    [2] = {   -- male
      [1]   = 0.685,   -- Cat
      [2]   = 0.633,   -- Tree of Life
      [3]   = 0.639,   -- Travel
      [4]   = 0.513,   -- Aquatic
      [5]   = 0.675,   -- Bear
      [27]  = 0.355,   -- Swift Flight
      [29]  = 0.355,   -- Flight     -- TODO
      [31]  = 0.771,   -- Moonkin
    },
    [3] = {   -- female
      [1]   = 0.685,   -- Cat
      [2]   = 0.633,   -- Tree of Life
      [3]   = 0.639,   -- Travel
      [4]   = 0.513,   -- Aquatic
      [5]   = 0.675,   -- Bear
      [27]  = 0.355,   -- Swift Flight
      [29]  = 0.355,   -- Flight     -- TODO
      [31]  = 0.771,   -- Moonkin
    },
  },

  ["HighmountainTauren"] = {
    [2] = {   -- male
      [1]   = 0.858,   -- Cat
      [2]   = 0.776,   -- Tree of Life
      [3]   = 0.881,   -- Travel
      [4]   = 0.71,    -- Aquatic
      [5]   = 0.827,   -- Bear
      [27]  = 0.587,   -- Swift Flight
      [29]  = 0.587,   -- Flight     -- TODO
      [31]  = 1.00,    -- Moonkin
    },
    [3] = {   -- female
      [1]   = 0.778,   -- Cat
      [2]   = 0.706,   -- Tree of Life
      [3]   = 0.804,   -- Travel
      [4]   = 0.644,   -- Aquatic
      [5]   = 0.75,    -- Bear
      [27]  = 0.532,   -- Swift Flight
      [29]  = 0.532,   -- Flight     -- TODO
      [31]  = 0.905,   -- Moonkin
    },
  },

  ["ZandalariTroll"] = {
    [2] = {   -- male
      [1]   = 0.596,   -- Cat
      [2]   = 0.844,   -- Tree of Life
      [3]   = 0.431,   -- Travel
      [4]   = 0.319,   -- Aquatic
      [5]   = 0.605,   -- Bear
      [27]  = 0.507,   -- Swift Flight
      [29]  = 0.507,   -- Flight     -- TODO
      [31]  = 0.701,   -- Moonkin
    },
    [3] = {   -- female
      [1]   = 0.601,   -- Cat
      [2]   = 0.855,   -- Tree of Life
      [3]   = 0.433,   -- Travel
      [4]   = 0.321,   -- Aquatic
      [5]   = 0.61,    -- Bear
      [27]  = 0.513,   -- Swift Flight
      [29]  = 0.513,   -- Flight     -- TODO
      [31]  = 0.71,    -- Moonkin
    },
  },



  ["NightElf"] = {
    [2] = {   -- male
      [1]   = 0.739,   -- Cat
      [2]   = 0.634,   -- Tree of Life
      [3]   = 0.66,    -- Travel
      [4]   = 0.512,   -- Aquatic
      [5]   = 0.688,   -- Bear
      [27]  = 0.383,   -- Swift Flight
      [29]  = 0.383,   -- Flight     -- TODO
      [31]  = 0.773,   -- Moonkin
    },
    [3] = {   -- female
      [1]   = 0.75,    -- Cat
      [2]   = 0.641,   -- Tree of Life
      [3]   = 0.67,    -- Travel
      [4]   = 0.519,   -- Aquatic
      [5]   = 0.698,   -- Bear
      [27]  = 0.388,   -- Swift Flight
      [29]  = 0.388,   -- Flight     -- TODO
      [31]  = 0.785,   -- Moonkin
    },
  },

  ["Worgen"] = {
    [2] = {   -- male
      [1]   = 0.689,   -- Cat
      [2]   = 0.63,    -- Tree of Life
      [3]   = 0.663,   -- Travel
      [4]   = 0.515,   -- Aquatic
      [5]   = 0.68,    -- Bear
      [27]  = 0.38,    -- Swift Flight
      [29]  = 0.38,    -- Flight     -- TODO
      [31]  = 0.72,    -- Moonkin
    },
    [3] = {   -- female
      [1]   = 0.685,   -- Cat
      [2]   = 0.63,    -- Tree of Life
      [3]   = 0.66,    -- Travel
      [4]   = 0.515,   -- Aquatic
      [5]   = 0.678,   -- Bear
      [27]  = 0.38,    -- Swift Flight
      [29]  = 0.38,    -- Flight     -- TODO
      [31]  = 0.72,    -- Moonkin
    },
  },

  ["KulTiran"] = {
    [2] = {   -- male
      [1]   = 0.689,   -- Cat
      [2]   = 0.844,   -- Tree of Life
      [3]   = 0.64,    -- Travel
      [4]   = 0.455,   -- Aquatic
      [5]   = 0.663,   -- Bear
      [27]  = 1.055,   -- Swift Flight
      [29]  = 1.055,   -- Flight     -- TODO
      [31]  = 0.80,    -- Moonkin
    },
    [3] = {   -- female
      [1]   = 0.689,   -- Cat
      [2]   = 0.849,   -- Tree of Life
      [3]   = 0.642,   -- Travel
      [4]   = 0.457,   -- Aquatic
      [5]   = 0.663,   -- Bear
      [27]  = 1.055,   -- Swift Flight
      [29]  = 1.055,   -- Flight     -- TODO
      [31]  = 0.80,    -- Moonkin
    },
  },

};
Shoulder.demonhunterFormToShoulderOffsetFactor = {
  ["BloodElf"] = {
    [2] = {   -- male
      ["Havoc"]     = 0.52,
      ["Vengeance"] = 0.74,
    },
    [3] = {   -- female
      ["Havoc"]     = 0.57,
      ["Vengeance"] = 0.87,
    },
  },
  ["NightElf"] = {
    [2] = {   -- male
      ["Havoc"]     = 0.52,
      ["Vengeance"] = 0.74,
    },
    [3] = {   -- female
      ["Havoc"]     = 0.61,
      ["Vengeance"] = 0.91,
    },
  },
}
Shoulder.ghostWolfModelId = 926251
Shoulder.shamanGhostwolfToShoulderOffsetFactor = {
  [16]  = 0.758,  -- Ghostwolf
};

Shoulder.state = Shoulder.state or {
    lastActiveMount = nil,
    lastModelId = nil,
    lastVehicleId = nil,
}

function Shoulder:GetCurrentMountId()
    if not (C_MountJournal and C_MountJournal.GetMountInfoByID and C_MountJournal.GetMountIDs) then
        return self.state.lastActiveMount
    end

    if self.state.lastActiveMount then
        local _, _, _, active = C_MountJournal.GetMountInfoByID(self.state.lastActiveMount)
        if active then
            return self.state.lastActiveMount
        end
    end

    local ids = C_MountJournal.GetMountIDs()
    if type(ids) ~= "table" then
        return self.state.lastActiveMount
    end

    for _, mountId in pairs(ids) do
        local _, _, _, active = C_MountJournal.GetMountInfoByID(mountId)
        if active then
            self.state.lastActiveMount = mountId
            return mountId
        end
    end

    return self.state.lastActiveMount
end

function Shoulder:GetCurrentModelId()
    if not modelFrame or not modelFrame.SetUnit or not modelFrame.GetModelFileID then
        return self.state.lastModelId
    end

    if modelFrame.ClearModel then
        modelFrame:ClearModel()
    end

    modelFrame:SetUnit("player")
    local modelId = modelFrame:GetModelFileID()

    if modelId and self.playerModelOffsetFactors[modelId] then
        self.state.lastModelId = modelId
        return modelId
    end

    if modelId then
        return modelId
    end

    local _, raceFile = UnitRace("player")
    local sex = UnitSex("player")
    if raceFile and self.raceAndGenderToModelId[raceFile] and self.raceAndGenderToModelId[raceFile][sex] then
        return self.raceAndGenderToModelId[raceFile][sex]
    end

    return self.state.lastModelId
end

function Shoulder:GetVehicleId()
    local vehicleGuid = UnitGUID("vehicle")
    if not vehicleGuid or (issecretvalue and issecretvalue(vehicleGuid)) then
        return self.state.lastVehicleId
    end

    local _, _, _, _, _, vehicleId = strsplit("-", vehicleGuid)
    vehicleId = tonumber(vehicleId)
    if vehicleId then
        self.state.lastVehicleId = vehicleId
    end
    return vehicleId
end

function Shoulder:ResolveHardcodedOverride(idType, id)
    if not idType or not id then return nil end
    local t = self.hardcodedOffsetFactors and self.hardcodedOffsetFactors[idType]
    if not t then return nil end
    return t[id]
end

function Shoulder:GetNormalPlayerFactor()
    local _, raceFile = UnitRace("player")
    local sex = UnitSex("player")
    local _, englishClass = UnitClass("player")

    if englishClass == "DEMONHUNTER" and raceFile and sex then
        if HasAuraSpell("player", 162264) then
            local v = self.demonhunterFormToShoulderOffsetFactor
                and self.demonhunterFormToShoulderOffsetFactor[raceFile]
                and self.demonhunterFormToShoulderOffsetFactor[raceFile][sex]
                and self.demonhunterFormToShoulderOffsetFactor[raceFile][sex]["Havoc"]
            if v then return v end
        elseif HasAuraSpell("player", 187827) then
            local v = self.demonhunterFormToShoulderOffsetFactor
                and self.demonhunterFormToShoulderOffsetFactor[raceFile]
                and self.demonhunterFormToShoulderOffsetFactor[raceFile][sex]
                and self.demonhunterFormToShoulderOffsetFactor[raceFile][sex]["Vengeance"]
            if v then return v end
        end
    end

    local modelId = self:GetCurrentModelId()
    if modelId and self.playerModelOffsetFactors[modelId] then
        return self.playerModelOffsetFactors[modelId]
    end

    local override = modelId and self:ResolveHardcodedOverride("modelId", modelId) or nil
    if override then
        return override
    end

    return 1
end

function Shoulder:GetShapeshiftFactor()
    local formId = GetShapeshiftFormID and GetShapeshiftFormID(true) or nil
    if not formId or formId == 30 then
        return nil
    end

    local _, englishClass = UnitClass("player")
    local _, raceFile = UnitRace("player")
    local sex = UnitSex("player")

    if englishClass == "DRUID" and raceFile and sex then
        local byRace = self.druidFormIdToShoulderOffsetFactor and self.druidFormIdToShoulderOffsetFactor[raceFile]
        local bySex = byRace and byRace[sex]
        if bySex and bySex[formId] then
            return bySex[formId]
        end
        return 1
    end

    if englishClass == "SHAMAN" and formId == 16 then
        return (self.shamanGhostwolfToShoulderOffsetFactor and self.shamanGhostwolfToShoulderOffsetFactor[16]) or 1
    end

    return nil
end

function Shoulder:GetMountedFactor()
    if not IsMounted() or UnitOnTaxi("player") then
        return nil
    end

    if HasAuraSpell("player", 87840) then
        local _, raceFile = UnitRace("player")
        local sex = UnitSex("player")
        local modelId = self:GetCurrentModelId()
        if modelId and self.playerModelOffsetFactors[modelId] then
            return self.playerModelOffsetFactors[modelId] * 10
        end
        if raceFile == "Worgen" and self.raceAndGenderToModelId[raceFile] and self.raceAndGenderToModelId[raceFile][sex] then
            local fallbackModelId = self.raceAndGenderToModelId[raceFile][sex]
            return (self.playerModelOffsetFactors[fallbackModelId] or 1) * 10
        end
        return 6
    end

    if HasAuraSpell("player", 40212) then
        return 2.5
    end

    if HasAuraSpell("player", 386196) then
        local modelId = self:GetCurrentModelId()
        if modelId and self.playerModelOffsetFactors[modelId] then
            return self.playerModelOffsetFactors[modelId] * 10
        end
        local sex = UnitSex("player")
        if self.raceAndGenderToModelId["Dracthyr"] and self.raceAndGenderToModelId["Dracthyr"][sex] then
            local dracthyrModel = self.raceAndGenderToModelId["Dracthyr"][sex]
            return (self.playerModelOffsetFactors[dracthyrModel] or 1) * 10
        end
        return 7.2
    end

    local mountId = self:GetCurrentMountId()
    if mountId then
        local override = self:ResolveHardcodedOverride("mountId", mountId)
        if override then
            return override
        end
    end

    return nil
end

function Shoulder:GetVehicleFactor()
    if not UnitInVehicle("player") then
        return nil
    end

    local vehicleId = self:GetVehicleId()
    if not vehicleId then
        return 1
    end

    return self:ResolveHardcodedOverride("vehicleId", vehicleId) or 1
end

function Shoulder:GetFactor()
    if not UnitRace or not UnitSex then
        return 1
    end

    local vehicleFactor = self:GetVehicleFactor()
    if vehicleFactor then
        return vehicleFactor
    end

    local mountedFactor = self:GetMountedFactor()
    if mountedFactor then
        return mountedFactor
    end

    local formFactor = self:GetShapeshiftFactor()
    if formFactor then
        return formFactor
    end

    return self:GetNormalPlayerFactor() or 1
end

function Shoulder:Invalidate()
    if modelFrame and modelFrame.ClearModel then
        modelFrame:ClearModel()
    end
end
