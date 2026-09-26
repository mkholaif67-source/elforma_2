'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const bridge = require('../lib/mobile-nutrition-bridge');
const nutrition = require('../lib/nutrition-engine-host');
const workout = require('../lib/workout-plan-finisher');

let passed = 0;
function test(name, fn) {
  try { fn(); passed++; }
  catch (e) { console.error('FAIL:', name); throw e; }
}
function profile(rate) {
  const p = {
    gender: 'male', age: 30, height: 181, weight: 108, targetWeight: 85,
    goal: 'lose', dailyActivity: 'light', trainingDays: 4,
    trainingMinutes: 60, experience: 'advanced', equipment: 'gym',
    diet: 'balanced', mealCount: 3, isTrainingDay: false
  };
  if (rate != null) p.weeklyRate = rate;
  return p;
}
function planFor(rate) {
  const c = bridge.buildEngineContext(profile(rate), {});
  return nutrition.computeMealPlan(c.profile, c.inputs);
}

test('exact submitted profile uses one target and one macro authority', () => {
  const out = planFor(1);
  assert.strictEqual(out.targets.bmr, 2066);
  assert.strictEqual(out.targets.targetCals, 2066);
  assert.strictEqual(out.targets.macros.protein, 153);
  assert.strictEqual(out.targets.macros.carbs, 164);
  assert.strictEqual(out.targets.macros.fat, 76);
  assert.strictEqual(out.plan.targetCals, out.targets.targetCals);
  assert.strictEqual(out.plan.targetMacros.protein, out.targets.macros.protein);
  assert.strictEqual(out.plan.targetMacros.carbs, out.targets.macros.carbs);
  assert.strictEqual(out.plan.targetMacros.fat, out.targets.macros.fat);
  assert.ok(Math.abs(out.plan.totals.cals - out.targets.targetCals) <= 100);
  assert.ok(out.plan._macroAudit && out.plan._macroAudit.passed, JSON.stringify(out.plan._macroAudit));
});

test('default safe rate remains above BMR and the final foods still reconcile', () => {
  const out = planFor(null);
  assert.ok(out.targets.targetCals > out.targets.bmr);
  assert.strictEqual(out.plan.targetCals, out.targets.targetCals);
  assert.ok(out.plan._macroAudit && out.plan._macroAudit.passed, JSON.stringify(out.plan._macroAudit));
});

test('cooked rice and lean-protein portions are human-sized', () => {
  for (const rate of [null, 1]) {
    const out = planFor(rate);
    for (const meal of out.plan.meals) for (const item of meal.foods || []) {
      const name = String(item.food && item.food.nameAr || '');
      if (/أرز|رز|مكرونة|مكرونه/.test(name)) assert.ok(item.grams >= 70, name + ': ' + item.grams);
      if (/فراخ|دجاج|سمك|بلطي|بوري|لحمة|لحم/.test(name)) assert.ok(item.grams <= 250, name + ': ' + item.grams);
    }
  }
});

test('every male active day has five to eight purposeful exercises', () => {
  for (const exp of ['beginner', 'intermediate', 'advanced']) {
    for (const days of [2, 3, 4, 5, 6]) {
      const p = { gender:'male', age:30, height:181, weight:108, goal:'cut',
        exp, equip:'gym', days, time:60, daily:'light', sleep:'ok', stress:'low',
        injuries:['none'], weak:[] };
      const out = workout.computeStablePlan(p).out;
      for (const plan of out.plans || []) for (const day of plan.plan || []) {
        const count = (day.exercises || []).length;
        if (!count) continue;
        assert.ok(count >= 5 && count <= 8,
          `${exp}/${days}/${plan.key}/${day.name}: ${count}`);
      }
    }
  }
});

test('Flutter restores a valid stored plan and refreshes completion state', () => {
  const workoutScreen = fs.readFileSync(path.join(__dirname, '../mobile/lib/screens/workout_screen.dart'), 'utf8');
  const sessionScreen = fs.readFileSync(path.join(__dirname, '../mobile/lib/screens/training_session_screen.dart'), 'utf8');
  const homeScreen = fs.readFileSync(path.join(__dirname, '../mobile/lib/screens/home_screen.dart'), 'utf8');
  assert.match(workoutScreen, /_storedOnlyResult/);
  assert.match(workoutScreen, /storedFallback == null/);
  assert.match(workoutScreen, /push<bool>/);
  assert.match(workoutScreen, /_completedToday = true/);
  assert.match(sessionScreen, /invalidateBootstrap\(\)/);
  assert.match(sessionScreen, /PlanStore\.I\.markChanged\(\)/);
  assert.match(homeScreen, /_load\(force: true\)/);
});

test('saved meals are only reused for the same calorie target', () => {
  const src = fs.readFileSync(path.join(__dirname, '../mobile/lib/screens/meal_plan_screen.dart'), 'utf8');
  assert.match(src, /_planTargetCals/);
  assert.match(src, /useSavedMeals/);
  assert.match(src, /comparableSavedTarget - serverTarget/);
});

console.log(`requested-root-regressions: ${passed} passed, 0 failed`);
