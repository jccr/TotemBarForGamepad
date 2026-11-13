local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Totem timers: the time left on each placed totem and on the weapon imbue
-- ---------------------------------------------------------------------------
-- The game reports one totem per element (GetTotemInfo). Out of combat its
-- start and duration are readable: the slot's swipe and text count down
-- from them, and the "about to expire" alert fires from them. In combat they
-- can be secret values. Then the game's duration object (GetTotemDuration)
-- drives the swipe and a duration text binding draws the text, so nothing
-- reads the time; the totem is read again once combat ends.
local Readable = ns.Readable
local IsSecret = ns.IsSecretValue

-- m:ss for anything under an hour: Blizzard's countdown would show "5m".
local function FormatClock(seconds)
    local whole = math.floor(math.max(0, seconds))
    return ("%d:%02d"):format(math.floor(whole / 60), whole % 60)
end

-- The same m:ss as a formatter the game applies itself (to restricted time
-- too): minutes, then the seconds within the minute, both rounded down.
local roundDown = Enum.NumericRuleFormatRounding.Down
local clockFormatter = C_StringUtil.CreateNumericRuleFormatter()
clockFormatter:SetBreakpoints({ {
    threshold = 0, min = 0, step = 1, rounding = roundDown, format = "%d:%02d",
    components = {
        { div = 60, step = 1, rounding = roundDown },
        { mod = 60, step = 1, rounding = roundDown },
    },
} })

-- Each slot: its template cooldown is the totem's swipe (with the game's
-- countdown numbers off, the time shows in timerText), plus a text binding
-- for restricted time.
for _, slot in ipairs(ns.slots) do
    local cooldown = slot.cooldown
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetCountdownAbbrevThreshold(3600)
    cooldown:SetCountdownMillisecondsThreshold(0)
    cooldown:SetCountdownFormatter(clockFormatter)
    local binding = C_DurationUtil.CreateDurationTextBinding()
    binding:SetFontString(slot.timerText)
    binding:SetFormatter(clockFormatter)
    binding:SetUpdateInterval(0.1)
    binding:SetExpiredText("")
    binding:SetZeroDurationText("")
    binding:Disable()
    slot.timeBinding = binding
end

local function SlotOfElement(elem)
    for index, slotElem in ipairs(TotemBarForGamepadDB.elementOrder) do
        if slotElem == elem then return ns.slots[index], index end
    end
end

