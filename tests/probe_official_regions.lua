-- Official support scope, region/build rollout and language independence.
local stub = dofile("tests/wow_stub.lua")
_G.CreateFrame = stub.CreateFrame
_G.GetCVar = function() return nil end
_G.GetCVarDefault = GetCVar
_G.WOW_PROJECT_MAINLINE = 1
local ns = {}
assert(loadfile("ClientSupport.lua"))("Max_Camera_Distance", ns)
local matrix = ns.ClientSupport
local locales = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "ptBR", "itIT", "ruRU", "koKR", "zhCN", "zhTW", "ukUA" }
local region, locale, currentVersion, currentInterface, currentBuild
_G.GetCurrentRegion = function() return matrix.region_ids[region] end
_G.GetCurrentRegionName = function() return region end
_G.GetLocale = function() return locale end
_G.GetBuildInfo = function() return currentVersion, tostring(currentBuild), "2026", currentInterface end
local count, declared = 0, 0
for _, product in ipairs(matrix.products) do
    for _, selectedRegion in ipairs(matrix.regions) do
        region = selectedRegion
        currentVersion, currentInterface, currentBuild = product.version, product.interface, product.builds[region] or 99999
        _G.WOW_PROJECT_ID = product.project
        local available = false
        for _, allowed in ipairs(product.regions) do if allowed == region then available = true end end
        for _, selectedLocale in ipairs(locales) do
            locale = selectedLocale
            local client = { ClientSupport = matrix }
            assert(loadfile("Compat.lua"))("Max_Camera_Distance", client)
            local c = client.Compat
            local info = c.GetRegionSupport()
            assert(info.product == product.key and info.region == region and info.locale == locale, "region/language misclassified the product")
            assert(info.regionListed == available, "incorrect regional availability")
            assert(info.status == (available and "official-live-interface" or "unlisted-region"), "incorrect support scope")
            assert(info.observedBuild == product.builds[region], "incorrect regional build snapshot")
            if product.key == "forever" then assert(c.IS_FOREVER and c.CONVERSION_RATIO == 15) end
            if product.key == "titan" then assert(c.IS_TITAN_REFORGED and not c.IS_RETAIL) end
            currentBuild = currentBuild + 1 -- regional hotfixes must not disable declared support
            assert(c.GetRegionSupport().status == info.status, "support depends on an exact hotfix build")
            count = count + 1
            if available then declared = declared + 1 end
        end
    end
end
assert(count == 390 and declared == 338, "official scope matrix unexpectedly changed")
-- Language is never a replacement for a missing region API.
region, locale = nil, "zhCN"
local unknown = { ClientSupport = matrix }
currentVersion, currentInterface, currentBuild = "12.1.5", 120105, 70783
_G.WOW_PROJECT_ID = 1
assert(loadfile("Compat.lua"))("Max_Camera_Distance", unknown)
assert(unknown.Compat.GetRegion() == "UNKNOWN")
assert(unknown.Compat.GetRegionSupport().status == "region-unknown", "locale guessed CN region")
-- Secret or unavailable region values remain unknown, without locale inference.
local secret = {}
_G.issecretvalue = function(value) return value == secret end
local regionGetter, nameGetter = GetCurrentRegion, GetCurrentRegionName
_G.GetCurrentRegion = function() return secret end
_G.GetCurrentRegionName = function() return secret end
local protected = { ClientSupport = matrix }
assert(loadfile("Compat.lua"))("Max_Camera_Distance", protected)
assert(protected.Compat.GetRegion() == "UNKNOWN")
_G.GetCurrentRegion = function() error("unavailable") end
_G.GetCurrentRegionName = function() error("unavailable") end
assert(protected.Compat.GetRegion() == "UNKNOWN")
_G.GetCurrentRegion, _G.GetCurrentRegionName, _G.issecretvalue = regionGetter, nameGetter, nil
region, locale = "CN", "enUS"
-- A regional Titan client may expose a generic 3.x version; interface identifies it.
currentVersion, currentInterface = "3.4.5", 38002
_G.WOW_PROJECT_ID = 11
assert(loadfile("Compat.lua"))("Max_Camera_Distance", unknown)
assert(unknown.Compat.IS_TITAN_REFORGED and unknown.Compat.CLIENT_TAG == "Titan Reforged")
assert(unknown.Compat.GetRegionSupport().product == "titan")
-- Archival Retail / old Wrath / Cata are not current official release targets.
for _, interface in ipairs({ 60200, 70300, 80300, 90207, 100207, 110200, 30405, 40402 }) do
    currentInterface = interface
    assert(loadfile("Compat.lua"))("Max_Camera_Distance", unknown)
    assert(unknown.Compat.GetRegionSupport().status == "unlisted-interface")
end
currentVersion, currentInterface, currentBuild = "12.1.7", 120107, 70999
_G.WOW_PROJECT_ID = 1
assert(loadfile("Compat.lua"))("Max_Camera_Distance", unknown)
assert(unknown.Compat.GetRegionSupport().status == "official-test-interface", "PTR was advertised as live")
assert(unknown.Compat.GetRegionSupport().observedBuild == nil, "PTR used a live build snapshot")
print("probe_official_regions: PASS (390 product/region/locale combinations, 338 declared, regional builds, CN Titan, no locale inference, PTR separation)")
