local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Main Display Frame
-- ---------------------------------------------------------------------------
-- No panel behind the buttons, like Blizzard's own action bars. Protected,
-- so Totem Bar Focus's secure code can scale it up in combat.
ns.bar = CreateFrame("Frame", "TotemBarForGamepadFrame", UIParent, "SecureFrameTemplate")
ns.bar:SetMovable(true)
ns.bar:SetClampedToScreen(true)

-- While Totem Bar Focus has the bar, it is scaled up and has a dark
-- shadow behind it, as Blizzard's gamepad bars when focused: buttons grow
-- from 32 to 40 (x1.25), and the shadow (gamepad-actionbar-focus-bg-section
-- at 37.5%) reaches 123 past each end and 37 above and below a bar of
-- 40px buttons, here scaled to TBG's 30px buttons.
ns.FOCUS_SCALE = 40 / 32
local SHADOW_ALONG, SHADOW_ACROSS = 123 * 30 / 40, 37 * 30 / 40
ns.barShadow = CreateFrame("Frame", nil, ns.bar, "SecureFrameTemplate")
ns.barShadow:SetFrameLevel(ns.bar:GetFrameLevel())
ns.barShadow:SetPoint("CENTER")
do
    local texture = ns.barShadow:CreateTexture(nil, "BACKGROUND")
    texture:SetAtlas("gamepad-actionbar-focus-bg-section")
    texture:SetAlpha(0.375)
    texture:SetAllPoints()
end
ns.barShadow:Hide()

ns.slots = {}
-- Every button with a flyout (its flyout and open tab), filled as they're made.
ns.flyoutSelectors = {}

-- ---------------------------------------------------------------------------
-- Blizzard's totem bar look (MultiCastActionBarFrame)
-- ---------------------------------------------------------------------------
-- Coordinates, sizes and offsets are Blizzard's own, from this client's UI
-- source (Blizzard_ActionBar/Shared/MultiCastActionBarFrame.lua and .xml,
-- exported with "exportInterfaceFiles code"); the live look was also checked
-- in game. Its buttons are 30px action buttons with the plain icon frame,
-- and they keep that art in the gamepad UI. Slot borders, empty slots and the
-- flyouts are cut from one texture (Interface\Buttons\UI-TotemBar).
local AB = ns.GamepadKit.ActionButtons
local BUTTON_SIZE, BUTTON_GAP = 30, 8
ns.BAR_BUTTON_SIZE = BUTTON_SIZE
local BUTTON_STEP = BUTTON_SIZE + BUTTON_GAP
-- Blizzard's bar frame leaves 3px around its buttons.
local BAR_PADDING = 3
local BUTTON_OPTIONS = { size = BUTTON_SIZE, followActiveUI = false,
    art = { normal = "UI-HUD-ActionBar-IconFrame", pushed = "UI-HUD-ActionBar-IconFrame-Down" } }
ns.TOTEM_CHOICE_SIZE = 24
-- An open flyout closes this long after the mouse leaves its button and it
-- (Blizzard's stays open; a TBG choice).
local FLYOUT_CLOSE_DELAY = 1

local TOTEM_BAR_TEXTURE = 310727
-- Texture pixels (x/128, y/256) to texture coordinates.
local function Pixels(left, right, top, bottom)
    return { left / 128, right / 128, top / 256, bottom / 256 }
end
-- Indexed by the game's totem slots: Fire 1, Earth 2, Water 3, Air 4.
local SLOT_EMPTY_COORDS = {
    Pixels(67, 97, 100, 130), -- Fire
    Pixels(66, 96, 3, 33),    -- Earth
    Pixels(39, 69, 209, 239), -- Water
    Pixels(66, 96, 36, 66),   -- Air
}
local SLOT_BORDER_COORDS = {
    Pixels(36, 70, 172, 206), -- Fire
    Pixels(1, 35, 172, 206),  -- Earth
    Pixels(1, 35, 207, 240),  -- Water
    Pixels(36, 70, 137, 171), -- Air
}
-- The neutral border Blizzard draws over its summon and Recall buttons
-- (TBG's weapon button uses it too).
local NEUTRAL_BORDER_COORDS = Pixels(1, 35, 137, 171)
-- Each element has its own colored cap, middle and tabs; the neutral set is
-- the summon button's (Call switcher) flyout. The highlights are shared.
local FLYOUT_HIGHLIGHTS = {
    close = Pixels(72, 92, 69, 79), -- 20x11
    open = Pixels(72, 92, 88, 98),  -- 20x11
}
local FLYOUT_ART_BY_ELEMENT = {
    [1] = { cap = Pixels(33, 65, 46, 68), column = Pixels(33, 65, 68, 88), -- Fire
        closeTab = Pixels(99, 127, 103, 121), openTab = Pixels(99, 127, 122, 140) },
    [2] = { cap = Pixels(0, 32, 46, 68), column = Pixels(0, 32, 68, 88), -- Earth
        closeTab = Pixels(99, 127, 141, 159), openTab = Pixels(99, 127, 160, 178) },
    [3] = { cap = Pixels(0, 32, 1, 23), column = Pixels(0, 32, 23, 43), -- Water
        closeTab = Pixels(99, 127, 180, 198), openTab = Pixels(99, 127, 199, 217) },
    [4] = { cap = Pixels(0, 32, 91, 113), column = Pixels(0, 32, 113, 133), -- Air
        closeTab = Pixels(99, 127, 218, 236), openTab = Pixels(99, 127, 237, 255) },
    neutral = { cap = Pixels(33, 65, 1, 23), column = Pixels(33, 65, 23, 43),
        closeTab = Pixels(99, 127, 65, 83), openTab = Pixels(99, 127, 84, 102) },
}
-- The weapon flyout uses Blizzard's neutral flyout art.
local WEAPON_FLYOUT_ELEMENT = "neutral"

-- Choices are 24px, 26px apart; the cap is 20px.
local FLYOUT_WIDTH, CHOICE_STEP, FLYOUT_CAP = 32, 26, 20

local function SetTotemArt(texture, coords)
    texture:SetTexture(TOTEM_BAR_TEXTURE)
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

-- The element's empty-slot art (Blizzard's "No Totem" look), for other files.
function ns.SetElementEmptyArt(texture, elem)
    SetTotemArt(texture, SLOT_EMPTY_COORDS[elem])
end

-- Every bar button has Blizzard's 34px border over its icon frame: the
-- element's on totem slots, the neutral one on the others.
local function CreateBarButton(name)
    local button = AB.Create(name, ns.bar, BUTTON_OPTIONS)
    button.timerText:SetFontObject("NumberFontNormal")
    local normal = button:GetNormalTexture()
    if normal then normal:SetDrawLayer("ARTWORK", 0) end
    button.border = button:CreateTexture(nil, "OVERLAY", nil, 2)
    button.border:SetPoint("CENTER")
    button.border:SetSize(BUTTON_SIZE * 34 / 30, BUTTON_SIZE * 34 / 30)
    SetTotemArt(button.border, NEUTRAL_BORDER_COORDS)
    return button
end

-- Usability tint, as on Blizzard's action buttons (including its totem bar):
-- full color when castable, blue without enough mana, dark otherwise.
local function TintButton(button, spell)
    if not button or not button.icon then return end
    if not spell then
        button.icon:SetVertexColor(1, 1, 1)
        return
    end
    local usable, noMana
    if C_Spell and C_Spell.IsSpellUsable then
        usable, noMana = C_Spell.IsSpellUsable(spell)
    elseif IsUsableSpell then
        usable, noMana = IsUsableSpell(spell)
    else
        return
    end
    -- A restricted (secret) answer can't be read: keep the current tint.
    if ns.IsSecretValue(usable) or ns.IsSecretValue(noMana) then return end
    if usable then
        button.icon:SetVertexColor(1, 1, 1)
    elseif noMana then
        button.icon:SetVertexColor(0.5, 0.5, 1)
    else
        button.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

local function TintSlot(slotIndex)
    local slot = ns.slots[slotIndex]
    local elem = TotemBarForGamepadDB.elementOrder[slotIndex]
    local selected = TotemBarForGamepadDB.activeCallSet[elem]
    TintButton(slot, selected ~= "none" and slot.chosenSpell or nil)
end

-- Every bar button; runs on the game's usability and power events.
function ns.UpdateUsability()
    if not TotemBarForGamepadDB then return end
    for slotIndex = 1, #ns.slots do TintSlot(slotIndex) end
    for _, button in ipairs({ ns.summonButton, ns.recallButton }) do
        if button and button:IsShown() then TintButton(button, button.spellName) end
    end
    if ns.enhancementButton then TintButton(ns.enhancementButton, ns.enhancementButton.chosenSpell) end
end

-- ---------------------------------------------------------------------------
-- Swipes: the placed totem's time left and the spell's cooldown
-- ---------------------------------------------------------------------------
-- A spell's cooldown (and the global cooldown) on a cooldown frame, as
-- Blizzard's action buttons show it. A duration object keeps it working when
-- combat restricts the cooldown values.
local function ShowSpellCooldown(cooldown, spell)
    if not cooldown then return end
    if not spell then
        cooldown:Clear()
        return
    end
    if C_Spell and C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
        local duration = C_Spell.GetSpellCooldownDuration(spell)
        if duration then
            cooldown:SetCooldownFromDurationObject(duration, true)
            return
        end
    end
    local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spell)
    if type(info) == "table" and not ns.IsSecretValue(info.startTime) and not ns.IsSecretValue(info.duration)
        and not ns.IsSecretValue(info.isEnabled) and info.isEnabled and info.startTime > 0 and info.duration > 0 then
        cooldown:SetCooldown(info.startTime, info.duration)
    else
        cooldown:Clear()
    end
