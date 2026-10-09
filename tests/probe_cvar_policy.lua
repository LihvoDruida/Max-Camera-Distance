local value, writes, legacyWrites, combat = "1", 0, 0, false
local policy = { secure = false, readOnly = false, locked = false }
local result = true
_G.GetBuildInfo = function() return "12.1.0", "69933", "2026", 120100 end
_G.WOW_PROJECT_ID, _G.WOW_PROJECT_MAINLINE = 1, 1
_G.C_CVar = {
    AreCVarsLoaded = function() return true end,
    GetCVar = function(name) return name == "cameraZoomSpeed" and value or nil end,
    GetCVarInfo = function() return value, "1", false, false, policy.locked, policy.secure, policy.readOnly end,
    SetCVar = function(_, new) writes = writes + 1; if result == true then value = tostring(new) end; return result end,
}
_G.GetCVar = C_CVar.GetCVar
_G.SetCVar = function() legacyWrites = legacyWrites + 1; return true end
_G.InCombatLockdown = function() return combat end
local ns = {}
assert(loadfile("Compat.lua"))("Max_Camera_Distance", ns)
local c = ns.Compat
assert(c.SafeSetCVar("cameraZoomSpeed", 2) and value == "2")
result = false
assert(not c.SafeSetCVar("cameraZoomSpeed", 3))
assert(legacyWrites == 0, "rejected modern write falls through to the global setter")
result = nil
assert(not c.SafeSetCVar("cameraZoomSpeed", 3), "nil failure reported as success")
assert(not c.SafeSetCVar("missingCVar", 3), "unsupported CVar write allowed")
for _, key in ipairs({ "readOnly", "locked", "secure" }) do
    policy[key], combat = true, true; c.InvalidateCVarCaches()
    local before = writes
    assert(not c.SafeSetCVar("cameraZoomSpeed", 3) and writes == before)
    policy[key] = false
end
-- Secret arguments must never be passed to a CVar API.
-- The cached API reference is reloaded after installing the mock predicate.
local secret = {}
_G.issecretvalue = function(v) return v == secret end
assert(loadfile("Compat.lua"))("Max_Camera_Distance", ns)
local before = writes
assert(not ns.Compat.SafeSetCVar("cameraZoomSpeed", secret) and writes == before)
print("probe_cvar_policy: PASS (rejections, unsupported, read-only, secure, secret)")
