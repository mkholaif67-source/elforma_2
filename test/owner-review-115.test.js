'use strict';
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const nutrition = require('../lib/nutrition-engine-host');

let pass = 0, fail = 0;
function t(name, fn) {
  try { fn(); pass++; console.log('  ✓ ' + name); }
  catch (error) { fail++; console.log('  ✗ ' + name + ' — ' + error.message); }
}
function foodName(food) {
  return String(food && food.food && food.food.nameAr || '').replace(/[\u00a0\u200f\u200e]/g, ' ').replace(/\s+/g, ' ').trim();
}
function dayCalories(plan) {
  return (plan.meals || []).reduce((sum, meal) => sum + (meal.foods || []).reduce((v, food) => v + (Number(food.cals) || 0), 0), 0);
}

console.log('\n[owner review v1.0.15 — nutrition]');
const generated = [];
for (const mealCount of [2, 3, 4, 5]) {
  for (const isTrainingDay of [false, true]) {
    for (const seed of [0, 1, 2]) {
      const profile = {
        gender: 'male', age: 30, height: 181, weight: 108, target: 90,
        activity: 1.375, goal: 'lose', selectedDiet: 'balanced', diet: 'balanced',
        mealCount, isTrainingDay, preWorkoutVariant: seed, saladVariant: seed,
      };
      generated.push({ mealCount, isTrainingDay, seed, plan: nutrition.computeMealPlan(profile, {}).plan });
    }
  }
}

t('24 generated plans cover 2–5 meals, training/rest and three day variants', () => assert.strictEqual(generated.length, 24));
t('egg is never above 150g per meal', () => {
  for (const row of generated) for (const meal of row.plan.meals || []) for (const food of meal.foods || []) {
    const name = foodName(food);
    const isEgg = (food.food && food.food.cat === 'egg') || /(^|\s)بيض(\s|$)/.test(name);
    if (isEgg && !/جبنة بيضاء/.test(name)) assert.ok(Number(food.grams) <= 150, name + ':' + food.grams);
  }
});
t('foul is never above 200g per meal', () => {
  for (const row of generated) for (const meal of row.plan.meals || []) for (const food of meal.foods || []) {
    const name = foodName(food);
    if (/فول/.test(name) && !/سوداني/.test(name)) assert.ok(Number(food.grams) <= 200, name + ':' + food.grams);
  }
});
t('main-meal bread is never shown below 50g', () => {
  for (const row of generated) for (const meal of row.plan.meals || []) for (const food of meal.foods || []) {
    if (!meal._autoPreWorkout && /عيش|خبز|توست/.test(foodName(food))) assert.ok(Number(food.grams) >= 50, foodName(food) + ':' + food.grams);
  }
});
t('oil and butter servings are whole grams inside 2–10g, combined daily at most 20g', () => {
  for (const row of generated) {
    let daily = 0;
    for (const meal of row.plan.meals || []) for (const food of meal.foods || []) {
      if (/زيت زيتون|زبدة|سمنة/.test(foodName(food))) {
        const grams = Number(food.grams);
        assert.ok(Number.isInteger(grams) && grams >= 2 && grams <= 10, foodName(food) + ':' + grams);
        daily += grams;
      }
    }
    assert.ok(daily <= 20, 'added fats=' + daily);
  }
});
t('visible daily calories stay between -100 and +50 kcal of target', () => {
  for (const row of generated) {
    const actual = dayCalories(row.plan);
    assert.ok(actual >= Number(row.plan.targetCals) - 100,
      JSON.stringify({mealCount: row.mealCount, training: row.isTrainingDay, target: row.plan.targetCals, actual}));
    assert.ok(actual <= Number(row.plan.targetCals) + 50,
      JSON.stringify({mealCount: row.mealCount, training: row.isTrainingDay, target: row.plan.targetCals, actual}));
  }
});
t('pre-workout remains outside the selected meal count', () => {
  for (const row of generated) {
    const normal = (row.plan.meals || []).filter(meal => !meal._autoPreWorkout && (meal.foods || []).length);
    assert.strictEqual(normal.length, row.mealCount);
  }
});

