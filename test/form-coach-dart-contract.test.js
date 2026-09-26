'use strict';
const assert = require('assert');
const fs = require('fs');
const read = (file) => fs.readFileSync(file, 'utf8');
const profileDir = 'mobile/lib/features/form_coach/profiles';
for (const file of ['biceps_curl_profile.dart', 'bodyweight_squat_profile.dart', 'lateral_raise_profile.dart']) {
  const source = read(`${profileDir}/${file}`);
  assert(source.includes("domain/form_rule.dart"), `${file} must import FormRule for its typed empty rules list`);
  assert(source.includes('rules: const <FormRule>[]'), `${file} must keep rules explicitly empty`);
}
const registry = read(`${profileDir}/form_profile_registry.dart`);
assert(registry.includes('static final List<FormProfile> profiles'), 'registry cannot const-spread a runtime catalog');
assert(registry.includes('List<FormProfile>.unmodifiable'), 'registry profiles must be immutable to consumers');
const debug = read('mobile/lib/features/form_coach/ui/widgets/debug_panel.dart');
assert(debug.includes('snapshot.readiness ?? ReadinessReport.unknownReport'), 'debug panel must handle nullable readiness');
assert(debug.includes('final Map<String, MetricReading> metrics = snapshot.metrics'), 'debug panel must use snapshot metric map');
assert(debug.includes('metrics=${metrics.length}'), 'debug panel must not read scale from a metric map');
assert(debug.includes('state.blockedReason.isEmpty'), 'blockedReason is non-nullable');
assert(!debug.includes('snapshot.readiness.ok'), 'debug panel must not dereference nullable readiness');
assert(!debug.includes('MetricSet metrics = snapshot.metrics'), 'debug panel must not assign map to MetricSet');
console.log('Form Coach Dart source contract: all compile-fix guards passed (Flutter SDK analyze still required)');
