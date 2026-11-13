local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Sound alerts
-- ---------------------------------------------------------------------------
-- The sounds are Blizzard's own alert sounds, the same selection its
-- Cooldown Manager and Combat Audio Alerts offer (CooldownViewerSoundData,
-- from Blizzard_CooldownViewer), read from the game with their localized
-- names, plus Blizzard's Text-to-Speech (it speaks the spell's name). They play the
-- way the Cooldown Manager plays them. A choice is saved as the sound's enum
-- name (e.g. "InstrumentsBellRing"), "TextToSpeech", or "None".
--
-- Events: a totem about to expire, a totem gone (ran out or destroyed; not
-- when you recall it), and the weapon enhancement about to expire.

ns.ALERT_NONE, ns.ALERT_TTS = "None", "TextToSpeech"

-- The category names Blizzard's Cooldown Manager menu uses.
local CATEGORY_LABELS = {
    Animals = "COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_ANIMALS",
    Devices = "COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_DEVICES",
    Impacts = "COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_IMPACTS",
    Instruments = "COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_INSTRUMENTS",
    Short = "COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_SHORT",
    War2 = "COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_WAR2",
    War3 = "COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_WAR3",
}

local function GameString(name, fallback)
    local value = _G[name]
    return type(value) == "string" and value ~= "" and value or fallback
end

-- Reverse lookup of an enum table: value -> key name.
local function EnumNames(enum)
    local names = {}
    for key, value in pairs(enum or {}) do names[value] = key end
    return names
end

local sounds, soundByKey, soundGroups
-- The choices: { key, label, soundKitID?, soundEnum?, category? } (label
-- is "Category: Sound"; text is the sound's own name), and the same sounds
-- grouped for menus: { { label = category, sounds = { ... } } }. Built on
-- first use (Blizzard_CooldownViewer loads with the UI).
local function BuildSounds()
    sounds = {
        { key = ns.ALERT_NONE, label = GameString("NONE", "None") },
        { key = ns.ALERT_TTS, label = GameString("COOLDOWN_VIEWER_SETTINGS_ALERT_LABEL_SOUND_TYPE_TEXT_TO_SPEECH", "Text to Speech") },
    }
    soundByKey, soundGroups = {}, {}
    local data = rawget(_G, "CooldownViewerSoundData")
    local soundNames = EnumNames(Enum and Enum.CooldownViewerSound)
    local categoryNames = EnumNames(Enum and Enum.CooldownViewerSoundCategory)
    -- Blizzard's categories in its order (the data is keyed by category enum).
    local categories = {}
    for category in pairs(type(data) == "table" and data or {}) do categories[#categories + 1] = category end
    table.sort(categories)
    for _, category in ipairs(categories) do
        local categoryName = categoryNames[category] or tostring(category)
        local group = { label = GameString(CATEGORY_LABELS[categoryName] or "", categoryName), sounds = {} }
        for _, entry in ipairs(data[category]) do
            local key = soundNames[entry.soundEnum]
            if key and entry.soundKitID then
                local text = entry.text or key
                local sound = { key = key, soundKitID = entry.soundKitID, soundEnum = entry.soundEnum,
                    text = text, label = group.label .. ": " .. text }
                sounds[#sounds + 1] = sound
                group.sounds[#group.sounds + 1] = sound
            end
        end
        if #group.sounds > 0 then soundGroups[#soundGroups + 1] = group end
    end
    for _, sound in ipairs(sounds) do soundByKey[sound.key] = sound end
end

function ns.GetAlertSounds()
    if not sounds then BuildSounds() end
    return sounds
end

function ns.GetAlertSoundGroups()
    if not sounds then BuildSounds() end
    return soundGroups
end

-- The saved key of a Cooldown Manager sound enum value (menus pass those).
function ns.AlertKeyForSoundEnum(soundEnum)
    for _, sound in ipairs(ns.GetAlertSounds()) do
        if sound.soundEnum == soundEnum then return sound.key end
    end
end

-- Plays a saved choice. spellName is what Text-to-Speech says.
function ns.PlayAlert(key, spellName)
    ns.GetAlertSounds()
    local sound = soundByKey[key or ns.ALERT_NONE]
    if not sound or key == ns.ALERT_NONE then return end
    if key == ns.ALERT_TTS then
        if spellName and TextToSpeechFrame_PlayCooldownAlertMessage then
            local allowOverlappedSpeech = true
            TextToSpeechFrame_PlayCooldownAlertMessage(nil, spellName, allowOverlappedSpeech)
        end
    elseif C_Sound and C_Sound.PlaySoundWithOptions then
        C_Sound.PlaySoundWithOptions({ soundKitID = sound.soundKitID, uiSoundSubType = "Gameplay SFX" })
    else
        PlaySound(sound.soundKitID, "SFX")
    end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local function DB() return TotemBarForGamepadDB end

-- Totems vanish without an alert when you recall them yourself or while
-- the world loads (zoning, logging in).
local quietUntil = 0
function ns.QuietTotemAlerts(seconds)
    quietUntil = math.max(quietUntil, GetTime() + seconds)
end

function ns.AlertTotemExpiring(spellName)
    if DB() then ns.PlayAlert(DB().alertTotemExpiring, spellName) end
end

function ns.AlertTotemExpired(spellName)
    if DB() and GetTime() >= quietUntil then ns.PlayAlert(DB().alertTotemExpired, spellName) end
end

-- The weapon enhancement warning: once per application, when its time left
-- first drops to the lead time (re-armed once it's above it again).
local weaponWarned = false
function ns.CheckWeaponAlert(remaining, spellName)
    local db = DB()
    if not db or not remaining then return end
    local lead = db.alertWeaponLeadTime or 60
    if remaining > lead then
        weaponWarned = false
    elseif remaining > 0 and not weaponWarned then
        weaponWarned = true
        ns.PlayAlert(db.alertWeaponExpiring, spellName)
    end
end
