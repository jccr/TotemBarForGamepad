local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Welcome guide
-- ---------------------------------------------------------------------------
-- Shown once per character (TotemBarForGamepadDB.welcomeShown), and again from
-- Options > AddOns. Two steps side by side (put the TBG Focus macro on the
-- gamepad bar; place the bar in Edit Mode), and the optional options under
-- both. Blizzard's dialog chrome (the
-- Game Menu's border and title plate) with GamepadKit's focus navigation.
--
-- "Open Edit Mode" is a secure button running /editmode, as typing it would:
-- opening Edit Mode from addon code would taint it (and the action bars it
-- moves). With a gamepad, A reaches it through FocusNav's secure binding.
-- Wide layout: step 1 | step 2 side by side, the optional step 3 under both.
local WIDTH, COLUMN_WIDTH, PADDING = 646, 280, 24
local ICON_SIZE, MINI_ICON = 56, 30
local GLYPH = 24

local window = ns.CreateGuideWindow("TotemBarForGamepadWelcome", ns.DISPLAY_NAME, WIDTH, 140)
ns.welcomeWindow = window
local titlePlate = window.titlePlate

local Kit = ns.GamepadKit
local function Glyph(key, fallback) return Kit.Glyph(key, GLYPH, fallback) end
local function Label(...) return window:Label(...) end
local function Button(...) return window:Button(...) end
local function Divider(...) return window:Divider(...) end
local function Below(...) return window:Below(...) end
local BUTTON_HEIGHT = ns.GUIDE_BUTTON_HEIGHT

local subtitle = Label("GameFontHighlightLarge", "Two steps and you're ready.")
subtitle:SetPoint("TOP", window, "TOP", 0, -34)

-- A column: big step number, title, a picture, one line of text, an action.
local COLUMN_TOP = 62
local columnCenters = { -WIDTH / 4 + 4, WIDTH / 4 - 4 }
local function Column(index, number, title)
    local x = columnCenters[index]
    local numeral = Label("GameFontNormalHuge", number)
    numeral:SetPoint("TOP", window, "TOP", x, -COLUMN_TOP)
    local heading = Label("GameFontNormalLarge2", title)
    heading:SetPoint("TOP", numeral, "BOTTOM", 0, -4)
    return x, heading
end
-- Each step's action sits on one row, so the D-pad moves straight across:
-- the macro icon (step 1) and Open Edit Mode (step 2). Both are anchored to
-- the window, under the headings (number 20 + title 18 tall).
local ACTION_ROW_TOP = COLUMN_TOP + 52
local vertical = Divider(true)
vertical:SetPoint("TOP", window, "TOP", 0, -COLUMN_TOP)
vertical:SetHeight(200)

-- Step 1: add Totem Bar Focus (its macro).
local barFocusDef = ns.GetMacroDef("totems")
Column(1, "1", "Add Totem Bar Focus")
local macroButton = CreateFrame("Button", nil, window)
macroButton:SetSize(ICON_SIZE, ICON_SIZE)
macroButton:SetPoint("TOP", window, "TOP", columnCenters[1], -ACTION_ROW_TOP)
macroButton.icon = macroButton:CreateTexture(nil, "ARTWORK")
macroButton.icon:SetAllPoints()
macroButton.icon:SetTexture(barFocusDef and ns.SpellIcon(barFocusDef.spellID) or 134400)
macroButton.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
macroButton:SetHighlightTexture(130718, "ADD") -- Interface\Buttons\ButtonHilight-Square
macroButton:RegisterForClicks("LeftButtonUp")
macroButton:RegisterForDrag("LeftButton")
local macroName = Label("GameFontNormal", barFocusDef and barFocusDef.name or "")
Below(macroName, macroButton, 4)
local text1 = Label("GameFontHighlightMedium", "Puts your gamepad on the totem bar.", COLUMN_WIDTH)
Below(text1, macroName, 8)
local bindLine = Label("GameFontHighlightLarge", Glyph("PAD1", "A") .. "  Bind to a button")
Below(bindLine, text1, 10)
local dragLine = Label("GameFontDisable", "or drag it with the mouse")
Below(dragLine, bindLine, 4)

local function ShowMacroTooltip(reason)
    ns.ShowMacroTooltip(macroButton, barFocusDef, reason)
end
local function PickUpMacro()
    local ok, reason = ns.PickupGamepadMacro(barFocusDef)
    if not ok then ShowMacroTooltip(reason) end
