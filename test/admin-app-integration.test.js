'use strict';
// =============================================================================
// [لوحة الادمن → التطبيق] اختبار تكامل حقيقي
// بيثبت إن كل أمر جوّا لوحة الادمن بيوصل للتطبيق فعلًا.
//
// كل قسم بينادي نفس دوال الموديول اللي مسارات /api/admin/* بتناديها
// (شوف api/admin.js)، وبعدين بيقرا النتيجة بنفس طريقة التطبيق:
//   - حالة الاشتراك: entitlement.summarize = نفس شكل subscription اللي
//     /api/mobile/me بيرجّعه للموبايل (api/mobile.js L456).
//   - قائمة المستخدمين في اللوحة: نفس SQL اللي في admin.users().
//   - الإعلانات/الإعدادات/الفيديو: نفس القارئ اللي في api/mobile.js.
// =============================================================================

const assert = require('assert');
const db = require('../lib/db');
const commerce = require('../lib/commerce');
const entitlement = require('../lib/entitlement');
const settings = require('../lib/settings');
const appconfig = require('../lib/appconfig');
const cfg = require('../lib/config');
const mobile = require('../api/mobile');
const fs = require('fs');
const path = require('path');

let pass = 0, fail = 0;
function t(name, fn){ try { fn(); pass++; console.log('  ok  - ' + name); } catch(e){ fail++; console.log('  FAIL- ' + name + ' :: ' + e.message); } }

// شكل الاشتراك زي ما التطبيق بيشوفه في /api/mobile/me
function appSeesSub(userId){ return entitlement.summarize(db.getSubscription(userId) || { plan:'free', status:'active' }); }

let uid;
const stamp = Date.now();

console.log('\n[admin-app-integration]');

// ---------------------------------------------------------------------------
t('إنشاء مستخدم جديد = مجاني افتراضيًا', function(){
  uid = db.createUser('int_' + stamp + '@test.local', null, 'Integration User', 'h', 's');
  assert.ok(uid > 0, 'مااتعملش مستخدم');
  const s = appSeesSub(uid);
  assert.strictEqual(s.plan, 'free', 'المفروض يبدأ free');
  assert.strictEqual(s.active, false, 'المفروض مش نشط');
});

// ==== 1) منح اشتراك من اللوحة (مشكلة "الكل مجاني") ====
t('منح Pro من اللوحة → التطبيق بيشوفه Pro نشط', function(){
  commerce.adminSetSubscription(uid, 'pro', 'active', 1, 'admin'); // = /api/admin/user/subscription action=grant
  const s = appSeesSub(uid);
  assert.strictEqual(s.active, true, 'التطبيق لسه شايفه مش نشط');
  assert.strictEqual(s.plan, 'pro', 'التطبيق لسه شايفه ' + s.plan);
  assert.strictEqual(s.isPro, true);
  assert.ok(s.current_period_end, 'مفيش تاريخ انتهاء');
});

t('قائمة المستخدمين في اللوحة بتوري Pro (مش مجاني)', function(){
  // نفس SQL اللي في admin.users()
  const row = db.db.prepare(
    'SELECT u.id, s.plan, s.status FROM users u LEFT JOIN subscriptions s ON s.user_id = u.id WHERE u.id = ?'
  ).get(uid);
  const shown = (row && row.plan) || 'free';
  assert.strictEqual(shown, 'pro', 'لوحة الادمن لسه بتوري ' + shown);
});

t('سحب الاشتراك من اللوحة → التطبيق يرجع مجاني', function(){
  commerce.adminSetSubscription(uid, 'free', 'canceled', null, 'admin'); // = action=revoke
  const s = appSeesSub(uid);
  assert.strictEqual(s.active, false);
  assert.strictEqual(s.plan, 'free');
});

t('اشتراك منتهي الصلاحية → التطبيق يقفله تلقائيًا', function(){
  const past = new Date(Date.now() - 24*3600*1000).toISOString();
  db.db.prepare("UPDATE subscriptions SET plan='pro', status='active', current_period_end=? WHERE user_id=?").run(past, uid);
  const s = appSeesSub(uid);
  assert.strictEqual(s.active, false, 'المفروض ينتهي');
  assert.strictEqual(s.plan, 'free', 'المنتهي المفروض يبان free');
});

