-- ---------------------------------------------------------------------------
-- GamepadKit: gamepad "Bind to Action Bar"
-- ---------------------------------------------------------------------------
-- A look-alike of Blizzard's gamepad bind mode (what X "Bind" opens in the
-- spellbook): it shows an action, waits for a button combination and hands
-- back the gamepad action bar slot it means. It binds only the 8 gamepad
-- action buttons while open, so LT/RT/LB/RB keep working (layer preview,
-- LB+RB paging). Starting Blizzard's own bind mode
-- from addon code taints the gamepad layer and its input stops, so this one
-- only reads Blizzard's bars; the host places the action (PlaceAction is open
-- to addons out of combat).
--
-- Kit.GamepadBindSlot(key, leftHeld, rightHeld) -> slot or nil
-- local prompt = Kit.CreateBindPrompt(name)
-- prompt:Open{ label = "Name", icon = texture,
--              onBind = function(slot, comboText) end,  -- the host places it
--              onCancel = function() end }
--
-- How Blizzard reads a combination (verified against its bars on this client):
-- the 8 gamepad action buttons are the GAMEPADACTIONBUTTON1-8 bindings (D-pad
-- and face buttons); GAMEPADLEFTMOD / GAMEPADRIGHTMOD (LT / RT) pick the bar:
-- none -> top, left -> left, right -> right, both -> bottom; the slot is that
-- bar button's CalculateAction(). Slot 0 is a reserved button (not bindable).
local _, ns = ...
local Kit = ns.GamepadKit

local BARS = {
    [false] = { [false] = "topBar", [true] = "rightBar" },
    [true] = { [false] = "leftBar", [true] = "bottomBar" },
}
local GLYPH_SIZE, LEGEND_GLYPH_SIZE = 24, 34
-- Blizzard's gamepad bar paging is LB + RB + D-pad Left/Right.
local PAGING_KEYS = { PADDLEFT = true, PADDRIGHT = true }
local proxyCount = 0

-- Which of the 8 gamepad action buttons a key is (1-8), from the game's bindings.
local function ActionButtonIndex(key)
    for index = 1, 8 do
        for _, bound in ipairs({ GetBindingKey("GAMEPADACTIONBUTTON" .. index) }) do
            if bound == key then return index end
        end
    end
end

function Kit.GamepadBindSlot(key, leftHeld, rightHeld)
    local pageUnit = rawget(_G, "GamepadMainActionBarFrame") and GamepadMainActionBarFrame.PageUnit
    local bars = pageUnit and pageUnit.actionBars
    local index = ActionButtonIndex(key)
    if not (bars and index) then return nil end
    local bar = bars[BARS[leftHeld and true or false][rightHeld and true or false]]
    local button = bar and bar.GetActionButtonByIndex and bar:GetActionButtonByIndex(index)
    local slot = button and button.CalculateAction and button:CalculateAction()
    if type(slot) ~= "number" or slot <= 0 then return nil end
    return slot
end

local Prompt = {}
Prompt.__index = Prompt

