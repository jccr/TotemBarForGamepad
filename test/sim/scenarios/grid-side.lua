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
    columns[c] = { owner = owner, container = container, choices = choices }
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
Click(h, false); State("open")
Press(h, "PADDRIGHT"); Press(h, "PADDUP"); Press(h, "PADDUP"); State("Fire choice 2")
Press(h, "PADDRIGHT"); State("Right onto Recall (bar)")
Press(h, "PADDRIGHT"); State("Right onto Weapon (stays bar)")
Press(h, "PADDUP"); Press(h, "PADDUP"); Press(h, "PADDRIGHT"); State("Weapon 2 -> Right wraps to Call 2")
