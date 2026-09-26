'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
const db = fs.readFileSync(path.join(root, 'app/workout/engine/db.js'), 'utf8').split('// MODULE EXERCISE DATABASE')[0];
const names = [...db.matchAll(/\{n:'((?:\\'|[^'])*)'/g)].map((m) => m[1].replace(/\\'/g, "'"));
const intentionallyDisabled = new Set([
  'Hammer Strength Incline Press', 'Cable Overhead Curl',
  'Barbell Wrist Curl',
  'Reverse Barbell Wrist Curl', 'Dumbbell Wrist Curl', 'Farmer Walk (Plates)',
  'Dead Hangs', 'Plank on Cable', 'Plank', 'Reverse Dumbbell Wrist Curl',
  'Mountain Climbers', 'Dead Bug',
]);
const dir = path.join(root, 'mobile/lib/features/form_coach/profiles');
const source = fs.readdirSync(dir).filter((file) => file.endsWith('.dart'))
  .map((file) => fs.readFileSync(path.join(dir, file), 'utf8')).join('\n');
const catalog = fs.readFileSync(path.join(dir, 'catalog_form_profiles.dart'), 'utf8');
const keywords = [...source.matchAll(/'([A-Za-z][A-Za-z0-9 ()°/+-]{3,})'/g)].map((m) => m[1]);
const norm = (value) => value.toLowerCase().replace(/[()°/,_-]/g, ' ').replace(/\s+/g, ' ').trim();
const missing = [...new Set(names)].filter((name) => intentionallyDisabled.has(name) ? false :
  !keywords.some((keyword) => norm(name) === norm(keyword) || norm(name).includes(norm(keyword))));
assert.deepStrictEqual(missing, [], missing.join('\n'));
assert.strictEqual(new Set(names).size, 141);
for (const token of ['hammer strength', 'cable overhead curl', 'leg curl', 'wrist curl']) {
  assert.ok(source.toLowerCase().includes(`'${token}'`), `missing exclusion ${token}`);
}
for (const name of ['Farmer Walk (Plates)', 'Dead Hangs', 'Plank on Cable', 'Plank', 'Mountain Climbers', 'Dead Bug']) {
  assert.ok(!catalog.includes(`'${name}'`), `disabled generic movement remains ${name}`);
}
console.log(`form coach catalog coverage: ${141 - intentionallyDisabled.size} mapped, ${intentionallyDisabled.size} intentionally disabled`);