end
macroButton:SetScript("OnClick", PickUpMacro)
macroButton:SetScript("OnDragStart", PickUpMacro)
macroButton:SetScript("OnEnter", function() ShowMacroTooltip() end)
macroButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Step 2: place the bar. Open Edit Mode, level with the macro icon, then a
-- little totem bar (each element's empty-slot art, in the bar's order).
Column(2, "2", "Place the bar")
-- Secure template last, so its click handler is the one that runs. A
-- protected frame can't anchor to text, so it's anchored to the window.
local editModeButton = Button("TotemBarForGamepadWelcomeEditMode", "Open Edit Mode",
    "UIPanelButtonTemplate, SecureActionButtonTemplate")
editModeButton:SetPoint("CENTER", window, "TOP", columnCenters[2], -(ACTION_ROW_TOP + ICON_SIZE / 2))
window.editModeButton = editModeButton
editModeButton:RegisterForClicks("AnyUp", "AnyDown")
editModeButton:SetAttribute("type", "macro")
editModeButton:SetAttribute("macrotext", "/editmode")
local miniBar = CreateFrame("Frame", nil, window)
local order = ns.ELEMENT_ORDER or { 2, 1, 3, 4 }
miniBar:SetSize(#order * MINI_ICON + (#order - 1) * 6, MINI_ICON)
miniBar:SetPoint("TOP", window, "TOP", columnCenters[2], -(ACTION_ROW_TOP + ICON_SIZE + 10))
for i, elem in ipairs(order) do
    local icon = miniBar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(MINI_ICON, MINI_ICON)
    icon:SetPoint("LEFT", miniBar, "LEFT", (i - 1) * (MINI_ICON + 6), 0)
    ns.SetElementEmptyArt(icon, elem)
end
local barName = Label("GameFontNormal", ns.DISPLAY_NAME)
Below(barName, miniBar, 4)
local text2 = Label("GameFontHighlightMedium", "Select it in Edit Mode and drag it into place.", COLUMN_WIDTH)
Below(text2, barName, 8)

local OPTIONAL_TOP = COLUMN_TOP + 222

-- Step 3 (optional), under both: a heading line, then one button under each
-- step (Gamepad Macros under the macro, Options under Edit Mode), so the
-- D-pad moves down each column. Done under everything.
local horizontal = Divider(false)
horizontal:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING, -OPTIONAL_TOP)
horizontal:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PADDING, -OPTIONAL_TOP)
local optionalLabel = Label("GameFontNormalLarge", "3  Optional")
local text3 = Label("GameFontHighlightMedium", "More macros, alerts and options.")
-- The two read as one centered line.
local OPTIONAL_GAP = 16
local optionalLine = CreateFrame("Frame", nil, window)
optionalLine:SetSize(1, 20)
optionalLine:SetPoint("TOP", window, "TOP", 0, -(OPTIONAL_TOP + 14))
optionalLabel:SetPoint("LEFT", optionalLine, "LEFT")
text3:SetPoint("LEFT", optionalLabel, "RIGHT", OPTIONAL_GAP, 0)
optionalLine:SetScript("OnShow", function(self)
    self:SetWidth(optionalLabel:GetStringWidth() + OPTIONAL_GAP + text3:GetStringWidth())
end)
local OPTIONAL_BUTTONS_TOP = OPTIONAL_TOP + 44
local macrosButton = Button(nil, "Gamepad Macros")
macrosButton:SetPoint("TOP", window, "TOP", columnCenters[1], -OPTIONAL_BUTTONS_TOP)
local optionsButton = Button(nil, "Open Options")
optionsButton:SetPoint("TOP", window, "TOP", columnCenters[2], -OPTIONAL_BUTTONS_TOP)

local DONE_TOP = OPTIONAL_BUTTONS_TOP + BUTTON_HEIGHT + 16
local doneButton = Button(nil, DONE or "Done")
doneButton:SetPoint("TOP", window, "TOP", 0, -DONE_TOP)
window:SetHeight(DONE_TOP + BUTTON_HEIGHT + PADDING)

-- ---------------------------------------------------------------------------
-- Showing and closing
-- ---------------------------------------------------------------------------
-- Edit Mode and the bind prompt hide the guide while they're open, and bring
-- it back after.
local pausedForEditMode = false


