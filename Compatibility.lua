-- Max Camera Distance compatibility layer for current and PTR clients.
-- This file is intentionally loaded before bundled libraries.
local addonName = ...
_G.MaxCameraDistanceCompat = _G.MaxCameraDistanceCompat or {}
local compat = _G.MaxCameraDistanceCompat
compat.version = "1.2.0"

-- Minimal LibStub v2-compatible fallback for no-lib/source packages.
--
-- IMPORTANT: this must have the same public fields as upstream LibStub. The old
-- fallback kept libs/minors in closure-only tables and did not expose `.minor`;
-- when the bundled LibStub.lua loaded immediately afterwards it evaluated
-- `LibStub.minor < 2` and could error on a clean client where no other addon had
-- already provided LibStub. Keeping the v2 surface here makes both packaged and
-- no-lib builds deterministic.
if type(_G.LibStub) ~= "table" then
    local LibStub = { libs = {}, minors = {}, minor = 2 }

    function LibStub:NewLibrary(major, minor)
        assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
        local parsedMinor = tonumber(tostring(minor):match("%d+"))
        assert(parsedMinor, "Minor version must either be a number or contain a number.")

        local oldminor = self.minors[major]
        if oldminor and oldminor >= parsedMinor then
            return nil
        end

        self.minors[major] = parsedMinor
        self.libs[major] = self.libs[major] or {}
        return self.libs[major], oldminor
    end

    function LibStub:GetLibrary(major, silent)
        if not self.libs[major] and not silent then
            error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
        end
        return self.libs[major], self.minors[major]
    end

    function LibStub:IterateLibraries()
        return pairs(self.libs)
    end

    setmetatable(LibStub, { __call = LibStub.GetLibrary })
    _G.LibStub = LibStub
end

-- No global FrameXML compatibility shims are installed here. The bundled code
-- does not reference the removed getglobal/setglobal/GetMouseFocus/CanAccessObject
-- helpers, so defining replacements globally would only widen the taint/conflict
-- surface for other addons. Compatibility is kept local to the APIs we actually
-- consume.

compat.loaded = true
