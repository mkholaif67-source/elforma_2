'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');

const intro = read('mobile/lib/widgets/brand_intro_scene.dart');
const splash = read('mobile/lib/screens/splash_screen.dart');
const onboarding = read(
  'mobile/lib/widgets/brand_onboarding_page.dart',
);
const assets = read('mobile/lib/widgets/brand_experience_visual.dart');
const pubspec = read('mobile/pubspec.yaml');

assert.match(intro, /Duration\(milliseconds: 5500\)/);
assert.match(splash, /duration: brandIntroDuration/);
assert.doesNotMatch(splash, /_c\.repeat/);

for (const text of [
  'أنت تستحق الأفضل دائمًا',
  'رحلتك تبدأ بخطوة تناسبك',
  'جدول تمرين',
  'خطة تدريب مخصصة تناسب مستواك وهدفك',
  'نظام غذائي',
  'خطة تغذية متوازنة تناسب يومك وهدفك',
  'عادات أفضل.. حياة أفضل',
  'خطوات بسيطة تصنع فرقًا كل يوم',
]) {
  assert.ok(onboarding.includes(text), `missing approved copy: ${text}`);
}

assert.match(assets, /assets\/brand_experience_v5/);
assert.match(pubspec, /assets\/brand_experience_v5\//);
assert.doesNotMatch(`${assets}\n${pubspec}`, /cinematic_v3/);

for (const filename of ['backdrop.webp','logo.png','shaker.png','intro_dumbbell.png','intro_bowl.png','tomato.png','avocado.png','leaf.png','sprout.png','athlete.png','dumbbell.png','bowl.png','stones.png']) {
  assert.ok(fs.existsSync(path.join(root,'mobile/assets/brand_experience_v5',filename)), `missing asset ${filename}`);
}
assert.doesNotMatch(assets, /intro_ingredients/);
assert.match(splash, /await _introComplete.future/);
assert.doesNotMatch(splash, /_BrandReadyScreen/);
console.log('brand experience v5 asset, copy and timing contracts passed');
