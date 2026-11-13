-- ---------------------------------------------------------------------------
-- GamepadKit: focus navigation for windows
-- ---------------------------------------------------------------------------
-- Native-looking D-pad / A / B navigation for an addon window, mirroring
-- Forever's gamepad UI (which addons cannot join: it is Blizzard-only):
-- a gold chevron on the focused control, Blizzard's focus glow around the
-- window, and a footer input legend with the gamepad's own glyphs.
--
-- local nav = Kit.CreateFocusNavigator(window, {
--     onClose = function() ... end,   -- B, and A on "close" items (required)
--     scrollFrame = sf, content = c,  -- optional: keep the focus scrolled into view
--     titlePlate = frame,             -- optional: gets its own glow
--     combatMessage = "...",          -- optional: printed when combat closes it
--     bindingsOnly = true,            -- optional: never capture the gamepad; drive
--                                     -- navigation with override bindings only, so
--                                     -- other buttons (LB/RB paging, triggers,
--                                     -- sticks) keep working while it's open
--     passWhileHeld = { hold = { "PADLSHOULDER", "PADRSHOULDER" },
--                       keys = { "PADDLEFT", "PADDRIGHT" } },
--                                     -- optional, with bindingsOnly: while all of
--                                     -- `hold` are held, `keys` go to the game
--                                     -- (e.g. Blizzard's LB+RB+D-pad paging)
-- })
-- nav:AddItem{ kind = "check" | "button" | "choice" | "close",
--              anchor = frame,          -- the chevron points at its left edge
--              control = button,        -- clicked by A (check/button)
--              label = "Select",        -- A's footer label (button)
--              step = function(delta),  -- choice: D-pad left/right
--              open = function(),       -- choice: A opens a classic UIDropDownMenu list
--              getIndex = function(),   -- choice: current value's list position
--              secureButton = "Name",   -- button: A clicks this secure button
--                                       --   for real (see below)
--              offset = 2, noScroll = false }
-- nav:SetStartItem(index)                 -- focused when the window opens
--
-- Window frame levels the glow expects (relative to the window): border +1,
-- window glow +2 (created here), title plate glow +3, title plate +4, close +5.
-- The navigator is active while the window is shown, a gamepad is enabled
-- and the player is out of combat; combat closes the window, because the
-- window holds the gamepad's buttons while focused.
--
-- Secure buttons: addon code can't click a secure action button for real
-- (the action would run tainted), and a window capturing gamepad buttons
-- can't pass one on (input propagation is keyboard-only). So while an item
-- with `secureButton` has focus, the window stops capturing the gamepad and
-- override bindings take over: A clicks the secure button (the physical
-- press, as a key binding would), the D-pad and B drive the navigator
-- through plain proxy buttons, and X and Y go to proxies that ignore them.
local _, ns = ...
local Kit = ns.GamepadKit
local unpack = unpack or table.unpack

local GLOW_ATLAS = "gamepad-uiframediamondmetal-focus-large"
-- The glow atlas is a 110x110 nine-slice, drawn on a half-scale layer. The
-- margin was measured against the Game Menu on screen: its glow peaks right
-- at the border's outer edge.
local GLOW_SCALE, GLOW_MARGIN = 0.5, 4.5
-- Matches the native footer's 34-unit input icons.
local LEGEND_GLYPH_SIZE = 34
local LEGEND_SPACER = "      "

local Navigator = {}
Navigator.__index = Navigator

local function AddGlow(parent, target, frameLevel)
    if not (target and Kit.AtlasExists(GLOW_ATLAS)) then return end
    local layer = CreateFrame("Frame", nil, parent)
    layer:SetScale(GLOW_SCALE)
    layer:SetFrameLevel(frameLevel)
    local texture = layer:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetAtlas(GLOW_ATLAS)
    if texture.SetTextureSliceMargins then
        texture:SetTextureSliceMargins(52, 52, 52, 52)
        if Enum and Enum.UITextureSliceMode and texture.SetTextureSliceMode then
            texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
    end
    -- Offsets are in the layer's half-scale units.
    local pad = GLOW_MARGIN / GLOW_SCALE
    layer:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
    layer:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
end

-- Blizzard's own chevron: the large gold one on the gamepad footer sheet,
-- measured from the texture (no named atlas exists for it).
local function CreateChevron(window)
    local chevron = CreateFrame("Frame", nil, window)
    chevron:SetSize(16, 37) -- same 24x56 proportions as the texture region
    chevron:SetFrameStrata("TOOLTIP")
    local texture = chevron:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetTexture(6227249)
    texture:SetTexCoord(44 / 2048, 68 / 2048, 140 / 1024, 196 / 1024)
    -- Out and back as two eased steps; a BOUNCE loop snaps at the turnaround.
    local bob = chevron:CreateAnimationGroup()
    bob:SetLooping("REPEAT")
    for order, offset in ipairs({ -4, 4 }) do
        local step = bob:CreateAnimation("Translation")
        step:SetOffset(offset, 0)
        step:SetDuration(0.6)
        step:SetSmoothing("IN_OUT")
        step:SetOrder(order)
    end
    chevron:SetScript("OnShow", function() bob:Play() end)
    chevron:SetScript("OnHide", function() bob:Stop() end)
    chevron:Hide()
    return chevron
end

-- Footer input legend, using Blizzard's footer slot art; labels are gold.
local function CreateLegend(window)
    local legend = CreateFrame("Frame", nil, window)
    legend:SetSize(240, 44)
    legend:SetPoint("TOP", window, "BOTTOM", 0, -2)
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
    legend:Hide()
    return legend
end

local function Prompt(key, label, fallback)
    return Kit.Prompt(key, label, LEGEND_GLYPH_SIZE, fallback)
end

local function ListShown()
    return DropDownList1 and DropDownList1:IsShown()
end

function Navigator:AddItem(item)
    item.offset = item.offset or 1
    self.items[#self.items + 1] = item
    return #self.items
end

function Navigator:SetStartItem(index)
    self.startIndex = index
end

function Navigator:ScrollIntoView(widget)
    local scroll, content = self.opts.scrollFrame, self.opts.content
    if not (scroll and content) then return end
    local contentTop = content:GetTop()
    local top, bottom = widget:GetTop(), widget:GetBottom()
    if not (contentTop and top and bottom) then return end
    -- Offsets from the content's top do not change as it scrolls.
    local fromTop, toBottom = contentTop - top, contentTop - bottom
    local current, view = scroll:GetVerticalScroll(), scroll:GetHeight()
    if fromTop - 8 < current then
        current = fromTop - 8
    elseif toBottom + 8 > current + view then
        current = toBottom + 8 - view
    end
    scroll:SetVerticalScroll(math.max(0, math.min(current, scroll:GetVerticalScrollRange())))
end

local PROXY_KEYS = { "PAD1", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD2", "PAD3", "PAD4" }
local proxyCount = 0

-- Plain buttons the bindings click while a secure item has focus; each feeds
-- its key to the navigator.
function Navigator:CreateProxies()
    self.proxies = {}
    proxyCount = proxyCount + 1
    for _, key in ipairs(PROXY_KEYS) do
        local proxy = CreateFrame("Button", "GamepadKitNavProxy" .. proxyCount .. key, UIParent)
        proxy:RegisterForClicks("AnyDown")
        proxy:SetScript("OnClick", function()
            if self.active then self:HandleButton(key) end
        end)
        self.proxies[key] = proxy:GetName()
    end
end

-- Gamepad input for the focused item (out of combat): the window captures
-- the buttons, or override bindings do: for a secure item (see above), and
-- always with opts.bindingsOnly. In bindings mode A goes to the secure button
-- when the item has one, else to the navigator like the other keys.
function Navigator:BindSecureButton()
    if InCombatLockdown() then return end
    local item = self.active and not self.listOpen and self.items[self.index]
    local target = item and item.secureButton or nil
    local useBindings = self.active and (self.opts.bindingsOnly or target ~= nil)
    if self.window.EnableGamePadButton then
        self.window:EnableGamePadButton((self.active and not useBindings) and true or false)
    end
    -- passWhileHeld: its keys are left unbound while its buttons are held.
    local pass = useBindings and self.passHeld and self.opts.passWhileHeld
    local passing = {}
    for _, key in ipairs(pass and pass.keys or {}) do passing[key] = true end
    local mode = useBindings and ((target or "navigator") .. (pass and "+pass" or "")) or nil
    if mode == self.boundMode then return end
    ClearOverrideBindings(self.window)
    if useBindings then
        if not self.proxies then self:CreateProxies() end
        for key, proxyName in pairs(self.proxies) do
            if not passing[key] then
                SetOverrideBindingClick(self.window, true, key, (key == "PAD1" and target) or proxyName, "LeftButton")
            end
        end
    end
    self.boundMode = mode
end

function Navigator:Update()
    self:BindSecureButton()
    if not self.active then
        self.chevron:Hide()
        self.legend:Hide()
        self.glow:Hide()
        return
    end
    if self.listOpen and not ListShown() then self.listOpen = false end

    local anchor, offset, text
    local close = Prompt("PAD2", "Close", "B")
    if self.listOpen then
        anchor, offset = _G["DropDownList1Button" .. self.listIndex], 1
        text = Prompt("PAD1", "Select", "A") .. LEGEND_SPACER .. Prompt("PAD2", "Back", "B")
    else
        local item = self.items[self.index]
        if not item then return end
        if not item.noScroll then self:ScrollIntoView(item.anchor) end
        anchor, offset = item.anchor, item.offset
        if item.kind == "close" then
            text = Prompt("PAD1", "Close", "A") .. LEGEND_SPACER .. close
        elseif item.kind == "choice" then
            text = Kit.Glyph("PADDLEFT", LEGEND_GLYPH_SIZE, "<") .. Kit.Glyph("PADDRIGHT", LEGEND_GLYPH_SIZE, ">")
                .. " Change" .. LEGEND_SPACER .. (item.open and (Prompt("PAD1", "List", "A") .. LEGEND_SPACER) or "")
                .. close
        elseif item.kind == "check" then
            text = Prompt("PAD1", "Toggle", "A") .. LEGEND_SPACER .. close
        else
            text = Prompt("PAD1", item.label or "Select", "A") .. LEGEND_SPACER .. close
        end
    end
    if anchor then
        self.chevron:ClearAllPoints()
        self.chevron:SetPoint("RIGHT", anchor, "LEFT", offset, 0)
        self.chevron:Show()
    end
    self.legend.text:SetText(text)
    self.legend:SetWidth(math.max(200, self.legend.text:GetStringWidth() + 56))
    self.legend:Show()
    self.glow:Show()
end

function Navigator:HandleButton(button)
    -- Classic list open: navigate its entries.
    if self.listOpen and ListShown() then
        local count = math.max(1, DropDownList1.numButtons or 1)
        if button == "PADDUP" then
            self.listIndex = self.listIndex <= 1 and count or self.listIndex - 1
        elseif button == "PADDDOWN" then
            self.listIndex = self.listIndex >= count and 1 or self.listIndex + 1
        elseif button == "PAD1" then
            local entry = _G["DropDownList1Button" .. self.listIndex]
            if entry then entry:Click() end
            -- Choosing closes the list; let it finish before redrawing.
            C_Timer.After(0, function() self:Update() end)
        elseif button == "PAD2" then
            CloseDropDownMenus()
            self.listOpen = false
        else
            return false
        end
        self:Update()
        return true
    end

    local item = self.items[self.index]
    local count = #self.items
    if not item then return false end
    if button == "PADDUP" then
        self.index = self.index <= 1 and count or self.index - 1
    elseif button == "PADDDOWN" then
        self.index = self.index >= count and 1 or self.index + 1
    elseif (button == "PADDLEFT" or button == "PADDRIGHT") and item.kind == "choice" and item.step then
        item.step(button == "PADDLEFT" and -1 or 1)
    elseif button == "PAD1" then
        -- A is the secure button's own binding (BindSecureButton).
        if item.secureButton then return false end
        if item.kind == "close" then
            self.opts.onClose()
            return true
        elseif item.kind == "choice" then
            if not item.open then return false end
            item.open()
            self.listOpen = ListShown() and true or false
            self.listIndex = item.getIndex and item.getIndex() or 1
        elseif item.control then
            item.control:Click()
        else
            return false
        end
    elseif button == "PAD2" then
        self.opts.onClose()
        return true
    else
        return false
    end
    self:Update()
    return true
end

function Kit.CreateFocusNavigator(window, opts)
    assert(type(opts) == "table" and type(opts.onClose) == "function", "GamepadKit: onClose is required")
    local nav = setmetatable({ window = window, opts = opts, items = {}, index = 1, listIndex = 1 }, Navigator)

    -- Drawn above the border: the Game Menu's glow peaks over the border's
    -- dark outer rim. The atlas is hollow, so it never covers the contents.
    local base = window:GetFrameLevel()
    nav.glow = CreateFrame("Frame", nil, window)
    nav.glow:SetAllPoints(window)
    nav.glow:SetFrameLevel(base + 2)
    nav.glow:Hide()
    AddGlow(nav.glow, window, base + 2)
    -- The title plate is smaller than the glow's hollow center, so its glow
    -- goes behind the plate to keep the title text crisp.
    if opts.titlePlate then AddGlow(nav.glow, opts.titlePlate, base + 3) end

    nav.chevron = CreateChevron(window)
    nav.legend = CreateLegend(window)

    -- passWhileHeld: watch the hold buttons while active (gamepad state is
    -- readable without capturing input) and rebind when they change.
    if opts.bindingsOnly and opts.passWhileHeld then
        local watcher = CreateFrame("Frame", nil, window)
        watcher:SetScript("OnUpdate", function()
            if not nav.active or InCombatLockdown() then return end
            local held = Kit.GamepadButtonsDown(unpack(opts.passWhileHeld.hold)) and true or false
            if held ~= (nav.passHeld or false) then
                nav.passHeld = held
                nav:BindSecureButton()
            end
        end)
    end

    window:SetScript("OnGamePadButtonDown", function(frame, button)
        local handled = nav.active and nav:HandleButton(button)
        -- Unused buttons pass through to the game where the client allows it.
        if not InCombatLockdown() then frame:SetPropagateKeyboardInput(not handled) end
    end)

    -- Gamepad navigation (focus, glow and legend) only while a gamepad
    -- is connected; plugging one in or out updates an open window.
    local function RefreshActive(frame)
        nav.active = frame:IsShown() and Kit.IsGamepadActive() and not InCombatLockdown()
        if not InCombatLockdown() and frame.EnableGamePadButton then
            frame:EnableGamePadButton(nav.active)
        end
        nav:Update()
    end

    window:HookScript("OnShow", function(frame)
        nav.index = nav.startIndex or 1
        nav.listOpen = false
        RefreshActive(frame)
    end)

    window:HookScript("OnHide", function(frame)
        nav.active = false
        nav.listOpen = false
        nav:Update()
        if not InCombatLockdown() and frame.EnableGamePadButton then
            frame:EnableGamePadButton(false)
        end
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    Kit.RegisterGamepadEvents(events)
    events:SetScript("OnEvent", function(_, event)
        if event:find("^GAME_PAD_") then
            if window:IsShown() and not InCombatLockdown() then RefreshActive(window) end
        elseif event == "PLAYER_REGEN_DISABLED" then
            if nav.active and window:IsShown() then
                opts.onClose()
                if opts.combatMessage then print(opts.combatMessage) end
            end
        elseif not window:IsShown() then
            -- Hidden during combat: release the gamepad (and any secure
            -- binding) now that it's allowed.
            nav:BindSecureButton()
            if window.EnableGamePadButton then window:EnableGamePadButton(false) end
        end
    end)
    return nav
end
