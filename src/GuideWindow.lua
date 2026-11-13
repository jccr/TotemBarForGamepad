local _, ns = ...
if not ns.isShaman then return end

-- ---------------------------------------------------------------------------
-- Guide windows: the welcome guide and the gamepad macros dialog
-- ---------------------------------------------------------------------------
-- Blizzard's dialog chrome (the Game Menu's border and title plate), a close
-- button, Escape to close, dragging, and the text, button and divider helpers
-- both guides lay out with. offsetY: the window's starting height above the
-- screen center (default 60). Returns the window and its helpers:
--   window.titlePlate  (for GamepadKit FocusNav's title glow)
--   window:Label(fontObject, text, width)
--   window:Button(name, text, template)
--   window:Divider(vertical)
--   window:Below(region, anchor, gap)
local BUTTON_WIDTH, BUTTON_HEIGHT = 200, 26
ns.GUIDE_BUTTON_HEIGHT = BUTTON_HEIGHT

local Window = {}

function Window:Label(fontObject, text, width)
    local fontString = self:CreateFontString(nil, "OVERLAY", fontObject)
    if width then fontString:SetWidth(width) end
    fontString:SetJustifyH("CENTER")
    fontString:SetText(text)
    return fontString
end

function Window:Button(name, text, template)
    local button = CreateFrame("Button", name, self, template or "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText(text)
    return button
end

function Window:Divider(vertical)
    local line = self:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    if vertical then line:SetWidth(1) else line:SetHeight(1) end
    return line
end

function Window:Below(region, anchor, gap)
    region:SetPoint("TOP", anchor, "BOTTOM", 0, -(gap or 10))
end

function ns.CreateGuideWindow(name, title, width, offsetY)
    local window = CreateFrame("Frame", name, UIParent)
    Mixin(window, Window)
    window:SetSize(width, 300)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY or 60)
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
    end)
    window:Hide()
    -- Escape closes it like other game windows.
    table.insert(UISpecialFrames, name)

    -- Back to front: border, window glow (+2), title glow (+3), title plate,
    -- close button (FocusNav adds the glows).
    local base = window:GetFrameLevel()
    local border = CreateFrame("Frame", nil, window, "DialogBorderTemplate")
    border:SetFrameLevel(base + 1)
    local header = CreateFrame("Frame", nil, window, "DialogHeaderTemplate")
    header:SetFrameLevel(base + 4)
    header:Setup(title)
    window.titlePlate = header

    local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -5)
    closeButton:SetFrameLevel(base + 5)
    closeButton:SetScript("OnClick", function() window:Hide() end)
    return window
end
