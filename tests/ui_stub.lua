-- Strict API contract stub for the native settings renderer. Unknown methods
-- error, unlike wow_stub's deliberately permissive initialization objects.
-- This models control state/callbacks, not WoW graphics, protection or taint.
local stub = { objects = {} }
local methods = {}
local function object(kind, name, parent, template)
    local o = { kind = kind, name = name, parent = parent, scripts = {}, shown = true,
        width = 100, height = 30, enabled = true, mouseEnabled = true, fontFamily = true, text = "", value = 0, level = 1, size = 13, scroll = 0 }
    stub.objects[#stub.objects + 1] = o
    return setmetatable(o, { __index = function(_, key)
        if key == "SetFontHeight" and stub.legacyFonts then return nil end
        if key:match("^SetBackdrop") and _G.BackdropTemplateMixin and template ~= "BackdropTemplate" then return nil end
        if methods[key] then return methods[key] end
        if tostring(key):match("^[A-Z]") then error("Unknown UI method " .. tostring(key) .. " on " .. kind) end
        return nil
    end })
end
local function call(o, script, ...) if o.scripts[script] then o.scripts[script](o, ...) end end
function methods:SetScript(key, fn) self.scripts[key] = fn end
function methods:GetScript(key) return self.scripts[key] end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetPoint(...) self.point = { ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:SetAllPoints() end
function methods:Show() local changed = not self.shown; self.shown = true; if changed then call(self, "OnShow") end end
function methods:Hide() local changed = self.shown; self.shown = false; if changed then call(self, "OnHide") end end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:SetText(value)
    self.text = tostring(value or "")
    call(self, "OnTextChanged", false)
end
function methods:GetText() return self.text end
function methods:SetFont(_, size) self.size = size; self.fontFamily = false end
function methods:SetFontHeight(size) self.size = size end
function methods:SetHighlightTexture(value) self.highlightTexture = value end
function methods:SetFontObject(value) self.fontObject = value; self.fontFamily = true end
function methods:EnableMouse(value) self.mouseEnabled = value end
function methods:GetTop() return self.testTop end
function methods:GetBottom() return self.testBottom end
function methods:SetHitRectInsets(...) self.hitInsets = { ... } end
function methods:GetFont() return "client-font.ttf", self.size, "" end
function methods:GetStringHeight()
    local text = self.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local lines = 0
    for part in (text .. "\n"):gmatch("(.-)\n") do
        lines = lines + math.max(1, math.ceil(#part * self.size * 0.6 / self.width))
    end
    return lines * self.size * 1.15
end
function methods:CreateFontString() return object("FontString", nil, self) end
function methods:CreateTexture() return object("Texture", nil, self) end
function methods:SetFrameLevel(value) self.level = value end
function methods:GetFrameLevel() return self.level end
function methods:SetScrollChild(child) self.child = child end
function methods:GetVerticalScrollRange() return math.max(0, self.child.height - self.height) end
function methods:SetVerticalScroll(value)
    value = math.max(0, math.min(self:GetVerticalScrollRange(), value))
    local changed = self.scroll ~= value
    self.scroll = value
    if changed then call(self, "OnVerticalScroll", value) end
end
function methods:GetVerticalScroll() return self.scroll end
function methods:SetMinMaxValues(lo, hi) self.lo, self.hi = lo, hi end
function methods:SetValue(value)
    value = math.max(self.lo or 0, math.min(self.hi or 100, value))
    local changed = self.value ~= value
    self.value = value
    if changed then call(self, "OnValueChanged", value) end
end
function methods:GetValue() return self.value end
function methods:SetValueStep(step) self.step = step end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = value end
function methods:IsEnabled() return self.enabled end
function methods:ClearFocus() self.focus = false end
function methods:HasFocus() return self.focus == true end
function methods:SetScale(value) self.scale = value end
function methods:RegisterEvent() end
-- These methods have no behavior needed by the test. They are explicit so a
-- misspelled/unsupported method can never silently turn into a no-op.
for _, name in ipairs({ "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetTextColor", "SetJustifyH",
    "SetJustifyV", "SetTextInsets", "SetAutoFocus", "SetMaxLetters",
    "EnableMouseWheel", "SetNormalTexture", "SetPushedTexture", "SetCheckedTexture",
    "SetOrientation", "SetThumbTexture", "SetObeyStepOnDrag", "SetAlpha", "SetColorTexture", "SetTexture",
    "SetMovable", "SetClampedToScreen", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetFrameStrata" }) do
    methods[name] = function() end
end
function stub.CreateFrame(kind, name, parent, template) return object(kind, name, parent, template) end
function stub.Click(o) if o.enabled then call(o, "OnClick") end end
function stub.Script(o, name, ...) return call(o, name, ...) end
return stub
