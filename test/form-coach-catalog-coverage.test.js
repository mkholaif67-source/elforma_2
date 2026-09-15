const assert = require('assert');
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
const db = fs.readFileSync(path.join(root, 'app/workout/engine/db.js'), 'utf8').split('// MODULE EXERCISE DATABASE')[0];
const names = [...db.matchAll(/\{n:'((?:\\'|[^'])*)'/g)].map((m) => m[1].replace(/\\'/g, "'"));
const profileDir = path.join(root, 'mobile/lib/features/form_coach/profiles');
const source = fs.readdirSync(profileDir).filter((f) => f.endsWith('.dart')).map((f) => fs.readFileSync(path.join(profileDir, f), 'utf8')).join('\n');
const keywords = [...source.matchAll(/'([A-Za-z][A-Za-z0-9 ()°/+-]{3,})'/g)].map((m) => m[1]);
const norm = (x) => x.toLowerCase().replace(/[()°/,_-]/g, ' ').replace(/\s+/g, ' ').trim();
const normalized = keywords.map(norm);
const missing = [...new Set(names)].filter((name) => {
  const n = norm(name);
  return !normalized.some((k) => n === k || n.includes(k));
});
assert.deepStrictEqual(missing, [], missing.join('\n'));
assert.strictEqual(new Set(names).size, 141);
console.log(`form coach catalog coverage: ${new Set(names).size} strength exercises mapped`);
