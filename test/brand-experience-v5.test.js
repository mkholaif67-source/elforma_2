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
  'خطة تبدأ منك',
  'هدفك ومستواك وحالتك الصحية، بداية اختيار خطة تناسبك.',
  'اعرف تتمرّن إزاي',
  'جدول يناسب مستواك، وفيديوهات توضّح لك أداء التمارين.',
  'أكل تحبّه ويناسبك',
  'وجبات من أكل تعرفه، بكميات تناسب هدفك ويومك.',
  'شوف تقدّمك خطوة بخطوة',
  'تابع وزنك وحركتك وشرب المياه، وابنِ عاداتك واحدة واحدة.',
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
for (const filename of ['health.webp','sport.webp','nutrition.webp','habits.webp']) {
  assert.ok(fs.existsSync(path.join(root,'mobile/assets/onboarding_v6',filename)));
}
assert.match(pubspec, /assets\/onboarding_v6\//);
assert.match(onboarding, /BoxFit.contain/);
assert.doesNotMatch(onboarding, /BoxFit.fill/);
assert.match(splash, /waiting: _introFinished/);
assert.match(splash, /await _introComplete.future/);
assert.doesNotMatch(splash, /_BrandReadyScreen/);
console.log('preserved intro timing and refreshed onboarding asset/copy contracts passed');
