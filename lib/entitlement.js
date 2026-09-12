'use strict';
// =============================================================================
// lib/entitlement.js — THE single source of truth for "is this subscription
// currently usable?" and "is this user a paying/entitled user?".
//
// [توحيد العقل] قبل الملف ده كان فيه 7 نسخ منفصلة من نفس القاعدة
// (lib/auth.js, api/auth.js, api/mobile.js activeSub + proContext, api/plan.js,
//  api/workout.js) وكل واحدة بشروط مختلفة شوية — وده كان سبب
// "الترقيع": أمر الأدمن يأثّر في مكان ومايأثّرش في مكان تاني.
// دلوقتي الكل بينادي الدوال دي وبس.
//
// A subscription row shape (from lib/db.js subscriptions table):
//   { user_id, plan, status, provider, current_period_end, updated_at, trial_used }
//   plan   : 'free' | 'trial' | 'pro' | 'promo' | (any admin-set paid plan)
//   status : 'active' | 'trialing' | 'canceled' | 'inactive' | ...
// =============================================================================

// هل الاشتراك نشط دلوقتي؟ (مع احترام تاريخ الانتهاء)
// The ONE rule: any non-free plan, in an active/trialing status, not expired.
// ملاحظة: بنقبل أي plan مش 'free' (pro / trial / promo / أي باقة يحطها الأدمن)
// عشان مايبقاش فيه باقة تتفعّل من الأدمن وماتتقراش في التطبيق.
function subActive(sub) {
  if (!sub || !sub.plan || sub.plan === 'free') return false;
  if (sub.status !== 'active' && sub.status !== 'trialing') return false;
  if (sub.current_period_end) {
    const end = Date.parse(sub.current_period_end);
    if (Number.isFinite(end) && end <= Date.now()) return false; // expired
  }
  return true;
}

// هل المستخدم مشترك فعّال؟ (نفس القاعدة — alias واضح للقراءة)
function isPro(sub) {
  return subActive(sub);
}

// هل الاشتراك تجربة مجانية؟
function isTrial(sub) {
  if (!sub) return false;
  return sub.plan === 'trial' || sub.status === 'trialing';
}

// الباقة الفعلية اللي العميل شايفها: لو مش نشط يبقى 'free'.
function effectivePlan(sub) {
  return subActive(sub) ? (sub && sub.plan) : 'free';
}

// ملخّص موحّد للاشتراك زي ما التطبيق/الويب بياخدوه.
// مصدر واحد لـ active / plan / isTrial … بدل ما كل endpoint يعيد حسابها.
function summarize(sub) {
  const raw = sub || { plan: 'free', status: 'active' };
  const active = subActive(raw);
  const trial = isTrial(raw) && active;
  return {
    active: active,
    plan: active ? raw.plan : 'free',
    isPro: active,
    isTrial: trial,
    trialExpired: isTrial(raw) && !active,
    contentAccess: active,
    canExport: active,
    trialUsed: Boolean(raw && raw.trial_used),
    current_period_end: raw.current_period_end || null,
  };
}

module.exports = { subActive, isPro, isTrial, effectivePlan, summarize };
