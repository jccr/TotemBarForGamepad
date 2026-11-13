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
local WIDTH, COLUMN_WIDTH, PADDING = 760, 330, 28
local BUTTON_WIDTH, BUTTON_HEIGHT, ICON_SIZE, MINI_ICON = 200, 26, 56, 30
local GLYPH = 24

local window = CreateFrame("Frame", "TotemBarForGamepadWelcome", UIParent)
window:SetSize(WIDTH, 300)
window:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
window:SetFrameStrata("DIALOG")
window:SetClampedToScreen(true)
window:SetMovable(true)
window:EnableMouse(true)
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", window.StartMoving)
window:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
end)
window:Hide()
ns.welcomeWindow = window
-- Escape closes it like other game windows.
table.insert(UISpecialFrames, window:GetName())

-- Back to front: border, window glow (+2), title glow (+3), title plate,
-- close button (FocusNav adds the glows).
local base = window:GetFrameLevel()
local okBorder, border = pcall(CreateFrame, "Frame", nil, window, "DialogBorderTemplate")
local okHeader, header = pcall(CreateFrame, "Frame", nil, window, "DialogHeaderTemplate")
local titlePlate
if okBorder and border and okHeader and header then
    border:SetFrameLevel(base + 1)
    header:SetFrameLevel(base + 4)
    if header.Setup then header:Setup(ns.DISPLAY_NAME)
    elseif header.Text then header.Text:SetText(ns.DISPLAY_NAME) end
    titlePlate = header
else
    if okBorder and border then border:Hide() end
    if okHeader and header then header:Hide() end
    local chrome = CreateFrame("Frame", nil, window, "BasicFrameTemplateWithInset")
    chrome:SetAllPoints()
    if chrome.CloseButton then chrome.CloseButton:Hide() end
    local title = chrome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", window, "TOP", 0, -5)
    title:SetText(ns.DISPLAY_NAME)
end
local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -5)
closeButton:SetFrameLevel(base + 5)
closeButton:SetScript("OnClick", function() window:Hide() end)

local Kit = ns.GamepadKit
local function Glyph(key, fallback) return Kit.Glyph(key, GLYPH, fallback) end

local function Label(fontObject, text, width)
    local fontString = window:CreateFontString(nil, "OVERLAY", fontObject)
    if width then fontString:SetWidth(width) end
    fontString:SetJustifyH("CENTER")
    fontString:SetText(text)
    return fontString
end

