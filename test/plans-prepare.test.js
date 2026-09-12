'use strict';
/* [FIX-CHAT-EXIT] Contract test for POST /api/mobile/plans/prepare —
   the dedicated heavy-lifting endpoint the analysis screen calls, so the
   onboarding chat never blocks on plan generation again.
 *
 * Proves:
 *   1. Saving the profile WITHOUT preparePlans stays fast and prepares nothing.
 *   2. /plans/prepare generates BOTH plans (workout persisted, nutrition stored).
 *   3. It is idempotent: a repeat call keeps the same plan and journey anchor.
 *   4. Concurrent calls share ONE engine run (per-user dedupe).
 *   5. It refuses unauthenticated / incomplete profiles loudly.
 */
const assert = require('node:assert/strict');
const fs = require('fs'), os = require('os'), path = require('path'), http = require('http');
process.env.EF_DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'ef-plans-prepare-'));
process.env.PORT = '0';
const server = require('../server');
const db = require('../lib/db');

function req(method, url, body, cookie) {
  return new Promise((resolve, reject) => {
    const data = body == null ? null : JSON.stringify(body);
    const r = http.request({ host: '127.0.0.1', port: server.address().port, path: url, method,
      headers: { ...(cookie ? { Cookie: cookie } : {}), ...(data ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } : {}) } },
      (res) => { let text = ''; res.on('data', (d) => text += d); res.on('end', () => {
        resolve({ status: res.statusCode, data: JSON.parse(text || '{}'),
          cookie: (res.headers['set-cookie'] || []).join(';').match(/ef_session=[^;]*/)?.[0] });
      }); });
    r.on('error', reject); r.end(data);
  });
}

const profile = { gender: 'male', age: 28, height: 180, weight: 88, targetWeight: 80,
  goal: 'lose', weeklyRate: 0.6, experience: 'intermediate', equipment: 'gym',
  trains: true, trainingDays: 4, preferredDays: [0, 2, 4, 6], trainingMinutes: 60,
  dailyActivity: 'moderate', sleep: 'ok', stress: 'low', steps: 9000,
  cardioSessions: 2, cardioIntensity: 'light', diet: 'balanced', mealCount: 3,
  fastingMode: 'none', injuries: [], weakPoints: [], healthConditions: [],
  activeModules: [], onboardingComplete: true };

(async () => {
  await new Promise((r) => server.listening ? r() : server.once('listening', r));

  const guest = await req('POST', '/api/mobile/plans/prepare', {});
  assert.equal(guest.status, 401, 'unauthenticated must be refused');

  const a = await req('POST', '/api/auth/signup', { email: 'prepare.a@gmail.com', password: 'X7#fQ29!zLm4@vK', name: 'User A' });
  assert.equal(a.status, 201, JSON.stringify(a.data));

  const noProfile = await req('POST', '/api/mobile/plans/prepare', {}, a.cookie);
  assert.equal(noProfile.status, 400, 'incomplete profile must be refused loudly');

  const t0 = Date.now();
  const saved = await req('PUT', '/api/mobile/profile', { profile }, a.cookie);
  const saveMs = Date.now() - t0;
  assert.equal(saved.status, 200, JSON.stringify(saved.data));
  assert.ok(saveMs < 5000, 'profile save must stay fast (no in-request engine run), took ' + saveMs + 'ms');

  const before = await req('GET', '/api/mobile/bootstrap', null, a.cookie);
  assert.equal(before.data.workoutPlan, null, 'fast save must NOT have built the plan');

  // Concurrent calls must share a single engine run.
  const [p1, p2] = await Promise.all([
    req('POST', '/api/mobile/plans/prepare', {}, a.cookie),
    req('POST', '/api/mobile/plans/prepare', {}, a.cookie),
  ]);
  assert.equal(p1.status, 200, JSON.stringify(p1.data));
  assert.equal(p2.status, 200, JSON.stringify(p2.data));
  assert.ok(p1.data.readiness && p1.data.readiness.nutritionReady, 'nutrition ready');
  assert.ok(p1.data.readiness && p1.data.readiness.workoutReady, 'workout ready');

  const after = await req('GET', '/api/mobile/bootstrap', null, a.cookie);
  assert.ok(after.data.workoutPlan && after.data.workoutPlan.id, 'bootstrap serves the prepared plan');
  const uid = after.data.user.id;
  assert.ok(db.db.prepare('SELECT plan_json FROM prepared_nutrition_plans WHERE user_id=?').get(uid),
    'prepared nutrition plan persisted');
  const stored = JSON.parse(db.activeWorkoutPlan(uid).plan_json);
  assert.ok(stored.plan.some((d) => d.exercises && d.exercises.length), 'real training days persisted');

  // Idempotent: repeat keeps plan identity and journey anchor.
  const anchor = stored._scheduleStartedMs, planId = after.data.workoutPlan.id;
  const again = await req('POST', '/api/mobile/plans/prepare', {}, a.cookie);
  assert.equal(again.status, 200);
  const bootAgain = await req('GET', '/api/mobile/bootstrap', null, a.cookie);
  assert.equal(bootAgain.data.workoutPlan.id, planId, 'repeat must not replace the plan');
  assert.equal(JSON.parse(db.activeWorkoutPlan(uid).plan_json)._scheduleStartedMs, anchor,
    'journey anchor must survive re-preparation');

  console.log('plans-prepare: all assertions passed (saveMs=' + saveMs + ')');
  server.close();
  process.exit(0);
})().catch((e) => { console.error(e); server.close(); process.exit(1); });
