-- ---------------------------------------------------------------------------
-- GamepadKit: native-looking gamepad support for WoW Forever addons
-- ---------------------------------------------------------------------------
-- Embedded library. To use it in another addon, copy this folder and list its
-- files in that addon's TOC before the addon's own files:
--     GamepadKit\GamepadKit.lua
--     GamepadKit\Glyphs.lua
--     GamepadKit\ActionButtons.lua
--     GamepadKit\FocusNav.lua
--     GamepadKit\BindPrompt.lua
--     GamepadKit\SecureGrid.lua
-- It lives in the host addon's private namespace (ns.GamepadKit) and creates
-- no globals of its own, so several addons can each embed a copy.
--
-- Everything here was verified on the Forever client (build 1.60.1.x):
-- Blizzard's own gamepad focus system is Blizzard-only, so GamepadKit
-- reproduces its look with Blizzard's own art instead of hooking it.
local _, ns = ...
local Kit = ns.GamepadKit or {}
ns.GamepadKit = Kit
Kit.VERSION = 1

-- Secret values (Midnight-era restriction) must never be compared or printed.
function Kit.IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function Kit.AtlasExists(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

function Kit.GetCVarBool(name)
    if C_CVar and C_CVar.GetCVarBool then return C_CVar.GetCVarBool(name) end
    return GetCVarBool and GetCVarBool(name)
end

-- True while gamepad support is on AND a gamepad is connected.
-- C_GamePad.IsEnabled only reflects the setting (GamePadEnable), which stays
-- on with the gamepad unplugged; the active device ID is what says one is
-- there (verified: 5 with an Xbox gamepad attached).
function Kit.IsGamepadActive()
    if not (C_GamePad and C_GamePad.IsEnabled) then return false end
    local ok, enabled = pcall(C_GamePad.IsEnabled)
    if not ok or not enabled or Kit.IsSecret(enabled) then return false end
    if C_GamePad.GetActiveDeviceID then
        local found, id = pcall(C_GamePad.GetActiveDeviceID)
        if not found or id == nil or Kit.IsSecret(id) then return false end
        if type(id) == "number" and id < 0 then return false end
    end
    if C_GamePad.GetAllDeviceIDs then
        local listed, ids = pcall(C_GamePad.GetAllDeviceIDs)
        if listed and type(ids) == "table" and not Kit.IsSecret(ids) and #ids == 0 then return false end
    end
    return true
end

-- The active gamepad's state (C_GamePad.GetDeviceMappedState, readable in
-- and out of combat) with its button and axis names: names.buttons[i] is a
-- binding name like "PADLSHOULDER", names.axes[i] a config name like
-- "LStickX". Nil when there's no gamepad or the state is hidden.
local padNames = {}
function Kit.ReadGamepad()
    local device = C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID()
    local state = device and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState(device)
    if not state or Kit.IsSecret(state) or Kit.IsSecret(state.buttons) or Kit.IsSecret(state.axes) then return end
    local names = padNames[device]
    if not names or names.count ~= #state.buttons then
        names = { count = #state.buttons, buttons = {}, axes = {} }
        for i = 1, #state.buttons do names.buttons[i] = C_GamePad.ButtonIndexToBinding(i - 1) or "" end
        for i = 1, #(state.axes or {}) do names.axes[i] = C_GamePad.AxisIndexToConfigName(i - 1) or "" end
        padNames[device] = names
    end
    return state, names
end

-- True while every named gamepad button is held.
function Kit.GamepadButtonsDown(...)
    local state, names = Kit.ReadGamepad()
    if not state then return false end
    local wanted, found = {}, 0
    for i = 1, select("#", ...) do wanted[select(i, ...)] = true end
    for i, down in ipairs(state.buttons) do
        if down and not Kit.IsSecret(down) and wanted[names.buttons[i]] then found = found + 1 end
    end
    return found == select("#", ...)
end

-- Gamepad connect/disconnect events (registered only where they exist).
Kit.GAMEPAD_EVENTS = { "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "GAME_PAD_ACTIVE_CHANGED" }

function Kit.RegisterGamepadEvents(frame)
    for _, event in ipairs(Kit.GAMEPAD_EVENTS) do
        if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then
            pcall(frame.RegisterEvent, frame, event)
        end
    end
end

-- True while Blizzard's gamepad action bar UI is on screen (read only: hooking
-- Blizzard's gamepad frames taints its gamepad focus code).
function Kit.UsingGamepadBar()
    return GamepadMainActionBarFrame ~= nil and GamepadMainActionBarFrame:IsShown() and true or false
end
