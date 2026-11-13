-- ---------------------------------------------------------------------------
-- GamepadKit: native action buttons and flyouts
-- ---------------------------------------------------------------------------
-- local AB = Kit.ActionButtons
-- AB.Create(name, parent, opts)      secure button (SecureActionButtonTemplate)
--                                     with Blizzard's action button art; fields:
--                                     icon, cooldown, hotkeyText, timerText, Arrow
--     opts.size            button size (default AB.SIZE, 45)
--     opts.art             { normal = atlas, pushed = atlas } drawn at button size
--     opts.followActiveUI  false: keep this art even while the gamepad UI is active
-- AB.RefreshStyles(force)            standard art, or the gamepad bar's art while
--                                     the gamepad UI is active (checked every
--                                     second automatically once a button exists)
-- AB.SetFlyoutArrow(button, dir, show)   dir: "UP" | "DOWN" | "RIGHT"
-- AB.AddFlyoutBackground(frame)      Blizzard's spell flyout background
-- AB.LayoutFlyout(frame, anchor, dir, count, choices)
--                                     sizes/anchors the flyout and places choice
--                                     buttons (created with AB.Create and scaled
--                                     to AB.CHOICE_SCALE)
--
-- ActionButtonTemplate is art only (the action bar logic lives in
-- ActionBarButtonTemplate), so it sits safely on top of a secure button.
-- Atlas names were read from Blizzard's own buttons on the Forever client.
local _, ns = ...
local Kit = ns.GamepadKit
local AB = {}
Kit.ActionButtons = AB

AB.SIZE, AB.GAP = 45, 6
-- Flyout choices are action buttons at 0.8 scale (36px), 4px apart.
AB.CHOICE_SCALE, AB.CHOICE_STEP = 0.8, 40
local FLYOUT_WIDTH, FLYOUT_PAD_START, FLYOUT_PAD_END = 47, 6, 10

local GAMEPAD_BUTTON_ART = {
    normal = "gamepad-actionbar-squareslot-border-normal",
    pushed = "gamepad-actionbar-squareslot-border-pressed",
    highlight = "gamepad-actionbar-squareslot-border-hover",
    mask = "SquareMask", maskInset = 26 / 32,
    shadow = "gamepad-actionbar-squareslot-dropshadow", shadowScale = 40 / 32,
}

local buttons = {}
local gamepadStyle
local styleTicker

local function CaptureArt(texture)
    if not texture then return nil end
    local w, h = texture:GetSize()
    return { atlas = texture:GetAtlas(), w = w, h = h }
end

local function SetArt(texture, atlas, w, h)
    if not (texture and atlas) then return end
    texture:SetAtlas(atlas)
    texture:SetSize(w, h)
end

-- Texture swaps only, so restyling is allowed in combat.
local function ApplyStyle(button, gamepad)
    local standard = button.kitStandardArt
    if not standard then return end
    local size = button.kitSize or AB.SIZE
    local normal, pushed, highlight = button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()
    if gamepad then
        SetArt(normal, GAMEPAD_BUTTON_ART.normal, size, size)
        SetArt(pushed, GAMEPAD_BUTTON_ART.pushed, size, size)
        SetArt(highlight, GAMEPAD_BUTTON_ART.highlight, size, size)
    else
        local function Restore(texture, art)
            if art then SetArt(texture, art.atlas, art.w, art.h) end
        end
        Restore(normal, standard.normal)
        Restore(pushed, standard.pushed)
        Restore(highlight, standard.highlight)
    end
    local mask = button.IconMask
    if mask and standard.mask then
        mask:ClearAllPoints()
        if gamepad then
            mask:SetAtlas(GAMEPAD_BUTTON_ART.mask)
            mask:SetPoint("CENTER", button.icon, "CENTER")
            mask:SetSize(size * GAMEPAD_BUTTON_ART.maskInset, size * GAMEPAD_BUTTON_ART.maskInset)
        else
            mask:SetAtlas(standard.mask)
            mask:SetAllPoints(button.icon)
        end
    end
    if button.kitShadow then button.kitShadow:SetShown(gamepad) end
    if button.SlotArt then button.SlotArt:SetShown(not gamepad) end
end

