'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

const social = read('mobile/lib/widgets/social_bar.dart');
assert(!social.includes('return GestureDetector('), 'SocialBar must use a keyboard-focusable Material control');
for (const label of ['فيسبوك', 'إنستجرام', 'تيك توك', 'إكس']) {
  assert(social.includes(`'${label}'`), `SocialBar accessible label missing: ${label}`);
}
assert(social.includes("label: 'فتح ${s.label}'"), 'SocialBar must expose a functional semantics label');
assert(social.includes('child: InkWell('), 'SocialBar must retain Material pressed/focus behavior');
assert(social.includes('child: ExcludeSemantics('), 'Decorative social SVG must not duplicate its parent label');

const auth = read('mobile/lib/screens/auth_screen.dart');
const passwordBlock = auth.slice(
  auth.indexOf('if (passwordProblem != null)'),
  auth.indexOf('if (_showConfirmation)'),
);
assert(passwordBlock.length > 0, 'Password validation block missing');
assert(!passwordBlock.includes('TextOverflow.ellipsis'), 'Important password error must never be ellipsized');
assert(passwordBlock.includes('maxLines: 2'), 'Password error must have room to wrap');
assert(auth.includes("message: 'الرجوع إلى تسجيل الدخول'"), 'Auth back target needs a visible tooltip');
assert(auth.includes('child: InkWell('), 'Auth back target needs keyboard/focus behavior');

const pantry = read('mobile/lib/screens/pantry_screen.dart');
const categoryPills = pantry.slice(
  pantry.indexOf('Widget _categoryPills()'),
  pantry.indexOf('Widget _list()'),
);
const pantryList = pantry.slice(
  pantry.indexOf('Widget _list()'),
  pantry.indexOf('Widget _saveBar('),
);
assert(!categoryPills.includes('GestureDetector('), 'Pantry categories must be keyboard focusable');
assert(!pantryList.includes('GestureDetector('), 'Pantry food rows must be keyboard focusable');
assert(categoryPills.includes('selected: active'), 'Pantry categories must expose selected state');
assert(pantryList.includes('selected: active'), 'Pantry food rows must expose selected state');
assert(pantry.includes('child: InkWell('), 'Pantry choices need visible Material interaction feedback');

const support = read('mobile/lib/screens/support_screen.dart');
const socialChip = support.slice(
  support.indexOf('Widget _socialChip('),
  support.indexOf('@override\n  Widget build('),
);
assert(!socialChip.includes('GestureDetector('), 'Support links must be keyboard focusable');
assert(socialChip.includes("label: 'فتح $label'"), 'Support links need functional labels');
assert(socialChip.includes('child: InkWell('), 'Support links need Material interaction feedback');

const helperUnits = read('mobile/lib/screens/helper_units_screen.dart');
const videoTarget = helperUnits.slice(
  helperUnits.indexOf("label: exercise.videoId.isEmpty"),
  helperUnits.indexOf('_reportLine(exercise)'),
);
assert(videoTarget.includes('child: InkWell('), 'Exercise video target must be keyboard focusable');
assert(videoTarget.includes('? null'), 'Missing exercise videos must not remain tappable');

const errorView = read('mobile/lib/widgets/error_view.dart');
assert(errorView.includes('color: AppColors.textSoft'), 'Error help copy must use an AA body color');
assert(errorView.includes('fontSize: 13'), 'Error help copy must stay at a readable UI size');
assert(!errorView.includes('color: Color(0xFF789083)'), 'Low-contrast error help color must not return');

const app = read('mobile/lib/main.dart');
assert(!app.includes('maxScaleFactor:'), 'App must not cap the system text scale');
assert(!app.includes('textScaler.clamp('), 'App must preserve the user text-size preference');
assert(auth.includes('Widget _buildReflowAuth('), 'Auth needs a normal-flow layout for narrow or large-text screens');
assert(auth.includes('constraints.maxWidth < 360 || textScale > 1.3'), 'Auth reflow breakpoint must cover narrow and large-text layouts');
assert(auth.includes('Widget _inlineErrorBanner()'), 'Auth reflow errors must remain fully readable');

for (const file of [
  'mobile/lib/screens/pricing_screen.dart',
  'mobile/lib/screens/workout_screen.dart',
  'mobile/lib/screens/home_screen.dart',
  'mobile/lib/widgets/announcement_card.dart',
]) {
  const source = read(file);
  assert(!source.includes('GestureDetector('), `${file} user actions must use Material controls`);
}

const offline = read('mobile/lib/widgets/offline_banner.dart');
assert(offline.includes('MediaQuery.disableAnimationsOf(context)'), 'Offline status motion must respect reduced motion');
assert(offline.includes('fontSize: 13'), 'Offline status must remain readable');
const cueBanner = read('mobile/lib/features/form_coach/ui/widgets/cue_banner.dart');
assert(cueBanner.includes('MediaQuery.disableAnimationsOf(context)'), 'Form cues must respect reduced motion');

const authErrorBlock = auth.slice(
  auth.indexOf('Positioned _errorBanner('),
  auth.indexOf('class _AuthHeroWaveClipper'),
);
assert(!authErrorBlock.includes('TextOverflow.ellipsis'), 'Auth server errors must remain fully readable');
assert(authErrorBlock.includes('height: 48'), 'Auth server errors need sufficient vertical room');

for (const file of [
  'mobile/lib/screens/analysis_screen.dart',
  'mobile/lib/screens/meal_plan_screen.dart',
  'mobile/lib/screens/splash_screen.dart',
  'mobile/lib/screens/workout_screen.dart',
]) {
  const source = read(file);
  assert(source.includes('MediaQuery.disableAnimationsOf(context)'), `${file} must respect reduced motion`);
}

console.log('UI accessibility source contract passed');
