local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Gamepad Macros
-- ---------------------------------------------------------------------------
-- Character macros that "/click" Totem Bar Focus or a cast proxy, for placing on
-- the gamepad action bar (where its LT/LB layers keep working natively).
-- The question-mark icon tells the game to show the macro's spell instead.
local MACRO_DYNAMIC_ICON = 134400

local macroDefs = {
    { key = "totems", name = "TBG Focus", target = "TotemBarForGamepadFocus", spellID = 66842, desc = "start or end Totem Bar Focus: your gamepad on the totem bar" },
    { key = "earth", elem = 2, name = "TBG Earth", target = "TotemBarForGamepadCastEarth", spellID = 8071, desc = "cast your Earth totem" },
    { key = "fire", elem = 1, name = "TBG Fire", target = "TotemBarForGamepadCastFire", spellID = 3599, desc = "cast your Fire totem" },
    { key = "water", elem = 3, name = "TBG Water", target = "TotemBarForGamepadCastWater", spellID = 5394, desc = "cast your Water totem" },
    { key = "air", elem = 4, name = "TBG Air", target = "TotemBarForGamepadCastAir", spellID = 8512, desc = "cast your Air totem" },
    { key = "weapon", weapon = true, name = "TBG Weapon", target = "TotemBarForGamepadCastWeapon", spellID = 8017, desc = "cast your weapon enhancement" },
}
-- No macros for Totemic Recall or the Calls: TBG keeps the game's totem bar in
-- sync, so the spells themselves (from the spellbook) already cast TBG's set.

ns.macroDefs = macroDefs

function ns.GetMacroDef(key)
    for _, def in ipairs(macroDefs) do
        if def.key == key then return def end
    end
end

-- A macro's icon as it shows on a bar: its current totem or weapon
-- enhancement; a totem macro with "No Totem" shows the element's empty art.
function ns.SetMacroIcon(texture, def)
    local spell = ns.GetMacroSpell(def)
    local icon = spell and ns.SpellIcon(spell)
    if not icon and def.elem then
        ns.SetElementEmptyArt(texture, def.elem)
        return
    end
    texture:SetTexture(icon or ns.SpellIcon(def.spellID) or MACRO_DYNAMIC_ICON)
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
end

-- The macro's tooltip: its name, what it does, then what to do with it (or
-- why that failed).
function ns.ShowMacroTooltip(owner, def, reason)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(def.name, 1, 1, 1)
    GameTooltip:AddLine(def.desc:sub(1, 1):upper() .. def.desc:sub(2), nil, nil, nil, true)
    if reason then
        GameTooltip:AddLine(reason, 1, 0.3, 0.3, true)
    elseif ns.GamepadKit.IsGamepadActive() then
        GameTooltip:AddLine("Press A to bind it to a gamepad button, or drag it to an action bar.", 0.4, 1, 0.4, true)
    else
        GameTooltip:AddLine("Drag to an action bar, or click to pick it up.", 0.4, 1, 0.4, true)
    end
    GameTooltip:Show()
end

-- Finds or creates the character macro for a definition. Returns its index,
-- or nil and a reason. Silent: it runs from the Options panel, where chat
-- output would taint the gamepad navigation.

-- Totem and weapon macros show their current spell (icon, tooltip, cooldown):
-- "#showtooltip" plus SetMacroSpell, which UpdateMacroIcons keeps current.
local function MacroBody(def)
    local click = "/click " .. def.target
    if def.elem or def.weapon then return "#showtooltip\n" .. click end
    return click
end

local function MacroIcon(def)
    if def.elem or def.weapon then return MACRO_DYNAMIC_ICON end
    local icon = ns.SpellIcon(def.spellID)
    if type(icon) ~= "number" and type(icon) ~= "string" then icon = MACRO_DYNAMIC_ICON end
    return icon
end

function ns.EnsureGamepadMacro(def)
    if InCombatLockdown() then return nil, "Leave combat to create macros." end
    if def.key == "totems" and not ns.barFocus then
        return nil, "Totem Bar Focus needs secure handlers, which this client lacks."
    end
    local body = MacroBody(def)
    local index = GetMacroIndexByName(def.name)
    if index and index > 0 then
        -- Ours by name (TBG prefix): keep its text and icon current.
        local _, _, existingBody = GetMacroInfo(index)
        if existingBody and existingBody:match("^%s*(.-)%s*$") ~= body and EditMacro then
            pcall(EditMacro, index, def.name, MacroIcon(def), body)
        end
        return index
    end
    local icon = MacroIcon(def)
    local ok, result = pcall(CreateMacro, def.name, icon, body, true)
    if not ok or not result or result == 0 then return nil, "Your character macro slots may be full." end
    return result
