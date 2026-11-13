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
local nav = Kit.CreateFocusNavigator(window, { onClose = function() closed = closed + 1; window.shown = false; window.scripts.OnHide(window) end })
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
Pad("PAD1"); print("  A on plain clicked:", clicked[1])
Pad("PADDDOWN"); S("down -> secure item")
print("  A goes to:", BINDINGS.PAD1)
Proxy("PADDDOWN"); S("down via proxy -> close item")
Proxy = Proxy; Pad("PADDUP"); S("up -> secure item again")
Proxy("PADDUP"); S("up via proxy -> plain item")
Pad("PADDDOWN"); Proxy("PAD2"); S("secure item, B via proxy -> closed"); print("  closed:", closed)
