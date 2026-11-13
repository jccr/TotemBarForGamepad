local Kit = NS.GamepadKit
Kit.AtlasExists = function() return false end
Kit.Prompt = function(k, label) return "[" .. k .. "]" .. label end
Kit.Glyph = function(k) return "[" .. k .. "]" end
local KEYS = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1" }
function GetBindingKey(cmd)
    if cmd == "GAMEPADLEFTMOD" then return "PADLTRIGGER" elseif cmd == "GAMEPADRIGHTMOD" then return "PADRTRIGGER" end
    local i = tonumber(cmd:match("GAMEPADACTIONBUTTON(%d)")); return i and KEYS[i]
end
local function Bar(base, reservedFace)
    local bar = { buttons = {} }
    for i = 1, 8 do bar.buttons[i] = { CalculateAction = function() return (reservedFace and i >= 5) and 0 or base + i end } end
    function bar:GetActionButtonByIndex(i) return self.buttons[i] end
    return bar
end
GamepadMainActionBarFrame = { PageUnit = { actionBars = { topBar = Bar(0, true), leftBar = Bar(184), rightBar = Bar(192), bottomBar = Bar(200) } } }
ERRORS = {}
UIErrorsFrame = { AddMessage = function(_, m) ERRORS[#ERRORS + 1] = m end }
RED_FONT_COLOR = { GetRGB = function() return 1, 0, 0 end }
GAMEPAD_BIND_FAILURE_INVALID_STANDARD_SLOT = "invalid slot"
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
BINDINGS = {}
function SetOverrideBindingClick(owner, _, key, target) BINDINGS[key] = target end
function ClearOverrideBindings() BINDINGS = {} end
local prompt = Kit.CreateBindPrompt("BP")
local f = prompt.frame
function f:EnableGamePadButton(on) self.capturing = on end
rawset(f, "ActionName", CreateFrame("Frame")); rawset(f, "ActionIcon", CreateFrame("Frame"))
local result
local function Open() result = nil; prompt:Open({ label = "TBG Focus", icon = 1, onBind = function(slot, combo) result = "bound " .. slot .. " via " .. combo end, onCancel = function() result = "cancelled" end }) end
local function Press(key) local name = BINDINGS[key]; if name then FRAMES[name].scripts.OnClick(FRAMES[name], "LeftButton", true) else print("  (" .. key .. " not bound: goes to the game)") end end
local function Try(label, mods, key)
    Open(); for _, m in ipairs(mods) do PAD.buttons[m] = true end
    Advance(0.05); Press(key)
    for _, m in ipairs(mods) do PAD.buttons[m] = nil end
    print(string.format("%-18s -> %-34s open=%s errors=%s", label, tostring(result), tostring(prompt:IsOpen()), table.concat(ERRORS, ",")))
    ERRORS = {}; if prompt:IsOpen() then prompt:Close(true) end
end
Try("LT + A", { "PADLTRIGGER" }, "PAD1")
Try("RT + D-pad Up", { "PADRTRIGGER" }, "PADDUP")
Try("LT + RT + X", { "PADLTRIGGER", "PADRTRIGGER" }, "PAD3")
Try("LT + B", { "PADLTRIGGER" }, "PAD2")
Try("D-pad Left alone", {}, "PADDLEFT")
Try("A alone (reserved)", {}, "PAD1")
Try("B alone = Back", {}, "PAD2")
Try("LB (not bound)", {}, "PADLSHOULDER")
Open(); print("  bound keys:", (function() local k = {} for key in pairs(BINDINGS) do k[#k + 1] = key end table.sort(k) return table.concat(k, " ") end)())
PAD.buttons.PADLSHOULDER = true; PAD.buttons.PADRSHOULDER = true; Advance(0.05)
print("  LB+RB held: D-pad L/R bound?", BINDINGS.PADDLEFT ~= nil, BINDINGS.PADDRIGHT ~= nil, "| A/Up bound?", BINDINGS.PAD1 ~= nil, BINDINGS.PADDUP ~= nil)
PAD.buttons.PADLSHOULDER = nil; PAD.buttons.PADRSHOULDER = nil; Advance(0.05)
print("  released: D-pad L/R bound?", BINDINGS.PADDLEFT ~= nil, BINDINGS.PADDRIGHT ~= nil)
prompt:Close(true); print("  closed: bindings left:", next(BINDINGS) ~= nil)
