// Load every TotemBarForGamepad file in TOC order inside fengari, with the strict
// frame stubs plus a permissive placeholder for any other WoW global. Then
// fire ADDON_LOADED / PLAYER_ENTERING_WORLD through the addon's own handler.
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const [,, outDir] = process.argv; // the addon folder
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const check = (status, what) => { if (status) throw new Error(what + ': ' + to_jsstring(lua.lua_tostring(L, -1))); };
const run = (code, name) => { check(lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(name)), name); check(lua.lua_pcall(L, 0, 0, 0), name); };
run(fs.readFileSync(path.join(__dirname, 'lib', 'wowstub.lua'), 'utf8'), 'stub');
run(`
-- Permissive placeholder for WoW globals the strict stub doesn't model.
local P = {}
setmetatable(P, { __index = function() return P end, __call = function() return P end,
  __concat = function(a, b) return tostring(a == P and "" or a) .. tostring(b == P and "" or b) end,
  __len = function() return 0 end, __unm = function() return 0 end,
  __add = function() return 0 end, __sub = function() return 0 end, __mul = function() return 0 end,
  __div = function() return 1 end, __lt = function() return false end, __le = function() return true end })
PLACEHOLDER = P
UnitClass = function() return "Shaman", "SHAMAN" end
InCombatLockdown = function() return false end
GetTime = function() return 100 end
issecretvalue = function() return false end
C_Texture = { GetAtlasInfo = function() return {} end }
C_Timer = { NewTicker = function() end, After = function() end }
C_ActionBar = { GetMultiCastBarIndex = function() return 10 end }
-- Settings API + key bindings (recording, no UI).
SETTINGS_LOG = {}
local function Rec(name) return function(...) SETTINGS_LOG[#SETTINGS_LOG + 1] = name return setmetatable({ attrs = {} }, { __index = function() return function() end end }) end end
Settings = { VarType = { Boolean = "boolean", Number = "number", String = "string" } }
Settings.CreateSliderOptions = function(a, b, c) return { SetLabelFormatter = function(self, t, f) SLIDER_FMT = f end } end
Settings.CreateSlider = function() SETTINGS_LOG[#SETTINGS_LOG + 1] = "slider" end
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
-- Blizzard's Cooldown Manager sound data (two categories) and playback.
Enum = Enum or {}
CDMSND_INSTRUMENTS_BELL_RING = "Bell Ring"; CDMSND_IMPACTS_LOW_THUD = "Low Thud"
COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_INSTRUMENTS = "Instruments"; COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_IMPACTS = "Impacts"
COOLDOWN_VIEWER_SETTINGS_ALERT_LABEL_SOUND_TYPE_TEXT_TO_SPEECH = "Text to Speech"; NONE = "None"
PLAYED = {}
C_Sound = { PlaySoundWithOptions = function(o) PLAYED[#PLAYED + 1] = "sound:" .. o.soundKitID .. "/" .. o.uiSoundSubType end }
TextToSpeechFrame_PlayCooldownAlertMessage = function(_, text) PLAYED[#PLAYED + 1] = "tts:" .. text end
function Settings.RegisterVerticalLayoutCategory(name)
    local layout = { inits = {} }
    function layout:AddInitializer(i) self.inits[#self.inits + 1] = i end
    LAYOUT = layout
    return { GetID = function() return 42 end, name = name }, layout
end
Settings.RegisterProxySetting = function(cat, var, vt, name, default, get, set)
    PROXIES = rawget(_G, "PROXIES") or {}
    PROXIES[var] = { get = get, set = set }
    return { SetValue = function(_, v) set(v) end, GetValue = function() return get() end, var = var }
end
Settings.CreateCheckbox = Rec("checkbox")
Settings.CreateDropdown = function(cat, setting, options) SETTINGS_LOG[#SETTINGS_LOG + 1] = "dropdown"; DROPDOWN_OPTIONS = rawget(_G, "DROPDOWN_OPTIONS") or {}; DROPDOWN_OPTIONS[#DROPDOWN_OPTIONS + 1] = options
  local init = { setting = setting }; DROPDOWN_INITS = rawget(_G, "DROPDOWN_INITS") or {}; DROPDOWN_INITS[#DROPDOWN_INITS + 1] = init; return init end
nop = function() end
GenerateClosure = function(f, a) return function(...) return f(a, ...) end end
Settings.CreateControlTextContainer = function() local d = {} return { Add = function(_, v, l) d[#d + 1] = { value = v, label = l } end, GetData = function() return d end } end
Settings.CreateElementInitializer = function(t, data) return { template = t, data = data } end
Settings.RegisterAddOnCategory = Rec("registerCategory")
Settings.OpenToCategory = function(id) print("OpenToCategory", id) end
CreateSettingsListSectionHeaderInitializer = function(text) return { header = text } end
CreateKeybindingEntryInitializer = function(index) return { binding = index } end
local BINDS = { "CLICK TotemBarForGamepadSlot1:LeftButton", "CLICK TotemBarForGamepadSlot2:LeftButton", "CLICK TotemBarForGamepadSlot3:LeftButton",
    "CLICK TotemBarForGamepadSlot4:LeftButton", "CLICK TotemBarForGamepadUtility1:LeftButton", "CLICK TotemBarForGamepadUtility2:LeftButton",
    "CLICK TotemBarForGamepadUtility3:LeftButton", "CLICK TotemBarForGamepadWeaponEnhancement:LeftButton" }
BOUND = {}
function GetNumBindings() return #BINDS end
function GetBinding(i) return BINDS[i] end
function GetBindingKey(command) for key, c in pairs(BOUND) do if c == command then return key end end end
function SetBinding(key, command) BOUND[key] = command return true end
function SaveBindings(set) SAVED_SET = set end; SAVED_SET = SAVED_SET
function GetCurrentBindingSet() return 2 end
function GetBindingText(key) return key end
function ClearOverrideBindings() end

ACTIONS = {}
function GetActionInfo(a) local v = ACTIONS[a] if v then return "spell", v end end
NUM_ACTIONBAR_BUTTONS = 12
GetBindingText = function(k) return "|A:Gamepad_Ltr_A_64:24:24|a" end
UISpecialFrames = {}
SlashCmdList = {}
EventRegistry = { RegisterCallback = function() end }
EditModeManagerFrame = setmetatable({ attrs = {}, name = "EditModeManagerFrame" }, getmetatable(UIParent))
hooksecurefunc = function() end
UIDropDownMenu_Initialize = function() end
UIDropDownMenu_CreateInfo = function() return {} end
C_SpellBook = { GetNumSpellBookSkillLines = function() return 0 end, IsSpellKnownOrInSpellBook = function() return true end,
  GetSpellBookItemInfo = function() return nil end, GetSpellBookSkillLineInfo = function() return nil end }
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 },
  WeaponSlot = { MainHand = 0 }, ItemEnchantType = { Imbue = 3 }, NumericRuleFormatRounding = { Down = 2 },
  CooldownViewerSound = { InstrumentsBellRing = 40, ImpactsLowThud = 30, TextToSpeech = 99 },
  CooldownViewerSoundCategory = { Impacts = 3, Instruments = 4 } }
CooldownViewerSoundData = { [3] = { { soundEnum = 30, soundKitID = 316531, text = "Low Thud" } },
  [4] = { { soundEnum = 40, soundKitID = 316493, text = "Bell Ring" } } }
C_Spell = { GetSpellName = function(id) return "Spell" .. tostring(id) end, GetSpellTexture = function() return 136000 end,
  GetSpellInfo = function(id) return { name = "Spell" .. tostring(id), spellID = 1 } end }
GetTotemInfo = function() return false, "", 0, 0 end
function CopyTable(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
-- The main hand's imbue (none by default).
IMBUE = { hasEnchant = false, enchantType = 3, timeLeft = 0 }
C_Item = { GetWeaponEnchantInfo = function() return { IMBUE } end }
-- Names that must read as truly absent (saved variables, optional APIs).
local ABSENT = { TotemBarForGamepadDB = true }
setmetatable(_G, { __index = function(_, k) if ABSENT[k] then return nil end return P end })
`, 'env');
// Frames also need: event registration, script storage, regions.
run(`
local F = getmetatable(UIParent)
local function store(self, script, fn) self.scripts = self.scripts or {}; self.scripts[script] = fn end
rawset(F, "SetScript", store)
rawset(F, "HookScript", function(self, script, fn) if not (self.scripts and self.scripts[script]) then store(self, script, fn) end end)
rawset(F, "GetScript", function(self, script) return self.scripts and self.scripts[script] end)
local base = F.__index
F.__index = function(t, k)
  local v = base(t, k)
  if v ~= nil then return v end
  if k == "SetScript" or k == "HookScript" then
    return function(self, script, fn) self.scripts = self.scripts or {}; self.scripts[script] = fn end
  end
  if ({ GetScale = 1, GetEffectiveScale = 1, GetWidth = 100, GetHeight = 100 })[k] then
    local n = ({ GetScale = 1, GetEffectiveScale = 1, GetWidth = 100, GetHeight = 100 })[k]
    return function() return n end
  end
  if k:match("^Get") or k:match("^Is") then return function() return nil end end
  -- Method-like names are no-op methods; any other field is nil, as in WoW.
  for _, verb in ipairs({ "Set", "Enable", "Register", "Unregister", "Clear", "Show", "Hide", "Play", "Stop",
    "Lock", "Unlock", "Click", "Add", "Run", "Call", "Start", "Raise", "Lower", "Execute", "Wrap" }) do
    if k:sub(1, #verb) == verb then return function() end end
  end
  return nil
end
`, 'frames');
run('NS = {}', 'ns');
// Turn an endless loop into an error with a traceback.
run(`local count = 0
debug.sethook(function() count = count + 1; if count > 200000 then debug.sethook(); error(debug.traceback("instruction limit"), 2) end end, "", 1000)`, 'hook');
const files = fs.readFileSync(path.join(outDir, 'TotemBarForGamepad.toc'), 'utf8').split('\n').filter(l => l.endsWith('.lua')).map(l => l.replace(/\\/g, '/'));
for (const f of files) {
  check(lauxlib.luaL_loadbuffer(L, to_luastring(fs.readFileSync(path.join(outDir, f), 'utf8')), null, to_luastring(f)), f);
  lua.lua_pushstring(L, to_luastring('TotemBarForGamepad')); lua.lua_getglobal(L, to_luastring('NS'));
  check(lua.lua_pcall(L, 2, 0, 0), 'load ' + f);
  console.log('loaded', f);
}
run(`local ok, err = xpcall(function()
-- The game's totem lists: Fire 2 totems, Earth 3, Water 1, Air none.
local LISTS = { [1] = { 3599, 8190 }, [2] = { 8071, 8075, 2484 }, [3] = { 5394 }, [4] = {} }
GetMultiCastTotemSpells = function(elem) return table.unpack(LISTS[elem] or {}) end
NS.bar.scripts.OnEvent(NS.bar, "ADDON_LOADED", "TotemBarForGamepad")
local db = TotemBarForGamepadDB
print("ADDON_LOADED ok; slots:", #NS.slots, "barFocus:", NS.barFocus ~= nil, "swipe:", db.slotSwipe, "hideEmpty:", db.hideEmptyElements)
NS.bar.scripts.OnEvent(NS.bar, "PLAYER_ENTERING_WORLD")
print("PLAYER_ENTERING_WORLD ok")
local function shown(b) return b.attrs.__shown ~= false end
local vis = {}
for i = 1, 4 do vis[#vis + 1] = NS.ELEMENT_NAMES[db.elementOrder[i]] .. "=" .. tostring(NS.slots[i].choiceCount) end
print("slot known counts:", table.concat(vis, " "))
local airSlot
for i = 1, 4 do if db.elementOrder[i] == 4 then airSlot = NS.slots[i] end end
print("current set:", db.activeCallSet[1], db.activeCallSet[2], db.activeCallSet[3], tostring(db.activeCallSet[4]))
local kinds = {} for _, col in ipairs(NS.barFocusColumns) do kinds[#kinds + 1] = col.kind end
print("barFocus columns:", table.concat(kinds, ","), "start col:", NS.barFocus:GetAttribute("start-col"))
local cc = NS.barFocusColumns[1]
local ck = {} for _, ch in ipairs(cc.choices) do ck[#ck + 1] = tostring(ch:GetAttribute("choice-key")) .. "/" .. tostring(ch:GetAttribute("choice-spell")) .. "/" .. tostring(ch:GetAttribute("macrotext1")) end
print("call choices:", table.concat(ck, "; "), "summon key:", NS.summonButton:GetAttribute("tbg-assigned-key"))
local c = NS.barFocusColumns[2]
local keys = {} for _, ch in ipairs(c.choices) do keys[#keys + 1] = tostring(ch.choiceKey) .. "/" .. tostring(ch:GetAttribute("choice-call-spell")) end
print("col1", c.elem, "entries:", table.concat(keys, ", "))
-- Pick "No Totem" then a totem via the flyout callback.
local fireIdx; for i = 1, 4 do if db.elementOrder[i] == 1 then fireIdx = i end end
NS.slots[fireIdx].flyout:OnChoicePicked("none", nil)
NS.UpdateLayout()
print("none kept:", db.activeCallSet[1], "spell1:", tostring(NS.slots[fireIdx]:GetAttribute("spell1")))
NS.slots[fireIdx].flyout:OnChoicePicked("Spell8190", "Spell8190")
print("pick kept:", db.activeCallSet[1], "writer spell:", NS.callWriters[1][1]:GetAttribute("spell1"))
-- Swipe modes.
for _, mode in ipairs({ "BOTH", "DURATION", "COOLDOWN" }) do
  db.slotSwipe = mode; NS.UpdateSlotSwipe(fireIdx)
end
print("swipe modes ok")
NS.UpdateSpellCooldowns()
print("cooldowns ok")
-- Hide-empty off / Edit Mode shows all four.
db.hideEmptyElements = false; NS.UpdateLayout(); print("hideEmpty off ok, air choiceCount", airSlot.choiceCount)
db.hideEmptyElements = true; NS.UpdateLayout()
NS.IsEditModeActive = function() return true end; NS.UpdateLayout(); print("edit mode layout ok")
NS.IsEditModeActive = function() return false end; NS.UpdateLayout()
-- No totems at all.
local saved = LISTS; LISTS = { {}, {}, {}, {} }; NS.UpdateLayout(); print("no totems layout ok"); LISTS = saved; NS.UpdateLayout()
-- Call switching.
db.callSets[2][1] = "Spell3599"
NS.SetCallPage(2)
print("call 2 fire casts", NS.slots[fireIdx]:GetAttribute("spell1"), "page1-spell", NS.slots[fireIdx]:GetAttribute("page1-spell"))
NS.SetCallPage(1)
-- Following the game's bar (base 108; Fire page 1 = 109).
local ev = NS.bar.scripts.OnEvent
ACTIONS[109] = 3599; ev(NS.bar, "ACTIONBAR_SLOT_CHANGED", 109)
print("follow fire:", db.activeCallSet[1])
ACTIONS[110] = 3599; local before = db.activeCallSet[2]; ev(NS.bar, "ACTIONBAR_SLOT_CHANGED", 110)
print("wrong-element ignored:", db.activeCallSet[2] == before)
ACTIONS[109] = nil; ev(NS.bar, "ACTIONBAR_SLOT_CHANGED", 109); print("slot clear follows:", db.activeCallSet[1])
-- Cast of a totem syncs its element.
ev(NS.bar, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8071); print("cast sync ok")
ev(NS.bar, "SPELL_UPDATE_COOLDOWN"); print("cooldown event ok")
NS.RegisterOptions()
print("options:", #LAYOUT.inits, "initializers;", table.concat(SETTINGS_LOG, ","))
print("barFocus defaults:", tostring(NS.barFocus:GetAttribute("primary-closes")), tostring(NS.barFocus:GetAttribute("secondary-closes")))
PROXIES.TOTEMBARFORGAMEPAD_barFocusCloseOnSelect.set(true)
PROXIES.TOTEMBARFORGAMEPAD_barFocusCloseOnCast.set(true)
print("close on cast:", NS.barFocus:GetAttribute("secondary-closes"), db.barFocusCloseOnCast)
print("barFocus options on:", NS.barFocus:GetAttribute("primary-closes"), NS.barFocus:GetAttribute("secondary-closes"),
    "saved:", db.barFocusCloseOnSelect, db.barFocusCloseOnCast)
NS.UpdateLayout()
print("kept after relayout:", NS.barFocus:GetAttribute("primary-closes"), NS.barFocus:GetAttribute("secondary-closes"))
PROXIES.TOTEMBARFORGAMEPAD_barFocusCloseOnSelect.set(false)
PROXIES.TOTEMBARFORGAMEPAD_barFocusCloseOnCast.set(false)
print("barFocus options off:", tostring(NS.barFocus:GetAttribute("primary-closes")), tostring(NS.barFocus:GetAttribute("secondary-closes")))
local kinds = {} for _, col in ipairs(NS.barFocusColumns) do kinds[#kinds + 1] = col.kind .. (col.elem and NS.ELEMENT_NAMES[col.elem] or "") end
print("bar columns:", table.concat(kinds, ","))
local starts = {}
for index, choice in ipairs(NS.firstFocusChoices) do
    PROXIES.TOTEMBARFORGAMEPAD_barFocusFirstFocus.set(index)
    starts[#starts + 1] = choice.label .. "=" .. tostring(NS.barFocus:GetAttribute("start-col")) .. (NS.barFocus:GetAttribute("start-last") and "(last)" or "")
end
print("first focus:", table.concat(starts, "; "))
PROXIES.TOTEMBARFORGAMEPAD_barFocusFirstFocus.set(1)
print("dropdown labels:", #DROPDOWN_OPTIONS[#DROPDOWN_OPTIONS]())
local pc = {} for i = 1, #NS.barFocusColumns do pc[#pc + 1] = NS.barFocusColumns[i].kind .. "=" .. tostring(NS.barFocus:GetAttribute("primary-casts-" .. i)) end
print("A casts (defaults):", table.concat(pc, " "), "totemCastOnChoose:", db.barFocusTotemCastOnSelect, "weaponCastOnChoose:", db.barFocusWeaponCastOnSelect)
PROXIES.TOTEMBARFORGAMEPAD_barFocusTotemCastOnSelect.set(true)
pc = {} for i = 1, #NS.barFocusColumns do pc[#pc + 1] = NS.barFocusColumns[i].kind .. "=" .. tostring(NS.barFocus:GetAttribute("primary-casts-" .. i)) end
print("A casts (totems choose+cast):", table.concat(pc, " "))
PROXIES.TOTEMBARFORGAMEPAD_barFocusTotemCastOnSelect.set(false)
LINES = {}
GameTooltip = setmetatable({ AddLine = function(_, t) LINES[#LINES + 1] = t end }, { __index = function() return function() end end })
Kit = NS.GamepadKit; Kit.PlaceTooltip = function() end
Kit.Glyph = function(key, size, fallback) return "[" .. tostring(fallback) .. "]" end
for _, focus in ipairs({ { 2, 0 }, { 2, 1 }, { 2, 2 } }) do
    LINES = {}
    NS.barFocus:OnKitGridFocus(focus[1], focus[2])
    print("hint col " .. focus[1] .. " row " .. focus[2] .. ":", LINES[#LINES])
end
db.barOrientation = "VERTICAL"; NS.barFocus:OnKitGridFocus(2, 0); print("vertical bar hint:", LINES[#LINES]); db.barOrientation = "HORIZONTAL"
local labels = {} for _, sd in ipairs(NS.GetAlertSounds()) do labels[#labels + 1] = sd.key .. "=" .. sd.label end
print("alert sounds:", table.concat(labels, "; "))
print("alert defaults:", db.alertTotemExpiring, db.alertTotemExpired, db.alertWeaponExpiring, db.alertLeadTime, db.alertWeaponLeadTime)
PLAYED = {}
NS.PlayAlert("InstrumentsBellRing", "Searing Totem"); NS.PlayAlert("TextToSpeech", "Searing Totem"); NS.PlayAlert("None", "x")
print("play:", table.concat(PLAYED, " | "))
-- Expired: an active slot cleared alerts; quiet period suppresses.
PLAYED = {}
local slot = NS.slots[1]; slot.active = true; slot.totemName = "Stoneskin Totem"
GetTime = function() return 1000 end
NS.EndTotemTimer(1); print("expired alert:", table.concat(PLAYED, " | "))
PLAYED = {}; slot.active = true; NS.QuietTotemAlerts(2); NS.EndTotemTimer(1); print("expired while quiet:", #PLAYED)
PLAYED = {}; NS.EndTotemTimer(1); print("clearing an inactive slot:", #PLAYED)
-- Weapon: warns once on dropping to the lead time, re-arms above it.
PLAYED = {}
for _, r in ipairs({ 300, 120, 61, 60, 59, 30, 0, 1800, 59 }) do NS.CheckWeaponAlert(r, "Flametongue Weapon") end
print("weapon alerts:", table.concat(PLAYED, " | "))
-- Settings: dropdown values and preview.
PLAYED = {}
PROXIES.TOTEMBARFORGAMEPAD_alertTotemExpired.set("TextToSpeech"); print("preview on change:", PLAYED[1], db.alertTotemExpired)
print("slider label:", SLIDER_FMT and SLIDER_FMT(60))
-- Blizzard-style sound menu: top options + category submenus of radios.
local function Desc(label)
    local d = { label = label, children = {} }
    function d:CreateHighlightButton(text) local c = Desc(text); self.children[#self.children + 1] = c; return c end
    function d:CreateHighlightRadio(text, isSel, setSel, data)
        local r = { label = text, isSel = isSel, setSel = setSel, data = data }; self.children[#self.children + 1] = r; return r
    end
    return d
end
RADIO_ADDED = 0
CooldownViewerUtil = { AddSoundAlertRadio = function(alertData, create, isSel, setSel, hl) RADIO_ADDED = RADIO_ADDED + 1; return create(alertData.text, isSel, setSel, alertData.soundEnum) end }
for _, init in ipairs(DROPDOWN_INITS) do
    if init.customOptionHandler and init.setting.var == "TOTEMBARFORGAMEPAD_alertTotemExpired" then
        local root = Desc("root"); init.customOptionHandler(root)
        local top = {} for _, c in ipairs(DROPDOWN_OPTIONS[1] and {} or {}) do end
        for _, sub in ipairs(root.children) do
            local items = {} for _, r in ipairs(sub.children) do items[#items + 1] = r.label .. (r.isSel(r.data) and "*" or "") end
            print("submenu", sub.label, ":", table.concat(items, ", "))
        end
        local bell = root.children[1].children[1]
        bell.setSel(bell.data); print("picked", bell.label, "-> saved", db.alertTotemExpired, "selected now", bell.isSel(bell.data))
        print("via Blizzard helper:", RADIO_ADDED)
        -- Blizzard's builder present: it gets our selection callbacks.
        CooldownViewerUtil.BuildSoundMenus = function(root, isSel, setSel, hl) BUILT = { isSel = isSel, setSel = setSel, hl = hl } end
        init.customOptionHandler(Desc("root2"))
        BUILT.setSel(30); print("Blizzard builder used:", BUILT ~= nil, "highlight", BUILT.hl, "-> saved", db.alertTotemExpired, BUILT.isSel(30), BUILT.isSel(40))
    end
end
for i, opts in ipairs(DROPDOWN_OPTIONS) do
    local data = opts() local labels = {} for _, o in ipairs(data) do labels[#labels + 1] = tostring(o.label) end
    print("dropdown " .. i .. " own options:", table.concat(labels, ", "))
end
-- Welcome guide
local w = NS.welcomeWindow
print("welcome exists:", w ~= nil, "shown flag before:", tostring(db.welcomeShown))
NS.ShowWelcome(); print("ShowWelcome ok")
print("welcome OnHide stored:", type(w.scripts), w.scripts and type(w.scripts.OnHide))
local onHide = w.scripts and w.scripts.OnHide; if onHide then onHide(w) end
print("welcomeShown after closing:", db.welcomeShown)
local em = w.editModeButton
print("edit mode button:", em and em:GetAttribute("type"), em and em:GetAttribute("macrotext"))
local row = CreateFrame("Frame"); NS.BuildMacroRow(row); print("macro row:", #row.tbgMacroButtons)
CreateMacro = function() return 7 end; GetMacroIndexByName = function() return 0 end; GetMacroInfo = function() return nil end
local okCalls = 0
for _, b in ipairs(row.tbgMacroButtons) do
    if type(b.OnSmartNavClick) == "function" then local ok, err = pcall(b.OnSmartNavClick, b); if ok then okCalls = okCalls + 1 else print("smartnav error", err) end end
end
print("OnSmartNavClick ran on", okCalls, "of", #row.tbgMacroButtons, "macro buttons")
-- Weapon enhancement button: learned imbues, keyed by spell ID.
db.showWeaponButton = true; db.weaponEnhancement = 99999; NS.UpdateLayout()
local wf = NS.enhancementButton.flyout
local wk = {} for _, ch in ipairs(wf.buttons) do if ch.choiceKey then wk[#wk + 1] = ch:GetAttribute("choice-key") .. "=" .. ch:GetAttribute("choice-spell") end end
print("weapon choices:", table.concat(wk, ", "), "pick:", db.weaponEnhancement, "casts:", NS.enhancementButton:GetAttribute("spell1"), "proxy:", NS.weaponProxy:GetAttribute("spell1"))
wf:OnChoicePicked(8024, "Spell8024"); print("weapon pick saved:", db.weaponEnhancement, NS.enhancementButton.chosenSpell)
local shownText; NS.enhancementButton.timerText.SetText = function(_, t) shownText = t end
IMBUE.hasEnchant, IMBUE.timeLeft = true, 754000; NS.UpdateImbueTimer(); print("imbue text:", shownText)
IMBUE.hasEnchant = false; NS.UpdateImbueTimer(); print("no imbue text:", shownText == "")
db.showWeaponButton = false; NS.UpdateLayout(); print("weapon hidden casts:", tostring(NS.enhancementButton:GetAttribute("spell1")), "proxy still:", NS.weaponProxy:GetAttribute("spell1"))
-- Totem timers: a readable totem starts the slot's timer; its rank is dropped for alerts.
GetTotemInfo = function(elem) if elem == 2 then return true, "Stoneskin Totem (Rank 3)", 990, 120 end return false, "", 0, 0 end
local earth; for i = 1, 4 do if db.elementOrder[i] == 2 then earth = NS.slots[i] end end
NS.ReadAllTotems(); print("totem timer:", earth.active, earth.timerStart, earth.timerDuration, earth.totemName)
GetTotemInfo = function() return false, "", 0, 0 end; PLAYED = {}; GetTime = function() return 5000 end
NS.ReadTotem(2, true); print("kept after cast:", earth.active)
NS.ReadTotem(2); print("ended:", earth.active, #PLAYED > 0)
ev(NS.bar, "PLAYER_LOGOUT"); print("logout ok", db.activeCallSet == nil)
end, debug.traceback)
-- A Lua error fails the test (after its output so far).
if not ok then error(err, 0) end
`, 'events');