function Kit.CreateBindPrompt(name)
    local prompt = setmetatable({}, Prompt)
    -- Blizzard's own bind info frame template: border, title box ("Bind to
    -- Action Bar"), glow, instruction, action name and icon.
    local ok, frame = pcall(CreateFrame, "Frame", name, UIParent, "GamepadActionBarEditBindingsInfoFrameTemplate")
    if not (ok and frame) then
        frame = CreateFrame("Frame", name, UIParent, "DialogBorderTemplate")
    end
    -- Without the template (or parts of it), the same pieces built here.
    if not frame.BindInstructionText then
        frame.BindInstructionText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        frame.BindInstructionText:SetPoint("TOP", 0, -50)
        frame.BindInstructionText:SetText(GAMEPAD_EDIT_FRAME_BIND_INFO_FRAME_BIND_INSTRUCTION
            or "Press the button combination you want to use for:")
    end
    if not frame.ActionName then
        frame.ActionName = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge2")
        frame.ActionName:SetPoint("CENTER", 0, -5)
    end
    if not frame.ActionIcon then
        frame.ActionIcon = frame:CreateTexture(nil, "ARTWORK")
        frame.ActionIcon:SetSize(40, 40)
        frame.ActionIcon:SetPoint("TOP", frame.ActionName, "BOTTOM", 0, -10)
    end
    frame:SetSize(485, 180)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 75)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:Hide()
    prompt.frame = frame

    -- Footer legend, as Blizzard's: B Back.
    local legend = CreateFrame("Frame", nil, frame)
    legend:SetSize(160, 44)
    legend:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
    local bg = legend:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local border = legend:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    if Kit.AtlasExists("gamepad-footer-slot-bg") then
        bg:SetAtlas("gamepad-footer-slot-bg")
        border:SetAtlas("gamepad-footer-slot-frameneutral")
    else
        bg:SetColorTexture(0, 0, 0, 0.8)
    end
    legend.text = legend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    legend.text:SetPoint("CENTER")
    legend.text:SetText(Kit.Prompt("PAD2", BACK or "Back", LEGEND_GLYPH_SIZE, "B"))

    -- Input: the prompt override-binds only the 8 gamepad action buttons (so
    -- pressing one binds instead of casting). LT/RT/LB/RB stay with the game:
    -- Blizzard's bars expand for the held layer, and LB+RB+D-pad still pages
    -- (D-pad Left/Right are let go while LB+RB are held). Whether LT/RT are
    -- held is read from the gamepad state at the press.
    local function OnActionKey(key)
        if not prompt:IsOpen() then return end
        local leftMod, rightMod = GetBindingKey("GAMEPADLEFTMOD"), GetBindingKey("GAMEPADRIGHTMOD")
        local left = leftMod and Kit.GamepadButtonsDown(leftMod)
        local right = rightMod and Kit.GamepadButtonsDown(rightMod)
        -- B on its own (a reserved button anyway) is Back.
        if key == "PAD2" and not left and not right then
            prompt:Close(true)
            return
        end
        local slot = Kit.GamepadBindSlot(key, left, right)
        if not slot then
            -- A reserved button (e.g. A without a trigger): Blizzard's message.
            UIErrorsFrame:AddMessage(GAMEPAD_BIND_FAILURE_INVALID_STANDARD_SLOT or "That button can't be bound.",
                RED_FONT_COLOR:GetRGB())
            return
        end
        local glyphs = {}
        if left then glyphs[#glyphs + 1] = Kit.Glyph(leftMod, GLYPH_SIZE, leftMod) end
        if right then glyphs[#glyphs + 1] = Kit.Glyph(rightMod, GLYPH_SIZE, rightMod) end
        glyphs[#glyphs + 1] = Kit.Glyph(key, GLYPH_SIZE, key)
        local onBind = prompt.spec and prompt.spec.onBind
        prompt:Close(false)
        if onBind then onBind(slot, table.concat(glyphs, " + ")) end
    end

    -- One plain proxy button per action key, clicked by its override binding.
    prompt.proxies = {}
    proxyCount = proxyCount + 1
    function prompt:Bind()
        if InCombatLockdown() then return end
        ClearOverrideBindings(frame)
        local paging = self.pagingHeld
        for index = 1, 8 do
            for _, key in ipairs({ GetBindingKey("GAMEPADACTIONBUTTON" .. index) }) do
                if not (paging and PAGING_KEYS[key]) then
                    local proxy = self.proxies[key]
                    if not proxy then
                        proxy = CreateFrame("Button", "GamepadKitBindProxy" .. proxyCount .. key, UIParent)
                        proxy:RegisterForClicks("AnyDown")
                        proxy:SetScript("OnClick", function() OnActionKey(key) end)
                        self.proxies[key] = proxy
                    end
                    SetOverrideBindingClick(frame, true, key, proxy:GetName(), "LeftButton")
                end
            end
        end
    end

    -- LB+RB (Blizzard's paging hold) is watched, not bound.
    frame:SetScript("OnUpdate", function()
        if InCombatLockdown() then return end
        local held = Kit.GamepadButtonsDown("PADLSHOULDER", "PADRSHOULDER") and true or false
        if held ~= (prompt.pagingHeld or false) then
            prompt.pagingHeld = held
            prompt:Bind()
        end
    end)
    frame:SetScript("OnHide", function()
        prompt.pagingHeld = false
        if not InCombatLockdown() then ClearOverrideBindings(frame) end
    end)

    -- Combat ends it (its bindings can't change then, and placing actions is
    -- blocked); this event comes just before the lockdown starts.
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function()
        if frame:IsShown() then prompt:Close(true) end
    end)
    return prompt
end

-- Out of combat only.
function Prompt:Open(spec)
    if InCombatLockdown() then return false end
    self.spec = spec
    local frame = self.frame
    frame.ActionName:SetText(spec.label or "")
    frame.ActionIcon:SetTexture(spec.icon or 134400)
    self.pagingHeld = false
    frame:Show()
    self:Bind()
    return true
end

function Prompt:Close(cancelled)
    local spec = self.spec
    self.spec = nil
    if not InCombatLockdown() then ClearOverrideBindings(self.frame) end
    self.frame:Hide()
    if cancelled and spec and spec.onCancel then spec.onCancel() end
end

function Prompt:IsOpen()
    return self.frame:IsShown()
end
