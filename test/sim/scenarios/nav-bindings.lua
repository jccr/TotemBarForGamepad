local Kit = NS.GamepadKit
Kit.IsGamepadActive = function() return true end
Kit.AtlasExists = function() return false end
Kit.Prompt = function(k, label) return "[" .. k .. "]" .. label end
Kit.Glyph = function(k) return "[" .. k .. "]" end
Kit.RegisterGamepadEvents = function() end
BINDINGS = {}
function SetOverrideBindingClick(owner, _, key, target) BINDINGS[key] = target end
function ClearOverrideBindings() BINDINGS = {} end
local window = CreateFrame("Frame", "Win")
function window:EnableGamePadButton(on) self.capturing = on end
local clicked = {}
local plain = CreateFrame("Button", "Plain"); function plain:Click() clicked[#clicked + 1] = "plain" end
local secure = CreateFrame("Button", "SecureEditMode")
local done = CreateFrame("Button", "Done")
local closed = 0
local nav = Kit.CreateFocusNavigator(window, { bindingsOnly = true, passWhileHeld = { hold = { "PADLSHOULDER", "PADRSHOULDER" }, keys = { "PADDLEFT", "PADDRIGHT" } }, onClose = function() closed = closed + 1; window.shown = false; window.scripts.OnHide(window) end })
nav:AddItem({ kind = "button", anchor = plain, control = plain })
nav:AddItem({ kind = "button", anchor = secure, secureButton = "SecureEditMode" })
nav:AddItem({ kind = "close", anchor = done })
local function S(label)
    local keys = {} for k, v in pairs(BINDINGS) do keys[#keys + 1] = k .. ">" .. v end table.sort(keys)
    print(string.format("%-32s focus=%d capture=%-5s bindings=%s", label, nav.index, tostring(window.capturing), table.concat(keys, " ")))
end
local function Pad(key) window.scripts.OnGamePadButtonDown(window, key) end
local function Proxy(key) local name = BINDINGS[key]; FRAMES[name].scripts.OnClick(FRAMES[name], "LeftButton", true) end
window.shown = true; window.scripts.OnShow(window); S("open (plain item)")
print("  LB/RB/LT/RT bound by the guide?", BINDINGS.PADLSHOULDER, BINDINGS.PADRSHOULDER, BINDINGS.PADLTRIGGER, BINDINGS.PADRTRIGGER)
local function DL() return tostring(BINDINGS.PADDLEFT ~= nil) .. "/" .. tostring(BINDINGS.PADDRIGHT ~= nil) end
print("  D-pad L/R bound (nothing held):", DL())
PAD.buttons.PADLSHOULDER = true; Advance(0.1); print("  LB only held -> L/R bound:", DL())
PAD.buttons.PADRSHOULDER = true; Advance(0.1); print("  LB+RB held   -> L/R bound:", DL(), "| Up/A still bound:", BINDINGS.PADDUP ~= nil, BINDINGS.PAD1 ~= nil)
PAD.buttons.PADLSHOULDER = nil; PAD.buttons.PADRSHOULDER = nil; Advance(0.1); print("  released     -> L/R bound:", DL())
Proxy("PAD1"); print("  A via proxy on plain clicked:", clicked[1])
Proxy("PADDDOWN"); S("down -> secure item"); print("  A goes to:", BINDINGS.PAD1)
Proxy("PADDDOWN"); S("down -> close item")
Proxy("PAD1"); S("A on close -> closed"); print("  closed:", closed)
