local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Totem Bar Focus
-- ---------------------------------------------------------------------------
-- A "/click TotemBarForGamepadFocus" macro on the gamepad bar puts the
-- gamepad on the bar itself, built on GamepadKit's secure grid (works in
-- combat). It opens on the "First Focus" button (Options > AddOns; the first
-- one by default). Left/Right moves along the bar (the Call switcher, the
-- totems, Recall, the weapon enhancement). Up or Y opens the focused
-- button's flyout and enters it; Down past its first choice, or Y, closes it
-- and returns to the bar (a flyout is open only while the focus is in it).
-- A selects and X casts: in a flyout A selects (and casts, with "Cast When
-- Selected") and X casts once without selecting; on the bar both cast the
-- button's spell. B closes. Options in Settings (ns.ApplyBarFocusOptions).
local Kit = ns.GamepadKit

-- The native art has padding around the button, so it needs a larger size
-- than the 14px binding glyphs to read at the same size in a tooltip line.
local TOOLTIP_GLYPH_SIZE = 20

-- Columns as TotemBarForGamepad sees them (kind, element), parallel to the grid's.
ns.barFocusColumns = {}

-- Hint words, Blizzard's own where it has one (its gamepad prompts label A
-- "Select", ACTION_LABEL_SELECT), so they match the game and its languages.
local function GameString(value, fallback)
    return type(value) == "string" and value ~= "" and value or fallback
end
local LABEL_SELECT = GameString(ACTION_LABEL_SELECT, "Select")
local LABEL_CAST = "Cast"
local LABEL_SELECT_CAST = LABEL_SELECT .. " & " .. LABEL_CAST
local LABEL_BACK = GameString(BACK, "Back")
local LABEL_CLOSE = GameString(CLOSE, "Close")
-- Blizzard's prompt divider between buttons that do the same thing: the
-- "gamepad-symbols-slash" atlas (16x24). The button glyphs carry transparent
-- padding (a 20 tall glyph shows a ~16 tall button) and the slash doesn't,
-- so it's sized to the visible button, not the glyph. Plain "/" if missing.
local SLASH_HEIGHT = math.floor(TOOLTIP_GLYPH_SIZE * 0.8 + 0.5)
local NUDGE_COLOR = CreateColor and CreateColor(1, 0.5, 0.25) or { WrapTextInColorCode = function(_, text) return text end }
local PROMPT_SLASH = "/"
if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("gamepad-symbols-slash") then
    PROMPT_SLASH = string.format("|A:gamepad-symbols-slash:%d:%d|a", SLASH_HEIGHT,
        math.floor(SLASH_HEIGHT * 16 / 24 + 0.5))
end

-- Text for a button whose glyph can't be shown.
local GLYPH_FALLBACK = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADDUP = "Up", PADDDOWN = "Down", PADDRIGHT = "Right" }
local function PadGlyph(key)
    return Kit.Glyph(key, TOOLTIP_GLYPH_SIZE, GLYPH_FALLBACK[key])
end

-- What a bar button casts (row 0): its spell, or nothing (e.g. "No Totem").
local function BarButtonSpell(button)
    local spell = button:GetAttribute("spell1")
    if not spell then return nil end
    return button.knownIDs and button.knownIDs[spell] or button.spellID or spell
end

