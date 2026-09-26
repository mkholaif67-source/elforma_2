'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');

const intro = read('mobile/lib/widgets/brand_intro_scene.dart');
const splash = read('mobile/lib/screens/splash_screen.dart');
const header = read('mobile/lib/widgets/auth_reference_header.dart');
const pubspec = read('mobile/pubspec.yaml');

assert.match(intro, /Duration\(milliseconds: 3450\)/);
assert.match(splash, /duration: brandIntroDuration/);
assert.doesNotMatch(splash, /_c\.repeat/);

assert.match(pubspec, /assets\/auth\//);
assert.match(pubspec, /family: Cairo/);
assert.match(header, /reference_logo.png/);
assert.doesNotMatch(pubspec, /brand_experience_v5/);
assert.ok(!fs.existsSync(path.join(root, 'mobile/assets/brand_experience_v5')));
for (const filename of ['reference_logo.png', 'splash_logo.png', 'login_fitness.svg', 'register_fitness.svg', 'google.svg']) {
  assert.ok(fs.existsSync(path.join(root, 'mobile/assets/auth', filename)), `missing asset ${filename}`);
}
for (const file of ['drawable/launch_background.xml', 'drawable-v21/launch_background.xml', 'values-v31/styles.xml']) {
  assert.match(read('mobile/android/app/src/main/res/' + file), /@android:color\/white/);
}
assert.match(splash, /waiting: _introFinished/);
assert.match(splash, /await _introComplete.future/);
assert.doesNotMatch(splash, /_BrandReadyScreen/);
assert.doesNotMatch(splash, /ResponsiveBrandOnboardingScreen|brandOnboardingSeenKey/);
assert.match(splash, /_brandFadeRoute\(const AuthScreen\(\)\)/);
assert.doesNotMatch(pubspec, /assets\/onboarding_/);
for (const f of ['screens/responsive_brand_onboarding_screen.dart', 'widgets/brand_onboarding_page.dart']) {
  assert.ok(!fs.existsSync(path.join(root, 'mobile/lib', f)));
}
console.log('branded splash and shared assets preserved; retired slides removed');
