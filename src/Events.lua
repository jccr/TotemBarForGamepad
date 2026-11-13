local addonName, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Game events
-- ---------------------------------------------------------------------------
-- One handler per event; the bar frame registers every event listed here.
local on = {}

-- Changes seen in combat wait here ({ [elem] = page }, or every slot), since
-- the bar's secure buttons can only be reconfigured out of combat.
local pendingTotemBar

local function FollowTotemBar(slots)
    if InCombatLockdown() then
        pendingTotemBar = pendingTotemBar or {}
        for elem = 1, 4 do
            if slots == nil then
                pendingTotemBar[elem] = pendingTotemBar[elem] or 1
            elseif slots[elem] then
                pendingTotemBar[elem] = slots[elem]
            end
        end
        return
    end
    if ns.FollowTotemBar(slots) then ns.UpdateLayout() end
end

local function HideBlizzardTotemBarIfSet()
    ns.SetBlizzardTotemBarHidden(TotemBarForGamepadDB.hideBlizzardTotemBar)
end

-- Saved settings: defaults for anything missing (tables copied), and each
-- Call's own set of picks; activeCallSet is the current Call's set.
local function LoadSettings()
    TotemBarForGamepadDB = TotemBarForGamepadDB or {}
    local db = TotemBarForGamepadDB
    for key, value in pairs(ns.defaults) do
        if db[key] == nil then db[key] = type(value) == "table" and CopyTable(value) or value end
    end
    db.callSets = db.callSets or {}
    for call = 1, #ns.callSpells do db.callSets[call] = db.callSets[call] or {} end
    if not db.callSets[db.activeCall] then db.activeCall = 1 end
    db.activeCallSet = db.callSets[db.activeCall]
end

function on.ADDON_LOADED(name)
    if name ~= addonName then return end
    LoadSettings()
    -- Edit Mode's layouts usually load later; EDIT_MODE_LAYOUTS_UPDATED then
    -- applies the layout's arrangement.
    ns.ApplyActiveLayout()
    HideBlizzardTotemBarIfSet()
    -- Options > AddOns (needs the settings and Bindings.xml).
    ns.RegisterOptions()
end

function on.PLAYER_ENTERING_WORLD()
    -- Zoning and logging in take every totem away: not a lost totem.
    ns.QuietTotemAlerts(3)
    ns.MaybeShowWelcome()
    -- Begin from what the game's totem bar holds.
    if ns.FollowTotemBar(nil) then ns.relayoutAfterCombat = true end
    ns.ApplyActiveLayout()
    if ns.relayoutAfterCombat and not InCombatLockdown() then ns.UpdateLayout() end
    HideBlizzardTotemBarIfSet()
    ns.ReadAllTotems()
end

function on.PLAYER_LOGOUT()
    -- activeCallSet is one of callSets; saving it twice would duplicate it.
    TotemBarForGamepadDB.activeCallSet = nil
end

-- A totem cast: read its element right away. The game may report the new
-- totem a moment after the cast, so the slot keeps its live timer meanwhile.
-- Restricted arguments (combat) can't be matched to a slot: read them all.
function on.UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
    if ns.IsSecretValue(unit) or ns.IsSecretValue(spellID) then
        ns.ReadAllTotems()
        ns.totemsNeedReread = true
        return
    end
    if unit ~= "player" or not spellID then return end
    local name = ns.SpellName(spellID)
    -- Totemic Recall takes the totems away on purpose: no "totem gone" alerts.
    if spellID == ns.recallSpell.id or (name and name == ns.SpellName(ns.recallSpell.id)) then
        ns.QuietTotemAlerts(2)
    end
    local elem = name and ns.totemElementByName[name]
    if elem then ns.ReadTotem(elem, true) end
end

-- Its arguments don't say which totem changed on every client: read all four.
function on.PLAYER_TOTEM_UPDATE()
    ns.ReadAllTotems()
    if TotemBarForGamepadDB.hideBlizzardTotemBar then ns.SetBlizzardTotemBarHidden(true) end
end

function on.SPELLS_CHANGED()
    ns.UpdateLayout()
    HideBlizzardTotemBarIfSet()
end

function on.PLAYER_REGEN_ENABLED()
    -- Macro icons for picks made in combat.
    ns.FlushMacroIcons()
    if ns.activeLayoutPending then
        -- A layout switch came in combat; applying it also lays the bar out.
        ns.ApplyActiveLayout()
    elseif ns.relayoutAfterCombat then
        ns.UpdateLayout()
    else
        ns.UpdateHotkeys()
    end
    if ns.totemsNeedReread then
        ns.totemsNeedReread = false
        ns.ReadAllTotems()
    end
    if pendingTotemBar then
        local slots = pendingTotemBar
        pendingTotemBar = nil
        FollowTotemBar(slots)
    end
end

-- The screen's height in UI units changed: the default spot moves with it.
function on.UI_SCALE_CHANGED()
    if TotemBarForGamepadDB and TotemBarForGamepadDB.offsetY == nil then ns.ApplyActiveLayout() end
end
on.DISPLAY_SIZE_CHANGED = on.UI_SCALE_CHANGED

-- Edit Mode loaded its layouts, or the active one changed.
on.EDIT_MODE_LAYOUTS_UPDATED = function() ns.ApplyActiveLayout() end
-- The game's key bindings: the keys shown on the bar.
on.UPDATE_BINDINGS = function() ns.UpdateHotkeys() end
-- Cooldown and global cooldown swipes, as on Blizzard's buttons.
on.SPELL_UPDATE_COOLDOWN = function() ns.UpdateSpellCooldowns() end
on.ACTIONBAR_UPDATE_COOLDOWN = on.SPELL_UPDATE_COOLDOWN
-- The usability tint on the icons (as on Blizzard's action buttons).
on.SPELL_UPDATE_USABLE = function() ns.UpdateUsability() end
on.ACTIONBAR_UPDATE_USABLE = on.SPELL_UPDATE_USABLE
on.UPDATE_SHAPESHIFT_FORM = on.SPELL_UPDATE_USABLE
on.UNIT_POWER_UPDATE = on.SPELL_UPDATE_USABLE

-- The game's totem bar is ready (Blizzard's totem bar redraws on this too).
function on.UPDATE_MULTI_CAST_ACTIONBAR()
    FollowTotemBar(nil)
end

-- The game's totem bar slots are action slots: follow changes made there.
-- The slot argument is 0 or nil when any slot may have changed.
function on.ACTIONBAR_SLOT_CHANGED(action)
    if action == 0 or action == nil then
        FollowTotemBar(nil)
        return
    end
    local page, elem = ns.TotemBarSlotOf(action)
    if page then FollowTotemBar({ [elem] = page }) end
end

for event in pairs(on) do
    if event == "UNIT_POWER_UPDATE" then
        ns.bar:RegisterUnitEvent(event, "player")
    else
        ns.bar:RegisterEvent(event)
    end
end
ns.bar:SetScript("OnEvent", function(_, event, ...) on[event](...) end)
