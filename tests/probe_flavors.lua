-- PROBE: client identity and API-family separation.
-- Forever must stay its own flavor while still using the modern API family;
-- Retail and Classic branches must not inherit Forever-only product behavior.

local failures = 0
local function check(label, ok, detail)
    if ok then
        print("  ok   " .. label)
    else
        failures = failures + 1
        print("  FAIL " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
    end
end

_G.WOW_PROJECT_MAINLINE = 1
_G.GetCVar = function() return nil end
_G.GetCVarDefault = function() return nil end
_G.SetCVar = function() return true end
_G.ReloadUI = function() end
_G.GetAddOnMetadata = function() return nil end
_G.C_CVar = nil
_G.C_UI = nil
_G.C_AddOns = nil
_G.InCombatLockdown = function() return false end

local function loadCase(name, version, build, interface, projectId, marker)
    _G.WOW_PROJECT_ID = projectId
    _G.GetBuildInfo = function() return version, tostring(build), "Sep 20 2026", interface end
    local ns = marker and { ClientFlavor = { FOREVER = true, SOURCE = "Camelot TOC" } } or {}
    local chunk, err = loadfile("Compat.lua")
    if not chunk then error(err) end
    local ok, loadErr = pcall(chunk, "Max_Camera_Distance", ns)
    if not ok then error(name .. ": " .. tostring(loadErr)) end
    return ns.Compat
end

print("PROBE flavor matrix")

local forever = loadCase("Forever", "1.60.1", 69913, 16001, 1, true)
check("Forever: separate product identity", forever.IS_FOREVER and not forever.IS_RETAIL and not forever.IS_CLASSIC,
    forever.CLIENT_TAG)
check("Forever: modern API family without Retail identity", forever.USES_MODERN_API and forever.CLIENT_TAG == "Forever")
check("Forever: modern camera cap", forever.MAX_CAMERA_YARDS == 39 and forever.CONVERSION_RATIO == 15,
    tostring(forever.MAX_CAMERA_YARDS) .. "/" .. tostring(forever.CONVERSION_RATIO))

local foreverFallback = loadCase("Forever fallback", "1.60.1", 69913, 16001, 1, false)
check("Forever: version/interface fallback remains available", foreverFallback.IS_FOREVER == true)

local retail = loadCase("Retail", "12.1.5", 70000, 120105, 1, false)
check("Retail: remains Retail", retail.IS_RETAIL and not retail.IS_FOREVER and retail.USES_MODERN_API,
    retail.CLIENT_TAG)
check("Retail: 12.1+ flag remains Retail-only", retail.IS_12_1_OR_LATER == true)

local era = loadCase("Classic Era", "1.15.9", 69722, 11509, 2, false)
check("Classic Era: remains classic, not Forever", era.IS_CLASSIC_ERA and era.IS_CLASSIC and not era.IS_FOREVER and not era.USES_MODERN_API,
    era.CLIENT_TAG)
check("Classic Era: classic camera model remains unchanged", era.MAX_CAMERA_YARDS == 50 and era.CONVERSION_RATIO == 12.5,
    tostring(era.MAX_CAMERA_YARDS) .. "/" .. tostring(era.CONVERSION_RATIO))

local mists = loadCase("Mists", "5.5.4", 70000, 50504, 5, false)
check("Mists: remains Classic-family", mists.IS_MOP_CLASSIC and mists.IS_CLASSIC and not mists.IS_FOREVER,
    mists.CLIENT_TAG)

print(failures == 0 and "PROBE PASSED" or ("PROBE FAILED (" .. failures .. ")"))
os.exit(failures == 0 and 0 or 1)
