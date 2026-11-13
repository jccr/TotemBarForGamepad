local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Per-Edit-Mode-Layout Position & Arrangement
-- ---------------------------------------------------------------------------
-- The bar reads these settings from the top level of TotemBarForGamepadDB. Each
-- Edit Mode layout keeps its own copy in TotemBarForGamepadDB.layouts, which is
-- restored into the top level when that layout becomes active.
-- x/y are the bar's center offset from UIParent's center in UIParent units,
-- so changing scale never moves the bar. No y: the default spot, worked out
-- from the screen's height and the bar's (ns.BAR_DEFAULT_BOTTOM_SHARE).
local LAYOUT_SETTINGS = { "offsetX", "offsetY", "barScale", "barOrientation", "flyoutsOpenDown", "weaponButtonSide" }
local activeLayoutKey

-- Nil until Edit Mode has loaded its layouts.
local function GetActiveLayoutKey()
    if not (EditModeManagerFrame and EditModeManagerFrame.GetActiveLayoutInfo) then return nil end
    local ok, info = pcall(EditModeManagerFrame.GetActiveLayoutInfo, EditModeManagerFrame)
    if not ok or type(info) ~= "table" then return nil end
    local name, layoutType = info.layoutName, info.layoutType
    if not name or ns.IsSecretValue(name) or ns.IsSecretValue(layoutType) then return nil end
    return tostring(layoutType or 0) .. ":" .. name
end

local function GetActiveLayoutName()
    return activeLayoutKey and activeLayoutKey:match("^[^:]*:(.*)$") or nil
end