-- Totem names come with their rank ("Searing Totem III", "Searing Totem
-- (Rank 3)"); alerts say the spell's name.
local function WithoutRank(name)
    return (name:gsub("%s*%b()", ""):gsub("%s+[IVX]+$", ""))
end

-- Back to readable timing: no binding, no duration object.
local function StopRestrictedTimer(slot)
    slot.timeBinding:Disable()
    slot.timerObject = nil
    slot.cooldown:SetHideCountdownNumbers(true)
end

local function ShowReadableTimer(slot, slotIndex, start, duration, name)
    -- The same totem reported again (e.g. by the cast and the totem event).
    if slot.active and not slot.timerObject and slot.timerStart == start and slot.timerDuration == duration then
        return
    end
    StopRestrictedTimer(slot)
    slot.timerStart, slot.timerDuration = start, duration
    slot.totemName = WithoutRank(name)
    slot.active, slot.expiryAlerted = true, false
    ns.UpdateSlotLook(slotIndex)
    slot.cooldown:SetCooldown(start, duration)
end

local function ShowRestrictedTimer(slot, slotIndex, timer)
    slot.timerObject = timer
    slot.active, slot.totemName = true, nil
    ns.UpdateSlotLook(slotIndex)
    slot.timerText:SetText("")
    slot.timeBinding:SetDuration(timer)
    slot.timeBinding:Enable()
    slot.timeBinding:UpdateFontString()
    slot.cooldown:SetCooldownFromDurationObject(timer)
end

-- Set when a totem's time was restricted; Events.lua reads every totem again
-- once combat ends.
ns.totemsNeedReread = false

-- Reads one element's totem into its slot. justCast: a cast just
-- happened, so a slot that reports no totem yet keeps its live timer until
-- the game reports the new one.
function ns.ReadTotem(elem, justCast)
    local slot, slotIndex = SlotOfElement(elem)
    if not slot then return end
    local _, name, start, duration = GetTotemInfo(elem)
    if IsSecret(start) or IsSecret(duration) then
        ns.totemsNeedReread = true
        local timer = GetTotemDuration(elem)
        if timer then ShowRestrictedTimer(slot, slotIndex, timer) end
        return
    end
    if duration and duration > 0 then
        -- The name can be restricted on its own; the slot's spell stands in.
        ShowReadableTimer(slot, slotIndex, start, duration, Readable(name) or slot.chosenSpell or "")
    elseif not justCast then
        ns.EndTotemTimer(slotIndex)
    end
end

function ns.ReadAllTotems()
    for elem = 1, 4 do ns.ReadTotem(elem) end
end

function ns.EndTotemTimer(slotIndex)
    local slot = ns.slots[slotIndex]
    if not slot then return end
    -- A totem that was down is gone (ran out or destroyed).
    if slot.active then ns.AlertTotemExpired(slot.totemName) end
    StopRestrictedTimer(slot)
    slot.active, slot.totemName = false, nil
    ns.UpdateSlotLook(slotIndex)
end

-- ---------------------------------------------------------------------------
-- Weapon imbue
-- ---------------------------------------------------------------------------
-- Seconds left on the main hand's shaman imbue: 0 without one, nil while
-- combat restricts it. This client lists imbues apart from oils and stones
-- (their own enchant type).
local function ImbueTimeLeft()
    local enchants = Readable(C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand))
    if not enchants then return nil end
    for _, enchant in pairs(enchants) do
        if Readable(enchant) and Readable(enchant.enchantType) == Enum.ItemEnchantType.Imbue then
            local hasEnchant, timeLeft = Readable(enchant.hasEnchant), Readable(enchant.timeLeft)
            if hasEnchant == nil or timeLeft == nil then return nil end
            return hasEnchant and timeLeft / 1000 or 0
        end
    end
    return 0
end

-- The weapon button's time text, and the weapon alert (which works whether
-- or not the button is on the bar).
local function UpdateImbueTimer()
    local left = ImbueTimeLeft()
    local button = ns.enhancementButton
    ns.CheckWeaponAlert(left, button.chosenSpell or ns.weaponProxy:GetAttribute("spell1"))
    local shown = TotemBarForGamepadDB.showWeaponButton and left and left > 0
    button.timerText:SetText(shown and FormatClock(left) or "")
end
ns.UpdateImbueTimer = UpdateImbueTimer

-- ---------------------------------------------------------------------------
-- Ticking
-- ---------------------------------------------------------------------------
local function UpdateTotemText(slot, slotIndex, now)
    local left = slot.timerStart + slot.timerDuration - now
    if left <= 0 then
        ns.EndTotemTimer(slotIndex)
        return
    end
    slot.timerText:SetText(FormatClock(left))
    -- About to expire (never for a totem shorter than the lead time).
    local lead = TotemBarForGamepadDB.alertLeadTime or 5
    if not slot.expiryAlerted and left <= lead and slot.timerDuration > lead then
        slot.expiryAlerted = true
        ns.AlertTotemExpiring(slot.totemName)
    end
end

-- Ten times a second, like the game's own duration text bindings. Restricted
-- timers draw themselves.
C_Timer.NewTicker(0.1, function()
    if not TotemBarForGamepadDB then return end
    local now = GetTime()
    for slotIndex, slot in ipairs(ns.slots) do
        if slot.active and not slot.timerObject then UpdateTotemText(slot, slotIndex, now) end
    end
    UpdateImbueTimer()
end)
