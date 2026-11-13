local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Options > AddOns > TotemBarForGamepad
-- ---------------------------------------------------------------------------
-- Built from Blizzard's own Settings controls, so it has the native look and
-- the game's own gamepad focus. Position, scale and arrangement stay in
-- Edit Mode.
--
-- Known Forever-side issue (verified in game, 2026-11-12): pressing A on
-- a dropdown opens its list from addon data, which leaves the gamepad
-- layer tainted until /reload. Left/right on a focused dropdown steps its value
-- without opening the list and is clean.
--
-- Nothing in these callbacks prints to chat: chat written from inside
-- Blizzard's Settings code taints fields its gamepad navigation reads.

-- Key bindings (Bindings.xml), in display order.
ns.bindingEntries = {
    { button = "TotemBarForGamepadSlot1", label = "Totem Slot 1" },
    { button = "TotemBarForGamepadSlot2", label = "Totem Slot 2" },
    { button = "TotemBarForGamepadSlot3", label = "Totem Slot 3" },
    { button = "TotemBarForGamepadSlot4", label = "Totem Slot 4" },
    { button = "TotemBarForGamepadSummon", label = "Call (current)" },
    { button = "TotemBarForGamepadRecall", label = ns.recallSpell.name },
    { button = "TotemBarForGamepadWeaponEnhancement", label = "Weapon Enhancement" },
}

function ns.BindingCommand(entry)
    return "CLICK " .. entry.button .. ":LeftButton"
end

_G.BINDING_HEADER_TOTEMBARFORGAMEPAD = ns.DISPLAY_NAME
for _, entry in ipairs(ns.bindingEntries) do
    _G["BINDING_NAME_" .. ns.BindingCommand(entry)] = entry.label
end

local category

local function DB()
    return TotemBarForGamepadDB or ns.defaults
end

local MACRO_ICON_SIZE, MACRO_ICON_GAP = 36, 6

local function ShowMacroTooltip(button, reason)
    ns.ShowMacroTooltip(button, button.def, reason)
end

local function PickUp(button)
    local ok, reason = ns.PickupGamepadMacro(button.def)
    if not ok then ShowMacroTooltip(button, reason) end
end

-- Fills the Settings list row (pooled; built once per frame).
-- Each icon shows what its macro shows on a bar: the selected totem (or weapon
-- enhancement); with nothing selected, the element's "No Totem" art.
local function RefreshMacroIcons(frame)
    for _, button in ipairs(frame.tbgMacroButtons or {}) do ns.SetMacroIcon(button.icon, button.def) end
end

-- The row on screen, if the Options page is showing it.
local shownMacroRow

function ns.RefreshMacroRow()
    if shownMacroRow and shownMacroRow:IsVisible() then RefreshMacroIcons(shownMacroRow) end
end

