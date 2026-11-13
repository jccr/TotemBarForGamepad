local Kit = NS.GamepadKit
Kit.GetCVarBool = function() return KEYDOWN end
local grid = Kit.CreateSecureGrid("P", { focusSize = 24, ownerFocusSize = 30, ownerSpellAttribute = "spell1",
    primary = [[ self:SetAttribute("primary-ran", (self:GetAttribute("primary-ran") or 0) + 1) ]],
    primaryMacroAttribute = "macro", secondary = { spellAttribute = "spell" }, tertiary = true })
local h = grid.header
-- Bar: Call(3) | Earth(4) | Fire(3) | Recall(0) | Weapon(2)
local spec = { { "Call", 3, "Call of the Elements" }, { "Earth", 4, "Stoneskin" }, { "Fire", 3, nil }, { "Recall", 0, "Totemic Recall" }, { "Weapon", 2, "Rockbiter" } }
local columns = {}
for c, s in ipairs(spec) do
    local owner = CreateFrame("Button", s[1])
    owner.attrs.spell1 = s[3]
    owner.attrs.sel = s[2] > 0 and 2 or nil
    local container = s[2] > 0 and CreateFrame("Frame", s[1] .. "Flyout") or nil
    local choices = {}
    for r = 1, s[2] do
        local ch = CreateFrame("Button", s[1] .. "Choice" .. r)
        ch.attrs.key = r
        ch.attrs.spell = r > 1 and (s[1] .. " spell " .. r) or nil
        ch.attrs.macro = "/click " .. s[1] .. "Set" .. r
        choices[r] = ch
    end
    -- Totem columns (Earth, Fire) have "No Totem" first: entry row 2.
    columns[c] = { owner = owner, container = container, choices = choices,
        entryRow = (s[1] == "Earth" or s[1] == "Fire") and 2 or nil }
end
grid:SetColumns(columns)
grid:SetStartColumn(2)
grid:SetDirections({ LEFT = { "col", -1 }, RIGHT = { "col", 1 }, UP = { "row", 1 }, DOWN = { "row", -1 } })
local function State(label)
    local col, row = h.attrs.col, h.attrs.row
    local open = {}
    for c, s in ipairs(spec) do if FRAMES[s[1] .. "Flyout"] and FRAMES[s[1] .. "Flyout"].shown then open[#open + 1] = s[1] end end
    local f = row == 0 and grid.ownerFocus or grid.focus
    print(string.format("%-28s col=%s row=%s focus=%s open=[%s] grid=%s", label, tostring(col), tostring(row),
        f.shown and f.anchor and f.anchor.name or "-", table.concat(open, ","), tostring(h.attrs.open)))
end
local function Actions() local a = table.concat(ACTIONS, " | "); ACTIONS = {}; return a == "" and "(none)" or a end
grid:SetStartColumn(1)
Click(h, false); State("open (first button = Call)")
Press(h, "PADDRIGHT"); Press(h, "PADDRIGHT"); Press(h, "PAD2"); State("Right x2, B closes")
Click(h, false); State("reopen, not last-used -> Call")
Press(h, "PAD2"); grid:SetStartLast(true)
Press(h, "PADDRIGHT"); Click(h, false); Press(h, "PADDRIGHT"); Press(h, "PADDRIGHT"); Press(h, "PADDRIGHT"); Press(h, "PAD2")
Click(h, false); State("last used -> Recall")