local function GetLayoutDB()
    if not activeLayoutKey then return nil end
    TotemBarForGamepadDB.layouts = TotemBarForGamepadDB.layouts or {}
    local layout = TotemBarForGamepadDB.layouts[activeLayoutKey]
    if not layout then
        -- A layout seen for the first time starts from the current arrangement,
        -- but at the default scale: scale is set per layout and never carried
        -- over. (It is relative to the UI scale, so 100% matches Blizzard's bars.)
        layout = {}
        for _, setting in ipairs(LAYOUT_SETTINGS) do layout[setting] = TotemBarForGamepadDB[setting] end
        layout.barScale = ns.defaults.barScale
        TotemBarForGamepadDB.layouts[activeLayoutKey] = layout
    end
    return layout
end

local function SetLayoutSetting(setting, value)
    TotemBarForGamepadDB[setting] = value
    local layout = GetLayoutDB()
    if layout then layout[setting] = value end
end

local function ApplyPosition()
    if InCombatLockdown() or not TotemBarForGamepadDB then return end
    local scale = TotemBarForGamepadDB.barScale or 1
    -- Dragging uses StartMoving, which makes the client cache its own copy
    -- (layout-local.txt) and restore it over ours at login; keep it from that.
    ns.bar:SetUserPlaced(false)
    ns.bar:SetScale(scale)
    local x, y = TotemBarForGamepadDB.offsetX or 0, TotemBarForGamepadDB.offsetY
    if y == nil then
        -- Center offset that puts the bar's bottom edge at the default height.
        local screen = UIParent:GetHeight()
        y = math.floor(screen * (ns.BAR_DEFAULT_BOTTOM_SHARE - 0.5) + ns.bar:GetHeight() * scale / 2 + 0.5)
    end
    ns.bar:ClearAllPoints()
    ns.bar:SetPoint("CENTER", UIParent, "CENTER", x / scale, y / scale)
    if ns.SetBarFocusRestPosition then ns.SetBarFocusRestPosition(scale, x, y) end
end

-- The bar's size changes with its layout: UpdateLayout re-places a bar in
-- the default spot.
ns.ApplyBarPosition = ApplyPosition

-- Convert wherever the bar currently sits into the stored center offset.
local function GetCenterOffset()
    local cx, cy = ns.bar:GetCenter()
    local px, py = UIParent:GetCenter()
    if not cx or not px then return nil end
    local ratio = ns.bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return math.floor(cx * ratio - px + 0.5), math.floor(cy * ratio - py + 0.5)
end

local function SavePosition()
    local x, y = GetCenterOffset()
    if not x then return end
    SetLayoutSetting("offsetX", x)
    SetLayoutSetting("offsetY", y)
    ApplyPosition()
end

-- ---------------------------------------------------------------------------
-- Blizzard Edit Mode Integration
-- ---------------------------------------------------------------------------
-- Uses Blizzard's own selection overlay and Edit Mode events. The settings
-- dialog is addon-built: Blizzard's dialog only serves registered Blizzard
-- systems, and registering one would taint Edit Mode and the action bars.
local editModeSelection
local editModeDialog
local editModeSelected = false
ns.activeLayoutPending = false
local RefreshEditModeDialog = function() end

local function IsEditModeActive()
    if not (EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive) then return false end
    local ok, active = pcall(EditModeManagerFrame.IsEditModeActive, EditModeManagerFrame)
    return ok and active and true or false
end
-- TotemBar.lua shows every slot (and the bar itself) while Edit Mode is open.
ns.IsEditModeActive = IsEditModeActive

local function ShowSelection(selected)
    local selection = editModeSelection
    selection.isSelected = selected
    local method = selected and selection.ShowSelected or selection.ShowHighlighted
    local ok = method and pcall(method, selection)
    if ok then
        selection.tbgFallback:Hide()
    else
        -- Template behaved differently than expected: plain blue overlay instead.
        selection.tbgFallback:SetColorTexture(0.25, 0.55, 1, selected and 0.45 or 0.25)
        selection.tbgFallback:Show()
        selection:Show()
    end
    if selection.Label then
        selection.Label:SetText(ns.DISPLAY_NAME)
        selection.Label:SetShown(selected)
    end
end

local function DeselectEditModeBar()
    if not editModeSelected then return end
    editModeSelected = false
    if editModeDialog then editModeDialog:Hide() end
    if editModeSelection and IsEditModeActive() then ShowSelection(false) end
end

-- Restore the active layout's arrangement, creating it from the current one
-- the first time a layout is seen.
function ns.ApplyActiveLayout()
    if not TotemBarForGamepadDB then return end
    if InCombatLockdown() then
        ns.activeLayoutPending = true
        return
    end
    ns.activeLayoutPending = false
    local key = GetActiveLayoutKey()
    if key then
        activeLayoutKey = key
        local layout = GetLayoutDB()
        for _, setting in ipairs(LAYOUT_SETTINGS) do
            if layout[setting] ~= nil then
                TotemBarForGamepadDB[setting] = layout[setting]
            else
                layout[setting] = TotemBarForGamepadDB[setting]
            end
        end
    end
    ApplyPosition()
    ns.UpdateLayout()
    RefreshEditModeDialog()
end

local function CreateEditModeDialog()
    local dialog = CreateFrame("Frame", "TotemBarForGamepadEditModeDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(300, 330)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetClampedToScreen(true)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        self.userMoved = true
    end)
    dialog:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })
    dialog:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    dialog:Hide()

    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    dialog.title:SetPoint("TOP", dialog, "TOP", 0, -16)
    dialog.title:SetText(ns.DISPLAY_NAME)

    dialog.layoutText = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dialog.layoutText:SetPoint("TOP", dialog.title, "BOTTOM", 0, -4)

    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        dialog:Hide()
        DeselectEditModeBar()
    end)

    -- Rows stack top to bottom; y is the running offset from the dialog's top.
    local y = 50
    local CONTROL_WIDTH = 240
    local function Place(frame, height, gap, xOffset)
        y = y + (gap or 6)
        frame:SetPoint("TOP", dialog, "TOP", xOffset or 0, -y)
        y = y + height
    end

    -- Per-layout arrangement (Edit Mode layouts).
    local function ChangeSetting(setting, value)
        if InCombatLockdown() then return end
        SetLayoutSetting(setting, value)
        ns.UpdateLayout()
        RefreshEditModeDialog()
    end

    -- Appearance kept for every layout.
    local function ChangeGlobal(setting, value)
        if InCombatLockdown() then return end
        TotemBarForGamepadDB[setting] = value
        ns.UpdateLayout()
        RefreshEditModeDialog()
    end

    local function CreateSectionLabel(text)
        local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetWidth(CONTROL_WIDTH)
        label:SetJustifyH("LEFT")
        label:SetText(text)
        Place(label, 14, 12)
        return label
    end

    local function CreateToggleButton(onClick)
        local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        button:SetSize(CONTROL_WIDTH, 22)
        button:SetScript("OnClick", onClick)
        Place(button, 22)
        return button
    end

    -- Checkbox with its label to the right, left-aligned with the buttons.
    local function CreateCheckbox(text, getChecked, onChange)
        local box = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
        box:SetSize(26, 26)
        box.text:SetText(text)
        box:SetScript("OnClick", function(self)
            if InCombatLockdown() then
                self:SetChecked(getChecked())
                return
            end
            onChange(self:GetChecked() and true or false)
        end)
        box.getChecked = getChecked
        Place(box, 26, 2, -(CONTROL_WIDTH - 26) / 2 - 2)
        return box
    end

    dialog.checkboxes = {}

    CreateSectionLabel("Layout")
    dialog.orientation = CreateToggleButton(function()
        ChangeSetting("barOrientation", TotemBarForGamepadDB.barOrientation == "VERTICAL" and "HORIZONTAL" or "VERTICAL")
    end)
    dialog.flyoutsOpenDown = CreateCheckbox("Open Totem Flyouts Below Icons",
        function() return TotemBarForGamepadDB.flyoutsOpenDown or false end,
        function(value) ChangeSetting("flyoutsOpenDown", value) end)
    dialog.weaponButtonSide = CreateToggleButton(function()
        ChangeSetting("weaponButtonSide", TotemBarForGamepadDB.weaponButtonSide == "LEFT" and "RIGHT" or "LEFT")
    end)

    CreateSectionLabel("Buttons")
    dialog.checkboxes[#dialog.checkboxes + 1] = CreateCheckbox("Show Weapon Enhancement",
        function() return TotemBarForGamepadDB.showWeaponButton and true or false end,
        function(value) ChangeGlobal("showWeaponButton", value) end)
    dialog.checkboxes[#dialog.checkboxes + 1] = CreateCheckbox("Hide Elements Without Totems",
        function() return TotemBarForGamepadDB.hideEmptyElements and true or false end,
        function(value) ChangeGlobal("hideEmptyElements", value) end)
    -- Cycles Duration + Cooldown -> Duration -> Cooldown (Blizzard).
    local SWIPE_NEXT = { BOTH = "DURATION", DURATION = "COOLDOWN", COOLDOWN = "BOTH" }
    dialog.slotSwipe = CreateToggleButton(function()
        ChangeGlobal("slotSwipe", SWIPE_NEXT[TotemBarForGamepadDB.slotSwipe or "BOTH"] or "BOTH")
    end)

    -- Slot order: each slot picks its element from the classic list (Blizzard's
    -- newer menu taints the gamepad layer); picking one already used swaps.
    CreateSectionLabel("Slot Order")
    local slotMenu = CreateFrame("Frame", "TotemBarForGamepadSlotMenu", UIParent, "UIDropDownMenuTemplate")
    local menuSlot
    UIDropDownMenu_Initialize(slotMenu, function(_, level)
        if not menuSlot then return end
        for _, elem in ipairs(ns.ELEMENT_ORDER) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = ns.ELEMENT_NAMES[elem] .. " Totem"
            info.checked = TotemBarForGamepadDB.elementOrder[menuSlot] == elem
            info.func = function()
                CloseDropDownMenus()
                if InCombatLockdown() then return end
                local order = TotemBarForGamepadDB.elementOrder
                for other = 1, 4 do
                    if other ~= menuSlot and order[other] == elem then
                        order[other] = order[menuSlot]
                        break
                    end
                end
                order[menuSlot] = elem
                ns.UpdateLayout()
                RefreshEditModeDialog()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    dialog.slotButtons = {}
    for slotIndex = 1, 4 do
        dialog.slotButtons[slotIndex] = CreateToggleButton(function(self)
            menuSlot = slotIndex
            ToggleDropDownMenu(1, nil, slotMenu, self, 0, 0)
        end)
    end

    CreateSectionLabel("Size")
    -- Scale row in the style of Blizzard's "Icon Size" setting: a label beside
    -- Blizzard's stepper slider. Its measurements come from a spare instance of
    -- Blizzard's own row template, which is only read (its slider reports to
    -- Blizzard's Edit Mode dialog, so TBG never uses it directly).
    local function ScaleText(value)
        return string.format("%d%%", math.floor(value * 100 + 0.5))
    end
    local function OnScaleChanged(value)
        if dialog.refreshing or InCombatLockdown() then return end
        value = math.floor(value * 100 + 0.5) / 100
        SetLayoutSetting("barScale", value)
        -- Positions are scale-independent, so the bar scales around its center.
        ApplyPosition()
    end

    local row = CreateFrame("Frame", nil, dialog)
    local stepper = MinimalSliderWithSteppersMixin
        and select(2, pcall(CreateFrame, "Frame", nil, row, "MinimalSliderWithSteppersTemplate"))
    if type(stepper) == "table" and stepper.Init and stepper.RegisterCallback then
        local style = { font = "GameFontHighlightMedium", labelWidth = 100, sliderWidth = 200, height = 32, gap = 5 }
        local ok, model = pcall(CreateFrame, "Frame", nil, nil, "EditModeSettingSliderTemplate")
        if ok and model then
            model:Hide()
            if model.Label then
                style.font = model.Label:GetFontObject() or style.font
                if model.Label:GetWidth() > 0 then style.labelWidth = model.Label:GetWidth() end
            end
            if model.Slider then
                local w, h = model.Slider:GetSize()
                if w > 0 then style.sliderWidth = w end
                if h > 0 then style.height = h end
                local x = select(4, model.Slider:GetPoint(1))
                if type(x) == "number" then style.gap = x end
            end
        end
        -- The value text sits past the slider's right end, inside the row (as in
        -- Blizzard's row, which is wider than its label and slider).
        local rowWidth = style.labelWidth + style.gap + style.sliderWidth + 48
        if ok and model and model:GetWidth() > rowWidth then rowWidth = model:GetWidth() end
        row:SetSize(rowWidth, style.height)
        row.label = row:CreateFontString(nil, "ARTWORK")
        row.label:SetFontObject(style.font)
        row.label:SetJustifyH("LEFT")
        row.label:SetSize(style.labelWidth, style.height)
        row.label:SetPoint("LEFT")
        row.label:SetText("Scale")
        stepper:SetSize(style.sliderWidth, style.height)
        stepper:SetPoint("LEFT", row.label, "RIGHT", style.gap, 0)
        local formatters = {}
        if CreateMinimalSliderFormatter and MinimalSliderWithSteppersMixin.Label then
            local right = MinimalSliderWithSteppersMixin.Label.Right
            formatters[right] = CreateMinimalSliderFormatter(right, ScaleText)
        end
        -- 50% to 200% in 5% steps.
        dialog.refreshing = true
        stepper:Init(TotemBarForGamepadDB.barScale or 1, 0.5, 2.0, 30, formatters)
        dialog.refreshing = false
        stepper:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
            OnScaleChanged(value)
        end, row)
        row.SetValue = function(_, value) stepper:SetValue(value) end
    else
        -- Fallback: the classic options slider.
        local slider = CreateFrame("Slider", "TotemBarForGamepadEditModeScale", row, "OptionsSliderTemplate")
        row:SetSize(240, 40)
        slider:SetPoint("BOTTOM")
        slider:SetWidth(240)
        slider:SetMinMaxValues(0.5, 2.0)
        slider:SetValueStep(0.05)
        slider:SetObeyStepOnDrag(true)
        local low = slider.Low or _G[slider:GetName() .. "Low"]
        local high = slider.High or _G[slider:GetName() .. "High"]
        local label = slider.Text or _G[slider:GetName() .. "Text"]
        if low then low:SetText("50%") end
        if high then high:SetText("200%") end
        slider:SetScript("OnValueChanged", function(_, value)
            OnScaleChanged(value)
            if label then label:SetText("Scale: " .. ScaleText(value)) end
        end)
        row.SetValue = function(_, value)
            slider:SetValue(value)
            if label then label:SetText("Scale: " .. ScaleText(value)) end
        end
    end
    Place(row, row:GetHeight(), 6)
    dialog.scale = row

    local function CreateResetButton(text, onClick)
        local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        button:SetSize(CONTROL_WIDTH, 22)
        button:SetText(text)
        button:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            onClick()
        end)
        Place(button, 22, 8)
        return button
    end

    CreateResetButton("Reset Position", function()
        SetLayoutSetting("offsetX", ns.defaults.offsetX)
        SetLayoutSetting("offsetY", nil)
        ApplyPosition()
    end)

    CreateResetButton("Reset Scale", function()
        SetLayoutSetting("barScale", ns.defaults.barScale)
        ApplyPosition()
        RefreshEditModeDialog()
    end)

    -- Fit the dialog to its rows (the Blizzard-style scale row is the widest).
    dialog:SetWidth(math.max(300, row:GetWidth() + 40))
    dialog:SetHeight(y + 18)

    return dialog
