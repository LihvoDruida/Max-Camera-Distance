-- Minimal WoW/Lua 5.1 stub, sufficient to load the addon files and drive the
-- ADDON_LOADED / PLAYER_LOGIN init path. Deliberately NOT a full client: it
-- cannot model secret values or real CVar semantics, and must not be trusted
-- for anything beyond load-order and registration behaviour.

local stub = {}

local frames = {}
stub.frames = frames

local function noop() end

-- A permissive object: any method the addon calls that this stub does not model
-- explicitly resolves to a no-op returning nil.
--
-- LIMITATION, stated on purpose: this means the stub can NEVER catch a misuse
-- of a frame/texture API, a typo in a method name, a taint problem, or anything
-- that would error on the live client. It exists so the initialisation path can
-- be driven end to end, and it is valid ONLY for the load-order and
-- registration questions the probes in this folder ask. Do not write probes
-- that assert anything about frame behaviour on the strength of it.
local function Permissive(proto)
    local tbl = proto or {}
    return setmetatable({}, {
        __index = function(self, key)
            local value = tbl[key]
            if value ~= nil then return value end
            rawset(self, key, noop)
            return noop
        end,
    })
end

stub.Permissive = Permissive

local frameProto = {}

function frameProto:RegisterEvent(event) self._events[event] = true end
function frameProto:RegisterUnitEvent(event, unit) self._events[event] = unit or true end
function frameProto:UnregisterEvent(event) self._events[event] = nil end
function frameProto:UnregisterAllEvents() self._events = {} end
function frameProto:SetScript(kind, fn) self._scripts[kind] = fn end
function frameProto:GetScript(kind) return self._scripts[kind] end
function frameProto:CreateFontString() return Permissive() end
function frameProto:CreateTexture() return Permissive() end
function frameProto:CreateAnimationGroup() return Permissive() end
function frameProto:GetName() return nil end
function frameProto:GetParent() return nil end

-- Shown/hidden is the one piece of frame state modelled for real, because
-- several code paths use a hidden frame purely as an on/off flag for their own
-- OnUpdate driver. Nothing else about frames is modelled - see the limitation
-- note above, which still stands.
function frameProto:Show() self._shown = true end
function frameProto:Hide() self._shown = false end
function frameProto:IsShown() return self._shown == true end
function frameProto:IsVisible() return self._shown == true end

local frameMeta = {
    __index = function(self, key)
        local value = frameProto[key]
        if value ~= nil then return value end
        rawset(self, key, noop)
        return noop
    end,
}

