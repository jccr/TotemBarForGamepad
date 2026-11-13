-- Runs GamepadKit's real grid snippets against simulated secure frames.
FRAMES = {}
local Frame = {}
Frame.__index = function(t, k) return rawget(Frame, k) or function() end end
function CreateFrame(_, name, parent)
    local f = setmetatable({ name = name, attrs = {}, refs = {}, wraps = {}, bindings = {}, shown = false, parent = parent }, Frame)
    if name then FRAMES[name] = f end
    FRAMES_ALL[#FRAMES_ALL + 1] = f
    return f
end
function Frame:SetAttribute(k, v) self.attrs[k] = v end
-- As in the restricted environment, snippets can't read "_" attributes.
SNIPPET_DEPTH = 0
function Frame:GetAttribute(k)
    if SNIPPET_DEPTH > 0 and k:sub(1, 1) == "_" then return nil end
    return self.attrs[k]
end
function Frame:GetName() return self.name end
function Frame:GetFrameRef(label) return self.refs[label] end
function Frame:IsShown() return self.shown end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetPoint(_, target) self.anchor = target end
function Frame:CreateTexture() return setmetatable({ attrs = {}, refs = {}, wraps = {}, bindings = {} }, Frame) end
function Frame:SetScript(k, f) rawset(self, "scripts", rawget(self, "scripts") or {}); self.scripts[k] = f end
function Frame:HookScript(k, f)
    rawset(self, "scripts", rawget(self, "scripts") or {})
    local old = self.scripts[k]
    self.scripts[k] = old and function(...) old(...); f(...) end or f
end
function Frame:IsShown() return rawget(self, "shown") and true or false end
function Frame:GetName() return rawget(self, "name") end
function Frame:GetFrameLevel() return 1 end
function Frame:CreateFontString() return setmetatable({ attrs = {}, refs = {}, wraps = {}, bindings = {} }, getmetatable(self)) end
function Frame:GetStringWidth() return 100 end
function Frame:SetText(t) rawset(self, "text", t) end
local Anim = {}
Anim.__index = function(t, k) return rawget(Anim, k) or function() end end
function Anim:Play() self.playing = true end
function Anim:Stop() self.playing = false end
function Anim:CreateAnimation() return setmetatable({}, Anim) end
function Frame:CreateAnimationGroup() return setmetatable({}, Anim) end
-- As in the restricted environment: the named arguments, then "..." holds the rest.
local function Compile(body, args)
    local fn, err = load("return function(" .. args .. ", ...)\n" .. body .. "\nend")
    assert(fn, err)
    fn = fn()
    return function(...)
        SNIPPET_DEPTH = SNIPPET_DEPTH + 1
        local r = table.pack(pcall(fn, ...))
        SNIPPET_DEPTH = SNIPPET_DEPTH - 1
        assert(r[1], r[2])
        return table.unpack(r, 2, r.n)
    end
end
function Frame:RunAttribute(name, ...)
    assert(type(self.attrs[name]) == "string", "Invalid snippet body " .. name)
    return Compile(self.attrs[name], "self")(self, ...)
end
function Frame:CallMethod(name, ...) local m = rawget(self, name) if m then return m(self, ...) end end
function Frame:ClearBindings() self.bindings = {} end
function Frame:RegisterForClicks(...)
    self.clicks = {}
    for _, c in ipairs({ ... }) do self.clicks[c] = true end
end
function Frame:SetBindingClick(_, key, target) self.bindings[key] = target end
function SecureHandlerSetFrameRef(frame, label, ref) assert(ref, "nil ref " .. label); frame.refs[label] = ref end
function SecureHandlerWrapScript(frame, script, header, pre) frame.wraps[script] = { header = header, pre = pre } end
function SecureHandlerExecute(frame, body) Compile(body, "self")(frame) end
function ClearOverrideBindings(f) f.bindings = {} end
COMBAT = false
function InCombatLockdown() return COMBAT end
NOW = 0
function GetTime() return NOW end
-- Scripted gamepad: PAD = { buttons = { [name] = true }, lx = 0, ly = 0, rx = 0, ry = 0 }
PAD = { buttons = {}, lx = 0, ly = 0, rx = 0, ry = 0 }
local BUTTONS = { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6",
    "PADLSTICK", "PADRSTICK", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADLSTICKUP" }
local AXES = { "LStickX", "LStickY", "RStickX", "RStickY", "GStickX", "GStickY", "PStickX", "PStickY", "LTrigger", "RTrigger" }
C_GamePad = {
    GetActiveDeviceID = function() return 5 end,
    ButtonIndexToBinding = function(i) return BUTTONS[i + 1] end,
    AxisIndexToConfigName = function(i) return AXES[i + 1] end,
    GetDeviceMappedState = function()
        local b = {}
        for i, name in ipairs(BUTTONS) do b[i] = PAD.buttons[name] and true or false end
        return { buttons = b, axes = { PAD.lx, PAD.ly, PAD.rx, PAD.ry, 0, 0, 0, 0, 0, 0 } }
    end,
}
-- Advance the clock in 0.05s steps, running every OnUpdate script.
function Advance(seconds)
    local steps = math.floor(seconds / 0.05 + 0.5)
    for _ = 1, steps do
        NOW = NOW + 0.05
        for _, f in pairs(FRAMES_ALL) do
            local scripts = rawget(f, "scripts")
            if scripts and scripts.OnUpdate then scripts.OnUpdate(f, 0.05) end
        end
    end
end
FRAMES_ALL = {}
UIParent = CreateFrame("Frame", "UIParent")
C_Timer = { NewTicker = function() end, After = function() end }
GetBindingText = function(k) return k end

-- Clicks: a header runs _onclick; a wrapped target runs its pre-snippet and
-- then acts like a secure action button on the ActionButtonUseKeyDown edge.
KEYDOWN = true
ACTIONS = {}
function Click(frame, down)
    if frame.attrs._onclick then
        if not down then Compile(frame.attrs._onclick, "self, button, down")(frame, "LeftButton", down) end
        return
    end
    local clicks = rawget(frame, "clicks") or { AnyUp = true }
    if not (clicks.AnyDown and down or clicks.AnyUp and not down) then return end
    local wrap = frame.wraps.OnClick
    local result = Compile(wrap.pre, "self, button, down, control")(frame, "LeftButton", down, wrap.header)
    if result == false then return end
    if down == KEYDOWN and frame.attrs.type then
        local what = frame.attrs.type == "spell" and frame.attrs.spell or frame.attrs.macrotext
        ACTIONS[#ACTIONS + 1] = frame.attrs.type .. ":" .. tostring(what):gsub("\n", " / ")
    end
end
function Press(header, key)
    for _, down in ipairs({ true, false }) do
        local target = header.bindings[key]
        if target then Click(FRAMES[target], down) end
    end
end
