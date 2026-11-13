// Lua 5.1 allows at most 200 locals in one function, the file's main chunk
// included; past that WoW refuses to load the file ("too many local
// variables"). Fails above LIMIT, which leaves some headroom.
//
//   node checks/locals.js <file.lua>
const fs = require('fs'), lp = require('luaparse');
const LIMIT = 180;
const file = process.argv[2];
const ast = lp.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.1' });
let count = 0;
for (const st of ast.body) {
  if (st.type === 'LocalStatement') count += st.variables.length;
  if (st.type === 'FunctionDeclaration' && st.isLocal) count++;
}
if (count > LIMIT) { console.log(`FAIL ${count} main-chunk locals (limit 200, keep under ${LIMIT})`); process.exit(1); }
console.log(`main-chunk locals: ${count}`);
