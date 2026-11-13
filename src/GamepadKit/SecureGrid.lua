-- ---------------------------------------------------------------------------
-- GamepadKit: secure button grid (works in combat)
-- ---------------------------------------------------------------------------
-- A bar of protected buttons (the columns' owners) with a flyout of choices
-- above each, navigated with the gamepad, as on Blizzard's gamepad bars.
-- Clicking the header (e.g. "/click <name>" from a macro on the gamepad bar)
-- opens it: secure code then temporarily override-binds the D-pad, A, X, Y
-- and B, which was verified to win over Forever's static gamepad bindings in
-- and out of combat. Closing clears those overrides and the normal bindings
-- return. Modifier combos (LT/LB) cannot be overridden, so only plain buttons
-- are used.
--
-- Rows: 0 is the owner (the bar button), 1.. its choices outward. A flyout
-- is open only while the focus is in it. The grid opens on the bar. Along
-- the bar the D-pad wraps. Up, or Y, opens the focused button's flyout and
-- enters it at the column's entry row (default the first choice); further
-- Up stops at the last choice. Down from the first choice, or Y from any,
-- closes it and returns to the bar. Sideways inside a flyout keeps the row
-- (up to the neighbor's last choice; the bar if it has none). B closes.
--
-- local grid = Kit.CreateSecureGrid(name, {
--     focusParent = frame, focusSize = 24,   -- choice highlight parent and size
--     ownerFocusSize = 30,                   -- bar button highlight size
--     ownerSpellAttribute = "attr", -- on each owner: the spell A/X cast on the bar
--     primary = [[ ... ]],          -- A on a choice: restricted snippet, self =
--                                   --    header; focus in self:GetAttribute("col"/"row")
--     primaryMacroAttribute = "attr",  -- optional: after primary, A runs the
--                                   --    focused choice's macro text from "attr"
--     secondary = { spellAttribute = "attr" },  -- X on a choice: cast its
--                                   --    spell once, without selecting it
--     onOpen, onClose, onFocus(col, row),   -- insecure callbacks
--     autoClose = { grace = s, idle = s, onNudge = fn(on) },  -- optional:
--                                   --    see "Moving on" below
--     openSnippet, closeSnippet,    -- optional restricted snippets (self = header)
--                                   --    run as the grid opens / closes, in combat too
-- })
-- grid.header
-- grid:SetColumns(columns)  -- out of combat; each column, in bar order:
--     { owner = frame, container = frame or nil, choices = { frames },
--       entryRow = n,               -- optional: where Up from the bar lands (default 1)
--       refs = { label = frame },   -- host frame refs, named "<label>-<col>"
--       attributes = { k = v } }    -- host attributes, named "<k>-<col>"
-- grid:SetDirections({ UP = { "row", 1 }, DOWN = { "row", -1 },
--                      LEFT = { "col", -1 }, RIGHT = { "col", 1 } })
-- grid:SetStartColumn(col)          -- the bar button focused on open (default 1)
-- grid:SetStartLast(enabled)         -- true: open on the bar button focused when
--                                      it last closed (else the start column)
-- grid:GetLastColumn(), grid:SetLastColumn(col)  -- that column, e.g. to keep
--                                      it on the same button across SetColumns
-- grid:SetPrimaryCasts(col, enabled) -- true: A on that column's choices also
--                                      casts the choice (select and cast)
-- grid:SetPrimaryCloses(enabled)     -- true: selecting (A) closes the grid
-- grid:SetSecondaryCloses(enabled)   -- true: casting (X, or A/X on the bar)
--                                      closes the grid
-- A selects: in a flyout it selects; on the bar it casts the button. X only
-- casts, and never changes the choice. Without a spell, casting does nothing.
-- Closing from A or X happens on the release, after the action has run.
-- grid:IsOpen(), grid:GetFocus(), grid:Close(), grid:RefreshOpen()
-- While open, containers carry the attribute "kit-grid-open", so their own
-- secure scripts can tell the grid is in use.
--
-- Moving on (opts.autoClose): while open, the gamepad is polled for other
-- input than the grid's (D-pad, A, B, X, Y): a stick pushed past halfway
-- for a moment, or any other button (triggers, shoulders, stick clicks, menu
-- buttons); input held when the grid opened counts once released. You've
-- moved on once `grace` seconds pass without grid input and some of that
-- other input came since the last grid input, so steering or turning the
-- camera between picks never counts. Out of combat that closes the grid, as
-- does `idle` seconds without any grid input. In combat only secure code may
-- close it and it can't see the gamepad, so moving on nudges instead: the
-- focus glow pulses and onNudge(true) lets the host show it; grid input
-- clears it. grid:IsNudging().
local _, ns = ...
local Kit = ns.GamepadKit

local Grid = {}
Grid.__index = Grid

local function CreateTarget(name, template)
    -- Visible 1px targets, matching what the binding probe verified.
    local target = CreateFrame("Button", name, UIParent, template or "SecureActionButtonTemplate")
    target:SetSize(1, 1)
    target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    target:SetAlpha(0)
    target:Show()
    return target
end

-- The gamepad action bar's own focus glow (42px around a 32px button).
local function CreateFocus(name, parent, size)
    local focus = CreateFrame("Frame", name, parent or UIParent, "SecureHandlerBaseTemplate")
    focus:SetSize(size, size)
    focus:SetFrameStrata("DIALOG")
    focus:EnableMouse(false)
    local glow = focus:CreateTexture(nil, "OVERLAY")
    glow:SetAtlas("gamepad-actionbar-fx-squareGlw")
    glow:SetPoint("CENTER")
    glow:SetSize(size * 42 / 32, size * 42 / 32)
    -- The nudge: the glow pulses (an animation, so it runs in combat too).
    focus.pulse = glow:CreateAnimationGroup()
    focus.pulse:SetLooping("BOUNCE")
    local fade = focus.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.25)
    fade:SetDuration(0.45)
    fade:SetSmoothing("IN_OUT")
    focus:Hide()
    return focus
end

-- Shows the flyout the focus is in (none on the bar), and the highlight.
local FOCUS_SNIPPET = [[
    local col, row = self:GetAttribute("col") or 1, self:GetAttribute("row") or 0
    for c = 1, self:GetAttribute("num-cols") or 0 do
        local container = self:GetAttribute("has-container-" .. c) and self:GetFrameRef("container-" .. c)
        if container then
            if c == col and row > 0 then container:Show() else container:Hide() end
        end
    end
    local focus, ownerFocus = self:GetFrameRef("focus"), self:GetFrameRef("owner-focus")
    local target = row == 0 and self:GetFrameRef("owner-" .. col) or self:GetFrameRef("choice-" .. col .. "-" .. row)
    local shown = row == 0 and ownerFocus or focus
    local other = row == 0 and focus or ownerFocus
    other:Hide()
    if not target then
        shown:Hide()
        return
    end
    shown:ClearAllPoints()
    shown:SetPoint("CENTER", target, "CENTER", 0, 0)
    shown:Show()
    self:CallMethod("OnKitGridFocus", col, row)
]]

-- Directions map to a column or row step, set by SetDirections.
local MOVE_SNIPPET = [[
    local dir = ...
    local cols = self:GetAttribute("num-cols") or 0
    if not self:GetAttribute("open") or cols == 0 then return end
    local delta = self:GetAttribute("delta-" .. dir) or 0
    local col = self:GetAttribute("col") or 1
    local row = self:GetAttribute("row") or 0
    if self:GetAttribute("axis-" .. dir) == "col" then
        -- Along the bar, wrapping; inside a flyout, into the next one.
        col = col + delta
        if col < 1 then col = cols elseif col > cols then col = 1 end
        self:SetAttribute("col", col)
        local count = self:GetAttribute("count-" .. col) or 0
        if row > count then self:SetAttribute("row", count) end
    elseif row == 0 then
        -- Into the flyout, always at its entry row.
        local count = self:GetAttribute("count-" .. col) or 0
        if delta <= 0 or count == 0 then return end
        self:SetAttribute("row", math.min(self:GetAttribute("entry-row-" .. col) or 1, count))
    else
        -- Stops at the last choice; back past the first lands on the bar.
        row = row + delta
        local count = self:GetAttribute("count-" .. col) or 0
        if row > count then return end
        if row < 0 then row = 0 end
        self:SetAttribute("row", row)
    end
    self:RunAttribute("_kit_focus")
]]

local CLOSE_SNIPPET = [[
    self:RunAttribute("_kit_host_close")
    self:SetAttribute("open", nil)
    self:SetAttribute("last-col", self:GetAttribute("col"))
    self:ClearBindings()
    for c = 1, self:GetAttribute("num-cols") or 0 do
        local container = self:GetAttribute("has-container-" .. c) and self:GetFrameRef("container-" .. c)
        if container then
            container:SetAttribute("kit-grid-open", nil)
            container:Hide()
        end
    end
    self:GetFrameRef("focus"):Hide()
    self:GetFrameRef("owner-focus"):Hide()
    self:CallMethod("OnKitGridClosed")
]]

local function OpenSnippet(name)
    local binds = {
        string.format([[self:SetBindingClick(true, "PADDUP", %q, "LeftButton")]], name .. "Up"),
        string.format([[self:SetBindingClick(true, "PADDDOWN", %q, "LeftButton")]], name .. "Down"),
        string.format([[self:SetBindingClick(true, "PADDLEFT", %q, "LeftButton")]], name .. "Left"),
        string.format([[self:SetBindingClick(true, "PADDRIGHT", %q, "LeftButton")]], name .. "Right"),
        string.format([[self:SetBindingClick(true, "PAD1", %q, "LeftButton")]], name .. "Primary"),
        string.format([[self:SetBindingClick(true, "PAD3", %q, "LeftButton")]], name .. "Secondary"),
        string.format([[self:SetBindingClick(true, "PAD4", %q, "LeftButton")]], name .. "Toggle"),
        [[self:SetBindingClick(true, "PAD2", self:GetName(), "LeftButton")]],
    }
    -- The header press (and B while open) toggles the grid. It opens on the
    -- start column's bar button, with the flyouts closed.
    return [[
        if self:GetAttribute("open") then
            self:RunAttribute("_kit_close")
            return
        end
        local cols = self:GetAttribute("num-cols") or 0
        if cols == 0 then return end
        self:SetAttribute("open", true)
        for c = 1, cols do
            local container = self:GetAttribute("has-container-" .. c) and self:GetFrameRef("container-" .. c)
            if container then
                container:UnregisterAutoHide()
                container:SetAttribute("kit-grid-open", true)
            end
        end
    ]] .. table.concat(binds, "\n") .. [[

        local start = self:GetAttribute("start-last") and self:GetAttribute("last-col")
            or self:GetAttribute("start-col") or 1
        if start < 1 or start > cols then start = 1 end
        self:SetAttribute("col", start)
        self:SetAttribute("row", 0)
        self:RunAttribute("_kit_host_open")
        -- Opened first, so the focus callback (e.g. a tooltip) comes last.
        self:CallMethod("OnKitGridOpened")
        self:RunAttribute("_kit_focus")
    ]]
end

-- On the bar (row 0), A and X cast the owner's spell; with none, nothing
-- happens. Shared by both buttons' click snippets (%q: the owner attribute).
local OWNER_CAST = [[
    if row == 0 then
        local owner = control:GetFrameRef("owner-" .. col)
        local spell = owner and owner:GetAttribute(%q)
        if not spell then
            self:SetAttribute("type", nil)
            return false
        end
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", spell)
        -- The cast is already set for this click, so closing can't stop it.
        if not down and control:GetAttribute("secondary-closes") then control:RunAttribute("_kit_close") end
        return
    end
]]

function Kit.CreateSecureGrid(name, opts)
    assert(type(opts) == "table" and opts.primary and opts.ownerSpellAttribute and opts.secondary,
        "GamepadKit: primary, secondary and ownerSpellAttribute are required")
    local grid = setmetatable({ name = name, opts = opts, columns = {}, containers = {} }, Grid)

    local header = CreateTarget(name, "SecureHandlerClickTemplate")
    header:RegisterForClicks("AnyUp")
    grid.header = header

    grid.focus = CreateFocus(name .. "Focus", opts.focusParent, opts.focusSize)
    grid.ownerFocus = CreateFocus(name .. "OwnerFocus", opts.focusParent, opts.ownerFocusSize or opts.focusSize)
    SecureHandlerSetFrameRef(header, "focus", grid.focus)
    SecureHandlerSetFrameRef(header, "owner-focus", grid.ownerFocus)

    header:SetAttribute("_kit_focus", FOCUS_SNIPPET)
    header:SetAttribute("_kit_move", MOVE_SNIPPET)
    header:SetAttribute("_kit_primary", opts.primary)
    header:SetAttribute("_kit_close", CLOSE_SNIPPET)
    -- Always a snippet (empty if none): restricted code can't read "_"
    -- attributes, so it can't check for one, only run it.
    header:SetAttribute("_kit_host_open", opts.openSnippet or "")
    header:SetAttribute("_kit_host_close", opts.closeSnippet or "")
    header:SetAttribute("_onclick", OpenSnippet(name))

    -- Bindings click on both press and release; navigation acts on press only.
    for _, dir in ipairs({ "Up", "Down", "Left", "Right" }) do
        local nav = CreateTarget(name .. dir)
        nav:RegisterForClicks("AnyDown")
        SecureHandlerWrapScript(nav, "OnClick", header,
            string.format([[ control:RunAttribute("_kit_move", "%s") return false ]], dir:upper()))
    end

    local ownerCast = string.format(OWNER_CAST, opts.ownerSpellAttribute)
    local choiceMacro = opts.primaryMacroAttribute
        and string.format("choice:GetAttribute(%q)", opts.primaryMacroAttribute) or "nil"

    -- A on a choice: the primary snippet on press; the choice's macro (if
    -- any) follows ActionButtonUseKeyDown (press or release), so it always
    -- runs after the snippet.
    local primary = CreateTarget(name .. "Primary")
    primary:RegisterForClicks("AnyUp", "AnyDown")
    SecureHandlerWrapScript(primary, "OnClick", header, [[
        if not control:GetAttribute("open") then
            self:SetAttribute("type", nil)
            return false
        end
        local col, row = control:GetAttribute("col") or 1, control:GetAttribute("row") or 0
    ]] .. ownerCast .. string.format([[
        local choice = control:GetFrameRef("choice-" .. col .. "-" .. row)
        if down then control:RunAttribute("_kit_primary") end
        local macro = choice and %s
        -- A column set to "primary casts" also casts the choice (SetPrimaryCasts).
        local spell = choice and control:GetAttribute("primary-casts-" .. col) and choice:GetAttribute(%q)
        if spell and macro then
            self:SetAttribute("type", "macro")
            self:SetAttribute("macrotext", macro .. "\n/cast " .. spell)
        elseif spell then
            self:SetAttribute("type", "spell")
            self:SetAttribute("spell", spell)
        else
            self:SetAttribute("type", macro and "macro" or nil)
            self:SetAttribute("macrotext", macro)
        end
        -- The action is already set for this click, so closing can't stop it.
        -- Selecting and casting closes for either option.
        if not down and (control:GetAttribute("primary-closes")
            or (spell and control:GetAttribute("secondary-closes"))) then
            control:RunAttribute("_kit_close")
        end
        if not (macro or spell) then return false end
    ]], choiceMacro, opts.secondary.spellAttribute))

    -- X: cast the focused choice's spell once, without selecting it.
    local secondary = CreateTarget(name .. "Secondary")
    secondary:RegisterForClicks("AnyUp", "AnyDown")
    SecureHandlerWrapScript(secondary, "OnClick", header, [[
        if not control:GetAttribute("open") then
            self:SetAttribute("type", nil)
            return false
        end
        local col, row = control:GetAttribute("col") or 1, control:GetAttribute("row") or 0
    ]] .. ownerCast .. string.format([[
        local choice = control:GetFrameRef("choice-" .. col .. "-" .. row)
        -- Nothing to cast (e.g. an "empty" entry): X does nothing.
        local spell = choice and choice:GetAttribute(%q)
        if not spell then
            self:SetAttribute("type", nil)
            return false
        end
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", spell)
        -- The cast is already set for this click, so closing can't stop it.
        if not down and control:GetAttribute("secondary-closes") then control:RunAttribute("_kit_close") end
    ]], opts.secondary.spellAttribute))

    -- Y: into the focused button's flyout, or back out of it (on press, like
    -- the D-pad). A button without a flyout ignores it.
    local toggle = CreateTarget(name .. "Toggle")
    toggle:RegisterForClicks("AnyDown")
    SecureHandlerWrapScript(toggle, "OnClick", header, [[
        if not control:GetAttribute("open") then return false end
        local col, row = control:GetAttribute("col") or 1, control:GetAttribute("row") or 0
        local count = control:GetAttribute("count-" .. col) or 0
        if row > 0 then
            control:SetAttribute("row", 0)
        elseif count == 0 then
            return false
        else
            control:SetAttribute("row", math.min(control:GetAttribute("entry-row-" .. col) or 1, count))
        end
        control:RunAttribute("_kit_focus")
        return false
    ]])

    function header:OnKitGridOpened()
        if opts.autoClose then grid:StartWatch() end
        if opts.onOpen then opts.onOpen() end
    end
    function header:OnKitGridClosed()
        if opts.autoClose then grid:StopWatch() end
        if opts.onClose then opts.onClose() end
    end
    function header:OnKitGridFocus(col, row) if opts.onFocus then opts.onFocus(col, row) end end
    return grid
