'use strict';
// /api/plan/* — server-side plan computation.
// The premium plan-generation logic runs ONLY on the server (via the engine
// host). Clients send their profile inputs and receive computed results,
// gated by subscription: free users get a limited preview, subscribers get
// the full plan. The engine logic itself never ships to the browser.
const auth = require('../lib/auth');
const db = require('../lib/db');
const { sendJson, readJsonBody, parseCookies } = require('../lib/util');
// [PHASE-0-PERF] المحرك (631ms لكل خطة) بقى بيشتغل في worker threads عبر
// engine-pool بدل التنفيذ المتزامن على الـ main thread اللي كان بيجمّد
// كل طلبات السيرفر مع كل حساب خطة. engine-pool بيرفض بـ engine_busy لو
// الطابور امتلأ بدل ما يعلّق الطلبات للأبد.
const enginePool = require('../lib/engine-pool');
const { rateLimit } = require('../lib/rateLimit');
// [توحيد العقل] المصدر الوحيد لحالة الاشتراك.
const entitlement = require('../lib/entitlement');
const bodyBounds = require('../lib/body-bounds');
const engineGuide = require('../lib/engine-error-guide');

// Share only simultaneous identical calculations. This is not a result cache:
// the entry is removed as soon as the worker finishes, so freshness and all
// subscription/response rules remain unchanged. It prevents double taps or
// two screens requesting the same heavy plan from occupying multiple workers.
const inFlightComputes = new Map();
function sharedCompute(type, owner, profile, inputs, factory) {
  const key = type + ':' + owner + ':' + JSON.stringify([profile, inputs]);
  const current = inFlightComputes.get(key);
  if (current) return current;
  const task = Promise.resolve().then(factory);
  if (inFlightComputes.size < 128) {
    inFlightComputes.set(key, task);
    const clear = () => { if (inFlightComputes.get(key) === task) inFlightComputes.delete(key); };
    task.then(clear, clear);
  }
  return task;
}

/* Plan generation is by far the heaviest thing this server does: it boots the
   whole diet engine inside a vm and assembles a full week of meals. One person
   hammering the button can therefore slow the app down for everyone, so the
   expensive endpoints get their own budget. Logged-in users are keyed by id so
   a shared cafe/office IP never punishes the wrong person. */
function tooMany(res, key, limit, windowMs) {
  if (rateLimit(key, limit, windowMs)) return false;
  sendJson(res, 429, { error: '\u0637\u0644\u0628\u0627\u062a \u0643\u062a\u064a\u0631\u0629 \u0641\u064a \u0648\u0642\u062a \u0642\u0635\u064a\u0631 \u2014 \u0627\u0633\u062a\u0646\u0649 \u062f\u0642\u064a\u0642\u0629 \u0648\u062d\u0627\u0648\u0644 \u062a\u0627\u0646\u064a' });
  return true;
}

// [توحيد العقل] مصدر واحد: lib/entitlement.js
const subActive = entitlement.subActive;

// Whitelist + coerce only known scalar profile fields coming from the client.
function cleanProfile(b) {
  const p = (b && b.profile) || {};
  const out = {};
  const S = function (k) { if (typeof p[k] === 'string' && p[k].length <= 40) out[k] = p[k]; };
  const N = function (k) { const v = Number(p[k]); if (Number.isFinite(v)) out[k] = v; };
  S('gender'); N('age'); N('height'); N('weight'); N('target'); N('activity');
  S('goal'); S('gainStyle'); S('selectedDiet'); N('mealCount');
  N('currentWeek'); N('expectedWeeklyLoss');
  if (Array.isArray(p.healthConditions)) out.healthConditions = p.healthConditions.filter(function (x) { return typeof x === 'string'; }).slice(0, 20);
  if (Array.isArray(p.dietProblems)) out.dietProblems = p.dietProblems.filter(function (x) { return typeof x === 'string'; }).slice(0, 20);
  if (!out.selectedDiet) out.selectedDiet = 'balanced';
  return out;
}
// Only allow inp-* keys (the DOM input ids the engine reads) with scalar values.
function cleanInputs(b) {
  const i = (b && b.inputs) || {};
  const out = {};
  Object.keys(i).slice(0, 40).forEach(function (k) {
    if (/^inp-[a-z0-9_-]+$/i.test(k)) { const v = i[k]; if (typeof v === 'string' || typeof v === 'number') out[k] = String(v); }
  });
  return out;
}

