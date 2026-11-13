local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Gamepad macros dialog
-- ---------------------------------------------------------------------------
-- The welcome guide's look, for every TBG macro: 1 Totem Bar Focus | 2 the
-- five cast macros (Earth, Fire, Water, Air, Weapon), each bound with A
-- (TBG's "Bind to Action Bar" prompt, which shows how) or dragged with the
-- mouse. Opened from
-- Options > AddOns and the welcome guide's optional step.
--
-- Opening it closes Blizzard's Settings panel completely (as Blizzard's own
-- Settings buttons that start another mode do), so LB+RB+D-pad paging reaches
-- the gamepad bars: the bind prompt binds into the page being shown. It
-- binds the D-pad only through override bindings and lets Left/Right go
-- while LB+RB are held, like the guide.
local WIDTH, COLUMN_WIDTH, PADDING = 646, 280, 24
local ICON_SIZE, CAST_ICON, CAST_GAP = 56, 44, 14

local window = ns.CreateGuideWindow("TotemBarForGamepadMacros", "Gamepad Macros", WIDTH)
ns.macroWindow = window
local Kit = ns.GamepadKit
local function Label(...) return window:Label(...) end

local subtitle = Label("GameFontHighlightLarge", "Bind them to gamepad buttons, or drag them to an action bar.")
subtitle:SetPoint("TOP", window, "TOP", 0, -34)

-- Two columns, as in the guide: a big step number and a title over each.
local COLUMN_TOP = 62
local columnCenters = { -WIDTH / 4 + 4, WIDTH / 4 - 4 }
local function Column(index, number, title)
    local numeral = Label("GameFontNormalHuge", number)
    numeral:SetPoint("TOP", window, "TOP", columnCenters[index], -COLUMN_TOP)
    local heading = Label("GameFontNormalLarge2", title)
    heading:SetPoint("TOP", numeral, "BOTTOM", 0, -4)
    return heading
end
local vertical = window:Divider(true)
vertical:SetPoint("TOP", window, "TOP", 0, -COLUMN_TOP)
vertical:SetHeight(172)

-- A macro icon: shows what the macro casts, picks it up with the mouse, and
-- binds it with A (FocusNav clicks its bind control).
local icons = {}
local nav