end

function Grid:IsOpen()
    return self.header:GetAttribute("open") and true or false
end

function Grid:GetFocus()
    return self.header:GetAttribute("col"), self.header:GetAttribute("row")
end

function Grid:GetColumn(col)
    return self.columns[col]
end

function Grid:SetStartColumn(col)
    self.header:SetAttribute("start-col", col)
end

function Grid:SetStartLast(enabled)
    self.header:SetAttribute("start-last", enabled and true or nil)
end

function Grid:GetLastColumn()
    return self.header:GetAttribute("last-col")
end

-- Out of combat only.
function Grid:SetLastColumn(col)
    self.header:SetAttribute("last-col", col)
end

-- Out of combat only.
function Grid:SetPrimaryCasts(col, enabled)
    self.header:SetAttribute("primary-casts-" .. col, enabled and true or nil)
end

function Grid:SetPrimaryCloses(enabled)
    self.header:SetAttribute("primary-closes", enabled and true or nil)
end

function Grid:SetSecondaryCloses(enabled)
    self.header:SetAttribute("secondary-closes", enabled and true or nil)
end

function Grid:SetDirections(map)
    for dir, step in pairs(map) do
        self.header:SetAttribute("axis-" .. dir, step[1])
        self.header:SetAttribute("delta-" .. dir, step[2])
    end