// ==== 2) التجربة المجانية 3 أيام ====
let uid2;
t('تفعيل التجربة 3 أيام → التطبيق يشوف trial نشط بـ 3 أيام', function(){
  uid2 = db.createUser('trial_' + stamp + '@test.local', null, 'Trial User', 'h', 's');
  const cfgApp = appconfig.get();
  const days = cfgApp.trialDays || commerce.TRIAL_DAYS; // = api/mobile.startTrial
  const r = commerce.startTrial(uid2, days);
  assert.strictEqual(r.ok, true, 'التجربة مااتفعلتش: ' + (r.error||''));
  const s = appSeesSub(uid2);
  assert.strictEqual(s.active, true, 'التطبيق مش شايف التجربة نشطة');
  assert.strictEqual(s.isTrial, true, 'التطبيق مش شايفها تجربة');
  const end = Date.parse(s.current_period_end);
  const daysLeft = Math.round((end - Date.now()) / 86400000);
  assert.ok(daysLeft >= 2 && daysLeft <= 3, 'الأيام المتبقية = ' + daysLeft);
});

t('التجربة ماتتفعلش مرتين لنفس الحساب', function(){
  const r2 = commerce.startTrial(uid2, 3);
  assert.strictEqual(r2.ok, false, 'المفروض ترفض التكرار');
  assert.strictEqual(r2.error, 'trial_already_used');
});

// ==== 3) الكوبونات ====
t('إضافة كوبون من اللوحة → يشتغل في الدفع، وحذفه يلغيه', function(){
  const code = 'ITEST' + (stamp % 100000);
  const up = commerce.upsertCoupon({ code, type:'percent', value:25, active:1 });
  assert.ok(up.ok, 'مااتضافش');
  const ev = commerce.couponEvaluate(code, 'm1', 400, uid);
  assert.ok(ev.ok, 'مااتقيّمش');
  assert.strictEqual(ev.discount, 100, 'خصم 25% من 400 المفروض 100');
  commerce.deleteCoupon(code);
  const ev2 = commerce.couponEvaluate(code, 'm1', 400, uid);
  assert.strictEqual(ev2.ok, false, 'المفروض اتمسح');
});

// ==== 4) البرومو كود (شهور مجانية) ====
let uid3;
t('إنشاء برومو من اللوحة → المستخدم يفعّله → التطبيق يشوفه مشترك', function(){
  const code = 'PROMO' + (stamp % 100000);
  commerce.adminUpsertPromo(code, 2, true); // = /api/admin/promo action=create
  uid3 = db.createUser('promo_' + stamp + '@test.local', null, 'Promo User', 'h', 's');
  const r = commerce.redeemPromo(uid3, code);
  assert.ok(r.ok, 'البرومو مااتفعلش: ' + (r.error||''));
  const s = appSeesSub(uid3);
  assert.strictEqual(s.active, true, 'التطبيق مش شايف البرومو نشط');
  assert.strictEqual(s.plan, 'promo');
  commerce.adminDeletePromo(code);
});

// ==== 5) مفاتيح المزايا (AI) ====
t('قفل ميزة AI من اللوحة → التطبيق يقراها مقفولة ومسار الخطة يفرضها', function(){
  db.setFeatureFlag('ai_nutritionist', '0');   // = /api/admin/features save
  assert.strictEqual(db.getFeatureFlag('ai_nutritionist'), '0');
  const mobileSrc = fs.readFileSync(path.join(__dirname, '../api/mobile.js'), 'utf8');
  assert.ok(mobileSrc.includes("getFeatureFlag('ai_nutritionist')==='0'"), 'مسار التغذية لا يفرض المفتاح');
  assert.ok(mobileSrc.includes("getFeatureFlag('ai_coach')==='0'"), 'مسار التمرين لا يفرض المفتاح');
  db.setFeatureFlag('ai_nutritionist', '1');
  assert.strictEqual(db.getFeatureFlag('ai_nutritionist'), '1');
});

// ==== 6) إعدادات التطبيق (صيانة/إصدار) ====
t('تفعيل وضع الصيانة من اللوحة → التطبيق يقراه', function(){
  const saved = appconfig.save({ maintenance: true, minBuild: 42, maintenanceMessage: 'صيانة اختبار' });
  assert.strictEqual(saved.maintenance, true);
  const readBack = appconfig.get(); // = اللي /api/mobile/app-config بيرجّعه
  assert.strictEqual(readBack.maintenance, true, 'التطبيق مش شايف الصيانة');
  assert.strictEqual(appconfig.versionGate().minBuild, 42, 'بوابة الإصدار مااتطبقتش');
  appconfig.save({ maintenance: false, minBuild: 0 }); // رجّع الوضع
});