local function MacroIcon(def, size)
    local button = CreateFrame("Button", nil, window)
    button.def = def
    button:SetSize(size, size)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button:SetHighlightTexture(130718, "ADD") -- Interface\Buttons\ButtonHilight-Square
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    local function PickUp(self)
        local ok, reason = ns.PickupGamepadMacro(self.def)
        if not ok then ns.ShowMacroTooltip(self, self.def, reason) end
    end
    button:SetScript("OnClick", PickUp)
    button:SetScript("OnDragStart", PickUp)
    button:SetScript("OnEnter", function(self) ns.ShowMacroTooltip(self, self.def) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icons[#icons + 1] = button
    return button
end

-- Step 1: Totem Bar Focus.
local heading1 = Column(1, "1", "Totem Bar Focus")
local focusIcon = MacroIcon(ns.GetMacroDef("totems"), ICON_SIZE)
window:Below(focusIcon, heading1, 10)
local focusName = Label("GameFontNormal", focusIcon.def.name)
window:Below(focusName, focusIcon, 4)
local text1 = Label("GameFontHighlightMedium", "Puts your gamepad on the totem bar.", COLUMN_WIDTH)
window:Below(text1, focusName, 8)

-- Step 2 (optional): one macro per bar slot, in the bar's order, and the
-- weapon enhancement.
local heading2 = Column(2, "2", "Cast Directly")
local optional = Label("GameFontDisable", "Optional")
window:Below(optional, heading2, 2)
local castRow = CreateFrame("Frame", nil, window)
local castKeys = { "earth", "fire", "water", "air", "weapon" }
castRow:SetSize(#castKeys * CAST_ICON + (#castKeys - 1) * CAST_GAP, CAST_ICON)
window:Below(castRow, optional, 10)
for index, key in ipairs(castKeys) do
    local def = ns.GetMacroDef(key)
    local icon = MacroIcon(def, CAST_ICON)
    icon:SetPoint("LEFT", castRow, "LEFT", (index - 1) * (CAST_ICON + CAST_GAP), 0)
    local name = Label("GameFontNormalSmall", def.elem and ns.ELEMENT_NAMES[def.elem] or "Weapon")
    name:SetPoint("TOP", icon, "BOTTOM", 0, -4)
end
local text2 = Label("GameFontHighlightMedium", "Each casts its slot's totem, or your weapon enhancement.",
    COLUMN_WIDTH)
text2:SetPoint("TOP", castRow, "BOTTOM", 0, -24)

-- Done, under both.
local DONE_TOP = COLUMN_TOP + 194
local doneButton = window:Button(nil, DONE or "Done")
doneButton:SetPoint("TOP", window, "TOP", 0, -DONE_TOP)
doneButton:SetScript("OnClick", function() window:Hide() end)
window:SetHeight(DONE_TOP + ns.GUIDE_BUTTON_HEIGHT + PADDING)

-- ---------------------------------------------------------------------------
-- Showing, binding, closing
-- ---------------------------------------------------------------------------
function ns.RefreshMacroGuide()
    if not window:IsShown() then return end
    for _, icon in ipairs(icons) do ns.SetMacroIcon(icon.icon, icon.def) end
end
window:HookScript("OnShow", ns.RefreshMacroGuide)
window:HookScript("OnHide", function() GameTooltip:Hide() end)

-- The bind prompt replaces the dialog while it's up; the dialog comes back
-- on the macro that was bound.
local function Bind(index)
    if InCombatLockdown() then return end
    local def = icons[index].def
    window:Hide()
    local function Resume()
        if InCombatLockdown() then return end
        nav:SetStartItem(index)
        window:Show()
    end
    local opened, reason = ns.BindGamepadMacro(def, Resume)
    if not opened then
        Resume()
        if reason then ns.ShowMacroTooltip(icons[index], def, reason) end
    end
end

local function ShowWindow()
    if InCombatLockdown() then return end
    for _, icon in ipairs(icons) do ns.EnsureGamepadMacro(icon.def) end
    nav:SetStartItem(1)
    window:Show()
end

-- Out of combat only (the dialog holds the D-pad while it's open). Closes
-- Options first; if Options asks to apply or discard changes, the dialog
-- waits until Options has closed.
local waitingForSettings = false
if EventRegistry then
    EventRegistry:RegisterCallback("SettingsPanel.OnHide", function()
        if waitingForSettings then
            waitingForSettings = false
            ShowWindow()
        end
    end, window)
end
function ns.ShowMacroGuide()
    if InCombatLockdown() then return end
    if SettingsPanel and SettingsPanel:IsShown() then
        waitingForSettings = true
        local skipTransitionBackToOpeningPanel = true
        SettingsPanel:Close(skipTransitionBackToOpeningPanel)
        return
    end
    ShowWindow()
end

-- Gamepad: Left/Right move along a row, Up/Down between the macros and Done;
-- A binds, B closes. Bindings only, with Blizzard's paging let through.
nav = Kit.CreateFocusNavigator(window, {
    onClose = function() window:Hide() end,
    titlePlate = window.titlePlate,
    bindingsOnly = true,
    passWhileHeld = { hold = { "PADLSHOULDER", "PADRSHOULDER" }, keys = { "PADDLEFT", "PADDRIGHT" } },
})
local BIND_LABEL = type(CONTEXT_ACTION_LABEL_BIND_TO_GAMEPAD_ACTION_BAR) == "string"
    and CONTEXT_ACTION_LABEL_BIND_TO_GAMEPAD_ACTION_BAR or "Bind"
local DONE_ITEM = #icons + 1
for index, icon in ipairs(icons) do
    local control = CreateFrame("Button", nil, window)
    control:SetScript("OnClick", function() Bind(index) end)
    nav:AddItem({ kind = "button", anchor = icon, offset = 2, control = control, label = BIND_LABEL,
        neighbors = {
            PADDLEFT = index > 1 and index - 1 or nil,
            PADDRIGHT = index < #icons and index + 1 or nil,
            PADDUP = DONE_ITEM, PADDDOWN = DONE_ITEM,
        } })
end
nav:AddItem({ kind = "close", anchor = doneButton, offset = 2, neighbors = { PADDUP = 1, PADDDOWN = 1 } })
