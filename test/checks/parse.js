// Syntax-checks an addon as WoW's Lua 5.1 would: every .lua file, plus every
// [[ ... ]] long string in them parsed on its own (secure snippets are
// compiled by the game at runtime, so a broken one only fails in game).
//
//   node checks/parse.js <addon dir>
const fs = require('fs'), path = require('path');
const lp = require('luaparse');
const dir = process.argv[2];
if (!dir) { console.error('usage: node checks/parse.js <addon dir>'); process.exit(2); }
const files = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p); else if (e.name.endsWith('.lua')) files.push(p);
  }
})(dir);
let failed = 0, snippets = 0;
for (const file of files) {
  const src = fs.readFileSync(file, 'utf8');
  const name = path.relative(dir, file);
  let ast;
  try { ast = lp.parse(src, { luaVersion: '5.1', locations: true }); }
  catch (e) { failed++; console.log('FAIL', name, e.message); continue; }
  // Snippets: [[ ]] string literals in the code (not in comments), skipping
  // templates filled by string.format.
  (function visit(node) {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) return node.forEach(visit);
    if (node.type === 'StringLiteral' && /^\[=*\[/.test(node.raw)) {
      const body = node.raw.replace(/^\[=*\[\n?/, '').replace(/\]=*\]$/, '');
      if (!/%[qsd]/.test(body)) {
        snippets++;
        try { lp.parse('return function(self, ...)\n' + body + '\nend', { luaVersion: '5.1' }); }
        catch (e) { failed++; console.log('FAIL', name, 'snippet at line', node.loc.start.line, e.message); }
      }
    }
    for (const k in node) if (k !== 'loc') visit(node[k]);
  })(ast);
}
console.log(failed ? `${failed} problem(s)` : `ok: ${files.length} files, ${snippets} snippets`);
process.exit(failed ? 1 : 0);