window:HookScript("OnHide", function()
    GameTooltip:Hide()
    if not pausedForEditMode and TotemBarForGamepadDB then TotemBarForGamepadDB.welcomeShown = true end
end)

doneButton:SetScript("OnClick", function() window:Hide() end)
optionsButton:SetScript("OnClick", function()
    window:Hide()
    ns.OpenSettings()
end)
macrosButton:SetScript("OnClick", function()
    window:Hide()
    ns.ShowMacroGuide()
end)

if EventRegistry and EventRegistry.RegisterCallback then
    local owner = {}
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        if window:IsShown() then
            pausedForEditMode = true
            window:Hide()
        end
    end, owner)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        if pausedForEditMode then
            pausedForEditMode = false
            if not InCombatLockdown() then window:Show() end
        end
    end, owner)
end

-- A on the macro: the bind prompt (ns.BindGamepadMacro); the guide steps
-- aside meanwhile.
local function ResumeGuide()
    if pausedForEditMode then
        pausedForEditMode = false
        if not InCombatLockdown() then window:Show() end
    end
end
local function BindBarFocusMacro()
    if InCombatLockdown() then return end
    pausedForEditMode = true
    window:Hide()
    local opened, reason = ns.BindGamepadMacro(barFocusDef, ResumeGuide)
    if not opened then
        ResumeGuide()
        if reason then ShowMacroTooltip(reason) end
    end
end

-- Out of combat only (the guide holds the gamepad while it's open). The
-- TBG Focus macro is created here, so it exists to bind.
function ns.ShowWelcome()
    if InCombatLockdown() then return end
    pausedForEditMode = false
    ns.EnsureGamepadMacro(barFocusDef)
    window:Show()
end

-- On login: once per character, a moment after the world has loaded.
function ns.MaybeShowWelcome()
    if not TotemBarForGamepadDB or TotemBarForGamepadDB.welcomeShown then return end
    C_Timer.After(1, function()
        if not TotemBarForGamepadDB.welcomeShown and not window:IsShown() then ns.ShowWelcome() end
    end)
end

-- Gamepad: a 2x2 grid over Done.
--   [macro]          -> [Open Edit Mode]
--   [Gamepad Macros] -> [Open Options]
--             [Done]
-- Left/Right across a row, Up/Down a column, Down from the bottom row to
-- Done (and Up from Done back to it). A uses them, B closes.
-- Bindings only: LB/RB (gamepad bar paging), the triggers and the sticks
-- keep working while the guide is up.
local nav = ns.GamepadKit.CreateFocusNavigator(window, {
    onClose = function() window:Hide() end,
    titlePlate = titlePlate,
    bindingsOnly = true,
    -- Blizzard's gamepad bar paging: LB + RB + D-pad Left/Right.
    passWhileHeld = { hold = { "PADLSHOULDER", "PADRSHOULDER" }, keys = { "PADDLEFT", "PADDRIGHT" } },
})
-- A binds the macro (Blizzard's own label for it: "Bind").
local bindControl = CreateFrame("Button", nil, window)
bindControl:SetScript("OnClick", BindBarFocusMacro)
nav:AddItem({ kind = "button", anchor = macroButton, offset = 2, control = bindControl,
    neighbors = { PADDRIGHT = 2, PADDDOWN = 3, PADDUP = 5 },
    label = type(CONTEXT_ACTION_LABEL_BIND_TO_GAMEPAD_ACTION_BAR) == "string" and CONTEXT_ACTION_LABEL_BIND_TO_GAMEPAD_ACTION_BAR or "Bind" })
nav:AddItem({ kind = "button", anchor = editModeButton, offset = 2, label = "Open",
    secureButton = editModeButton:GetName(), neighbors = { PADDLEFT = 1, PADDDOWN = 4, PADDUP = 5 } })
nav:AddItem({ kind = "button", anchor = macrosButton, offset = 2, label = "Open", control = macrosButton,
    neighbors = { PADDRIGHT = 4, PADDUP = 1, PADDDOWN = 5 } })
nav:AddItem({ kind = "button", anchor = optionsButton, offset = 2, label = "Open", control = optionsButton,
    neighbors = { PADDLEFT = 3, PADDUP = 2, PADDDOWN = 5 } })
nav:AddItem({ kind = "close", anchor = doneButton, offset = 2, neighbors = { PADDUP = 3, PADDDOWN = 1 } })