end

-- Which swipe a slot shows (Edit Mode "Slot Swipe"): the placed totem's time
-- left (slot.cooldown) and/or the spell's cooldown (slot.spellCooldown).
-- The time text and glow of a placed totem show in every mode.
function ns.UpdateSlotSwipe(slotIndex)
    local slot = ns.slots[slotIndex]
    if not slot or not TotemBarForGamepadDB then return end
    local mode = TotemBarForGamepadDB.slotSwipe or "BOTH"
    local showDuration = mode == "DURATION" or (mode == "BOTH" and slot.active)
    local showCooldown = mode == "COOLDOWN" or (mode == "BOTH" and not slot.active)
    slot.cooldown:SetDrawSwipe(showDuration)
    slot.cooldown:SetDrawEdge(false)
    slot.cooldown:SetDrawBling(showDuration)
    slot.spellCooldown:SetShown(showCooldown)
    -- The totem's own time text already shows while it is down.
    slot.spellCooldown:SetHideCountdownNumbers(slot.active and true or false)
end

-- Every button's spell cooldown; runs on the game's cooldown events.
function ns.UpdateSpellCooldowns()
    if not TotemBarForGamepadDB then return end
    for _, slot in ipairs(ns.slots) do
        local elem = TotemBarForGamepadDB.elementOrder[slot.slotIndex]
        local selected = TotemBarForGamepadDB.activeCallSet[elem]
        ShowSpellCooldown(slot.spellCooldown, selected ~= "none" and slot.chosenSpell or nil)
    end
    ShowSpellCooldown(ns.summonButton.cooldown, ns.summonButton.spellName)
    ShowSpellCooldown(ns.recallButton.cooldown, ns.recallButton.spellName)
    ShowSpellCooldown(ns.enhancementButton.cooldown, ns.enhancementButton.chosenSpell)
end

-- A slot's icon (its chosen totem, or the element's empty art for "No
-- Totem"), tint and swipe. Without a placed totem it shows no time.
function ns.UpdateSlotLook(slotIndex)
    local slot = ns.slots[slotIndex]
    if not slot then return end
    local elem = TotemBarForGamepadDB.elementOrder[slotIndex]
    local spell = TotemBarForGamepadDB.activeCallSet[elem] ~= "none" and slot.chosenSpell
    local icon = spell and ns.SpellIcon(slot.knownIDs and slot.knownIDs[spell] or spell)
    if icon then
        slot.icon:SetTexture(icon)
        slot.icon:SetTexCoord(0, 1, 0, 1)
    else
        SetTotemArt(slot.icon, SLOT_EMPTY_COORDS[elem])
    end
    slot.icon:Show()
    TintSlot(slotIndex)
    if not slot.active then
        slot.timerText:SetText("")
        slot.cooldown:Clear()
    end
    ns.UpdateSlotSwipe(slotIndex)
end

-- Key bindings are the game's own (Bindings.xml: "CLICK <button>:LeftButton"),
-- set in Options > Key Bindings or TBG's Options page. This shows each one's
-- key the way Blizzard abbreviates it on action buttons.
local function BindingKeyText(buttonName)
    local key = ns.Readable(GetBindingKey("CLICK " .. buttonName .. ":LeftButton"))
    if not key then return "" end
    return ns.Readable(GetBindingText(key, true)) or key
end

function ns.UpdateHotkeys()
    local buttons = { ns.enhancementButton, ns.summonButton, ns.recallButton }
    for _, button in ipairs(ns.slots) do buttons[#buttons + 1] = button end
    for _, button in ipairs(buttons) do
        button.hotkeyText:SetText(BindingKeyText(button:GetName()))
    end
end

-- ---------------------------------------------------------------------------
-- Call writers: TBG's picks into the game's totem bar
-- ---------------------------------------------------------------------------
-- The game's totem bar is a block of action slots: one page of four (Fire,
-- Earth, Water, Air) per Call, starting at the multicast bar. Writing one is
-- a protected action, so each slot gets a hidden secure button with the
-- "multispell" action; a flyout choice clicks it in the same hardware click
-- that picked the totem, so it works in combat too.
local TOTEM_BAR_START = (C_ActionBar.GetMultiCastBarIndex() - 1) * NUM_ACTIONBAR_BUTTONS

-- The game action slot of a Call's element.
local function CallAction(page, elem)
    return TOTEM_BAR_START + (page - 1) * 4 + elem
