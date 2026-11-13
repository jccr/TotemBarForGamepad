// Run GamepadKit (real code) in fengari with WoW stubs, create a grid like
// Totem Bar Focus does (with TotemBarFocus.lua's own ASSIGN_SNIPPET), and syntax-check every snippet it installs (Lua 5.1).
const fs = require('fs');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const lp = require('luaparse');
const [,, kitDir, focusFile] = process.argv;
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
function run(code, name, args = 0) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(name)) !== 0) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  if (lua.lua_pcall(L, args, 0, 0) !== 0) throw new Error(name + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
}
run(fs.readFileSync(require('path').join(__dirname, '..', 'lib', 'wowstub.lua'), 'utf8'), 'stub');
run('NS = { isShaman = true }', 'ns');
// Each addon file receives (addonName, ns) as varargs.
const runFile = (f) => {
  const code = 'local f = ...; return f(...)';
  if (lauxlib.luaL_loadbuffer(L, to_luastring(fs.readFileSync(f, 'utf8')), null, to_luastring(f)) !== 0) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  lua.lua_pushstring(L, to_luastring('TotemBarForGamepad')); lua.lua_getglobal(L, to_luastring('NS'));
  if (lua.lua_pcall(L, 2, 0, 0) !== 0) throw new Error(f + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
};
for (const f of ['GamepadKit.lua', 'Glyphs.lua', 'ActionButtons.lua', 'FocusNav.lua', 'SecureGrid.lua']) runFile(kitDir + '/' + f);
// The same options TotemBarFocus.lua passes, with its real assign snippet.
const focusSrc = fs.readFileSync(focusFile, 'utf8');
const assign = focusSrc.match(/local ASSIGN_SNIPPET = (\[\[[\s\S]*?\]\])/)[1];
run(`local Kit = NS.GamepadKit
Kit.CreateSecureGrid("TotemBarForGamepadFocus", { focusParent = UIParent, focusSize = 36,
  
  primary = ${assign}, primaryMacroAttribute = "macrotext1", ownerSpellAttribute = "spell1", ownerFocusSize = 30, secondary = { spellAttribute = "totem-spell" }, tertiary = true })`, 'create');
lua.lua_getglobal(L, to_luastring('SNIPPETS'));
const n = lauxlib.luaL_len(L, -1); let bad = 0;
for (let i = 1; i <= n; i++) {
  lua.lua_rawgeti(L, -1, i);
  lua.lua_getfield(L, -1, to_luastring('name')); const name = to_jsstring(lua.lua_tostring(L, -1)); lua.lua_pop(L, 1);
  lua.lua_getfield(L, -1, to_luastring('body')); const body = to_jsstring(lua.lua_tostring(L, -1)); lua.lua_pop(L, 2);
  try { lp.parse('local self, button, down, control\n' + body, { luaVersion: '5.1' }); console.log('ok    ', name); }
  catch (e) { bad++; console.log('FAILED', name, e.message); }
}
console.log(bad ? bad + ' snippet(s) failed' : 'all ' + n + ' grid snippets OK');
