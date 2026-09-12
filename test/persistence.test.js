'use strict';
// Proves the real root cause is fixed: admin data SURVIVES a server restart.
// Phase 1 (child process): create a user + admin-grant PRO, save uid.
// Phase 2 (SEPARATE child process, same EF_DATA_DIR = simulated restart):
//   the subscription must still be there. Before the fix, the Docker CMD wiped
//   elforma.db* on every boot, so this would come back 'free'.
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

let pass = 0, fail = 0;
function ok(name, fn) { try { fn(); pass++; console.log('  \u2713 ' + name); } catch (e) { fail++; console.log('  \u2717 ' + name + ' -> ' + (e && e.message)); } }

const DATA = '/data/eft_persist';
fs.rmSync(DATA, { recursive: true, force: true });
fs.mkdirSync(DATA, { recursive: true });

const ROOT = path.join(__dirname, '..');
function runNode(code) {
  const raw = execFileSync(process.execPath, ['--experimental-sqlite', '-e', code], {
    cwd: ROOT,
    env: Object.assign({}, process.env, { EF_DATA_DIR: DATA }),
    encoding: 'utf8',
  });
  // القاعدة بتطبع لوج إقلاع — نقرا بس السطر اللي بعد العلامة.
  const m = raw.split('__OUT__').pop();
  return String(m || '').trim();
}

console.log('[persistence: data survives restart]');

// ---- Phase 1: write (process #1) ----
const writeCode = `
  const db = require('./lib/db');
  const commerce = require('./lib/commerce');
  const info = db.db.prepare("INSERT INTO users (email,name,pass_hash,pass_salt,verified,created_at) VALUES (?,?,?,?,1,?)").run('persist@x.com','P','h','s', db.now());
  const uid = Number(info.lastInsertRowid);
  commerce.adminSetSubscription(uid, 'pro', 'active', 1, 'admin');
  process.stdout.write('__OUT__' + String(uid));
`;
const uid = runNode(writeCode);
ok('phase 1 created user + granted pro', () => assert(Number(uid) > 0));

// ---- Phase 2: read after a fresh process (simulated restart) ----
const readCode = `
  const db = require('./lib/db');
  const entitlement = require('./lib/entitlement');
  const s = db.getSubscription(${Number(uid)}) || {};
  process.stdout.write('__OUT__' + JSON.stringify({ plan: s.plan||'free', status: s.status||'', active: entitlement.subActive(s), durable: db.storage && db.storage.durable, engine: db.storage && db.storage.engine }));
`;
const out = JSON.parse(runNode(readCode));
ok('AFTER restart: subscription is STILL pro/active (not wiped)', () => {
  assert.strictEqual(out.plan, 'pro');
  assert.strictEqual(out.status, 'active');
  assert.strictEqual(out.active, true);
});
ok('storage indicator is exposed', () => {
  assert(typeof out.durable === 'boolean');
  assert(typeof out.engine === 'string' && out.engine.length > 0);
});

// ---- Static guard: Dockerfile must NOT delete the DB on boot ----
const dockerfileRaw = fs.readFileSync(path.join(ROOT, 'Dockerfile'), 'utf8');
// نتجاهل سطور الكومنت (# ...) عشان الشرح بيذكر الأمر القديم قصدًا.
const dockerfile = dockerfileRaw.split('\n').filter(l => !/^\s*#/.test(l)).join('\n');
ok('Dockerfile no longer deletes elforma.db on start', () => {
  assert(!/rm\s+-f[^\n]*elforma\.db/.test(dockerfile), 'destructive rm of elforma.db still present in Dockerfile');
});
ok('Dockerfile CMD runs the server directly', () => {
  assert(/CMD\s*\[\s*"node"\s*,\s*"--experimental-sqlite"\s*,\s*"server\.js"\s*\]/.test(dockerfile), 'expected clean node CMD');
});

console.log('\n' + pass + ' passed, ' + fail + ' failed');
if (fail > 0) process.exit(1);