function stub.CreateFrame()
    local f = setmetatable({ _events = {}, _scripts = {}, _shown = false }, frameMeta)
    frames[#frames + 1] = f
    return f
end

function stub.Fire(event, ...)
    for _, f in ipairs(frames) do
        if f._events[event] and f._scripts.OnEvent then
            f._scripts.OnEvent(f, event, ...)
        end
    end
end

-- ---------------------------------------------------------------- LibStub
function stub.InstallLibStub()
    local libs, minors = {}, {}
    local LibStub = setmetatable({ libs = libs, minors = minors }, {
        __call = function(self, major, silent)
            if not libs[major] and not silent then
                error("Cannot find a library instance of " .. tostring(major))
            end
            return libs[major], minors[major]
        end,
    })

    function LibStub:NewLibrary(major, minor)
        minor = tonumber(tostring(minor):match("%d+"))
        if minors[major] and minors[major] >= minor then return nil end
        minors[major] = minor
        libs[major] = libs[major] or {}
        return libs[major], minors[major]
    end

    function LibStub:GetLibrary(major, silent)
        if not libs[major] and not silent then
            error("Cannot find a library instance of " .. tostring(major))
        end
        return libs[major], minors[major]
    end

    _G.LibStub = LibStub
    return LibStub
end

-- ------------------------------------------------- Fake Ace3 (registry only)
-- Enough of AceDB / AceConfig / AceConfigRegistry / AceConfigDialog to observe
-- whether the addon registers its options table and which store it ends up on.
function stub.InstallAce3()
    local LibStub = _G.LibStub
    assert(LibStub, "InstallLibStub must run first")

    local registry = LibStub:NewLibrary("AceConfigRegistry-3.0", 20)
    registry.tables = registry.tables or {}
    function registry:RegisterOptionsTable(app, tbl) self.tables[app] = tbl end
    function registry:GetOptionsTable(app) return self.tables[app] end
    function registry:NotifyChange(app)
        if not self.tables[app] then
            error(("%s isn't registered with AceConfigRegistry, unable to notify"):format(app), 2)
        end
    end

    local config = LibStub:NewLibrary("AceConfig-3.0", 3)
    function config:RegisterOptionsTable(app, tbl, slash)
        return registry:RegisterOptionsTable(app, tbl)
    end

    local dialog = LibStub:NewLibrary("AceConfigDialog-3.0", 80)
    dialog.opened = {}
    function dialog:Open(app)
        if not registry:GetOptionsTable(app) then
            error(("%s isn't registered with AceConfigRegistry, unable to open config"):format(app), 2)
        end
        self.opened[#self.opened + 1] = app
    end
    dialog.blizCategories = {}
    function dialog:AddToBlizOptions(app, name, parent, path)
        self.blizCategories[#self.blizCategories + 1] = tostring(name) .. "/" .. tostring(path or "root")
    end

    local dbOptions = LibStub:NewLibrary("AceDBOptions-3.0", 15)
    function dbOptions:GetOptionsTable() return { type = "group", name = "Profiles", args = {} } end

    local aceDB = LibStub:NewLibrary("AceDB-3.0", 28)
    function aceDB:New(tbl, defaults)
        local sv = _G[tbl]
        if type(sv) ~= "table" then sv = {}; _G[tbl] = sv end
        sv.profiles = sv.profiles or {}
        sv.profileKeys = sv.profileKeys or {}

        local charKey = UnitName("player") .. " - " .. GetRealmName()
        local profileKey = sv.profileKeys[charKey] or charKey
        sv.profileKeys[charKey] = profileKey
        sv.profiles[profileKey] = sv.profiles[profileKey] or {}

        local profile = sv.profiles[profileKey]
        for k, v in pairs(defaults.profile or {}) do
            if profile[k] == nil then profile[k] = v end
        end

        local db = { profile = profile, profiles = sv.profiles, profileKeys = sv.profileKeys, __isAceDB = true }
        function db:RegisterCallback() end
        function db:ResetProfile() end
        function db:GetCurrentProfile() return profileKey end
        return db
    end

    return { registry = registry, dialog = dialog, config = config, db = aceDB }
end

-- ------------------------------------------------------------------- CVars
-- A case-insensitive CVar table with write counting. Real CVar semantics
-- (secure/locked CVars, combat restrictions, the client's own side effects such
-- as CameraKeepCharacterCentered overriding ActionCam) are NOT modelled; this
-- only answers "what did the addon read and write, and how often".
function stub.InstallCVars(initial)
    local values = {}
    local store = { values = values, writes = 0, writeLog = {}, reads = 0, readsByName = {}, beforeWrite = nil }

    local function key(name) return tostring(name):lower() end

    function store:Set(name, value)
        values[key(name)] = tostring(value)
    end

    function store:Get(name)
        return values[key(name)]
    end

    function store:Number(name)
        return tonumber(values[key(name)])
    end

    function store:ResetCounters()
        self.writes = 0
        self.writeLog = {}
        self.reads = 0
        self.readsByName = {}
    end

    function store:ReadsOf(name)
        return self.readsByName[key(name)] or 0
    end

    for name, value in pairs(initial or {}) do
        store:Set(name, value)
    end

    local function DoSet(name, value)
        local k = key(name)
        -- The client only knows CVars that exist; writing an unknown one is a
        -- no-op here rather than silently creating it, which is what makes
        -- HasCVar-gated code paths testable.
        if values[k] == nil then return false end
        -- Some clients (observed on Forever 1.60.1) can emit CVAR_UPDATE while
        -- SetCVar is still on the stack and before GetCVar sees the new value.
        -- Tests can opt into that exact ordering through this hook.
        if store.beforeWrite then
            store.beforeWrite(name, value)
        end
        values[k] = tostring(value)
        store.writes = store.writes + 1
        store.writeLog[#store.writeLog + 1] = k .. "=" .. tostring(value)
        return true
    end

    local function DoGet(name)
        local k = key(name)
        store.reads = store.reads + 1
        store.readsByName[k] = (store.readsByName[k] or 0) + 1
        return values[k]
    end

    _G.GetCVar = function(name) return DoGet(name) end
    _G.GetCVarDefault = function(name) return store.defaults and store.defaults[key(name)] end
    _G.SetCVar = function(name, value) return DoSet(name, value) end
    _G.GetCVarBool = function(name) return (tonumber(values[key(name)]) or 0) ~= 0 end
    _G.C_CVar = {
        GetCVar = _G.GetCVar,
        GetCVarDefault = _G.GetCVarDefault,
        SetCVar = _G.SetCVar,
    }

    store.defaults = {}
    function store:SetDefault(name, value)
        self.defaults[key(name)] = tostring(value)
    end

    function store:SetBeforeWriteHook(callback)
        self.beforeWrite = callback
    end

    return store
end

return stub