end

RefreshEditModeDialog = function()
    local dialog = editModeDialog
    if not dialog or not dialog:IsShown() then return end
    local vertical = TotemBarForGamepadDB.barOrientation == "VERTICAL"
    local function Side(setting)
        local first = TotemBarForGamepadDB[setting] == "LEFT"
        if vertical then return first and "Top" or "Bottom" end
        return first and "Left" or "Right"
    end
    local layoutName = GetActiveLayoutName()
    dialog.layoutText:SetText(layoutName and ("Layout: " .. layoutName) or "")
    dialog.orientation:SetText(vertical and "Orientation: Vertical" or "Orientation: Horizontal")
    dialog.flyoutsOpenDown:SetChecked(TotemBarForGamepadDB.flyoutsOpenDown or false)
    -- Vertical bars always open flyouts to the side.
    dialog.flyoutsOpenDown:SetEnabled(not vertical)
    dialog.flyoutsOpenDown.text:SetFontObject(vertical and "GameFontDisable" or "GameFontHighlight")
    dialog.weaponButtonSide:SetText("Weapon Enhancement: " .. Side("weaponButtonSide"))
    local SWIPE_TEXT = { BOTH = "Duration + Cooldown", DURATION = "Duration", COOLDOWN = "Cooldown (Blizzard)" }
    dialog.slotSwipe:SetText("Slot Swipe: " .. (SWIPE_TEXT[TotemBarForGamepadDB.slotSwipe or "BOTH"] or SWIPE_TEXT.BOTH))
    for _, box in ipairs(dialog.checkboxes) do box:SetChecked(box.getChecked()) end
    for slotIndex, button in ipairs(dialog.slotButtons) do
        local elem = TotemBarForGamepadDB.elementOrder[slotIndex]
        button:SetText(string.format("Slot %d: %s Totem", slotIndex, ns.ELEMENT_NAMES[elem] or "?"))
    end
    dialog.refreshing = true
    dialog.scale:SetValue(TotemBarForGamepadDB.barScale or 1)
    dialog.refreshing = false
