-- FocusNav item neighbors (the gamepad macros dialog): Left/Right along a row
-- of five, Up/Down to Done and back, the ends of the row stay put.
local Kit = NS.GamepadKit
Kit.IsGamepadActive = function() return true end
Kit.AtlasExists = function() return false end
Kit.Prompt = function(k, label) return "[" .. k .. "]" .. label end
Kit.Glyph = function(k) return "[" .. k .. "]" end
Kit.RegisterGamepadEvents = function() end
BINDINGS = {}
function SetOverrideBindingClick(_, _, key, target) BINDINGS[key] = target end
function ClearOverrideBindings() BINDINGS = {} end
local window = CreateFrame("Frame", "MacroWin")
function window:EnableGamePadButton(on) self.capturing = on end
local nav = Kit.CreateFocusNavigator(window, { bindingsOnly = true, onClose = function() end })
local count = 5
for index = 1, count do
    nav:AddItem({ kind = "button", anchor = CreateFrame("Button", "Icon" .. index), control = CreateFrame("Button"),
        neighbors = { PADDLEFT = index > 1 and index - 1 or nil, PADDRIGHT = index < count and index + 1 or nil,
            PADDUP = count + 1, PADDDOWN = count + 1 } })
end
nav:AddItem({ kind = "close", anchor = CreateFrame("Button", "DoneBtn"), neighbors = { PADDUP = 1, PADDDOWN = 1 } })
local function Proxy(key) local name = BINDINGS[key]; FRAMES[name].scripts.OnClick(FRAMES[name], "LeftButton", true) end
local function Expect(label, want)
    local ok = nav.index == want
    print((ok and "ok   " or "FAIL ") .. label .. ": focus " .. nav.index .. (ok and "" or (" (expected " .. want .. ")")))
end
nav:SetStartItem(3)
window.shown = true; window.scripts.OnShow(window); Expect("opens on the start item", 3)
Proxy("PADDRIGHT"); Expect("right", 4)
Proxy("PADDRIGHT"); Proxy("PADDRIGHT"); Expect("right stops at the end", 5)
Proxy("PADDLEFT"); Proxy("PADDLEFT"); Proxy("PADDLEFT"); Proxy("PADDLEFT"); Proxy("PADDLEFT"); Expect("left stops at the start", 1)
Proxy("PADDDOWN"); Expect("down to Done", 6)
Proxy("PADDUP"); Expect("up from Done to the first", 1)
Proxy("PADDUP"); Expect("up from a macro to Done", 6)
