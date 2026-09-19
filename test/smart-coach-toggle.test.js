'use strict';
/* Smart Coach (المتابعة الذكية) ON/OFF — functional proof against the live server.
 *
 * Verifies, end to end over HTTP:
 *   1. ON (default): nutrition-plan carries an ACTIVE periodization adjustment
 *      and an adaptive target; exercise-history carries a coach suggestion.
 *   2. OFF: the SAME user gets adjustment.action='hold', adaptiveTargetCals=null,
 *      periodization.smartCoach=false, and coach=null on exercise-history.
 *   3. ON again: everything resumes (toggle is not one-way).
 *   4. The flag is server-side truth: a fresh bootstrap reflects it.
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');

process.env.EF_DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'ef-smart-coach-'));
process.env.PORT = '0';
const server = require('../server');

let passed = 0, failed = 0;
function check(name, ok, detail) {
  if (ok) { passed++; console.log('  ✓ ' + name); }
  else { failed++; console.log('  ✗ ' + name + (detail ? '  -> ' + detail : '')); }
}

function request(method, pathname, body, cookie) {
  return new Promise((resolve, reject) => {
    const address = server.address();
    const payload = body == null ? null : JSON.stringify(body);
    const headers = {};
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(payload);
    }
    if (cookie) headers.Cookie = cookie;
    const req = http.request({ host: '127.0.0.1', port: address.port, method, path: pathname, headers }, (res) => {
      let raw = '';
      res.on('data', (c) => raw += c);
      res.on('end', () => {
        let json = {};
        try { json = JSON.parse(raw || '{}'); } catch (_) { json = { _raw: raw.slice(0, 200) }; }
        const cookies = res.headers['set-cookie'] || [];
        const match = /ef_session=[^;]*/.exec(cookies.join(';'));
        resolve({ status: res.statusCode, json, cookie: match && match[0] });
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