// ==== 7) الإعلانات ====
t('إضافة إعلان من اللوحة → التطبيق يعرضه (ويحترم الجمهور)', function(){
  settings.setJSON('announcements', [
    { id:'a_all', title:'للكل', body:'x', placement:'both', audience:'all', active:true, order:0 },
    { id:'a_pro', title:'للمشتركين', body:'y', placement:'both', audience:'pro', active:true, order:1 },
  ]);
  const asFree = mobile.activeAnnouncementsPublic('home', { isPro:false });
  const asPro  = mobile.activeAnnouncementsPublic('home', { isPro:true });
  const freeIds = asFree.map(function(a){ return a.id; });
  const proIds = asPro.map(function(a){ return a.id; });
  assert.ok(freeIds.indexOf('a_all') > -1, 'إعلان الكل ماوصلش للمجاني');
  assert.ok(freeIds.indexOf('a_pro') === -1, 'إعلان المشتركين وصل للمجاني بالغلط');
  assert.ok(proIds.indexOf('a_pro') > -1, 'إعلان المشتركين ماوصلش للمشترك');
  settings.setJSON('announcements', []); // تنظيف
});

t('قفل الإعلانات كلها من الإعدادات → التطبيق مايعرضش حاجة', function(){
  settings.setJSON('announcements', [{ id:'a1', title:'x', body:'y', placement:'both', audience:'all', active:true, order:0 }]);
  appconfig.save({ announcementsEnabled: false });
  const items = mobile.activeAnnouncementsPublic('home', { isPro:false });
  assert.strictEqual(items.length, 0, 'المفروض مايظهرش إعلان لما يتقفلوا');
  appconfig.save({ announcementsEnabled: true });
  settings.setJSON('announcements', []);
});

// ==== 8) فيديو التمارين ====
t('تعديل فيديو تمرين من اللوحة → يتخزّن ويبان للتطبيق، والحذف يرجّع الأصل', function(){
  const key = 'int_test_ex_' + (stamp % 100000);
  db.setVideoOverride(key, 'تمرين اختبار', 'dQw4w9WgXcQ', 'note', 1); // = /api/admin/video/set
  const list = db.videoOverrideList();
  const found = list.find(function(r){ return r.exercise_key === key; });
  assert.ok(found, 'التعديل مااتخزنش');
  assert.strictEqual(found.video_id, 'dQw4w9WgXcQ');
  db.clearVideoOverride(key);
  const list2 = db.videoOverrideList();
  assert.ok(!list2.find(function(r){ return r.exercise_key === key; }), 'الحذف مااشتغلش');
});

// ==== 9) الأسعار ====
t('الباقة المضافة من الأدمن → تظهر في كتالوج الباقات الذي يقرأه التطبيق', function(){
  const before = settings.getJSON('custom_plans', []);
  const code = 'admin_test_' + (stamp % 100000);
  settings.setJSON('custom_plans', [{ code:code, name:'باقة اختبار', months:2, price_egp:222, price_usd:7 }]);
  const shown = cfg.publicConfig().plans.find(function(p){ return p.code === code; });
  assert.ok(shown, 'الباقة محفوظة لكن غير ظاهرة في /api/plans');
  assert.strictEqual(shown.price_egp, 222);
  settings.setJSON('custom_plans', before || []);
});

t('تغيير السعر من اللوحة → يظهر في الإعداد العام للتطبيق', function(){
  const before = settings.getJSON('pricing', {});
  settings.setJSON('pricing', Object.assign({}, before, { m1: { price_egp: 137, anchor_egp: 200, price_usd: 5, anchor_usd: 9, badge:'', tagline:'' } }));
  const pub = cfg.publicConfig();
  const m1 = (pub.plans || []).find(function(p){ return p.code === 'm1'; });
  assert.ok(m1, 'مفيش باقة m1');
  assert.ok(JSON.stringify(m1).indexOf('137') > -1, 'السعر الجديد 137 ماظهرش في الباقة: ' + JSON.stringify(m1));
  settings.setJSON('pricing', before || {}); // رجّع
});

// تنظيف المستخدمين الاختباريين
try {
  [uid, uid2, uid3].forEach(function(id){ if (id) db.db.prepare('DELETE FROM users WHERE id = ?').run(id); });
} catch (_) {}

console.log('\n[admin-app-integration] pass=' + pass + ' fail=' + fail);
if (fail > 0) process.exit(1);