local function ShowBarFocusTooltip(col, row)
    local column = ns.barFocusColumns[col]
    if not column then
        GameTooltip:Hide()
        return
    end
    GameTooltip:SetOwner(ns.bar, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
    -- The hint lists only what works here: nothing casts without a spell.
    -- Buttons that do the same thing are joined with Blizzard's slash.
    local hints = {}
    local function Hint(text, ...)
        local glyphs = {}
        for i = 1, select("#", ...) do glyphs[i] = PadGlyph(select(i, ...)) end
        hints[#hints + 1] = table.concat(glyphs, PROMPT_SLASH) .. " " .. text
    end
    if row == 0 then
        local spell = BarButtonSpell(column.button)
        if spell then
            ns.SetSpellTooltipContent(spell)
        else
            GameTooltip:SetText(ns.NO_TOTEM_TEXT, 1, 1, 1)
        end
        if spell then Hint(LABEL_CAST, "PAD1", "PAD3") end
        -- Into the flyout: the D-pad toward it, or Y (both open it and enter).
        if #column.choices > 0 then
            local into = (TotemBarForGamepadDB.barOrientation == "VERTICAL" and "PADDRIGHT")
                or (TotemBarForGamepadDB.flyoutsOpenDown and "PADDDOWN" or "PADDUP")
            Hint(LABEL_SELECT, into, "PAD4")
        end
    else
        local choice = column.choices[row]
        if not choice then
            GameTooltip:Hide()
            return
        end
        if choice.spellName then
            ns.SetSpellTooltipContent(choice.spellID or choice.spellName)
        else
            GameTooltip:SetText(ns.NO_TOTEM_TEXT, 1, 1, 1)
        end
        if choice.choiceKey == column.button:GetAttribute("tbg-assigned-key") then
            GameTooltip:AddLine("Currently selected", 0.4, 1, 0.4)
        end
        Hint(choice.spellName and ns.BarFocusSelectCasts(col) and LABEL_SELECT_CAST or LABEL_SELECT, "PAD1")
        if choice.spellName then Hint(LABEL_CAST, "PAD3") end
        Hint(LABEL_BACK, "PAD4")
    end
    if ns.barFocusGrid and ns.barFocusGrid:IsNudging() then
        -- Nudge (you seem to have moved on, in combat): B Close first, highlighted.
        table.insert(hints, 1, PadGlyph("PAD2") .. " " .. NUDGE_COLOR:WrapTextInColorCode(LABEL_CLOSE))
    else
        Hint(LABEL_CLOSE, "PAD2")
    end
    GameTooltip:AddLine(table.concat(hints, "   "), 1, 1, 1)
    GameTooltip:Show()

    -- Keep the tooltip off the bar and its open flyout.
    local avoid = {}
    for _, c in ipairs(ns.barFocusColumns) do
        if c.flyout then avoid[#avoid + 1] = c.flyout end
    end
    local order
    if TotemBarForGamepadDB.barOrientation == "VERTICAL" then
        order = { "left", "right", "above", "below" }
    elseif TotemBarForGamepadDB.flyoutsOpenDown then
        order = { "above", "pastBottom", "right", "left" }
    else
        order = { "below", "pastTop", "right", "left" }
    end
    Kit.PlaceTooltip(GameTooltip, ns.bar, avoid, order, 0)
end

-- A: same effect as clicking the choice in its flyout, without closing.
-- Frame refs owner/choice come from the grid; proxy/writer/kind are ours.
local ASSIGN_SNIPPET = [[
    local col, row = self:GetAttribute("col"), self:GetAttribute("row")
    local choice = col and row and self:GetFrameRef("choice-" .. col .. "-" .. row)
    if not choice then return end
    local key, name = choice:GetAttribute("choice-key"), choice:GetAttribute("choice-spell")
    -- "No Totem" has a key and no spell: it empties the slot and the call set.
    if not key then return end
    -- A Call: the choice's macro (run after this) clicks it, which switches the Call.
    if self:GetAttribute("kind-" .. col) == "call" then return end
    local button = self:GetFrameRef("owner-" .. col)
    local isTotem = self:GetAttribute("kind-" .. col) == "totem"
    local summon = self:GetFrameRef("summon-" .. col)
    local page = summon and summon:GetAttribute("call-page") or 1
    button:SetAttribute("spell1", name)
    local proxy = self:GetFrameRef("proxy-" .. col)
    if proxy then proxy:SetAttribute("spell1", name) end
    if isTotem then
        -- The current Call's writer; the choice's macro (run after this,
        -- see primaryMacroAttribute) writes that slot in the game.
        local writer = self:GetFrameRef("writer" .. page .. "-" .. col)
        if writer then
            writer:SetAttribute("spell1", choice:GetAttribute("choice-call-spell") or 0)
            choice:SetAttribute("macrotext1", "/click " .. writer:GetName() .. " LeftButton")
        end
        button:SetAttribute("page" .. page .. "-spell", name)
    end
    if isTotem then button:SetAttribute("page" .. page .. "-key", key) end
    button:SetAttribute("tbg-assigned-key", key)
    self:CallMethod("OnBarFocusAssign", col, key, name)
]]

ns.barFocusGrid = Kit.CreateSecureGrid("TotemBarForGamepadFocus", {
    focusParent = ns.bar,
    focusSize = ns.TOTEM_CHOICE_SIZE,
    ownerFocusSize = ns.BAR_BUTTON_SIZE,
    -- On the bar, A and X cast what the button casts.
    ownerSpellAttribute = "spell1",
    primary = ASSIGN_SNIPPET,
    -- A also writes the game's totem bar, like clicking the choice.
    primaryMacroAttribute = "macrotext1",
    secondary = { spellAttribute = "choice-spell" },
    onOpen = function() GameTooltip:Hide() end,
    onClose = function() GameTooltip:Hide() end,
    onFocus = ShowBarFocusTooltip,
    -- Forgot Totem Bar Focus was open: after 5s without its input while
    -- doing other things it closes (in combat: nudges); 10s of no input
    -- at all closes it out of combat.
    autoClose = {
        grace = 5,
        idle = 10,
        onNudge = function()
            local col, row = ns.barFocusGrid:GetFocus()
            if col then ShowBarFocusTooltip(col, row or 0) end
        end,
    },
    -- The bar grows around its center and gets its shadow while focused.
    openSnippet = [[ self:RunAttribute("tbg-bar-focus", self:GetAttribute("tbg-focus-scale")) ]],
    closeSnippet = [[ self:RunAttribute("tbg-bar-focus", 1) ]],
})
ns.barFocus = ns.barFocusGrid.header
SecureHandlerSetFrameRef(ns.barFocus, "tbg-bar", ns.bar)
SecureHandlerSetFrameRef(ns.barFocus, "tbg-bar-shadow", ns.barShadow)
ns.barFocus:SetAttribute("tbg-focus-scale", ns.FOCUS_SCALE)
-- Scales the bar by `factor` around its center (position and scale come
-- from ns.SetBarFocusRestPosition), showing the shadow when it's above 1.
ns.barFocus:SetAttribute("tbg-bar-focus", [[
    local factor = ...
    local scale = (self:GetAttribute("tbg-bar-scale") or 1) * factor
    local bar = self:GetFrameRef("tbg-bar")
    bar:SetScale(scale)
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", "$parent", "CENTER",
        (self:GetAttribute("tbg-bar-x") or 0) / scale, (self:GetAttribute("tbg-bar-y") or 0) / scale)
    local shadow = self:GetFrameRef("tbg-bar-shadow")
    if factor > 1 then shadow:Show() else shadow:Hide() end
]])

function ns.barFocus:OnBarFocusAssign(col, key, name)
    local column = ns.barFocusColumns[col]
    if column and column.flyout and column.flyout.OnChoicePicked then
        column.flyout:OnChoicePicked(key, name)
    end
    ShowBarFocusTooltip(col, self:GetAttribute("row"))
end

-- The bar's resting position (Edit Mode), so Totem Bar Focus can scale it around
-- its center. Out of combat only (from EditMode.lua when it places the bar).
function ns.SetBarFocusRestPosition(scale, x, y)
    if not ns.barFocus then return end
    ns.barFocus:SetAttribute("tbg-bar-scale", scale)
    ns.barFocus:SetAttribute("tbg-bar-x", x)
    ns.barFocus:SetAttribute("tbg-bar-y", y)
    -- Placing the bar resets its scale: an open Totem Bar Focus scales it up again.
    if ns.barFocusGrid:IsOpen() then
        SecureHandlerExecute(ns.barFocus, [[ self:RunAttribute("tbg-bar-focus", self:GetAttribute("tbg-focus-scale")) ]])
    end
end

function ns.CloseBarFocus()
    if ns.barFocusGrid then ns.barFocusGrid:Close() end
end

-- Rebuild the Totem Bar Focus columns: every shown bar button, in bar order, with its
-- flyout if it has choices. Only runs out of combat (from UpdateLayout).
-- Choices for "First Focus" (Options > AddOns), by saved index. A button
-- that isn't on the bar falls back to the first one.
ns.firstFocusChoices = {
    { label = "First Button" },
    { label = "Call Switcher", kind = "call" },
    { label = "Earth Totem", kind = "totem", elem = 2 },
    { label = "Fire Totem", kind = "totem", elem = 1 },
    { label = "Water Totem", kind = "totem", elem = 3 },
    { label = "Air Totem", kind = "totem", elem = 4 },
    { label = ns.recallSpell.name, kind = "recall" },
    { label = "Weapon Enhancement", kind = "weapon" },
    { label = "Last Used", last = true },
}

local function ColumnIndex(kind, elem)
    for index, column in ipairs(ns.barFocusColumns) do
        if column.kind == kind and (not elem or column.elem == elem) then return index end
    end
end

-- Where Totem Bar Focus starts. Out of combat only.
local function ApplyFirstFocus()
    local choice = ns.firstFocusChoices[TotemBarForGamepadDB.barFocusFirstFocus or 1] or ns.firstFocusChoices[1]
    ns.barFocusGrid:SetStartColumn(choice.kind and ColumnIndex(choice.kind, choice.elem) or 1)
    ns.barFocusGrid:SetStartLast(choice.last)
end

function ns.UpdateBarFocus(barButtons, isVertical)
    if not ns.barFocusGrid then return end
    -- "Last Used" follows its button, wherever the new layout puts it.
    local lastColumn = ns.barFocusColumns[ns.barFocusGrid:GetLastColumn() or 0]
    wipe(ns.barFocusColumns)
    local gridColumns = {}
    for _, button in ipairs(barButtons) do
        local flyout = button.flyout and button.choiceCount and button.choiceCount > 0 and button.flyout or nil
        local choices = {}
        for _, choice in ipairs(flyout and flyout.buttons or {}) do
            if choice:IsShown() and choice.choiceKey then choices[#choices + 1] = choice end
        end
        local column = { button = button, flyout = flyout, choices = choices }
        local refs, attributes = {}, {}
        if button == ns.summonButton then
            column.kind = "call"
        elseif button == ns.recallButton then
            column.kind = "recall"
        elseif button == ns.enhancementButton then
            column.kind = "weapon"
            refs.proxy = ns.weaponProxy
        else
            local elem = TotemBarForGamepadDB.elementOrder[button.slotIndex]
            column.kind = "totem"
            column.elem = elem
            refs.proxy = ns.castProxies[elem]
            refs.summon = ns.summonButton
            for page = 1, #ns.callSpells do
                if ns.callWriters[page] then refs["writer" .. page] = ns.callWriters[page][elem] end
            end
        end
        attributes.kind = column.kind
        ns.barFocusColumns[#ns.barFocusColumns + 1] = column
        -- Up from the bar skips "No Totem" (first, next to the bar): Down reaches it.
        local entryRow = choices[1] and choices[1].choiceKey == "none" and 2 or 1
        gridColumns[#gridColumns + 1] = { container = flyout, owner = button, choices = choices,
            entryRow = entryRow, refs = refs, attributes = attributes }
    end
    ns.barFocusGrid:SetColumns(gridColumns)
    local lastIndex
    for index, column in ipairs(ns.barFocusColumns) do
        if lastColumn and column.button == lastColumn.button then lastIndex = index end
    end
    ns.barFocusGrid:SetLastColumn(lastIndex)
    ns.ApplyBarFocusOptions()

    -- The bar runs along one axis, the flyouts along the other (choice 1 next
    -- to the bar); the D-pad follows the flyout's direction.
    if isVertical then
        ns.barFocusGrid:SetDirections({ UP = { "col", -1 }, DOWN = { "col", 1 }, LEFT = { "row", -1 }, RIGHT = { "row", 1 } })
    else
        local up = TotemBarForGamepadDB.flyoutsOpenDown and -1 or 1
        ns.barFocusGrid:SetDirections({ LEFT = { "col", -1 }, RIGHT = { "col", 1 }, UP = { "row", up }, DOWN = { "row", -up } })
    end
end

-- Whether A (Select) on that column's choices also casts them ("Cast When
-- Selected", Options > AddOns: off for totems, on for weapon enhancements).
function ns.BarFocusSelectCasts(col)
    local column, db = ns.barFocusColumns[col], TotemBarForGamepadDB
    if not column or not db then return false end
    if column.kind == "totem" then return db.barFocusTotemCastOnSelect and true or false end
    if column.kind == "weapon" then return db.barFocusWeaponCastOnSelect and true or false end
    return false
end

-- The Totem Bar Focus options (Options > AddOns). Out of combat only; a
-- change made in combat applies with the next layout.
function ns.ApplyBarFocusOptions()
    if not ns.barFocusGrid or not TotemBarForGamepadDB then return end
    if InCombatLockdown() then
        ns.relayoutAfterCombat = true
        return
    end
    ns.barFocusGrid:SetPrimaryCloses(TotemBarForGamepadDB.barFocusCloseOnSelect)
    ns.barFocusGrid:SetSecondaryCloses(TotemBarForGamepadDB.barFocusCloseOnCast)
    for index in ipairs(ns.barFocusColumns) do
        ns.barFocusGrid:SetPrimaryCasts(index, ns.BarFocusSelectCasts(index))
    end
    ApplyFirstFocus()
end

-- A layout refresh (e.g. SPELLS_CHANGED) re-hides flyouts; keep an open Totem Bar Focus intact.
function ns.RefreshOpenBarFocus()
    if ns.barFocusGrid then ns.barFocusGrid:RefreshOpen() end
end