local function Button(name, text, template)
    local button = CreateFrame("Button", name, window, template or "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText(text)
    return button
end

local function Divider(vertical)
    local line = window:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    if vertical then line:SetWidth(1) else line:SetHeight(1) end
    return line
end

local subtitle = Label("GameFontHighlightLarge", "Two steps and you're ready.")
subtitle:SetPoint("TOP", window, "TOP", 0, -40)

-- A column: big step number, title, a picture, one line of text, an action.
local COLUMN_TOP = 78
local columnCenters = { -WIDTH / 4 + 4, WIDTH / 4 - 4 }
local function Column(index, number, title)
    local x = columnCenters[index]
    local numeral = Label("GameFontNormalHuge", number)
    numeral:SetPoint("TOP", window, "TOP", x, -COLUMN_TOP)
    local heading = Label("GameFontNormalLarge2", title)
    heading:SetPoint("TOP", numeral, "BOTTOM", 0, -4)
    return x, heading
end
local function Below(region, anchor, gap)
    region:SetPoint("TOP", anchor, "BOTTOM", 0, -(gap or 10))
end

local vertical = Divider(true)
vertical:SetPoint("TOP", window, "TOP", 0, -COLUMN_TOP)
vertical:SetHeight(230)

-- Step 1: add Totem Bar Focus (its macro).
local barFocusDef
for _, def in ipairs(ns.macroDefs or {}) do
    if def.key == "totems" then barFocusDef = def end
end
local _, heading1 = Column(1, "1", "Add Totem Bar Focus")
local macroButton = CreateFrame("Button", nil, window)
macroButton:SetSize(ICON_SIZE, ICON_SIZE)
Below(macroButton, heading1, 14)
macroButton.icon = macroButton:CreateTexture(nil, "ARTWORK")
macroButton.icon:SetAllPoints()
macroButton.icon:SetTexture(barFocusDef and ns.SpellIcon(barFocusDef.spellID) or 134400)
macroButton.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
macroButton:SetHighlightTexture(130718, "ADD") -- Interface\Buttons\ButtonHilight-Square
macroButton:RegisterForClicks("LeftButtonUp")
macroButton:RegisterForDrag("LeftButton")
local macroName = Label("GameFontNormal", barFocusDef and barFocusDef.name or "")
Below(macroName, macroButton, 6)
local text1 = Label("GameFontHighlightMedium", "Puts your gamepad on the totem bar.", COLUMN_WIDTH)
Below(text1, macroName, 12)
local bindLine = Label("GameFontHighlightLarge", Glyph("PAD1", "A") .. "  Bind to a button")
Below(bindLine, text1, 14)
local dragLine = Label("GameFontDisable", "or drag it with the mouse")
Below(dragLine, bindLine, 6)

local function ShowMacroTooltip(reason)
    if not barFocusDef then return end
    GameTooltip:SetOwner(macroButton, "ANCHOR_RIGHT")
    GameTooltip:SetText(barFocusDef.name, 1, 1, 1)
    GameTooltip:AddLine(barFocusDef.desc:sub(1, 1):upper() .. barFocusDef.desc:sub(2), nil, nil, nil, true)
    if reason then
        GameTooltip:AddLine(reason, 1, 0.3, 0.3, true)
    else
        GameTooltip:AddLine("Drag to an action bar, or click to pick it up.", 0.4, 1, 0.4, true)
    end
    GameTooltip:Show()
end
local function PickUpMacro()
    if not barFocusDef then return end
    local ok, reason = ns.PickupGamepadMacro(barFocusDef)
    if not ok then ShowMacroTooltip(reason) end
end
macroButton:SetScript("OnClick", PickUpMacro)
macroButton:SetScript("OnDragStart", PickUpMacro)
macroButton:SetScript("OnEnter", function() ShowMacroTooltip() end)
macroButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Step 2: place the bar. The picture is a little totem bar (each element's
-- empty-slot art, in the bar's order).
local _, heading2 = Column(2, "2", "Place the bar")
local miniBar = CreateFrame("Frame", nil, window)
local order = ns.ELEMENT_ORDER or { 2, 1, 3, 4 }
miniBar:SetSize(#order * MINI_ICON + (#order - 1) * 6, ICON_SIZE)
Below(miniBar, heading2, 14)
for i, elem in ipairs(order) do
    local icon = miniBar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(MINI_ICON, MINI_ICON)
    icon:SetPoint("LEFT", miniBar, "LEFT", (i - 1) * (MINI_ICON + 6), 0)
    ns.SetElementEmptyArt(icon, elem)
end
local barName = Label("GameFontNormal", ns.DISPLAY_NAME)
Below(barName, miniBar, 6)
local text2 = Label("GameFontHighlightMedium", "Select it in Edit Mode and drag it into place.", COLUMN_WIDTH)
Below(text2, barName, 12)
-- Secure template last, so its click handler is the one that runs.
local editModeButton = Button("TotemBarForGamepadWelcomeEditMode", "Open Edit Mode",
    "UIPanelButtonTemplate, SecureActionButtonTemplate")
-- A protected frame can't anchor to text, so it sits at the column's foot,
-- anchored to the window (OPTIONAL_TOP: where the optional row begins).
local OPTIONAL_TOP = COLUMN_TOP + 250
editModeButton:SetPoint("BOTTOM", window, "TOP", columnCenters[2], -(OPTIONAL_TOP - 22))
window.editModeButton = editModeButton
editModeButton:RegisterForClicks("AnyUp", "AnyDown")
editModeButton:SetAttribute("type", "macro")
editModeButton:SetAttribute("macrotext", "/editmode")

-- Step 3 (optional), under both: the options.
local horizontal = Divider(false)
horizontal:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING, -OPTIONAL_TOP)
horizontal:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PADDING, -OPTIONAL_TOP)
local optionalLabel = Label("GameFontNormalLarge", "3  Optional")
optionalLabel:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING + 8, -(OPTIONAL_TOP + 18))
optionalLabel:SetJustifyH("LEFT")
local text3 = Label("GameFontHighlightMedium", "Tune alerts, focus behavior and key bindings.")
text3:SetPoint("LEFT", optionalLabel, "RIGHT", 16, 0)
text3:SetJustifyH("LEFT")
local optionsButton = Button(nil, "Open Options")
optionsButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -(PADDING + 8), -(OPTIONAL_TOP + 14))

local doneButton = Button(nil, DONE or "Done")
doneButton:SetPoint("TOP", window, "TOP", 0, -(OPTIONAL_TOP + 64))
window:SetHeight(OPTIONAL_TOP + 64 + BUTTON_HEIGHT + PADDING)

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
    if ns.OpenSettings then ns.OpenSettings() end
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
    if not barFocusDef or InCombatLockdown() then return end
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
    if barFocusDef then ns.EnsureGamepadMacro(barFocusDef) end
    window:Show()
end

-- On login: once per character, a moment after the world has loaded.
function ns.MaybeShowWelcome()
    if not TotemBarForGamepadDB or TotemBarForGamepadDB.welcomeShown then return end
    C_Timer.After(1, function()
        if not TotemBarForGamepadDB.welcomeShown and not window:IsShown() then ns.ShowWelcome() end
    end)
end

-- Gamepad: D-pad moves through the steps in order (the macro, Edit Mode,
-- Options, Done), A uses them, B closes.
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
    label = type(CONTEXT_ACTION_LABEL_BIND_TO_GAMEPAD_ACTION_BAR) == "string" and CONTEXT_ACTION_LABEL_BIND_TO_GAMEPAD_ACTION_BAR or "Bind" })
nav:AddItem({ kind = "button", anchor = editModeButton, offset = 2, label = "Open",
    secureButton = editModeButton:GetName() })
nav:AddItem({ kind = "button", anchor = optionsButton, offset = 2, label = "Open", control = optionsButton })
nav:AddItem({ kind = "close", anchor = doneButton, offset = 2 })