end

-- Puts the macro on the cursor, for dropping on an action bar slot.
function ns.PickupGamepadMacro(def)
    local index, reason = ns.EnsureGamepadMacro(def)
    if index then
        ns.UpdateMacroIcons()
        PickupMacro(index)
    end
    return index ~= nil, reason
end

-- Binds a macro to a gamepad button combination: GamepadKit's bind prompt
-- (Blizzard's "Bind to Action Bar" look) reads the combination, and the macro
-- is placed in that gamepad bar slot, replacing what was there, as Blizzard's
-- bind does. onDone(bound) runs when it closes. Out of combat only.
local bindPrompt
function ns.BindGamepadMacro(def, onDone)
    local function Done(bound) if onDone then onDone(bound) end end
    if InCombatLockdown() then return false, "Leave combat to bind macros." end
    local index, reason = ns.EnsureGamepadMacro(def)
    if not index then return false, reason end
    ns.UpdateMacroIcons()
    bindPrompt = bindPrompt or ns.GamepadKit.CreateBindPrompt("TotemBarForGamepadBindPrompt")
    local spell = ns.GetMacroSpell(def)
    local opened = bindPrompt:Open({
        label = def.name,
        icon = (spell and ns.SpellIcon(spell)) or ns.SpellIcon(def.spellID) or 134400,
        onBind = function(slot, combo)
            if InCombatLockdown() then return Done(false) end
            ClearCursor()
            PickupMacro(index)
            PlaceAction(slot)
            ClearCursor()
            local kind, id = GetActionInfo(slot)
            local bound = kind == "macro" and id == index
            if bound then
                UIErrorsFrame:AddMessage(def.name .. ": " .. combo, YELLOW_FONT_COLOR:GetRGB())
            else
                UIErrorsFrame:AddMessage(GAMEPAD_BIND_FAILURE_GENERIC_FAIL or "Couldn't bind it there.", RED_FONT_COLOR:GetRGB())
            end
            Done(bound)
        end,
        onCancel = function() Done(false) end,
    })
    return opened
end

-- ---------------------------------------------------------------------------
-- Macro icons follow the selection
-- ---------------------------------------------------------------------------
-- SetMacroSpell works during combat on this client (verified in game, 2026-11-12),
-- unlike editing macros, so picks made in combat show at once. The deferral
-- below remains for clients where that isn't so.
ns.macroSpellInCombat = true
local iconsPending = false

function ns.GetMacroSpell(def)
    if not TotemBarForGamepadDB then return nil end
    if def.elem then
        for slotIndex, slot in ipairs(ns.slots) do
            if TotemBarForGamepadDB.elementOrder[slotIndex] == def.elem then return slot.chosenSpell end
        end
    elseif def.weapon then
        -- The bar's weapon button may be hidden; the macro's proxy still casts.
        return ns.enhancementButton.chosenSpell or (ns.weaponProxy and ns.weaponProxy:GetAttribute("spell1"))
    end
end

function ns.UpdateMacroIcons()
    -- The Options page's macro row follows the selection too.
    if ns.RefreshMacroRow then ns.RefreshMacroRow() end
    if ns.RefreshMacroGuide then ns.RefreshMacroGuide() end
    if not (SetMacroSpell and TotemBarForGamepadDB and GetMacroIndexByName) then return end
    if InCombatLockdown() and not ns.macroSpellInCombat then
        iconsPending = true
        return
    end
    iconsPending = false
    for _, def in ipairs(macroDefs) do
        if def.elem or def.weapon then
            local index = GetMacroIndexByName(def.name)
            if index and index > 0 then
                -- No spell ("No Totem"): back to the question mark.
                pcall(SetMacroSpell, index, ns.GetMacroSpell(def) or "")
            end
        end
    end
end

function ns.FlushMacroIcons()
    if iconsPending then ns.UpdateMacroIcons() end
end
