'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const fallback = read('mobile/lib/features/form_coach/profiles/fallback_form_engine.dart');
const request = read('mobile/lib/features/form_coach/integration/form_coach_request.dart');
const ui = read('mobile/lib/features/form_coach/ui/form_coach_entry_card.dart');

for (const family of ['press', 'fly', 'pull', 'row', 'curl', 'extension', 'hinge', 'squat', 'lunge', 'raise']) {
  assert.ok(fallback.includes(`FallbackMovementFamily.${family}`), `missing ${family} family`);
}
for (const mechanic of ['bodyRegion', 'jointActions', 'plane', 'position', 'equipment', 'unilateral', 'cameraView', 'confidence']) {
  assert.ok(new RegExp(`\\b${mechanic}\\b`).test(fallback), `missing ${mechanic} mechanic`);
}
assert.ok(fallback.includes('secondaryEvidence'), 'fallback accepts a family without secondary evidence');
assert.ok(fallback.includes('FallbackMode.cannotAssess'), 'fallback has no safe refusal mode');
assert.ok(fallback.includes('rules: const <FormRule>[]'), 'fallback invented form rules');
assert.ok(!fallback.includes('http://') && !fallback.includes('https://'), 'fallback has network dependency');
assert.ok(fallback.includes('trackingOnly'), 'fallback is not limited to tracking');

const verifiedPosition = request.indexOf('final FormProfile? verifiedProfile');
const fallbackPosition = request.indexOf('FormFallbackEngine.resolve');
assert.ok(verifiedPosition >= 0 && fallbackPosition > verifiedPosition, 'fallback does not run after verified lookup');
assert.ok(request.includes('if (!fallback.isUsable || fallback.profile == null) return null'), 'insufficient fallback is not refused');
assert.ok(request.includes('resolutionKind: resolutionKind'), 'resolution provenance is not preserved');
assert.ok(ui.includes('متابعة احتياطية للعدات والمدى فقط'), 'fallback UX over-promises coaching');
console.log('Form Coach fallback safety/provenance contract: all assertions passed');
