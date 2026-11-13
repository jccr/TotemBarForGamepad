// Runs one simulator scenario against GamepadKit's real code.
//
//   node sim/run.js <GamepadKit dir> <scenario.lua>
//
// lib/gridsim.lua is a small stand-in for WoW's secure environment: frames
// with attributes, frame refs and scripts; restricted snippets (attribute
// snippets and SecureHandlerWrapScript pre-bodies) compiled and run with the
// real rules that matter here (no reading "_" attributes, "..." holds only the
// extra arguments); clicks that respect RegisterForClicks and the
// ActionButtonUseKeyDown edge; a scripted gamepad (PAD.buttons, PAD.lx...);
// and a clock (Advance) that drives OnUpdate scripts.
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const [,, kitDir, scenario] = process.argv;
if (!kitDir || !scenario) { console.error('usage: node sim/run.js <GamepadKit dir> <scenario.lua>'); process.exit(2); }
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const run = (code, name) => {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(name)) || lua.lua_pcall(L, 0, 0, 0))
    throw new Error(name + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
};
run(fs.readFileSync(path.join(__dirname, '..', 'lib', 'gridsim.lua'), 'utf8'), 'sim');
run('NS = {}', 'ns');
// GamepadKit's files in its TOC order; each gets (addonName, ns) like WoW does.
for (const f of ['GamepadKit.lua', 'Glyphs.lua', 'ActionButtons.lua', 'FocusNav.lua', 'BindPrompt.lua', 'SecureGrid.lua']) {
  const file = path.join(kitDir, f);
  if (!fs.existsSync(file)) continue;
  if (lauxlib.luaL_loadbuffer(L, to_luastring(fs.readFileSync(file, 'utf8')), null, to_luastring(f)))
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  lua.lua_pushstring(L, to_luastring('TBG')); lua.lua_getglobal(L, to_luastring('NS'));
  if (lua.lua_pcall(L, 2, 0, 0)) throw new Error(f + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
}
run(fs.readFileSync(scenario, 'utf8'), path.basename(scenario));
