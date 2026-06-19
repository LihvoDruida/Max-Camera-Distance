-- Max Camera Distance compatibility layer for current and PTR clients.
-- This file is intentionally loaded before bundled libraries.
local addonName = ...
_G.MaxCameraDistanceCompat = _G.MaxCameraDistanceCompat or {}
local compat = _G.MaxCameraDistanceCompat
compat.version = "1.0.0"

-- Minimal LibStub fallback so source/no-lib zips can still load the bundled
-- LibCamera helper and the addon can gracefully degrade when Ace3 is not bundled.
if type(_G.LibStub) ~= "table" then
    local libs = {}
    local minors = {}
    local LibStub = {}

    function LibStub:NewLibrary(major, minor)
        if type(major) ~= "string" then return nil end
        minor = tonumber(minor) or 0
        local oldminor = minors[major]
        if oldminor and oldminor >= minor then
            return nil
        end
        minors[major] = minor
        libs[major] = libs[major] or {}
        return libs[major]
    end

    function LibStub:GetLibrary(major, silent)
        if libs[major] then
            return libs[major]
        end
        if not silent then
            error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
        end
        return nil
    end

    function LibStub:IterateLibraries()
        return pairs(libs)
    end

    setmetatable(LibStub, {
        __call = function(self, major, silent)
            return self:GetLibrary(major, silent)
        end,
    })

    _G.LibStub = LibStub
end

-- Older AceGUI builds call the old global SetDesaturation(texture, bool).
-- Some PTR/current clients only expose texture methods, so provide a harmless shim.
if type(_G.SetDesaturation) ~= "function" then
    _G.SetDesaturation = function(texture, desaturated)
        if not texture then return end
        if type(texture.SetDesaturated) == "function" then
            return texture:SetDesaturated(not not desaturated)
        end
        if type(texture.SetDesaturation) == "function" then
            return texture:SetDesaturation(desaturated and 1 or 0)
        end
    end
end

-- Retail/PTR replacement compatibility for addons/libs still using GetMouseFocus.
if type(_G.GetMouseFocus) ~= "function" and type(_G.GetMouseFoci) == "function" then
    _G.GetMouseFocus = function()
        local focus = _G.GetMouseFoci()
        if type(focus) == "table" then
            return focus[1]
        end
        return focus
    end
end

compat.loaded = true
