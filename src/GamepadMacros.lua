local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Gamepad Macros
-- ---------------------------------------------------------------------------
-- Character macros that "/click" Totem Bar Focus or a cast proxy, for placing on
-- the gamepad action bar (where its LT/LB layers keep working natively).
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

-- Finds or creates the character macro for a definition. Returns its index,
-- or nil and a reason. Silent: it runs from the Options panel, where chat
-- output would taint the gamepad navigation.
-- The question-mark icon tells the game to show the macro's spell instead.
local MACRO_DYNAMIC_ICON = 134400

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
