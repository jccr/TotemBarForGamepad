-- ---------------------------------------------------------------------------
-- GamepadKit: gamepad button glyphs
-- ---------------------------------------------------------------------------
-- Kit.Glyph(key, size, fallback)         Blizzard's monochrome button art for the
--                                         connected gamepad's label style
-- Kit.BindingGlyph(key, size, fallback)  the client's (colored) binding glyph
-- Kit.LabelFamily()                      "Ltr" (Xbox), "Shp" (PlayStation),
--                                         "Rev" (Nintendo), "Gen" (generic) or nil
-- Kit.Prompt(key, label, size, fallback) glyph followed by a label
-- Keys are binding names: PAD1..PAD4, PADDLEFT, PADDRIGHT, ...
local _, ns = ...
local Kit = ns.GamepadKit

-- The client's key-binding glyphs: always the right buttons, but colored.
function Kit.BindingGlyph(key, size, fallback)
    local ok, text = pcall(GetBindingText, key)
    if ok and type(text) == "string" and not Kit.IsSecret(text) and text:find("|A:") then
        return (text:gsub(":24:24", ":" .. size .. ":" .. size))
    end
    return fallback
end

-- Names were read off Blizzard's own Game Menu footer under each label style
-- (note Blizzard's "Crox" spelling, and Nintendo's swapped layout: PAD1 is the
-- bottom button, labeled B; PAD3 is labeled Y and PAD4 X). D-pad names are
-- tried in order.
local NATIVE_GLYPHS = {
    Ltr = { -- Xbox
        PAD1 = { "Gamepad-Xbox1-ButtonA-Normal" },
        PAD2 = { "Gamepad-Xbox1-ButtonB-Normal" },
        PAD3 = { "Gamepad-Xbox1-ButtonX-Normal" },
        PAD4 = { "Gamepad-Xbox1-ButtonY-Normal" },
        PADDLEFT = { "Gamepad-Xbox1-DPadLeft-Normal" },
        PADDRIGHT = { "Gamepad-Xbox1-DPadRight-Normal" },
    },
    Shp = { -- PlayStation
        PAD1 = { "Gamepad-PS-ButtonCrox-Normal" },
        PAD2 = { "Gamepad-PS-ButtonCircle-Normal" },
        PAD3 = { "Gamepad-PS-ButtonSquare-Normal" },
        PAD4 = { "Gamepad-PS-ButtonTriangle-Normal" },
        PADDLEFT = { "Gamepad-PS-DPadLeft-Normal" },
        PADDRIGHT = { "Gamepad-PS-DPadRight-Normal" },
    },
    Rev = { -- Nintendo
        PAD1 = { "gamepad-switch-128x-face-b-normal" },
        PAD2 = { "gamepad-switch-128x-face-a-normal" },
        PAD3 = { "gamepad-switch-128x-face-y-normal" },
        PAD4 = { "gamepad-switch-128x-face-x-normal" },
        PADDLEFT = { "gamepad-switch-128x-dpad-left-normal", "gamepad-switch-128x-left-normal" },
        PADDRIGHT = { "gamepad-switch-128x-dpad-right-normal", "gamepad-switch-128x-right-normal" },
    },
}

-- The binding glyphs carry the label style in their name: Gamepad_Ltr_ (Xbox),
-- Gamepad_Shp_ (PlayStation), Gamepad_Rev_ (Nintendo), Gamepad_Gen_ (generic).
function Kit.LabelFamily()
    local ok, text = pcall(GetBindingText, "PAD1")
    if not ok or type(text) ~= "string" or Kit.IsSecret(text) then return nil end
    return text:match("Gamepad_(%a+)_")
end

function Kit.Glyph(key, size, fallback)
    local family = NATIVE_GLYPHS[Kit.LabelFamily() or ""]
    for _, atlas in ipairs(family and family[key] or {}) do
        if Kit.AtlasExists(atlas) then
            return string.format("|A:%s:%d:%d|a", atlas, size, size)
        end
    end
    -- Generic gamepads, or art not found: the binding glyphs.
    return Kit.BindingGlyph(key, size, fallback)
end

function Kit.Prompt(key, label, size, fallback)
    return Kit.Glyph(key, size, fallback) .. " " .. label
end
