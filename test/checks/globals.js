// Fails if a file writes a global (a missing "local" leaks it to every
// addon), except the TOC's SavedVariables and Blizzard's SLASH_/BINDING_
// conventions. With -v, also lists the globals it reads.
//
//   node checks/globals.js <file.lua> [addon.toc] [-v]
const fs = require('fs'), lp = require('luaparse');
const args = process.argv.slice(2), verbose = args.includes('-v');
const [file, toc] = args.filter(a => a !== '-v');
const allowed = new Set();
if (toc) for (const m of fs.readFileSync(toc, 'utf8').matchAll(/^##\s*SavedVariables(?:PerCharacter)?:\s*(.+)$/gm))
  m[1].split(',').forEach(n => allowed.add(n.trim()));
const ast = lp.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.1', scope: true, locations: true });
const writes = [], reads = new Map();
const ok = name => allowed.has(name) || /^(SLASH|BINDING)_/.test(name);
(function visit(n) {
  if (!n || typeof n !== 'object') return;
  if (Array.isArray(n)) return n.forEach(visit);
  if (n.type === 'AssignmentStatement')
    for (const t of n.variables) if (t.type === 'Identifier' && !t.isLocal && !ok(t.name)) writes.push(`${t.name} (line ${t.loc.start.line})`);
  if (n.type === 'FunctionDeclaration' && !n.isLocal && n.identifier && n.identifier.type === 'Identifier' && !ok(n.identifier.name))
    writes.push(`${n.identifier.name}() (line ${n.loc.start.line})`);
  if (n.type === 'Identifier' && n.isLocal === false && !reads.has(n.name)) reads.set(n.name, n.loc.start.line);
  for (const k in n) if (k !== 'loc') visit(n[k]);
})(ast);
if (verbose) console.log('reads:', [...reads.keys()].sort().join(' '));
if (writes.length) { console.log('FAIL global writes: ' + writes.join(', ')); process.exit(1); }
console.log('no global writes');