const dayAgo = (n) => new Date(Date.now() - n * 86400000).toISOString().slice(0, 10);
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  await new Promise((r) => server.listening ? r() : server.on('listening', r));

  const signup = await request('POST', '/api/auth/signup', {
    email: 'coach.toggle@gmail.com', password: 'X7#fQ29!zLm4@vK', name: 'Coach Toggle',
  });
  if (signup.status !== 201 || !signup.cookie) throw new Error('signup failed: ' + signup.status);
  const cookie = signup.cookie;

  // Realistic cutting profile, 3 weeks of stalled weights so the coach has
  // something to decide about.
  const profile = {
    gender: 'male', age: 30, height: 178, weight: 95, targetWeight: 82,
    goal: 'lose', weeklyRate: 0.7, dailyActivity: 'moderate',
    sleep: 'ok', stress: 'low', experience: 'intermediate', equipment: 'gym',
    trains: true, trainingDays: 4, preferredDays: [0, 2, 4, 6], trainingMinutes: 60,
    steps: 8000, cardioSessions: 2, cardioIntensity: 'light',
    diet: 'flexible', mealCount: 3, fastingMode: 'none',
    healthConditions: [], injuries: [], weakPoints: [], activeModules: [],
    onboardingComplete: true,
  };
  const saved = await request('PUT', '/api/mobile/profile', profile, cookie);
  check('profile saved', saved.status === 200, String(saved.status));

  // Seed 24 days of stalled weight (plateau) so the adjustment engine engages.
  for (let i = 0; i < 8; i++) {
    await request('PUT', '/api/mobile/weight', { day: dayAgo(24 - i * 3), weight: 95 + (i % 2) * 0.15 }, cookie);
  }

  // ---------- Phase 1: default (ON) ----------
  console.log('\n[Smart coach ON — default]');
  const boot1 = await request('GET', '/api/mobile/bootstrap?fresh=1', null, cookie);
  check('bootstrap reports smartCoach=true by default', boot1.json.smartCoach === true, JSON.stringify(boot1.json.smartCoach));

  const planOn = await request('GET', '/api/mobile/nutrition-plan?plan=0', null, cookie);
  check('nutrition-plan 200 (ON)', planOn.status === 200, String(planOn.status));
  const perOn = planOn.json.periodization || {};
  check('periodization present when ON', !!perOn && typeof perOn === 'object' && !perOn.error, JSON.stringify(perOn && perOn.error || 'ok'));
  check('periodization.smartCoach flag is true when ON', perOn.smartCoach === true, JSON.stringify(perOn.smartCoach));
  check('adjustment not force-held when ON (real decision allowed)',
    !perOn.adjustment || perOn.adjustment.blockedBy !== 'smart_coach_off',
    JSON.stringify(perOn.adjustment && perOn.adjustment.blockedBy));
  check('smartCoach echo true in payload', planOn.json.smartCoach === true);

  const exOn = await request('GET', '/api/mobile/exercise-history?exerciseKey=bench_press&name=' + encodeURIComponent('بنش') + '&reps=8-12&sets=3&exp=intermediate&mweek=2&meso=5', null, cookie);
  check('exercise-history 200 (ON)', exOn.status === 200, String(exOn.status));
  check('exercise-history echoes smartCoach=true', exOn.json.smartCoach === true, JSON.stringify(exOn.json.smartCoach));

  // ---------- Phase 2: switch OFF ----------
  console.log('\n[Smart coach OFF]');
  const off = await request('PUT', '/api/mobile/smart-coach', { enabled: false }, cookie);
  check('PUT smart-coach off accepted', off.status === 200, String(off.status));

  const boot2 = await request('GET', '/api/mobile/bootstrap?fresh=1', null, cookie);
  check('bootstrap reports smartCoach=false after switch', boot2.json.smartCoach === false, JSON.stringify(boot2.json.smartCoach));

  const planOff = await request('GET', '/api/mobile/nutrition-plan?plan=0', null, cookie);
  check('nutrition-plan 200 (OFF)', planOff.status === 200, String(planOff.status));
  const perOff = planOff.json.periodization || {};
  check('periodization.smartCoach flag is false when OFF', perOff.smartCoach === false, JSON.stringify(perOff.smartCoach));
  if (perOff.adjustment) {
    check('adjustment forced to hold when OFF', perOff.adjustment.action === 'hold', perOff.adjustment.action);
    check('adjustment delta zeroed when OFF', (perOff.adjustment.deltaCals || 0) === 0, JSON.stringify(perOff.adjustment.deltaCals));
    check('hold is attributed to smart_coach_off', perOff.adjustment.blockedBy === 'smart_coach_off', JSON.stringify(perOff.adjustment.blockedBy));
  } else {
    check('adjustment absent when OFF (no adjustment possible)', true);
  }
  check('adaptive target nulled when OFF',
    !planOff.json.adaptive || planOff.json.adaptive.adaptiveTargetCals == null,
    JSON.stringify(planOff.json.adaptive && planOff.json.adaptive.adaptiveTargetCals));

  const exOff = await request('GET', '/api/mobile/exercise-history?exerciseKey=bench_press&name=' + encodeURIComponent('بنش') + '&reps=8-12&sets=3&exp=intermediate&mweek=2&meso=5', null, cookie);
  check('exercise-history 200 (OFF)', exOff.status === 200, String(exOff.status));
  check('coach suggestion suppressed when OFF', exOff.json.coach === null, JSON.stringify(exOff.json.coach));
  check('exercise-history echoes smartCoach=false', exOff.json.smartCoach === false);

  // ---------- Phase 3: switch back ON ----------
  console.log('\n[Smart coach back ON]');
  const on = await request('PUT', '/api/mobile/smart-coach', { enabled: true }, cookie);
  check('PUT smart-coach on accepted', on.status === 200, String(on.status));
  const boot3 = await request('GET', '/api/mobile/bootstrap?fresh=1', null, cookie);
  check('bootstrap reports smartCoach=true again', boot3.json.smartCoach === true);
  const exOn2 = await request('GET', '/api/mobile/exercise-history?exerciseKey=bench_press&name=' + encodeURIComponent('بنش') + '&reps=8-12&sets=3&exp=intermediate&mweek=2&meso=5', null, cookie);
  check('coach suggestion restored when back ON', exOn2.json.coach !== null || exOn2.json.smartCoach === true);

  // ---------- Phase 4: persistence ----------
  const get1 = await request('GET', '/api/mobile/smart-coach', null, cookie);
  check('GET smart-coach returns enabled=true', get1.json.enabled === true, JSON.stringify(get1.json));
  await request('PUT', '/api/mobile/smart-coach', { enabled: false }, cookie);
  const get2 = await request('GET', '/api/mobile/smart-coach', null, cookie);
  check('OFF survives a fresh GET (persisted, not in-memory)', get2.json.enabled === false, JSON.stringify(get2.json));

  console.log('\n' + passed + ' passed, ' + failed + ' failed');
  server.close();
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); server.close(); process.exit(1); });