end

local function CreateCallWriter(page, elem)
    local writer = CreateFrame("Button", "TotemBarForGamepadCallSet" .. page .. "_" .. elem, UIParent,
        "SecureActionButtonTemplate")
    writer:Hide()
    -- "/click" sends one release; act on it even with ActionButtonUseKeyDown on.
    writer:RegisterForClicks("LeftButtonUp")
    writer:SetAttribute("useOnKeyDown", false)
    writer:SetAttribute("type1", "multispell")
    writer:SetAttribute("action1", CallAction(page, elem))
    writer:SetAttribute("spell1", 0)
    return writer
end

ns.callWriters = {}
for page = 1, #ns.callSpells do
    ns.callWriters[page] = {}
    for elem = 1, 4 do ns.callWriters[page][elem] = CreateCallWriter(page, elem) end
end

-- ---------------------------------------------------------------------------
-- Following the game's totem bar
-- ---------------------------------------------------------------------------
-- The game's totem bar is the source of truth, as on Blizzard's own bar: a
-- change made there (or by Blizzard's flyout) becomes that Call's selection.

-- Returns the call page and element of a game action slot, if it is one.
function ns.TotemBarSlotOf(action)
    if type(action) ~= "number" or ns.IsSecretValue(action) then return end
    local offset = action - TOTEM_BAR_START - 1
    if offset < 0 or offset >= 4 * #ns.callWriters then return end
    return math.floor(offset / 4) + 1, offset % 4 + 1
end

-- TBG's key for what the game has in that slot: the totem's spell name,
-- "none" for an empty slot, or nil when it can't be read or isn't one of
-- this element's learned totems.
local function ReadTotemBarKey(page, elem)
    local action = CallAction(page, elem)
    if not action or not GetActionInfo then return end
    local actionType, id = GetActionInfo(action)
    if ns.IsSecretValue(actionType) or ns.IsSecretValue(id) then return end
    if not actionType then return "none" end
    if actionType ~= "spell" or not id then return end
    local name = ns.SpellName(id)
    for _, totem in ipairs(ns.GetElementTotems(elem)) do
        if totem.id == id or (name and totem.name == name) then return totem.name end
    end
end

-- Whether the game has sent the action bars yet: before it has, every slot
-- reads empty. Any action on any bar means they're in.
local function ActionBarsLoaded()
    if not HasAction then return false end
    for action = 1, TOTEM_BAR_START + 4 * #ns.callSpells do
        local has = HasAction(action)
        if ns.IsSecretValue(has) then return false end
        if has then return true end
    end
    return false
end

-- Adopts the game's choices into each Call's saved set, an empty slot as
-- "No Totem". slots: { [elem] = page }, or nil for every slot of every Call.
-- Returns true if any Call's set changed. Reading the bar works whether or
-- not Blizzard's totem bar is shown: these are the game's action slots, not
-- its frames.
function ns.FollowTotemBar(slots)
    if not TotemBarForGamepadDB or not ns.callWriters[1] then return false end
    -- A whole-bar read before the bars have loaded would see them all empty.
    local trustEmpty = slots ~= nil or ActionBarsLoaded()
    local changed = false
    for page = 1, #ns.callWriters do
        for elem = 1, 4 do
            if slots == nil or slots[elem] == page then
                local key = ReadTotemBarKey(page, elem)
                if key == "none" and not trustEmpty then key = nil end
                local set = TotemBarForGamepadDB.callSets[page]
                if key and set and set[elem] ~= key then
                    set[elem] = key
                    changed = true
                end
            end
        end
    end
    return changed
end

-- The spell a Call's writer puts into the game's slot (0 = empty).
local function WriteCallSlot(page, elem, spellID)
    if InCombatLockdown() or not ns.callWriters[page] then return end
    ns.callWriters[page][elem]:SetAttribute("spell1", spellID or 0)
end

-- The macro a flyout choice runs to write its Call's slot in the game's totem
-- bar (the secure click code rebuilds it for the current Call).
local function ApplyMacro(page, elem)
    local writer = ns.callWriters[page] and ns.callWriters[page][elem]
    return writer and ("/click " .. writer:GetName() .. " LeftButton") or nil
end

-- Blizzard's totem flyout: a slim column with a cap and close tab at the
-- far end. Art is drawn for an upward flyout; other directions rotate it.
-- A tab button (Blizzard's open/close flyout tabs): 28x18 art with a 20x11
-- highlight, sized explicitly so the art can be rotated with the flyout.
local function CreateFlyoutTab(parent, highlight)
    local tab = CreateFrame("Button", nil, parent, "SecureHandlerClickTemplate")
    tab:SetSize(28, 18)
    tab:RegisterForClicks("LeftButtonUp")
    tab.art = tab:CreateTexture(nil, "ARTWORK")
    tab.art:SetPoint("CENTER")
    tab.art:SetSize(28, 18)
    tab.glow = tab:CreateTexture(nil, "HIGHLIGHT")
    tab.glow:SetPoint("CENTER")
    tab.glow:SetSize(20, 11)
    tab.glow:SetBlendMode("ADD")
    SetTotemArt(tab.glow, highlight)
    return tab
end

-- Points a tab along the flyout direction (art is drawn for upward flyouts).
local function OrientTab(tab, rotation, sideways)
    tab:SetSize(sideways and 18 or 28, sideways and 28 or 18)
    tab.art:SetRotation(rotation)
    tab.glow:SetRotation(rotation)
end

-- The column and cap come in two copies: Blizzard's, which runs under the
-- close tab, and a shorter one for Totem Bar Focus (no close tab), with
-- as little room past the last choice as before the first. The flyout's
-- secure show code picks one, so it can switch in combat (secure code can
-- show frames, not move textures).
local FOCUS_ART_TRIM = 6
local function AddTotemFlyoutArt(flyout)
    for _, key in ipairs({ "standardArt", "focusArt" }) do
        local holder = CreateFrame("Frame", nil, flyout, "SecureHandlerBaseTemplate")
        holder:SetAllPoints(flyout)
        holder:SetFrameLevel(flyout:GetFrameLevel())
        holder.cap = holder:CreateTexture(nil, "BACKGROUND")
        holder.column = holder:CreateTexture(nil, "BACKGROUND")
        flyout[key] = holder
    end
    flyout.focusArt:Hide()
    -- The close tab at the far end closes the flyout, as on Blizzard's bar.
    flyout.closeTab = CreateFlyoutTab(flyout, FLYOUT_HIGHLIGHTS.close)
    flyout.closeTab:SetAttribute("_onclick", [[ self:GetParent():Hide() ]])
end

-- Blizzard's flyout geometry, in distance from the button edge it opens
-- from: the flyout starts flush with the button and is 26 per entry + 22 long
-- (4 before the first entry, 2 after the last, the 18px close tab); its middle
-- is 30 shorter than the flyout, with the 20px cap right after it; the close
-- tab ends flush with the far edge; the open tab sits on the button edge.
-- All centered across.
local FLYOUT_AXIS = {
    UP = { edge = "TOP", start = "BOTTOM", dx = 0, dy = 1, rotation = 0 },
    DOWN = { edge = "BOTTOM", start = "TOP", dx = 0, dy = -1, rotation = math.pi },
    RIGHT = { edge = "RIGHT", start = "LEFT", dx = 1, dy = 0, rotation = -math.pi / 2 },
}

local function LayoutTotemFlyout(flyout, anchor, direction, count)
    count = math.max(1, count)
    local axis = FLYOUT_AXIS[direction] or FLYOUT_AXIS.UP
    local length = count * CHOICE_STEP + 2 + FLYOUT_CAP
    local sideways = direction == "RIGHT"
    local tab = flyout.closeTab
    local opener = anchor.flyoutOpener
    for _, region in ipairs({ tab, opener }) do region:ClearAllPoints() end

    -- This element's colors (slots can change element with the slot order).
    local art = FLYOUT_ART_BY_ELEMENT[anchor.element or WEAPON_FLYOUT_ELEMENT]
    SetTotemArt(tab.art, art.closeTab)
    SetTotemArt(opener.art, art.openTab)

    flyout:ClearAllPoints()
    if sideways then flyout:SetSize(length, FLYOUT_WIDTH) else flyout:SetSize(FLYOUT_WIDTH, length) end
    flyout:SetPoint(axis.start, anchor, axis.edge, 0, 0)

    -- Centers along the flyout, from its button-side edge.
    local function Place(region, distance)
        region:SetPoint("CENTER", flyout, axis.start, axis.dx * distance, axis.dy * distance)
    end
    for _, set in ipairs({ { flyout.standardArt, 0 }, { flyout.focusArt, FOCUS_ART_TRIM } }) do
        local holder, trim = set[1], set[2]
        local cap, column = holder.cap, holder.column
        cap:ClearAllPoints()
        column:ClearAllPoints()
        SetTotemArt(cap, art.cap)
        SetTotemArt(column, art.column)
        local middle = length - FLYOUT_CAP - 10 - trim
        -- Rotated textures keep their own size, so sizes are given as for "UP".
        column:SetSize(FLYOUT_WIDTH, middle)
        cap:SetSize(FLYOUT_WIDTH, FLYOUT_CAP)
        Place(column, middle / 2)
        Place(cap, middle + FLYOUT_CAP / 2)
        cap:SetRotation(axis.rotation)
        column:SetRotation(axis.rotation)
    end
    Place(tab, length - 9)
    opener:SetPoint("CENTER", anchor, axis.edge, axis.dx * 9, axis.dy * 9)

    OrientTab(tab, axis.rotation, sideways)
    OrientTab(opener, axis.rotation, sideways)

    for index, choice in ipairs(flyout.buttons) do
        choice:ClearAllPoints()
        Place(choice, 4 + ns.TOTEM_CHOICE_SIZE / 2 + (index - 1) * CHOICE_STEP)
    end
end

local function FlyoutDirection(isVertical)
    if isVertical then return "RIGHT" end
    return TotemBarForGamepadDB.flyoutsOpenDown and "DOWN" or "UP"
end

-- The flyout behavior Blizzard's bar shares between its buttons: hovering a
-- button shows its open tab (one tab at a time), the tab opens the flyout,
-- and only one flyout is open at a time. It closes from its close tab, the
-- open tab, a choice, or a cast from its button; TBG also closes it a moment
-- after the mouse has left. Closing while still over the button brings the
-- open tab back. showTooltip(button) is the button's own tooltip (out of combat).
local function CreateFlyoutShell(slot, frameName, showTooltip)
    -- A child of the bar, so it follows the bar's Edit Mode scale.
    local flyout = CreateFrame("Frame", frameName, ns.bar,
        "SecureHandlerShowHideTemplate")
    flyout:SetFrameStrata("HIGH")
    AddTotemFlyoutArt(flyout)
    flyout:EnableMouse(true)
    flyout:Hide()
    flyout.buttons = {}
    slot.flyout = flyout

    local opener = CreateFlyoutTab(ns.bar, FLYOUT_HIGHLIGHTS.open)
    opener:SetFrameLevel(slot:GetFrameLevel() + 5)
    opener:Hide()
    slot.flyoutOpener = opener
    ns.flyoutSelectors[#ns.flyoutSelectors + 1] = { flyout = flyout, opener = opener }

    SecureHandlerSetFrameRef(flyout, "slot", slot)
    SecureHandlerSetFrameRef(flyout, "opener", opener)
    SecureHandlerSetFrameRef(opener, "flyout", flyout)
    SecureHandlerSetFrameRef(opener, "slot", slot)
    flyout:SetAttribute("close-delay", FLYOUT_CLOSE_DELAY)
    opener:SetAttribute("_onclick", [[
        local flyout = self:GetFrameRef("flyout")
        if flyout:IsShown() then
            flyout:Hide()
            return
        end
        if not flyout:GetAttribute("can-open") then return end
        flyout:Show()
        flyout:RegisterAutoHide(flyout:GetAttribute("close-delay"))
        flyout:AddToAutoHide(self:GetFrameRef("slot"))
        for _, choice in ipairs(newtable(flyout:GetChildren())) do
            if choice:IsShown() then flyout:AddToAutoHide(choice) end
        end
        self:Hide()
    ]])
    -- In Totem Bar Focus (which opens one flyout at a time itself),
    -- B and the D-pad close the flyout, so it has no close tab and uses
    -- the shorter art. Otherwise one flyout at a time: opening this one
    -- closes the others.
    SecureHandlerSetFrameRef(flyout, "close-tab", flyout.closeTab)
    SecureHandlerSetFrameRef(flyout, "standard-art", flyout.standardArt)
    SecureHandlerSetFrameRef(flyout, "focus-art", flyout.focusArt)
    flyout:SetAttribute("_onshow", [[
        local closeTab, standard, focusArt = self:GetFrameRef("close-tab"),
            self:GetFrameRef("standard-art"), self:GetFrameRef("focus-art")
        if self:GetAttribute("kit-grid-open") then
            closeTab:Hide()
            standard:Hide()
            focusArt:Show()
            return
        end
        closeTab:Show()
        standard:Show()
        focusArt:Hide()
        for i = 1, self:GetAttribute("peer-count") or 0 do
            local other = self:GetFrameRef("peer-flyout-" .. i)
            if other and other:IsShown() and not other:GetAttribute("kit-grid-open") then other:Hide() end
        end
    ]])
    flyout:SetAttribute("_onhide", [[
        self:UnregisterAutoHide()
        local slot = self:GetFrameRef("slot")
        if self:GetAttribute("can-open") and slot:IsVisible() and slot:IsUnderMouse(true) then
            local opener = self:GetFrameRef("opener")
            opener:Show()
            opener:RegisterAutoHide(0.3)
            opener:AddToAutoHide(slot)
        end
    ]])
    -- Casting from the button closes its flyout (Blizzard: PostClick).
    SecureHandlerWrapScript(slot, "OnClick", flyout, [[
        if control:IsShown() and not control:GetAttribute("kit-grid-open") then control:Hide() end
    ]])

    slot:SetScript("OnEnter", function(self)
        if InCombatLockdown() then return end
        showTooltip(self)
    end)
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Hovering shows the open tab (kept while over the button or the tab).
    -- One tab at a time, as Blizzard's bar has a single one: the others go.
    SecureHandlerWrapScript(slot, "OnEnter", flyout, [[
        for i = 1, control:GetAttribute("peer-count") or 0 do
            local other = control:GetFrameRef("peer-opener-" .. i)
            if other then other:Hide() end
        end
        if control:GetAttribute("can-open") and not control:IsShown() then
            local opener = control:GetFrameRef("opener")
            opener:Show()
            opener:RegisterAutoHide(0.3)
            opener:AddToAutoHide(self)
        end
    ]])
    return flyout
end

local function CreateFlyoutChoice(name, flyout)
    local btn = CreateFrame("Button", name, flyout, "SecureActionButtonTemplate")
    btn:SetSize(ns.TOTEM_CHOICE_SIZE, ns.TOTEM_CHOICE_SIZE)
    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon:SetAllPoints()
    btn:SetHighlightTexture(130718, "ADD") -- Interface\Buttons\ButtonHilight-Square, as Blizzard's
    btn:RegisterForClicks("LeftButtonUp")
    -- Act on the release it is registered for. Otherwise, with the game's
    -- ActionButtonUseKeyDown on, the secure action (writing the game's
    -- totem bar) waits for a press that never arrives.
    btn:SetAttribute("useOnKeyDown", false)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

-- Picking a choice, in secure code so it works in combat. What a choice holds
-- (attributes, set by UpdateLayout): "choice-key" (TBG's saved key for it),
-- "choice-spell" (what the button casts from now on) and, for totems,
-- "choice-call-spell" (the spell ID written into the game's totem bar).
-- The flyout (control) refers to its button ("slot"), the button's macro
-- proxy and the Call writers of its element.
local CHOOSE_SNIPPET = [[
    if button ~= "LeftButton" or down or not self:IsVisible() then return false end
    local key = self:GetAttribute("choice-key")
    if not key then return false end
    local spell = self:GetAttribute("choice-spell")
    local owner = control:GetFrameRef("slot")
    owner:SetAttribute("spell1", spell)
    owner:SetAttribute("tbg-assigned-key", key)
    local proxy = control:GetFrameRef("cast-proxy")
    if proxy then proxy:SetAttribute("spell1", spell) end

    -- Totems also become the current Call's pick: kept per Call on the
    -- button for the Call switcher, and written into the game's totem bar by
    -- this choice's own macro action, which clicks the Call's writer.
    local summon = control:GetFrameRef("summon")
    if summon then
        local call = summon:GetAttribute("call-page") or 1
        owner:SetAttribute("page" .. call .. "-spell", spell)
        owner:SetAttribute("page" .. call .. "-key", key)
        local writer = control:GetFrameRef("call-writer" .. call)
        if writer then
            writer:SetAttribute("spell1", self:GetAttribute("choice-call-spell") or 0)
            self:SetAttribute("macrotext1", "/click " .. writer:GetName() .. " LeftButton")
        end
    end
    -- Totem Bar Focus keeps the flyout open while it browses.
    if not control:GetAttribute("kit-grid-open") then control:Hide() end
    control:CallMethod("OnChoicePicked", key, spell)
]]

-- A selector flyout (totems of one element, or weapon enhancements): up to
-- eight choices, "No Totem" first on totem slots. onPicked(key, spell) runs
-- after the secure code has switched what the button casts.
local MAX_CHOICES = 8
local function CreateChoiceFlyout(owner, frameName, choicePrefix, onPicked)
    local flyout = CreateFlyoutShell(owner, frameName, function(self)
        local spell = owner.chosenSpell
        if spell then ns.ShowTooltipForSpell(self, owner.knownIDs and owner.knownIDs[spell] or spell) end
    end)
    function flyout:OnChoicePicked(key, spell) onPicked(key, spell) end

    local function ShowChoiceTooltip(choice)
        if choice.choiceKey == "none" then
            ns.ShowNoTotemTooltip(choice)
        elseif choice.spellID or choice.spellName then
            ns.ShowTooltipForSpell(choice, choice.spellID or choice.spellName)
        end
    end
    for index = 1, MAX_CHOICES do
        local choice = CreateFlyoutChoice(choicePrefix .. index, flyout)
        choice:SetScript("OnEnter", ShowChoiceTooltip)
        SecureHandlerWrapScript(choice, "OnClick", flyout, CHOOSE_SNIPPET)
        flyout.buttons[index] = choice
    end
end

-- The four totem slots. Each one's template cooldown is the placed totem's
-- swipe (TotemTimers.lua); a second cooldown frame shows the spell's own
-- cooldown, as on Blizzard's bar (ns.UpdateSlotSwipe).
local function CreateTotemSlot(slotIndex)
    local slot = CreateBarButton("TotemBarForGamepadSlot" .. slotIndex)
    slot.slotIndex = slotIndex
    slot:RegisterForClicks("AnyUp", "AnyDown")
    slot:SetAttribute("type1", "spell")
    slot.spellCooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    slot.spellCooldown:SetAllPoints(slot.cooldown)
    slot.spellCooldown:SetFrameLevel(slot.cooldown:GetFrameLevel())

    -- A pick replaces the current Call's choice for the slot's element; a
    -- totem already down stays down.
    CreateChoiceFlyout(slot, "TotemBarForGamepadFlyout" .. slotIndex,
        "TotemBarForGamepadFlyoutBtn_" .. slotIndex .. "_", function(key, spell)
            local db = TotemBarForGamepadDB
            local elem, call = db.elementOrder[slotIndex], db.activeCall
            db.activeCallSet[elem] = key
            slot.chosenSpell = spell
            slot.pageSpellNames[call] = spell
            WriteCallSlot(call, elem, spell and slot.knownIDs[spell])
            ns.UpdateSlotLook(slotIndex)
            ns.UpdateSpellCooldowns()
            GameTooltip:Hide()
            ns.UpdateMacroIcons()
        end)
    slot.pageSpellNames = {}
    slot.knownIDs = {}
    return slot
end

for slotIndex = 1, 4 do ns.slots[slotIndex] = CreateTotemSlot(slotIndex) end

-- Blizzard's summon button: casts the current Call; its neutral flyout is the
-- Call switcher. Switching reloads the slots (and their macros and Totem Bar Focus)
-- from that Call's set, in secure code so it works in combat.
local CALL_CHOICE_SNIPPET = [[
    if button ~= "LeftButton" or down or not self:IsVisible() then return false end
    local page = self:GetAttribute("call-page")
    if not page then return false end
    local summon = control:GetFrameRef("slot")
    summon:SetAttribute("call-page", page)
    summon:SetAttribute("spell1", self:GetAttribute("call-spell"))
    -- Totem Bar Focus's tooltip marks the current Call with this.
    summon:SetAttribute("tbg-assigned-key", page)
    for i = 1, 4 do
        local slot = control:GetFrameRef("totem-slot" .. i)
        if slot then
            local spell = slot:GetAttribute("page" .. page .. "-spell")
            slot:SetAttribute("spell1", spell)
            local proxy = control:GetFrameRef("totem-proxy" .. i)
            if proxy then proxy:SetAttribute("spell1", spell) end
            slot:SetAttribute("tbg-assigned-key", slot:GetAttribute("page" .. page .. "-key"))
        end
    end
    -- While Totem Bar Focus is open, keep every column visible.
    if not control:GetAttribute("kit-grid-open") then control:Hide() end
    control:CallMethod("OnCallPage", page)
    return false
]]

local function ShowBarSpellTooltip(self)
    if self.spellName then ns.ShowTooltipForSpell(self, self.spellID or self.spellName) end
end

ns.summonButton = CreateBarButton("TotemBarForGamepadSummon")
ns.summonButton:RegisterForClicks("AnyUp", "AnyDown")
ns.summonButton:SetAttribute("call-page", 1)
ns.summonButton:Hide()
do
    local callFlyout = CreateFlyoutShell(ns.summonButton, "TotemBarForGamepadCallFlyout", ShowBarSpellTooltip)
    function callFlyout:OnCallPage(page) ns.SetCallPage(page) end
    for index = 1, #ns.callSpells do
        local btn = CreateFlyoutChoice("TotemBarForGamepadCallChoice" .. index, callFlyout)
        btn:SetScript("OnEnter", function(self)
            if self.call then ns.ShowTooltipForSpell(self, ns.callSpells[self.call].id) end
        end)
        SecureHandlerWrapScript(btn, "OnClick", callFlyout, CALL_CHOICE_SNIPPET)
        callFlyout.buttons[index] = btn
    end
end

ns.recallButton = CreateBarButton("TotemBarForGamepadRecall")
ns.recallButton:RegisterForClicks("AnyUp", "AnyDown")
ns.recallButton:SetScript("OnEnter", ShowBarSpellTooltip)
ns.recallButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
-- Recalling from TBG's bar: no "totem gone" alerts. In combat the cast
-- event can't say it was Totemic Recall, but this press can.
-- (It acts on the press or the release, by the game's key-down setting.)
ns.recallButton:HookScript("PreClick", function() ns.QuietTotemAlerts(2) end)
ns.recallButton:Hide()

-- The weapon enhancement button (a TBG extra, with Blizzard's neutral art).
-- Its choices are keyed by spell ID.
local QUESTION_MARK_ICON = 134400
ns.enhancementButton = CreateBarButton("TotemBarForGamepadWeaponEnhancement")
ns.enhancementButton:RegisterForClicks("AnyUp", "AnyDown")
ns.enhancementButton:Hide()
CreateChoiceFlyout(ns.enhancementButton, "TotemBarForGamepadWeaponFlyout", "TotemBarForGamepadWeaponFlyoutChoice",
    function(spellID, spell)
        TotemBarForGamepadDB.weaponEnhancement = spellID
        ns.enhancementButton.chosenSpell = spell
        ns.enhancementButton.icon:SetTexture(ns.SpellIcon(ns.enhancementButton.knownIDs[spell] or spellID)
            or QUESTION_MARK_ICON)
        ns.UpdateSpellCooldowns()
        GameTooltip:Hide()
        ns.UpdateMacroIcons()
    end)

-- Every selector knows the others' open tabs and flyouts: hovering one hides
-- the other tabs, and opening one closes the other flyouts.
for _, selector in ipairs(ns.flyoutSelectors) do
    local count = 0
    for _, other in ipairs(ns.flyoutSelectors) do
        if other ~= selector then
            count = count + 1
            SecureHandlerSetFrameRef(selector.flyout, "peer-opener-" .. count, other.opener)
            SecureHandlerSetFrameRef(selector.flyout, "peer-flyout-" .. count, other.flyout)
        end
    end
    selector.flyout:SetAttribute("peer-count", count)
end

-- ---------------------------------------------------------------------------
-- Macro Cast Proxies (for "/click" macros on the gamepad action bar)
-- ---------------------------------------------------------------------------
-- Gamepad bindings are static, so gamepad casting goes through macros the
-- player places on the gamepad bar. "/click" delivers one release click, so the
-- proxies always act on release, like the Call writers above.
-- Proxies are keyed by element (not bar position), so reordering slots never
-- breaks a macro.
local function CreateCastProxy(name)
    local proxy = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    proxy:RegisterForClicks("LeftButtonUp")
    proxy:SetAttribute("useOnKeyDown", false)
    proxy:Hide()
    return proxy
end

ns.castProxies = {}
for elem = 1, 4 do
    ns.castProxies[elem] = CreateCastProxy("TotemBarForGamepadCast" .. ns.ELEMENT_NAMES[elem])
end
ns.weaponProxy = CreateCastProxy("TotemBarForGamepadCastWeapon")
SecureHandlerSetFrameRef(ns.enhancementButton.flyout, "cast-proxy", ns.weaponProxy)

-- The weapon enhancement button and its flyout: every learned enhancement,
-- in Definitions.lua's order. The pick is kept by its Definitions.lua spell
-- ID; one no longer known falls back to the first known. Tooltips and icons
-- show the learned rank (knownIDs: name -> that rank's spell ID). The macro proxy casts the pick
-- whether or not the button is on the bar. Returns whether the button shows.
local function UpdateEnhancementButton(spellbook, isVertical)
    local button, db = ns.enhancementButton, TotemBarForGamepadDB
    local learned, nameOf, rankOf = {}, {}, {}
    button.knownIDs = {}
    for _, spellID in ipairs(ns.imbueSpells) do
        local name = ns.LearnedSpellName(spellbook, spellID)
        if name then
            learned[#learned + 1] = spellID
            nameOf[spellID] = name
            rankOf[spellID] = ns.LearnedRankID(spellbook, spellID)
            button.knownIDs[name] = rankOf[spellID]
        end
    end
    if learned[1] and not nameOf[db.weaponEnhancement] then db.weaponEnhancement = learned[1] end
    local pick = db.weaponEnhancement
    ns.weaponProxy:SetAttribute("type1", nameOf[pick] and "spell" or nil)
    ns.weaponProxy:SetAttribute("spell1", nameOf[pick])

    local shown = db.showWeaponButton and learned[1] ~= nil
    local spell = shown and nameOf[pick] or nil
    button.chosenSpell = spell
    button.choiceCount = shown and #learned or 0
    button:SetAttribute("type1", spell and "spell" or nil)
    button:SetAttribute("spell1", spell)
    button:SetAttribute("tbg-assigned-key", spell and pick or nil)
    button.spellID = spell and rankOf[pick]
    button.icon:SetTexture(spell and ns.SpellIcon(rankOf[pick]) or QUESTION_MARK_ICON)
    button:SetShown(spell ~= nil)

    local flyout = button.flyout
    flyout:Hide()
    flyout:SetAttribute("can-open", shown)
    LayoutTotemFlyout(flyout, button, FlyoutDirection(isVertical), button.choiceCount)
    for index, choice in ipairs(flyout.buttons) do
        local spellID = shown and learned[index] or nil
        choice.choiceKey, choice.spellID = spellID, spellID and rankOf[spellID]
        choice.spellName = spellID and nameOf[spellID]
        choice:SetAttribute("choice-key", spellID)
        choice:SetAttribute("choice-spell", choice.spellName)
        choice.icon:SetTexture(spellID and ns.SpellIcon(rankOf[spellID]) or QUESTION_MARK_ICON)
        choice.icon:SetTexCoord(0, 1, 0, 1)
        choice:SetShown(spellID ~= nil)
    end
    ns.UpdateImbueTimer()
    return shown
end

-- One bar button that casts a fixed spell when learned (Recall, the summon
-- button's Call). Returns whether it shows.
local function SetButtonSpell(button, spellID, name)
    button.spellName, button.spellID = name, name and spellID
    button:SetAttribute("type1", name and "spell" or nil)
    button:SetAttribute("spell1", name)
    if name then button.icon:SetTexture(ns.SpellIcon(spellID) or QUESTION_MARK_ICON) end
    button:SetShown(name ~= nil)
    return name ~= nil
end

-- The summon button (casts the current Call), its switcher (every learned
-- Call) and Recall. Returns whether the summon and Recall buttons show.
local function UpdateCallButtons(spellbook)
    local db, summon = TotemBarForGamepadDB, ns.summonButton
    local learned = {}
    summon.callNames = {}
    for call, spell in ipairs(ns.callSpells) do
        local name = ns.LearnedSpellName(spellbook, spell.id)
        if name then
            learned[#learned + 1] = call
            summon.callNames[call] = name
        end
    end
    -- The current Call has to be a learned one.
    if learned[1] and not summon.callNames[db.activeCall] then
        db.activeCall = learned[1]
        db.activeCallSet = db.callSets[db.activeCall]
    end
    local current = db.activeCall
    local summonShown = SetButtonSpell(summon, ns.callSpells[current].id, summon.callNames[current])
    summon.choiceCount = #learned
    summon:SetAttribute("call-page", current)
    summon:SetAttribute("tbg-assigned-key", summonShown and current or nil)

    local flyout = summon.flyout
    flyout:Hide()
    flyout:SetAttribute("can-open", learned[1] ~= nil)
    for index, choice in ipairs(flyout.buttons) do
        local call = learned[index]
        choice.call = call
        choice.spellName = call and summon.callNames[call]
        choice.spellID = call and ns.callSpells[call].id
        choice:SetAttribute("call-page", call)
        choice:SetAttribute("call-spell", choice.spellName)
        -- For Totem Bar Focus: the choice's key, the spell X casts, and the
        -- macro A runs (a click on this choice, which switches the Call).
        choice.choiceKey = call
        choice:SetAttribute("choice-key", call)
        choice:SetAttribute("choice-spell", choice.spellName)
        choice:SetAttribute("macrotext1", call and ("/click " .. choice:GetName() .. " LeftButton") or nil)
        if call then
            choice.icon:SetTexture(ns.SpellIcon(choice.spellID) or QUESTION_MARK_ICON)
            choice.icon:SetTexCoord(0, 1, 0, 1)
        end
        choice:SetShown(call ~= nil)
    end

    local recallID = ns.recallSpell.id
    local recallShown = SetButtonSpell(ns.recallButton, recallID, ns.LearnedSpellName(spellbook, recallID))
    return summonShown, recallShown
end

-- Switches the current Call (from the switcher). The secure code has already
-- switched what the buttons cast; this updates the saved state and the looks.
-- In combat only the looks change; the rest waits for combat to end.
function ns.SetCallPage(call)
    local db = TotemBarForGamepadDB
    if not db or not db.callSets[call] then return end
    db.activeCall = call
    db.activeCallSet = db.callSets[call]
    if not InCombatLockdown() then
        ns.UpdateLayout()
        return
    end
    local summon = ns.summonButton
    summon.spellName = summon.callNames and summon.callNames[call]
    summon.spellID = summon.spellName and ns.callSpells[call].id
    if summon.spellName then summon.icon:SetTexture(ns.SpellIcon(summon.spellID) or QUESTION_MARK_ICON) end
    for slotIndex, slot in ipairs(ns.slots) do
        slot.chosenSpell = slot.pageSpellNames[call]
        ns.UpdateSlotLook(slotIndex)
    end
    ns.UpdateUsability()
    ns.UpdateSpellCooldowns()
    ns.UpdateMacroIcons()
    ns.relayoutAfterCombat = true
end

-- ---------------------------------------------------------------------------
-- Bar visibility
-- ---------------------------------------------------------------------------
-- As Blizzard's bar: hidden while a vehicle or override bar takes over (and
-- in pet battles), and when no element has a totem; always shown in Edit
-- Mode. A secure state driver, so vehicles hide it in combat too.
local barVisibility
local function UpdateBarVisibility(hasSlots)
    local condition
    if ns.IsEditModeActive() then
        condition = "show"
    elseif not hasSlots then
        condition = "hide"
    else
        condition = "[vehicleui][overridebar][petbattle] hide; show"
    end
    if condition == barVisibility then return end
    barVisibility = condition
    RegisterStateDriver(ns.bar, "visibility", condition)
end

-- Blizzard's own totem bar (and its totem timers), out of the way while TBG
-- replaces it: moved under a hidden frame, so nothing Blizzard shows later
-- brings it back. Their parents are remembered here, not on the frames.
local blizzardHider = CreateFrame("Frame", nil, UIParent)
blizzardHider:Hide()
local blizzardParents = {}
function ns.SetBlizzardTotemBarHidden(hidden)
    if InCombatLockdown() then return end
    for _, name in ipairs({ "MultiCastActionBarFrame", "TotemFrame" }) do
        local frame = _G[name]
        if frame and hidden and frame:GetParent() ~= blizzardHider then
            blizzardParents[frame] = frame:GetParent()
            frame:SetParent(blizzardHider)
        elseif frame and not hidden and blizzardParents[frame] then
            frame:SetParent(blizzardParents[frame])
            blizzardParents[frame] = nil
        end
    end
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------
ns.relayoutAfterCombat = false

-- Blizzard's order: summon button, the shown slots, Recall. The weapon
-- button (a TBG extra) goes on the outside of the chosen side.
local function BarOrder(shownSlots, summonShown, recallShown, enhancementShown)
    local order = {}
    local function Add(button) order[#order + 1] = button end
    local enhancementLeft = TotemBarForGamepadDB.weaponButtonSide == "LEFT"
    if enhancementShown and enhancementLeft then Add(ns.enhancementButton) end
    if summonShown then Add(ns.summonButton) end
    for _, slot in ipairs(shownSlots) do Add(slot) end
    if recallShown then Add(ns.recallButton) end
    if enhancementShown and not enhancementLeft then Add(ns.enhancementButton) end
    return order
end

-- Sizes the bar (and its Totem Bar Focus shadow) and lines the buttons up.
local function ArrangeBar(order, isVertical)
    local length = math.max(1, #order) * BUTTON_STEP - BUTTON_GAP + 2 * BAR_PADDING
    local depth = BUTTON_SIZE + 2 * BAR_PADDING
    -- The shadow atlas is drawn for a horizontal bar; a vertical one stretches it.
    if isVertical then
        ns.bar:SetSize(depth, length)
        ns.barShadow:SetSize(depth + 2 * SHADOW_ACROSS, length + 2 * SHADOW_ALONG)
    else
        ns.bar:SetSize(length, depth)
        ns.barShadow:SetSize(length + 2 * SHADOW_ALONG, depth + 2 * SHADOW_ACROSS)
    end
    for index, button in ipairs(order) do
        local offset = BAR_PADDING + (index - 1) * BUTTON_STEP
        button:ClearAllPoints()
        if isVertical then
            button:SetPoint("TOP", ns.bar, "TOP", 0, -offset)
        else
            button:SetPoint("LEFT", ns.bar, "LEFT", offset, 0)
        end
    end
end

-- One flyout choice: "No Totem" (entry "none"), a totem { id, name }, or
-- nothing (hidden). writeMacro writes the current Call's slot in the game.
local function SetTotemChoice(choice, entry, elem, writeMacro)
    choice:SetAttribute("type1", entry and writeMacro and "macro" or nil)
    choice:SetAttribute("macrotext1", entry and writeMacro or nil)
    local totem = type(entry) == "table" and entry or nil
    choice.choiceKey = entry and (totem and totem.name or "none")
    choice.spellName = totem and totem.name
    choice.spellID = totem and totem.id
    choice:SetAttribute("choice-key", choice.choiceKey)
    choice:SetAttribute("choice-spell", choice.spellName)
    choice:SetAttribute("choice-call-spell", totem and totem.id or 0)
    if totem then
        choice.icon:SetTexture(ns.SpellIcon(totem.id) or QUESTION_MARK_ICON)
        choice.icon:SetTexCoord(0, 1, 0, 1)
    elseif entry then
        SetTotemArt(choice.icon, SLOT_EMPTY_COORDS[elem])
    end
    choice:SetShown(entry ~= nil)
end

-- A totem slot for its element: every Call's pick (the game's totem bar, as
-- followed by ns.FollowTotemBar; no pick, or one that isn't learned, shows
-- as "No Totem", since the game's bar would drop nothing; an unlearned pick
-- stays saved, in case the spellbook just hasn't loaded), what it casts now, its macro
-- proxy, the secure references its flyout and the Call switcher use, and
-- its flyout: "No Totem" next to the button, then the learned totems in the
-- game's order (as on Blizzard's totem bar).
local function UpdateTotemSlot(slotIndex, totems, shown, isVertical)
    local db = TotemBarForGamepadDB
    local slot, elem, current = ns.slots[slotIndex], db.elementOrder[slotIndex], db.activeCall
    slot.element = elem
    slot.choiceCount = #totems
    slot.knownIDs = {}
    for _, totem in ipairs(totems) do slot.knownIDs[totem.name] = totem.id end

    local currentKey
    for call = 1, #ns.callSpells do
        local key = db.callSets[call][elem]
        if key ~= "none" and not slot.knownIDs[key] then key = "none" end
        if call == current then currentKey = key end
        local spell = key ~= "none" and key or nil
        slot.pageSpellNames[call] = spell
        slot:SetAttribute("page" .. call .. "-spell", spell)
        slot:SetAttribute("page" .. call .. "-key", key)
        WriteCallSlot(call, elem, spell and slot.knownIDs[spell])
    end
    slot.chosenSpell = slot.pageSpellNames[current]
    slot:SetAttribute("spell1", slot.chosenSpell)
    slot:SetAttribute("tbg-assigned-key", currentKey)
    SetTotemArt(slot.border, SLOT_BORDER_COORDS[elem])

    local proxy = ns.castProxies[elem]
    proxy:SetAttribute("type1", "spell")
    proxy:SetAttribute("spell1", slot.chosenSpell)
    local flyout = slot.flyout
    SecureHandlerSetFrameRef(flyout, "cast-proxy", proxy)
    SecureHandlerSetFrameRef(flyout, "summon", ns.summonButton)
    for call = 1, #ns.callSpells do
        SecureHandlerSetFrameRef(flyout, "call-writer" .. call, ns.callWriters[call][elem])
    end
    SecureHandlerSetFrameRef(ns.summonButton.flyout, "totem-slot" .. slotIndex, slot)
    SecureHandlerSetFrameRef(ns.summonButton.flyout, "totem-proxy" .. slotIndex, proxy)

    local entries = {}
    if totems[1] then entries[1] = "none" end
    for _, totem in ipairs(totems) do
        if #entries < MAX_CHOICES then entries[#entries + 1] = totem end
    end
    flyout:Hide()
    flyout:SetAttribute("can-open", entries[1] ~= nil)
    LayoutTotemFlyout(flyout, slot, FlyoutDirection(isVertical), #entries)
    local writeMacro = ApplyMacro(current, elem)
    for index, choice in ipairs(flyout.buttons) do SetTotemChoice(choice, entries[index], elem, writeMacro) end

    slot:SetShown(shown)
    ns.UpdateSlotLook(slotIndex)
end

-- Rebuilds the bar from the spellbook and the saved settings. Out of combat
-- only; a call in combat runs once combat ends.
function ns.UpdateLayout()
    if InCombatLockdown() then
        ns.relayoutAfterCombat = true
        return
    end
    ns.relayoutAfterCombat = false
    local db = TotemBarForGamepadDB
    local isVertical = db.barOrientation == "VERTICAL"
    local spellbook = ns.ReadSpellbook()
    local summonShown, recallShown = UpdateCallButtons(spellbook)
    local enhancementShown = UpdateEnhancementButton(spellbook, isVertical)

    -- In Edit Mode every slot shows, so the bar can be placed at full size.
    local showEmpty = ns.IsEditModeActive() or not db.hideEmptyElements
    local shownSlots = {}
    for slotIndex = 1, 4 do
        local totems = ns.GetElementTotems(db.elementOrder[slotIndex])
        local shown = totems[1] ~= nil or showEmpty
        if shown then shownSlots[#shownSlots + 1] = ns.slots[slotIndex] end
        UpdateTotemSlot(slotIndex, totems, shown, isVertical)
    end

    local order = BarOrder(shownSlots, summonShown, recallShown, enhancementShown)
    ArrangeBar(order, isVertical)
    -- The default spot depends on the bar's height (EditMode.lua).
    if db.offsetY == nil and ns.ApplyBarPosition then ns.ApplyBarPosition() end
    LayoutTotemFlyout(ns.summonButton.flyout, ns.summonButton, FlyoutDirection(isVertical), ns.summonButton.choiceCount)
    UpdateBarVisibility(shownSlots[1] ~= nil)

    ns.UpdateBarFocus(order, isVertical)
    ns.RefreshOpenBarFocus()
    ns.UpdateHotkeys()
    ns.UpdateUsability()
    ns.UpdateSpellCooldowns()
    ns.UpdateMacroIcons()
end