console.log('\n[owner review v1.0.15 — workout export]');
const exportSource = fs.readFileSync(path.join(__dirname, '../mobile/lib/models/plan_export.dart'), 'utf8');
t('day title parser extracts canonical split names and strips descriptions', () => {
  assert.match(exportSource, /Anterior\|Posterior\|Push\|Pull\|Legs\?/);
  assert.match(exportSource, /return session\.group\(0\)!\.trim\(\)/);
  assert.doesNotMatch(exportSource, /s = '\$before — \$after'/);
  assert.ok(exportSource.includes('<span class=\"day-label\">${_esc(cleanName)}</span>'));
});
t('sets and reps have fixed columns and cannot wrap', () => {
  assert.match(exportSource, /\.ex-num \{/);
  assert.match(exportSource, /white-space: nowrap/);
  assert.match(exportSource, /unicode-bidi: isolate/);
  assert.match(exportSource, /font-variant-numeric: tabular-nums/);
  assert.match(exportSource, /<colgroup>/);
  assert.match(exportSource, /table-layout: fixed/);
});

console.log('\n[owner review v1.0.15 — admin verification]');
process.env.EF_DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'ef-owner-115-'));
process.env.PORT = '0';
const server = require('../server');
const db = require('../lib/db');
function request(method, pathname, body, cookie) {
  return new Promise((resolve, reject) => {
    const payload = body == null ? null : JSON.stringify(body);
    const headers = {};
    if (payload) { headers['Content-Type'] = 'application/json'; headers['Content-Length'] = Buffer.byteLength(payload); }
    if (cookie) headers.Cookie = cookie;
    const req = http.request({host: '127.0.0.1', port: server.address().port, method, path: pathname, headers}, res => {
      let raw = '';
      res.on('data', chunk => raw += chunk);
      res.on('end', () => {
        const setCookie = res.headers['set-cookie'] || [];
        const hit = /ef_session=[^;]*/.exec(setCookie.join(';'));
        let json = null; try { json = JSON.parse(raw); } catch (_) {}
        resolve({status: res.statusCode, raw, json, cookie: hit && hit[0]});
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

(async () => {
  await new Promise(resolve => server.listening ? resolve() : server.on('listening', resolve));
  const signup = await request('POST', '/api/auth/signup', {
    email: 'mokholaif7@gmail.com', password: 'owner-review-pass-115', name: 'Owner Review',
  });
  t('unverified allowlisted owner stays identified as an admin email', () => {
    assert.strictEqual(signup.status, 201);
    assert.ok(signup.cookie);
  });
  const before = await request('GET', '/api/admin/whoami', null, signup.cookie);
  t('whoami reports verification state without granting admin early', () => {
    assert.strictEqual(before.status, 200);
    assert.strictEqual(before.json.adminEmail, true);
    assert.strictEqual(before.json.verified, false);
    assert.strictEqual(before.json.admin, false);
  });
  const blocked = await request('GET', '/admin.html', null, signup.cookie);
  t('owner is kept on a verification-aware admin page, not auto-redirected', () => {
    assert.strictEqual(blocked.status, 403);
    assert.match(blocked.raw, /محتاج تأكيد البريد/);
    assert.doesNotMatch(blocked.raw, /http-equiv=\"refresh\"/);
  });
  db.setVerified(db.userByEmail('mokholaif7@gmail.com').id);
  const after = await request('GET', '/api/admin/whoami', null, signup.cookie);
  t('verified plus allowlisted owner receives admin access', () => {
    assert.strictEqual(after.json.verified, true);
    assert.strictEqual(after.json.admin, true);
  });
  t('safe server recovery command is packaged', () => {
    const pkg = require('../package.json');
    assert.match(pkg.scripts['admin:verify'], /scripts\/verify-admin\.js/);
    const source = fs.readFileSync(path.join(__dirname, '../scripts/verify-admin.js'), 'utf8');
    assert.match(source, /isAdminEmail/);
    assert.match(source, /setVerified/);
    assert.match(source, /admin_verified_from_server_console/);
  });

  console.log('\n' + (fail ? '❌' : '✅') + ' owner-review-115: ' + pass + ' passed, ' + fail + ' failed');
  server.close(() => process.exit(fail ? 1 : 0));
})().catch(error => {
  console.error(error);
  server.close(() => process.exit(1));
});