function AB.RefreshStyles(force)
    local gamepad = Kit.UsingGamepadBar()
    if gamepad == gamepadStyle and not force then return end
    gamepadStyle = gamepad
    for _, button in ipairs(buttons) do ApplyStyle(button, gamepad) end
end

function AB.IsGamepadStyle()
    return gamepadStyle and true or false
end

function AB.Create(name, parent, opts)
    opts = opts or {}
    local size = opts.size or AB.SIZE
    -- SecureActionButtonTemplate goes last: a later template's scripts win, and
    -- ActionButtonTemplate (through FlyoutButtonTemplate) has its own OnClick,
    -- which would replace the secure one and leave mouse clicks doing nothing.
    local ok, button = pcall(CreateFrame, "CheckButton", name, parent, "ActionButtonTemplate, SecureActionButtonTemplate")
    if not (ok and button) then
        button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    end
    button:SetSize(size, size)
    button.kitSize = size

    button.icon = button.icon or (name and _G[name .. "Icon"])
    if not button.icon then
        button.icon = button:CreateTexture(nil, "BACKGROUND")
        button.icon:SetAllPoints()
    end
    button.cooldown = button.cooldown or (name and _G[name .. "Cooldown"])
    if not button.cooldown then
        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints()
    end
    -- Native hotkey text (NumberFontNormalSmallGray, top right).
    button.hotkeyText = button.HotKey or (name and _G[name .. "HotKey"])
    if not button.hotkeyText then
        button.hotkeyText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
        button.hotkeyText:SetPoint("TOPRIGHT", -2, -2)
    end
    -- Countdown in the native cooldown font, above the swipe.
    local textParent = button.TextOverlayContainer or button.cooldown
    button.timerText = textParent:CreateFontString(nil, "OVERLAY",
        _G.SystemFont_Shadow_Large_Outline and "SystemFont_Shadow_Large_Outline" or "GameFontHighlight")
    button.timerText:SetPoint("CENTER", button, "CENTER", 0, 0)

    -- A clicked CheckButton toggles "checked"; these buttons never show it.
    -- (Hidden rather than reset: SetChecked may be blocked in combat.)
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then checked:SetAlpha(0) end

    button.kitShadow = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    button.kitShadow:SetAtlas(GAMEPAD_BUTTON_ART.shadow)
    button.kitShadow:SetPoint("CENTER")
    button.kitShadow:SetSize(size * GAMEPAD_BUTTON_ART.shadowScale, size * GAMEPAD_BUTTON_ART.shadowScale)
    button.kitShadow:Hide()

    if opts.art then
        SetArt(button:GetNormalTexture(), opts.art.normal, size, size)
        SetArt(button:GetPushedTexture(), opts.art.pushed, size, size)
        local highlight = button:GetHighlightTexture()
        if highlight then highlight:SetSize(size, size) end
    end
    -- The template insets its cooldown swipe 3px at 45px; keep that ratio.
    if size ~= AB.SIZE and button.cooldown then
        local inset = math.floor(3 * size / AB.SIZE + 0.5)
        button.cooldown:ClearAllPoints()
        button.cooldown:SetPoint("TOPLEFT", inset, -inset)
        button.cooldown:SetPoint("BOTTOMRIGHT", -inset, inset)
    end

    button.kitStandardArt = {
        normal = CaptureArt(button:GetNormalTexture()),
        pushed = CaptureArt(button:GetPushedTexture()),
        highlight = CaptureArt(button:GetHighlightTexture()),
        mask = button.IconMask and button.IconMask:GetAtlas() or nil,
    }
    if opts.followActiveUI == false then return button end
    buttons[#buttons + 1] = button
    ApplyStyle(button, gamepadStyle)

    -- Follow the active UI: the gamepad bar can be switched at any time.
    if not styleTicker and C_Timer and C_Timer.NewTicker then
        styleTicker = C_Timer.NewTicker(1, function() AB.RefreshStyles() end)
    end
    return button
end

-- The native flyout arrow (art points up), placed on the flyout's side.
function AB.SetFlyoutArrow(button, direction, show)
    local arrow = button.Arrow
    if not arrow then return end
    arrow:ClearAllPoints()
    if not show then
        arrow:Hide()
        return
    end
    if direction == "RIGHT" then
        arrow:SetPoint("CENTER", button, "RIGHT", -1, 0)
        arrow:SetRotation(-math.pi / 2)
    elseif direction == "DOWN" then
        arrow:SetPoint("CENTER", button, "BOTTOM", 0, 1)
        arrow:SetRotation(math.pi)
    else
        arrow:SetPoint("CENTER", button, "TOP", 0, -1)
        arrow:SetRotation(0)
    end
    arrow:Show()
end

-- Blizzard's spell flyout background: start piece by the button, a tiled
-- middle, and the end cap. Art is drawn upward; other directions rotate it.
function AB.AddFlyoutBackground(flyout)
    local function Piece(atlas)
        local texture = flyout:CreateTexture(nil, "BACKGROUND")
        texture:SetAtlas(atlas)
        return texture
    end
    flyout.kitBackground = {
        start = Piece("UI-HUD-ActionBar-IconFrame-FlyoutBottom"),
        finish = Piece("UI-HUD-ActionBar-IconFrame-FlyoutButton"),
        vertical = Piece("!UI-HUD-ActionBar-IconFrame-FlyoutMid"),
        horizontal = Piece("_UI-HUD-ActionBar-IconFrame-FlyoutMidLeft"),
    }
end

function AB.LayoutFlyout(flyout, anchor, direction, count, choices)
    count = math.max(1, count)
    local length = FLYOUT_PAD_START + count * AB.CHOICE_STEP - 4 + FLYOUT_PAD_END
    local bg = flyout.kitBackground
    for _, texture in pairs(bg) do
        texture:ClearAllPoints()
        texture:SetRotation(0)
    end
    bg.start:SetSize(FLYOUT_WIDTH, 5)
    bg.finish:SetSize(FLYOUT_WIDTH, 29)
    flyout:ClearAllPoints()
    if direction == "RIGHT" then
        flyout:SetSize(length, FLYOUT_WIDTH)
        flyout:SetPoint("LEFT", anchor, "RIGHT", 0, 0)
        bg.start:SetPoint("CENTER", flyout, "LEFT", 2.5, 0)
        bg.start:SetRotation(-math.pi / 2)
        bg.finish:SetPoint("CENTER", flyout, "RIGHT", -14.5, 0)
        bg.finish:SetRotation(-math.pi / 2)
        bg.horizontal:SetPoint("TOPLEFT", flyout, "TOPLEFT", 5, 0)
        bg.horizontal:SetPoint("BOTTOMRIGHT", flyout, "BOTTOMRIGHT", -29, 0)
        bg.horizontal:Show()
        bg.vertical:Hide()
    else
        local up = direction ~= "DOWN"
        flyout:SetSize(FLYOUT_WIDTH, length)
        flyout:SetPoint(up and "BOTTOM" or "TOP", anchor, up and "TOP" or "BOTTOM", 0, 0)
        local rotation = up and 0 or math.pi
        bg.start:SetPoint("CENTER", flyout, up and "BOTTOM" or "TOP", 0, up and 2.5 or -2.5)
        bg.start:SetRotation(rotation)
        bg.finish:SetPoint("CENTER", flyout, up and "TOP" or "BOTTOM", 0, up and -14.5 or 14.5)
        bg.finish:SetRotation(rotation)
        bg.vertical:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", flyout, up and "BOTTOMLEFT" or "TOPLEFT", 0, up and 5 or -5)
        bg.vertical:SetPoint(up and "TOPRIGHT" or "BOTTOMRIGHT", flyout, up and "TOPRIGHT" or "BOTTOMRIGHT", 0, up and -29 or 29)
        bg.vertical:Show()
        bg.horizontal:Hide()
    end
    -- Choice offsets are in the choices' own (scaled) units.
    for index, choice in ipairs(choices or {}) do
        choice:ClearAllPoints()
        local offset = (FLYOUT_PAD_START + (index - 1) * AB.CHOICE_STEP) / AB.CHOICE_SCALE
        if direction == "RIGHT" then
            choice:SetPoint("LEFT", flyout, "LEFT", offset, 0)
        elseif direction == "DOWN" then
            choice:SetPoint("TOP", flyout, "TOP", 0, -offset)
        else
            choice:SetPoint("BOTTOM", flyout, "BOTTOM", 0, offset)
        end
    end
end