end

-- Out of combat only.
function Grid:SetColumns(columns)
    local header = self.header
    self.columns = columns
    for c, column in ipairs(columns) do
        -- A column without a container (no flyout) is only its bar button.
        header:SetAttribute("has-container-" .. c, column.container ~= nil)
        if column.container then
            self.containers[column.container] = true
            SecureHandlerSetFrameRef(header, "container-" .. c, column.container)
        end
        SecureHandlerSetFrameRef(header, "owner-" .. c, column.owner)
        for r, choice in ipairs(column.choices) do
            SecureHandlerSetFrameRef(header, "choice-" .. c .. "-" .. r, choice)
        end
        header:SetAttribute("count-" .. c, #column.choices)
        header:SetAttribute("entry-row-" .. c, column.entryRow or 1)
        for label, frame in pairs(column.refs or {}) do
            SecureHandlerSetFrameRef(header, label .. "-" .. c, frame)
        end
        for key, value in pairs(column.attributes or {}) do
            header:SetAttribute(key .. "-" .. c, value)
        end
    end
    header:SetAttribute("num-cols", #columns)
end

-- Out of combat only.
-- The same secure close as B (so the host's closeSnippet runs too).
function Grid:Close()
    if InCombatLockdown() then return end
    if self:IsOpen() then
        SecureHandlerExecute(self.header, [[ self:RunAttribute("_kit_close") ]])
    end
    for container in pairs(self.containers) do
        container:SetAttribute("kit-grid-open", nil)
        container:Hide()
    end
end

-- After the host re-lays out its columns (which may hide flyouts) while the
-- grid is open: keep the focus in range and show it again.
function Grid:RefreshOpen()
    if not self:IsOpen() then return end
    if #self.columns == 0 then
        self:Close()
        return
    end
    for container in pairs(self.containers) do container:SetAttribute("kit-grid-open", nil) end
    for _, column in ipairs(self.columns) do
        if column.container then column.container:SetAttribute("kit-grid-open", true) end
    end
    SecureHandlerExecute(self.header, [[
        if (self:GetAttribute("col") or 1) > (self:GetAttribute("num-cols") or 0) then
            self:SetAttribute("col", 1)
        end
        local col, row = self:GetAttribute("col"), self:GetAttribute("row") or 0
        local count = self:GetAttribute("count-" .. col) or 0
        if row > count then self:SetAttribute("row", count) end
        self:RunAttribute("_kit_focus")
    ]])
end

-- ---------------------------------------------------------------------------
-- Moving on: watch the gamepad while the grid is open (opts.autoClose)
-- ---------------------------------------------------------------------------
local GRID_KEYS = { PADDUP = true, PADDDOWN = true, PADDLEFT = true, PADDRIGHT = true,
    PAD1 = true, PAD2 = true, PAD3 = true, PAD4 = true }
local STICK_AXES = { LStickX = true, LStickY = true, RStickX = true, RStickY = true }
local STICK_PUSH, STICK_HOLD, POLL_INTERVAL = 0.5, 0.15, 0.05

local ReadGamepad = Kit.ReadGamepad

-- What the pad is doing: grid input, other buttons ({ [name] = true }),
-- and whether a stick is pushed. Stick directions also show as buttons
-- (PADLSTICKUP...); those are left to the axes.
local function Snapshot()
    local state, names = ReadGamepad()
    if not state then return end
    local grid, others, stick = false, {}, false
    for i, down in ipairs(state.buttons) do
        local name = names.buttons[i]
        if down and not Kit.IsSecret(down) and name ~= "" and not name:match("^PAD[LR]STICK.") then
            if GRID_KEYS[name] then grid = true else others[name] = true end
        end
    end
    for i, value in ipairs(state.axes or {}) do
        if STICK_AXES[names.axes[i]] and not Kit.IsSecret(value) and math.abs(value) > STICK_PUSH then stick = true end
    end
    return grid, others, stick
end

function Grid:IsNudging()
    return self.nudging and true or false
end

function Grid:SetNudge(on)
    on = on and true or false
    if on == self:IsNudging() then return end
    self.nudging = on
    for _, focus in ipairs({ self.focus, self.ownerFocus }) do
        if on then focus.pulse:Play() else focus.pulse:Stop() end
    end
    if self.opts.autoClose.onNudge then self.opts.autoClose.onNudge(on) end
end

-- Moved on: close if allowed, else nudge.
function Grid:MovedOn()
    if InCombatLockdown() then self:SetNudge(true) else self:Close() end
end

-- Other input this poll: a button not held since opening, or a stick held
-- pushed long enough.
function Grid:SawOtherInput(others, stickPushed, step)
    for name in pairs(self.heldAtOpen) do
        if not others[name] then self.heldAtOpen[name] = nil end
    end
    local seen = false
    for name in pairs(others) do
        if not self.heldAtOpen[name] then seen = true end
    end
    if self.stickHeldAtOpen then
        if not stickPushed then self.stickHeldAtOpen = false end
    elseif stickPushed then
        self.stickTime = self.stickTime + step
        if self.stickTime >= STICK_HOLD then seen = true end
    else
        self.stickTime = 0
    end
    return seen
end

function Grid:StartWatch()
    local auto = self.opts.autoClose
    local _, held, stick = Snapshot()
    self.heldAtOpen = held or {}
    self.stickHeldAtOpen = stick
    self.stickTime = 0
    self.lastGridInput = GetTime()
    self.otherSinceGrid = false
    self.watcher = self.watcher or CreateFrame("Frame")
    local elapsedSincePoll = 0
    self.watcher:SetScript("OnUpdate", function(_, elapsed)
        elapsedSincePoll = elapsedSincePoll + elapsed
        if elapsedSincePoll < POLL_INTERVAL then return end
        local step = elapsedSincePoll
        elapsedSincePoll = 0
        local grid, others, stickPushed = Snapshot()
        if grid == nil then return end
        local now = GetTime()
        if grid then
            self.lastGridInput = now
            self.otherSinceGrid = false
            self:SetNudge(false)
        end
        if self:SawOtherInput(others, stickPushed, step) and not grid then self.otherSinceGrid = true end
        local quiet = now - self.lastGridInput
        if self.otherSinceGrid and quiet >= (auto.grace or 5) then
            self:MovedOn()
        elseif auto.idle and quiet >= auto.idle and not InCombatLockdown() then
            -- Idle (no grid input at all): out of combat only; no nudge for it.
            self:Close()
        end
    end)
end

function Grid:StopWatch()
    if self.watcher then self.watcher:SetScript("OnUpdate", nil) end
    self:SetNudge(false)
end

-- Place a tooltip where it covers neither `anchor` nor any of `avoid`:
-- the first side in `order` that fits ("below", "above", "pastTop",
-- "pastBottom", "right", "left"). Works in screen pixels, so frame scales
-- don't matter. `belowGap` adds room under the anchor (e.g. for a label).
function Kit.PlaceTooltip(tooltip, anchor, avoid, order, belowGap)
    local anchorScale, tipScale = anchor:GetEffectiveScale(), tooltip:GetEffectiveScale()
    local left, right, top, bottom = anchor:GetLeft(), anchor:GetRight(), anchor:GetTop(), anchor:GetBottom()
    if not (left and right and top and bottom) then return end
    left, right, top, bottom = left * anchorScale, right * anchorScale, top * anchorScale, bottom * anchorScale
    local screenW = UIParent:GetWidth() * UIParent:GetEffectiveScale()
    local screenH = UIParent:GetHeight() * UIParent:GetEffectiveScale()
    local w, h = tooltip:GetWidth() * tipScale, tooltip:GetHeight() * tipScale
    local gap = 8 * tipScale

    local farLeft, farRight, farTop, farBottom = left, right, top, bottom
    for _, frame in ipairs(avoid or {}) do
        local fl, fr, ft, fb = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
        if frame:IsShown() and fl and fr and ft and fb then
            local s = frame:GetEffectiveScale()
            farLeft, farRight = math.min(farLeft, fl * s), math.max(farRight, fr * s)
            farTop, farBottom = math.max(farTop, ft * s), math.min(farBottom, fb * s)
        end
    end

    local cx, cy = (left + right) / 2, (top + bottom) / 2
    local under = gap + (belowGap or 0) * tipScale
    local candidates = {
        below = { fits = bottom - under >= h, point = "TOP", x = cx, y = bottom - under },
        above = { fits = screenH - (top + gap) >= h, point = "BOTTOM", x = cx, y = top + gap },
        pastTop = { fits = screenH - (farTop + gap) >= h, point = "BOTTOM", x = cx, y = farTop + gap },
        pastBottom = { fits = farBottom - gap >= h, point = "TOP", x = cx, y = farBottom - gap },
        right = { fits = screenW - (farRight + gap) >= w, point = "LEFT", x = farRight + gap, y = cy },
        left = { fits = farLeft - gap >= w, point = "RIGHT", x = farLeft - gap, y = cy },
    }
    local choice = candidates[order[1]]
    for _, side in ipairs(order) do
        if candidates[side] and candidates[side].fits then
            choice = candidates[side]
            break
        end
    end
    tooltip:ClearAllPoints()
    tooltip:SetPoint(choice.point, UIParent, "BOTTOMLEFT", choice.x / tipScale, choice.y / tipScale)
end
