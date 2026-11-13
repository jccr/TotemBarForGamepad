local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Spells: names, icons, what the player has learned, and tooltips
-- ---------------------------------------------------------------------------
-- Built on the client's C_Spell / C_SpellBook API (what Blizzard's own UI on
-- this client uses). In combat some answers come back as secret values: they
-- can be passed to the game but not read, compared or stored, so every
-- lookup here hands back nil for those.

local IsSecretValue = issecretvalue or function() return false end
ns.IsSecretValue = IsSecretValue

local function Readable(value)
    if value ~= nil and not IsSecretValue(value) then return value end
end
ns.Readable = Readable

-- spell: a spell ID or name.
function ns.SpellName(spell)
    return spell and Readable(C_Spell.GetSpellName(spell))
end

function ns.SpellIcon(spell)
    return spell and Readable(C_Spell.GetSpellTexture(spell))
end

-- The spellbook as a set of spell names. Totem and weapon spells have ranks:
-- the book can hold a higher rank under another spell ID than the one in
-- Definitions.lua, so learned spells are also matched by name.
function ns.ReadSpellbook()
    local names = {}
    local bank, spellType = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType.Spell
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skill = C_SpellBook.GetSpellBookSkillLineInfo(line)
        local first = skill and skill.itemIndexOffset or 0
        for index = first + 1, first + (skill and skill.numSpellBookItems or 0) do
            local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
            local name = item and item.itemType == spellType and Readable(item.name)
            if name then names[name] = true end
        end
    end
    return names
end

-- The spell's name when the player has learned it (any rank), else nil.
-- spellbook: from ns.ReadSpellbook.
function ns.LearnedSpellName(spellbook, spellID)
    local name = ns.SpellName(spellID)
    if not name then return nil end
    if spellbook[name] or C_SpellBook.IsSpellKnownOrInSpellBook(spellID) then return name end
end

-- The learned totems of an element, in the game's order: what Blizzard's
-- flyout lists (GetMultiCastTotemSpells). { { id = spellID, name = name }, ... }
function ns.GetElementTotems(elem)
    local list = {}
    if not GetMultiCastTotemSpells then return list end
    for _, id in ipairs({ GetMultiCastTotemSpells(elem) }) do
        local name = Readable(id) and ns.SpellName(id)
        if name then
            list[#list + 1] = { id = id, name = name }
            ns.totemElementByName[name] = elem
        end
    end
    return list
end

-- ---------------------------------------------------------------------------
-- Tooltips
-- ---------------------------------------------------------------------------
-- Blizzard's tooltip anchoring for action buttons: the default anchor with
-- "Enhanced Tooltips" (UberTooltips) on, otherwise to the button's right.
function ns.SetTooltipOwner(owner)
    if GetCVarBool and GetCVarBool("UberTooltips") and GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, owner)
    else
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    end
end

-- spell: a spell ID or name. A name is shown as the spell it resolves to.
function ns.SetSpellTooltipContent(spell)
    local spellID = type(spell) == "number" and spell
    if not spellID then
        local info = C_Spell.GetSpellInfo(spell)
        spellID = info and Readable(info.spellID)
    end
    if spellID then
        GameTooltip:SetSpellByID(spellID, false, true)
    else
        GameTooltip:SetText(tostring(spell), 1, 1, 1)
    end
end

function ns.ShowTooltipForSpell(owner, spell)
    ns.SetTooltipOwner(owner)
    ns.SetSpellTooltipContent(spell)
    GameTooltip:Show()
end

-- Blizzard's "No Totem" tooltip (its localized string).
function ns.ShowNoTotemTooltip(owner)
    ns.SetTooltipOwner(owner)
    local color = HIGHLIGHT_FONT_COLOR
    GameTooltip:SetText(ns.NO_TOTEM_TEXT, color and color.r or 1, color and color.g or 1, color and color.b or 1)
    GameTooltip:Show()
end
