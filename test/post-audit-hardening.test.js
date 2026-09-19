'use strict';

// Read-only source contracts for the post-audit hardening batch. These tests
// deliberately avoid a provider, Flutter SDK, or production credentials.
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const root = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
let pass = 0;
const check = (label, fn) => { fn(); pass++; console.log('  ✓ ' + label); };

console.log('[post-audit hardening contracts]');

check('geo headers require both proxy and geo trust flags', () => {
  const s = read('lib/config.js');
  assert(s.includes("process.env.EF_TRUST_PROXY !== '1'"));
  assert(s.includes("process.env.EF_TRUST_GEO_HEADERS !== '1'"));
});

check('guest plan and workout budgets are smaller and keyed per IP', () => {
  assert(read('api/plan.js').includes('const computeBudget = user ? 12 : 4'));
  assert(read('api/plan.js').includes("const computeKey = user ? 'u' + user.id : 'ip'"));
  assert(read('api/workout.js').includes("const computeKey = user ? 'u' + user.id : 'ip'"));
});

check('review submission has account and IP limits', () => {
  const s = read('api/reviews.js');
  assert(s.includes("review:submit:user:"));
  assert(s.includes("review:submit:ip:"));
});

check('age policy remains independent from removed consent workflow', () => {
  assert(read('lib/age-policy.js').includes('requiresGuardianConsent'));
  assert(!read('lib/db.js').includes('guardian_consents'));
  assert(!read('api/mobile.js').includes('guardianConsentRequired'));
  assert(!read('api/plan.js').includes('guardian_consent_required'));
  assert(!read('api/workout.js').includes('guardian_consent_required'));
  assert(!read('mobile/lib/screens/profile_setup_screen.dart').includes('موافقة ولي الأمر'));
});

check('receipt mirroring has a fail-closed production option', () => {
  assert(read('lib/receipt-storage.js').includes('EF_RECEIPTS_REMOTE_URL'));
  assert(read('api/pay.js').includes('EF_REQUIRE_DURABLE_RECEIPTS'));
  assert(read('api/admin.js').includes('receiptStorage.stream'));
});

check('auth fields expose platform autofill hints', () => {
  const s = read('mobile/lib/screens/auth_screen.dart');
  assert((s.match(/autofillHints:/g) || []).length >= 6);
});

check('release optimization is enabled while signing remains CI-controlled', () => {
  const s = read('mobile/android/app/build.gradle.kts');
  assert(s.includes('isMinifyEnabled = true'));
  assert(s.includes('isShrinkResources = true'));
  assert(read('mobile/tools/apply_release_signing.py').includes('ANDROID_KEYSTORE_BASE64'));
});

console.log('\n' + pass + ' passed, 0 failed');
