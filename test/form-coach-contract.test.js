// Source-level contract for the merged Form Coach checkpoints.
const assert = require('assert');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const mobile = path.join(root, 'mobile');
const feature = path.join(mobile, 'lib/features/form_coach');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const readFeature = (p) => fs.readFileSync(path.join(feature, p), 'utf8');

const required = [
  'domain/assessment.dart',
  'domain/form_coach_engine.dart',
  'domain/form_profile.dart',
  'domain/form_rule.dart',
  'domain/readiness.dart',
  'domain/rep_cycle.dart',
  'runtime/camera_pose_pipeline.dart',
  'runtime/pose_detection_service.dart',
  'runtime/form_coach_controller.dart',
  'ui/form_coach_screen.dart',
  'ui/form_coach_entry_card.dart',
  'profiles/form_profile_registry.dart',
  'profiles/incline_barbell_press_profile.dart',
];
for (const file of required) assert.ok(fs.existsSync(path.join(feature, file)), `missing ${file}`);

const pubspec = read('mobile/pubspec.yaml');
for (const dependency of ['camera:', 'google_mlkit_commons:', 'google_mlkit_pose_detection:', 'flutter_tts:']) {
  assert.ok(pubspec.includes(`  ${dependency}`), `missing ${dependency}`);
}
assert.ok(read('mobile/android/app/src/main/AndroidManifest.xml').includes('android.permission.CAMERA'));
const session = read('mobile/lib/screens/training_session_screen.dart');
assert.ok(session.includes("features/form_coach/ui/form_coach_entry_card.dart"));
assert.ok(session.includes('FormCoachEntryCard'));
const registry = readFeature('profiles/form_profile_registry.dart');
assert.ok(registry.includes('inclineBarbellPressProfile'));
const incline = readFeature('profiles/incline_barbell_press_profile.dart');
assert.ok(incline.includes('FormSupportLevel.trackingOnly'));
assert.ok(incline.includes('notDetectableAr'));
const runtime = required.filter((f) => f.startsWith('runtime/')).map(readFeature).join('\n');
assert.ok(!/http\.|http:|database|upload/i.test(runtime), 'camera path must stay on-device');
assert.ok(runtime.includes('isBusy') && runtime.includes('_inFlight'), 'backpressure contract missing');
console.log('merged Form Coach contract: all assertions passed');
