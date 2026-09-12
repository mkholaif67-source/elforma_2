'use strict';
// End-to-end proof for: does an admin action actually reach what the app reads?
// Same-process, same DB the server uses. Subscription + trial + announcements.
const assert = require('assert');
const db = require('../lib/db');
const commerce = require('../lib/commerce');
const entitlement = require('../lib/entitlement');
const settings = require('../lib/settings');

let pass = 0, fail = 0;
function ok(name, fn) { try { fn(); pass++; console.log('  \u2713 ' + name); } catch (e) { fail++; console.log('  \u2717 ' + name + ' -> ' + (e && e.message)); } }

const now = new Date().toISOString();
const info = db.db.prepare("INSERT INTO users (email,name,pass_hash,pass_salt,verified,created_at) VALUES (?,?,?,?,1,?)")
  .run('e2e' + Date.now() + '@x.com', 'E2E', 'h', 's', now);
const uid = Number(info.lastInsertRowid);

console.log('[admin -> app path]');
ok('user created', () => assert(uid > 0));

// The exact query the admin users() panel uses to show the plan column.
function adminSeesPlan() {
  const r = db.db.prepare('SELECT s.plan, s.status, s.current_period_end FROM users u LEFT JOIN subscriptions s ON s.user_id = u.id WHERE u.id = ?').get(uid);
  return { plan: (r && r.plan) || 'free', status: (r && r.status) || 'active', end: r && r.current_period_end };
}
// What the mobile bootstrap computes for the app.
function appSees() { return entitlement.summarize(db.getSubscription(uid)); }

ok('BEFORE: admin panel shows free', () => assert.strictEqual(adminSeesPlan().plan, 'free'));
ok('BEFORE: app sees not-pro', () => assert.strictEqual(appSees().active, false));

// 1) Admin grants a 1-month PRO subscription.
commerce.adminSetSubscription(uid, 'pro', 'active', 1, 'admin');

ok('AFTER grant: admin panel shows pro/active', () => {
  const a = adminSeesPlan();
  assert.strictEqual(a.plan, 'pro'); assert.strictEqual(a.status, 'active');
  assert(a.end && new Date(a.end) > new Date(), 'end date must be in the future');
});
ok('AFTER grant: app sees pro active', () => {
  const s = appSees();
  assert.strictEqual(s.active, true); assert.strictEqual(s.plan, 'pro'); assert.strictEqual(s.isPro, true);
});

// 2) Admin revokes.
commerce.adminSetSubscription(uid, 'free', 'canceled', null, 'admin');
ok('AFTER revoke: admin panel shows free', () => assert.strictEqual(adminSeesPlan().plan, 'free'));
ok('AFTER revoke: app sees not-pro', () => assert.strictEqual(appSees().active, false));

// 3) Free 3-day trial.
const tr = commerce.startTrial(uid, 3);
ok('startTrial returns ok', () => assert(tr && tr.ok, 'trial error: ' + JSON.stringify(tr)));
ok('AFTER trial: app sees active trial', () => {
  const s = appSees();
  assert.strictEqual(s.active, true); assert.strictEqual(s.isTrial, true);
});
ok('AFTER trial: admin panel shows trial/trialing', () => {
  const a = adminSeesPlan();
  assert.strictEqual(a.plan, 'trial'); assert.strictEqual(a.status, 'trialing');
});

// 4) Announcement audience: a pro-only announcement reaches a pro user only.
settings.setJSON('announcements', [
  { id: 'a1', title: 'PRO offer', body: 'x', active: true, placement: 'both', audience: 'pro' },
  { id: 'a2', title: 'FREE tip', body: 'y', active: true, placement: 'both', audience: 'free' },
]);
function visibleTo(isPro) {
  const list = settings.getJSON('announcements', []) || [];
  return list.filter(a => a.active === true &&
    !(a.audience === 'pro' && !isPro) && !(a.audience === 'free' && isPro)).map(a => a.id);
}
ok('announcement store round-trips (admin write is readable)', () => {
  assert.strictEqual((settings.getJSON('announcements', []) || []).length, 2);
});
ok('pro user sees pro announcement, not free-only', () => {
  const v = visibleTo(true); assert(v.includes('a1') && !v.includes('a2'), 'got ' + v.join(','));
});
ok('free user sees free announcement, not pro-only', () => {
  const v = visibleTo(false); assert(v.includes('a2') && !v.includes('a1'), 'got ' + v.join(','));
});

console.log('\n' + pass + ' passed, ' + fail + ' failed');
if (fail > 0) process.exit(1);
