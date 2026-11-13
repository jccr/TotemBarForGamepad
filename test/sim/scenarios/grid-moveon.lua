local Kit = NS.GamepadKit
Kit.GetCVarBool = function() return KEYDOWN end
Kit.IsSecret = function() return false end
local nudges = {}
local grid = Kit.CreateSecureGrid("P", { focusSize = 24, ownerFocusSize = 30, ownerSpellAttribute = "spell1",
    primary = [[ ]], secondary = { spellAttribute = "spell" },
    autoClose = { grace = 5, idle = 10, onNudge = function(on) nudges[#nudges + 1] = tostring(on) end } })
local h = grid.header
local owner = CreateFrame("Button", "Earth"); owner.attrs.spell1 = "Stoneskin"
local container = CreateFrame("Frame", "EarthFlyout")
local choices = {}
for r = 1, 3 do choices[r] = CreateFrame("Button", "EarthChoice" .. r); choices[r].attrs.spell = "S" .. r end
grid:SetColumns({ { owner = owner, container = container, choices = choices } })
grid:SetDirections({ LEFT = { "col", -1 }, RIGHT = { "col", 1 }, UP = { "row", 1 }, DOWN = { "row", -1 } })
local function Open() Click(h, false) end
local function S(label) print(string.format("%-46s t=%4.1f open=%-5s nudge=%-5s", label, NOW, tostring(h.attrs.open), tostring(grid:IsNudging()))) end
local function Tap(name) PAD.buttons[name] = true; Advance(0.1); PAD.buttons[name] = nil; Advance(0.1) end

-- 1. Steering between picks never closes.
Open(); S("1 open")
for _ = 1, 4 do PAD.lx = 1; Advance(2); PAD.lx = 0; Tap("PADDUP") end
S("1 steer 2s, pick, x4 (8s+)")
-- 2. Moving on: steer 6s without picking -> closes at 5s.
PAD.lx = 1; Advance(4.5); S("2 steer 4.5s (still open)"); Advance(1); PAD.lx = 0; S("2 steer 5.5s (closed)")
-- 3. Pure idle 10s closes out of combat.
Open(); Advance(9.5); S("3 idle 9.5s (open)"); Advance(1); S("3 idle 10.5s (closed)")
-- 4. Trigger once, then quiet: closes at 5s after last pick.
Open(); Tap("PADRTRIGGER"); Advance(4); S("4 RT then 4.2s (open)"); Advance(1); S("4 RT then 5.2s (closed)")
-- 5. Trigger held at open: ignored until released.
PAD.buttons.PADLTRIGGER = true; Open(); Advance(6); S("5 LT held from open 6s (open)")
PAD.buttons.PADLTRIGGER = nil; Advance(1); S("5 released (no new input, open)")
Tap("PADLTRIGGER"); Advance(0.1); S("5 tapped LT again, quiet>5s -> closed")
-- 6. Brief stick bump doesn't count.
Open(); PAD.rx = 1; Advance(0.1); PAD.rx = 0; Advance(6); S("6 0.1s bump then 6s (open; idle not yet 10)")
grid:Close()
-- 7. Combat: moving on nudges; picking clears; idle never nudges.
COMBAT = true
Open(); Advance(11); S("7 combat idle 11s (open, no nudge)")
PAD.ly = 1; Advance(1); PAD.ly = 0; S("7 combat moved after long quiet -> nudge")
Tap("PADDUP"); S("7 pick clears nudge")
PAD.ly = 1; Advance(3); PAD.ly = 0; S("7 move 3s after pick (no nudge)")
Advance(2.5); S("7 then 5.5s quiet -> nudge")
COMBAT = false; Advance(0.1); S("8 combat ends (moved on) -> closes")
print("nudge calls:", table.concat(nudges, ","))