// FREE preview: numeric targets + only the first meal; the rest stays locked.
function gatePreview(full) {
  const meals = (full.plan && full.plan.meals) || [];
  return {
    locked: true,
    targets: full.targets,
    plan: {
      targetCals: full.plan && full.plan.targetCals,
      totals: full.plan && full.plan.totals,
      mealsTotal: meals.length,
      meals: meals.slice(0, 1)
    }
  };
}

async function compute(req, res, ip) {
  const user = auth.currentUser(parseCookies(req));
  if (tooMany(res, 'plan:compute:' + (user ? 'u' + user.id : 'ip' + ip), 12, 60000)) return;
  const b = await readJsonBody(req);
  const profile = cleanProfile(b);
  const inputs = cleanInputs(b);
  const bodyProblem = bodyBounds.validateBody(profile);
  if (bodyProblem) return sendJson(res, 422, { error: 'profile_incomplete', code: bodyProblem.code, message: engineGuide.GUIDE[bodyProblem.code] });
  let full;
  try { full = await sharedCompute('plan', user ? 'u' + user.id : 'ip' + ip, profile, inputs, () => enginePool.computeMealPlanAsync(profile, inputs)); }
  catch (e) {
    const m = (e && e.message) || '';
    if (/engine_busy|engine_timeout|engine_pool_closed/.test(m)) {
      return sendJson(res, 503, { error: 'الخادم مشغول حاليًا — حاول بعد دقيقة' });
    }
    const guided = engineGuide.messageFor(e);
    if (guided) return sendJson(res, 422, { error: 'profile_incomplete', code: engineGuide.codeFrom(e), message: guided });
    return sendJson(res, 500, { error: 'تعذر حساب الخطة' });
  }
  const sub = user ? (db.getSubscription(user.id) || { plan: 'free', status: 'active' }) : null;
  if (subActive(sub)) return sendJson(res, 200, { ok: true, locked: false, targets: full.targets, plan: full.plan });
  return sendJson(res, 200, Object.assign({ ok: true }, gatePreview(full)));
}

// Numeric targets only (BMR/TDEE/calories/macros) — safe for any request.
async function targets(req, res) {
  const tUser = auth.currentUser(parseCookies(req));
  if (tooMany(res, 'plan:targets:' + (tUser ? 'u' + tUser.id : 'anon'), 30, 60000)) return;
  const b = await readJsonBody(req);
  const profile = cleanProfile(b);
  const inputs = cleanInputs(b);
  const bodyProblem = bodyBounds.validateBody(profile);
  if (bodyProblem) return sendJson(res, 422, { error: 'profile_incomplete', code: bodyProblem.code, message: engineGuide.GUIDE[bodyProblem.code] });
  let t;
  try { t = await sharedCompute('targets', tUser ? 'u' + tUser.id : 'anon', profile, inputs, () => enginePool.computeTargetsAsync(profile, inputs)); }
  catch (e) {
    const m = (e && e.message) || '';
    if (/engine_busy|engine_timeout|engine_pool_closed/.test(m)) {
      return sendJson(res, 503, { error: 'الخادم مشغول حاليًا — حاول بعد دقيقة' });
    }
    const guided = engineGuide.messageFor(e);
    if (guided) return sendJson(res, 422, { error: 'profile_incomplete', code: engineGuide.codeFrom(e), message: guided });
    return sendJson(res, 500, { error: 'تعذر الحساب' });
  }
  return sendJson(res, 200, { ok: true, targets: t });
}

module.exports = { compute, targets, _sharedCompute: sharedCompute, _inFlightComputes: inFlightComputes };
