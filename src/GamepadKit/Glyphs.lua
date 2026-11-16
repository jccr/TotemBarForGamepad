-- ---------------------------------------------------------------------------
-- GamepadKit: gamepad button glyphs
-- ---------------------------------------------------------------------------
-- Kit.Glyph(key, size, fallback)         Blizzard's monochrome button art for the
--                                         connected gamepad's label style (Xbox
--                                         art for generic gamepads)
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

-- Blizzard's prompt art for each label style, from its own prompt table
-- (InputIconTexture.lua; note Blizzard's "Crox" spelling, and Nintendo's
-- swapped layout: PAD1 is the bottom button, labeled B; PAD3 is labeled Y
-- and PAD4 X). Keys are binding names (GamepadConstants.lua).
local NATIVE_GLYPHS = {
    Ltr = { -- Xbox
        PAD1 = "gamepad-xbox1-buttona-normal",
        PAD2 = "gamepad-xbox1-buttonb-normal",
        PAD3 = "gamepad-xbox1-buttonx-normal",
        PAD4 = "gamepad-xbox1-buttony-normal",
        PADDUP = "gamepad-xbox1-dpadup-normal",
        PADDDOWN = "gamepad-xbox1-dpaddown-normal",
        PADDLEFT = "gamepad-xbox1-dpadleft-normal",
        PADDRIGHT = "gamepad-xbox1-dpadright-normal",
        PADLSHOULDER = "gamepad-xbox1-trigger-lb-normal",
        PADRSHOULDER = "gamepad-xbox1-trigger-rb-normal",
        PADLTRIGGER = "gamepad-xbox1-trigger-lt-normal",
        PADRTRIGGER = "gamepad-xbox1-trigger-rt-normal",
        PADLSTICK = "gamepad-xbox1-stick-l3-normal",
        PADRSTICK = "gamepad-xbox1-stick-r3-normal",
        PADBACK = "gamepad-xbox1-view-normal",
        PADFORWARD = "gamepad-xbox1-menu-normal",
    },
    Shp = { -- PlayStation
        PAD1 = "gamepad-ps-buttoncrox-normal",
        PAD2 = "gamepad-ps-buttoncircle-normal",
        PAD3 = "gamepad-ps-buttonsquare-normal",
        PAD4 = "gamepad-ps-buttontriangle-normal",
        PADDUP = "gamepad-ps-dpadup-normal",
        PADDDOWN = "gamepad-ps-dpaddown-normal",
        PADDLEFT = "gamepad-ps-dpadleft-normal",
        PADDRIGHT = "gamepad-ps-dpadright-normal",
        PADLSHOULDER = "gamepad-ps-triggerl1-normal",
        PADRSHOULDER = "gamepad-ps-triggerr1-normal",
        PADLTRIGGER = "gamepad-ps-triggerl2-normal",
        PADRTRIGGER = "gamepad-ps-triggerr2-normal",
        PADLSTICK = "gamepad-ps-stickl3-normal",
        PADRSTICK = "gamepad-ps-stickr3-normal",
        PADBACK = "gamepad-ps-touchpad-normal",
        PADFORWARD = "gamepad-ps-menu-normal",
    },
    Rev = { -- Nintendo
        PAD1 = "gamepad-switch-128x-face-b-normal",
        PAD2 = "gamepad-switch-128x-face-a-normal",
        PAD3 = "gamepad-switch-128x-face-y-normal",
        PAD4 = "gamepad-switch-128x-face-x-normal",
        PADDUP = "gamepad-switch-128x-dpad-up-normal",
        PADDDOWN = "gamepad-switch-128x-dpad-down-normal",
        PADDLEFT = "gamepad-switch-128x-dpad-left-normal",
        PADDRIGHT = "gamepad-switch-128x-dpad-right-normal",
        PADLSHOULDER = "gamepad-switch-128x-shoulder-l-normal",
        PADRSHOULDER = "gamepad-switch-128x-shoulder-r-normal",
        PADLTRIGGER = "gamepad-switch-128x-zl-normal",
        PADRTRIGGER = "gamepad-switch-128x-zr-normal",
        PADLSTICK = "gamepad-switch-128x-stick-l3-normal",
        PADRSTICK = "gamepad-switch-128x-stick-r3-normal",
        PADBACK = "gamepad-switch-128x-minus-normal",
        PADFORWARD = "gamepad-switch-128x-plus-normal",
    },
}

-- The binding glyphs carry the label style in their name: Gamepad_Ltr_ (Xbox),
-- Gamepad_Shp_ (PlayStation), Gamepad_Rev_ (Nintendo), Gamepad_Gen_ (generic).
function Kit.LabelFamily()
    local ok, text = pcall(GetBindingText, "PAD1")
    if not ok or type(text) ~= "string" or Kit.IsSecret(text) then return nil end
    return text:match("Gamepad_(%a+)_")
end

-- Generic gamepads (Steam Input, for one) get the Xbox art, as in Blizzard's
-- own prompts (InputIconTexture.lua gives "Generic" the "Letters" textures).
NATIVE_GLYPHS.Gen = NATIVE_GLYPHS.Ltr

function Kit.Glyph(key, size, fallback)
    local family = NATIVE_GLYPHS[Kit.LabelFamily() or ""]
    local atlas = family and family[key]
    if atlas and Kit.AtlasExists(atlas) then
        return string.format("|A:%s:%d:%d|a", atlas, size, size)
    end
    -- No label style, or art not found: the binding glyphs.
    return Kit.BindingGlyph(key, size, fallback)
end

function Kit.Prompt(key, label, size, fallback)
    return Kit.Glyph(key, size, fallback) .. " " .. label
end
