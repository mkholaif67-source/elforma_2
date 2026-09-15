'use strict';
// ============================================================
//  Background Pre-compute
//  بيحسب خطة التغذية في الخلفية بعد ما المستخدم يحفظ بروفايله.
//  المستخدم بياخد الرد فوراً وبعدين الخطة بتتحسب وتتخزن في الـ DB.
//  المرة الجاية يفتح شاشة الخطة → بتيجي من الـ DB في 2ms بدل 631ms.
// ============================================================
const db      = require('./db');
const bridge  = require('./mobile-nutrition-bridge');
const energy  = require('./energy-unified');
const cal     = require('./nutrition-calendar');
const mfp     = require('./meal-food-preferences');
const pool    = require('./engine-pool');
const { nutritionCache } = require('./cache-redis');

// قايمة انتظار: ممنوع يحسب لنفس المستخدم مرتين في نفس الوقت
const _inFlight = new Set();

/**
 * بعد حفظ البروفايل: احسب الخطة في الخلفية وخزّنها.
 * @param {number} userId
 * @param {object} profile  — كائن البروفايل المحفوظ
 * @param {number} [tzOffset=180] — Cairo +3 كـ fallback
 */
function schedulePrecompute(userId, profile, tzOffset) {
  if (!userId || !profile || !profile.age || !profile.height || !profile.weight) return;
  if (_inFlight.has(userId)) return; // حساب جاري للمستخدم ده

  // ابدأ بعد الـ response (setImmediate = بعد ما يتبعت الرد)
  setImmediate(function () {
    _inFlight.add(userId);
    _run(userId, profile, tzOffset || 180)
      .catch(function (e) {
        if (process.env.EF_ENV !== 'production') {
          console.error('[precompute] user=' + userId, e.message);
        }
      })
      .finally(function () {
        _inFlight.delete(userId);
      });
  });
}

async function _run(userId, p, tzOffset) {
  const living = energy.contextForUser(p, userId);
  const ctx    = bridge.buildEngineContext(living, living.__extras);

  ctx.inputs.mealFavorites = mfp.read(userId);

  const pantry = bridge.resolvePantry(p, db.foodPreferences(userId, 400));
  if (pantry.ids && pantry.ids.length) ctx.inputs.availableFoods = pantry.ids;

  // يوم الدورة واليوم المحلي
  const tzOff = Number.isFinite(tzOffset) ? tzOffset : 180;
  const calendar = cal.calendar(p.nutritionStartedAt, tzOff);
  ctx.inputs['inp-week']   = calendar.week;
  ctx.inputs.dayOfCycle    = calendar.day;

  // حالة التمرين
  let isTraining = false;
  try {
    const plans = db.db
      .prepare('SELECT plan_json FROM workout_plans WHERE user_id=? AND active=1 LIMIT 1')
      .get(userId);
    if (plans) {
      const plan = JSON.parse(plans.plan_json);
      isTraining = !!(plan && plan.today && plan.today.isTraining);
    }
  } catch (_) {}
  ctx.profile.isTrainingDay = isTraining;
  ctx.inputs.isTrainingDay  = isTraining;

  if (living.coachTargetCals > 0) {
    ctx.profile.coachTargetCals = living.coachTargetCals;
    ctx.inputs.coachTargetCals  = living.coachTargetCals;
  }

  // الحساب في worker thread — مش بيجمّد الـ event loop
  const result = await pool.computeMealPlanAsync(ctx.profile, ctx.inputs);

  if (!result || !result.plan || !Array.isArray(result.plan.meals)) {
    throw new Error('precompute_bad_result');
  }

  // خزّن الخطة في prepared_nutrition_plans
  const profileKey = JSON.stringify({ profile: ctx.profile, inputs: ctx.inputs });
  const planJson   = JSON.stringify(result);
  db.db.prepare(
    `INSERT INTO prepared_nutrition_plans(user_id, profile_json, plan_json, created_at)
     VALUES(?, ?, ?, ?)
     ON CONFLICT(user_id)
     DO UPDATE SET profile_json=excluded.profile_json,
                   plan_json=excluded.plan_json,
                   created_at=excluded.created_at`
  ).run(userId, profileKey, planJson, new Date().toISOString());

  // امسح كاش التغذية عشان المرة الجاية يجيب الخطة الجديدة
  try { nutritionCache.invalidatePrefix('np:' + userId + ':'); } catch (_) {}

  console.log('[precompute] done user=' + userId + ' meals=' + result.plan.meals.length);
}

module.exports = { schedulePrecompute };