end

local function ShowEditModeDialog()
    editModeDialog = editModeDialog or CreateEditModeDialog()
    if not editModeDialog.userMoved then
        -- Open beside the bar, on the side with more room.
        editModeDialog:ClearAllPoints()
        if (TotemBarForGamepadDB.offsetX or 0) > 0 then
            editModeDialog:SetPoint("RIGHT", ns.bar, "LEFT", -24, 0)
        else
            editModeDialog:SetPoint("LEFT", ns.bar, "RIGHT", 24, 0)
        end
        -- Then stay put, like Blizzard's dialog: anchored to the bar it would
        -- move whenever the bar's scale changes (the bar scales around its center).
        local left, bottom = editModeDialog:GetLeft(), editModeDialog:GetBottom()
        if left and bottom then
            editModeDialog:ClearAllPoints()
            editModeDialog:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        end
    end
    editModeDialog:Show()
    RefreshEditModeDialog()
end

local function SetupEditMode()
    if not (EditModeManagerFrame and EventRegistry and EventRegistry.RegisterCallback) then return end
    local ok, selection = pcall(CreateFrame, "Frame", "TotemBarForGamepadEditModeSelection", ns.bar,
        "EditModeSystemSelectionTemplate")
    if not ok or not selection then return end
    editModeSelection = selection
    selection:ClearAllPoints()
    selection:SetAllPoints(ns.bar)
    selection:SetFrameLevel(ns.bar:GetFrameLevel() + 30)
    selection.tbgFallback = selection:CreateTexture(nil, "OVERLAY")
    selection.tbgFallback:SetAllPoints(selection)
    selection.tbgFallback:Hide()
    selection:EnableMouse(true)
    selection:RegisterForDrag("LeftButton")
    -- Replace the template's handlers, which expect a Blizzard system parent.
    selection:SetScript("OnMouseDown", function()
        if InCombatLockdown() then return end
        if EditModeManagerFrame.ClearSelectedSystem then
            pcall(EditModeManagerFrame.ClearSelectedSystem, EditModeManagerFrame)
        end
        editModeSelected = true
        ShowSelection(true)
        ShowEditModeDialog()
    end)
    selection:SetScript("OnMouseUp", nil)
    selection:SetScript("OnEnter", nil)
    selection:SetScript("OnLeave", nil)
    selection:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        ns.bar:StartMoving()
    end)
    selection:SetScript("OnDragStop", function()
        ns.bar:StopMovingOrSizing()
        -- Keep the client's layout cache from restoring its own copy at login.
        ns.bar:SetUserPlaced(false)
        if not InCombatLockdown() then SavePosition() end
    end)
    selection:Hide()

    local owner = {}
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        if InCombatLockdown() then return end
        ns.CloseBarFocus()
        ns.UpdateLayout()
        ShowSelection(false)
    end, owner)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        editModeSelected = false
        selection.isSelected = false
        selection.tbgFallback:Hide()
        selection:Hide()
        if editModeDialog then editModeDialog:Hide() end
        if InCombatLockdown() then ns.relayoutAfterCombat = true else ns.UpdateLayout() end
    end, owner)
    -- Selecting a Blizzard frame deselects the totem bar.
    if EditModeManagerFrame.SelectSystem then
        hooksecurefunc(EditModeManagerFrame, "SelectSystem", DeselectEditModeBar)
    end
end
SetupEditMode()