function ns.BuildMacroRow(frame)
    shownMacroRow = frame
    if frame.tbgMacroButtons then
        RefreshMacroIcons(frame)
        return
    end
    frame.tbgMacroButtons = {}
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", frame, "LEFT", 37, 0)
    label:SetText("Drag to an Action Bar")
    for index, def in ipairs(ns.macroDefs) do
        local button = CreateFrame("Button", nil, frame)
        button.def = def
        button:SetSize(MACRO_ICON_SIZE, MACRO_ICON_SIZE)
        button:SetPoint("LEFT", frame, "CENTER", -90 + (index - 1) * (MACRO_ICON_SIZE + MACRO_ICON_GAP), 0)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button:SetHighlightTexture(130718, "ADD") -- Interface\Buttons\ButtonHilight-Square
        button:RegisterForClicks("LeftButtonUp")
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnClick", PickUp)
        button:SetScript("OnDragStart", PickUp)
        -- A from Blizzard's gamepad navigation (it calls OnSmartNavClick
        -- instead of clicking): bind it to a gamepad button combination.
        function button:OnSmartNavClick()
            GameTooltip:Hide()
            local opened, reason = ns.BindGamepadMacro(self.def)
            if not opened and reason then ShowMacroTooltip(self, reason) end
        end
        button:SetScript("OnEnter", function(self) ShowMacroTooltip(self) end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.tbgMacroButtons[index] = button
    end
    RefreshMacroIcons(frame)
end

-- Registered once TotemBarForGamepadDB exists (ADDON_LOADED), when the game has also
-- read Bindings.xml.
function ns.RegisterOptions()
    if category then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting
        and Settings.RegisterAddOnCategory) then
        return
    end
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(ns.DISPLAY_NAME)
    local VarType = Settings.VarType
    local settings = {}

    local function Header(text, tooltip)
        if CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text, tooltip))
        end
    end

    local function Register(key, varType, name, default, get, set)
        local setting = Settings.RegisterProxySetting(category, "TOTEMBARFORGAMEPAD_" .. key, varType, name, default,
            get, set)
        settings[key] = setting
        return setting
    end

    local function Checkbox(key, name, tooltip, get, set)
        local setting = Register(key, VarType.Boolean, name, ns.defaults[key] or false, get, set)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    local function Dropdown(key, name, tooltip, default, getLabels, get, set)
        local setting = Register(key, VarType.Number, name, default, get, set)
        Settings.CreateDropdown(category, setting, function()
            local container = Settings.CreateControlTextContainer()
            for value, label in ipairs(getLabels()) do container:Add(value, label) end
            return container:GetData()
        end, tooltip)
    end

    local function DBCheckbox(key, name, tooltip, onChange)
        Checkbox(key, name, tooltip,
            function() return DB()[key] and true or false end,
            function(value)
                if not TotemBarForGamepadDB then return end
                TotemBarForGamepadDB[key] = value
                if onChange then onChange(value) end
            end)
    end

    -- Behavior lives here; appearance (layout, buttons, slot order, size) is in
    -- TBG's Edit Mode options.
    Header("Appearance: Edit Mode", "The bar's position, scale, orientation, buttons and slot order are set in"
        .. " Edit Mode (Game Menu > Edit Mode): select the " .. ns.DISPLAY_NAME .. " bar.")

    Header("General")
    if CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer("Welcome Guide", "Show", function()
            if ns.ShowWelcome then ns.ShowWelcome() end
        end, "The first-time guide: adding Totem Bar Focus, placing the bar, and these options.", true))
    end
    DBCheckbox("hideBlizzardTotemBar", "Hide Blizzard Totem Bar",
        "Hide the game's own totem bar and totem timers. This bar keeps controlling the game's totem bar.",
        function(value) ns.SetBlizzardTotemBarHidden(value) end)

    -- Sound alerts: Blizzard's Cooldown Manager sounds or Text-to-Speech
    -- (SoundAlerts.lua). Changing a sound plays it.
    Header("Alerts", "Sounds when a totem or your weapon enhancement is about to run out, and when a totem is gone.")
    local function SampleTotem()
        for _, slot in ipairs(ns.slots) do
            if slot.chosenSpell then return slot.chosenSpell end
        end
        return ns.DISPLAY_NAME
    end
    local function SoundDropdown(key, name, tooltip, sample)
        local setting = Register(key, VarType.String, name, ns.defaults[key],
            function() return DB()[key] or ns.defaults[key] end,
            function(value)
                if not TotemBarForGamepadDB then return end
                TotemBarForGamepadDB[key] = value
                ns.PlayAlert(value, sample())
            end)
        -- As Blizzard's Combat Audio Alerts sound dropdowns (AudioAssist.lua):
        -- its own options on top (None, Text to Speech), then Blizzard's own
        -- sound menus (CooldownViewerUtil.BuildSoundMenus): a submenu per
        -- category, each sound a radio with Blizzard's play-sample button.
        local initializer = Settings.CreateDropdown(category, setting, function()
            local container = Settings.CreateControlTextContainer()
            for _, sound in ipairs(ns.GetAlertSounds()) do
                if not sound.soundEnum then container:Add(sound.key, sound.label) end
            end
            return container:GetData()
        end, tooltip)
        local function IsSelected(soundEnum)
            return (DB()[key] or ns.defaults[key]) == ns.AlertKeyForSoundEnum(soundEnum)
        end
        local function SetSelected(soundEnum)
            local soundKey = ns.AlertKeyForSoundEnum(soundEnum)
            if soundKey then setting:SetValue(soundKey) end
        end
        initializer.customOptionHandler = function(rootDescription)
            if CooldownViewerUtil and CooldownViewerUtil.BuildSoundMenus then
                local useHighlightStyle = true
                CooldownViewerUtil.BuildSoundMenus(rootDescription, IsSelected, SetSelected, useHighlightStyle)
                return
            end
            -- Without Blizzard's builder: the same menus from the same data.
            for _, group in ipairs(ns.GetAlertSoundGroups()) do
                local submenu = rootDescription:CreateHighlightButton(group.label, nop, -1)
                local CreateRadio = GenerateClosure(submenu.CreateHighlightRadio, submenu)
                for _, sound in ipairs(group.sounds) do
                    local alertData = { text = sound.text, soundEnum = sound.soundEnum }
                    if CooldownViewerUtil and CooldownViewerUtil.AddSoundAlertRadio then
                        local useHighlightStyle = true
                        CooldownViewerUtil.AddSoundAlertRadio(alertData, CreateRadio, IsSelected, SetSelected, useHighlightStyle)
                    else
                        CreateRadio(sound.text, IsSelected, SetSelected, sound.soundEnum)
                    end
                end
            end
        end
    end
    local function SecondsSlider(key, name, tooltip, minValue, maxValue, step)
        local setting = Register(key, VarType.Number, name, ns.defaults[key],
            function() return DB()[key] or ns.defaults[key] end,
            function(value)
                if TotemBarForGamepadDB then TotemBarForGamepadDB[key] = value end
            end)
        local options = Settings.CreateSliderOptions(minValue, maxValue, step)
        if MinimalSliderWithSteppersMixin then
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                return string.format("%d s", value)
            end)
        end
        Settings.CreateSlider(category, setting, options, tooltip)
    end
    SoundDropdown("alertTotemExpiring", "Totem Expiring", "When a totem is about to run out.", SampleTotem)
    SecondsSlider("alertLeadTime", "Totem Warning Time", "How long before a totem runs out the alert plays.", 1, 15, 1)
    SoundDropdown("alertTotemExpired", "Totem Expired",
        "When a totem is gone: it ran out or was destroyed (not when you recall it).", SampleTotem)
    SoundDropdown("alertWeaponExpiring", "Weapon Enhancement Expiring", "When your weapon enhancement is about to run out.",
        function() return ns.enhancementButton.chosenSpell or ns.DISPLAY_NAME end)
    SecondsSlider("alertWeaponLeadTime", "Weapon Warning Time",
        "How long before your weapon enhancement runs out the alert plays.", 30, 300, 15)

    Header("Totem Bar Focus", "Your gamepad on the totem bar, started by the TBG Focus macro on your gamepad action bar.")
    Dropdown("barFocusFirstFocus", "First Focus", "The bar button focused when Totem Bar Focus starts. Last Used"
        .. " reopens where you were. A button that isn't on the bar falls back to the first one.", 1,
        function()
            local labels = {}
            for index, choice in ipairs(ns.firstFocusChoices) do labels[index] = choice.label end
            return labels
        end,
        function() return DB().barFocusFirstFocus or 1 end,
        function(value)
            if not TotemBarForGamepadDB then return end
            TotemBarForGamepadDB.barFocusFirstFocus = value
            ns.ApplyBarFocusOptions()
        end)
    -- A selects (in a flyout), X casts once without selecting.
    DBCheckbox("barFocusCloseOnSelect", "Close After Selecting",
        "Selecting a totem, Call or weapon enhancement (A) ends Totem Bar Focus.",
        function() ns.ApplyBarFocusOptions() end)
    DBCheckbox("barFocusCloseOnCast", "Close After Casting",
        "Casting (X, or A on the bar) ends Totem Bar Focus.",
        function() ns.ApplyBarFocusOptions() end)
    DBCheckbox("barFocusTotemCastOnSelect", "Totems: Cast When Selected",
        "Selecting a totem (A) also casts it. X always casts the focused totem without selecting it.",
        function() ns.ApplyBarFocusOptions() end)
    DBCheckbox("barFocusWeaponCastOnSelect", "Weapon: Cast When Selected",
        "Selecting a weapon enhancement (A) also casts it. X always casts it without selecting it.",
        function() ns.ApplyBarFocusOptions() end)

    -- Gamepad macros: drag an icon to an action bar, or click it to pick the
    -- macro up. The macro is created the first time it is used.
    Header("Gamepad Macros", "Macros for the gamepad action bar: Totem Bar Focus, and casting each slot.")
    -- The macros dialog binds them with the gamepad (this list's navigation
    -- can't reach the icon row). It closes Options, so LB+RB paging works.
    if CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer("Gamepad Macros", "Open", function()
            ns.ShowMacroGuide()
        end, "Bind each macro to a gamepad button, step by step.", true))
    end
    local macroRow = Settings.CreateElementInitializer
        and select(2, pcall(Settings.CreateElementInitializer, "TotemBarForGamepadMacroRowTemplate", {}))
    if type(macroRow) == "table" then
        macroRow.InitFrame = function(_, frame) ns.BuildMacroRow(frame) end
        layout:AddInitializer(macroRow)
    elseif CreateSettingsButtonInitializer then
        -- Fallback: one "Pick Up" button per macro.
        for _, def in ipairs(ns.macroDefs) do
            layout:AddInitializer(CreateSettingsButtonInitializer(def.name, "Pick Up", function()
                ns.PickupGamepadMacro(def)
            end, def.desc, true))
        end
    end

    -- The game's own key bindings (also under Key Bindings > AddOns).
    if CreateKeybindingEntryInitializer and GetNumBindings then
        Header("Key Bindings")
        local indexByCommand = {}
        for i = 1, GetNumBindings() do
            local command = GetBinding(i)
            if command then indexByCommand[command] = i end
        end
        for _, entry in ipairs(ns.bindingEntries) do
            local index = indexByCommand[ns.BindingCommand(entry)]
            if index then layout:AddInitializer(CreateKeybindingEntryInitializer(index, true)) end
        end
    end

    Settings.RegisterAddOnCategory(category)
end

-- Opens this page (the welcome guide's "Open Options").
function ns.OpenSettings()
    if category and not InCombatLockdown() then Settings.OpenToCategory(category:GetID()) end
end
