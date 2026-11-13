local _, ns = ...
-- Everything in TotemBarForGamepad is Shaman-only; other files check this flag.
ns.isShaman = select(2, UnitClass("player")) == "SHAMAN"
if not ns.isShaman then return end

-- The name players see. Internally (folder, TotemBarForGamepadDB, frame names
-- that macros and key bindings use) it is TotemBarForGamepad.
ns.DISPLAY_NAME = "Totem Bar for Gamepad"
ns.NO_TOTEM_TEXT = MULTI_CAST_TOOLTIP_NO_TOTEM or "No Totem"

-- The bar's default spot: centered, its bottom edge this share of the
-- screen's height above the bottom of the screen (38 units on the usual
-- 768-unit-tall screen), so it lands in the same place on any screen size,
-- UI scale, bar scale or orientation.
ns.BAR_DEFAULT_BOTTOM_SHARE = 0.05

ns.defaults = {
    -- Bar center offset from screen center, in screen (UIParent) units. No
    -- offsetY: the default spot (ns.BAR_DEFAULT_BOTTOM_SHARE).
    offsetX = 0,
    barScale = 1.0,
    -- Sound alerts (SoundAlerts.lua): a Cooldown Manager sound's enum name,
    -- "TextToSpeech" or "None"; lead times in seconds.
    alertTotemExpiring = "InstrumentsBellRing",
    alertTotemExpired = "ImpactsLowThud",
    alertWeaponExpiring = "InstrumentsBellRing",
    alertLeadTime = 5,
    alertWeaponLeadTime = 60,
    hideBlizzardTotemBar = true,
    -- Totem Bar Focus: selecting (A) closes it; casting (X, or A/X on the bar)
    -- closes it.
    barFocusCloseOnSelect = false,
    barFocusCloseOnCast = false,
    -- Totem Bar Focus: selecting (A) a totem / weapon enhancement also casts it.
    barFocusTotemCastOnSelect = false,
    barFocusWeaponCastOnSelect = true,
    -- The bar button Totem Bar Focus starts on (ns.firstFocusChoices).
    barFocusFirstFocus = 1,
    -- Edit Mode: hide the slots of elements with no learned totems (Blizzard's way).
    hideEmptyElements = true,
    -- Edit Mode: what a slot's swipe shows. "BOTH": the placed totem's time
    -- left, else the spell's cooldown; "DURATION": time left only;
    -- "COOLDOWN": the spell's cooldown only (Blizzard's totem bar).
    slotSwipe = "BOTH",
    -- Edit Mode: bar orientation, and whether a horizontal bar's flyouts
    -- open downward (a vertical bar's open to the right).
    barOrientation = "HORIZONTAL",
    flyoutsOpenDown = false,
    -- The weapon enhancement button: shown, on which end of the bar, and
    -- the enhancement it casts (a spell ID from ns.imbueSpells).
    showWeaponButton = false,
    weaponButtonSide = "RIGHT",
    weaponEnhancement = 8017,
    -- Element ID per bar slot, in Blizzard's totem bar order (Earth, Fire, Water, Air).
    elementOrder = { 2, 1, 3, 4 },
    -- The current Call (totem bar page). Each Call keeps its own set in
    -- callSets (built at load; activeCallSet is the current one at runtime):
    -- element -> the totem's spell name or "none". An element without a choice
    -- follows the game's totem bar, else takes its first totem.
    activeCall = 1,
}

ns.recallSpell = { id = 36936, name = "Totemic Recall" }
-- One Call per totem bar page, in Blizzard's order (its summon-button flyout).
ns.callSpells = {
    { id = 66842, name = "Call of the Elements" },
    { id = 66843, name = "Call of the Ancestors" },
    { id = 66844, name = "Call of the Spirits" },
}

-- The shaman weapon imbues, in spellbook order: Rockbiter, Flametongue,
-- Frostbrand and Windfury Weapon (rank 1 IDs; any learned rank counts).
ns.imbueSpells = { 8017, 8024, 8033, 8232 }

-- Totem spell name -> element, filled from the game's lists (ns.GetElementTotems).
ns.totemElementByName = {}

-- Elements are keyed by the game's totem slot IDs (FIRE_TOTEM_SLOT = 1,
-- EARTH_TOTEM_SLOT = 2, WATER_TOTEM_SLOT = 3, AIR_TOTEM_SLOT = 4): totem
-- slots, the game's totem bar actions and every table above use them.
ns.ELEMENT_NAMES = { [1] = "Fire", [2] = "Earth", [3] = "Water", [4] = "Air" }
-- Display order, as on Blizzard's totem bar: Earth, Fire, Water, Air.
ns.ELEMENT_ORDER = { 2, 1, 3, 4 }
