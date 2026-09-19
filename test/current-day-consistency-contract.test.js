const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const api = read('mobile/lib/api.dart');
const workout = read('mobile/lib/screens/workout_screen.dart');
const home = read('mobile/lib/screens/home_screen.dart');
const entry = read('mobile/lib/features/form_coach/ui/form_coach_entry_card.dart');
const session = read('mobile/lib/screens/training_session_screen.dart');
const assert = (condition, message) => { if (!condition) throw new Error(message); };

assert(api.includes('_bootstrapCached = _copyResult(persisted);'), 'persisted bootstrap is not memoized');
assert(api.includes('return _copyResult(persisted);'), 'persisted bootstrap is not copied');
assert(workout.includes('Api.I.bootstrapRevision.addListener(_onBootstrapFresh);'), 'Workout fresh listener missing');
assert(workout.includes('Api.I.bootstrapRevision.removeListener(_onBootstrapFresh);'), 'Workout fresh listener cleanup missing');
assert(workout.includes('void _onBootstrapFresh()'), 'Workout fresh handler missing');
assert(workout.includes("_hydrateActivePlan(r.data, bootstrap.data['workoutPlan']);"), 'Workout does not overlay the active Home snapshot');
assert(workout.includes('if (!storedNeedsRepair || storedFallback == null)'), 'Workout can replace the active snapshot with an unscheduled repair result');
assert(home.includes("case 'upper_lower':") && home.includes("return 'Upper / Lower';"), 'Upper/Lower label mapping missing');
assert(home.includes("'$exercises تمارين جاهزة ليك'"), 'exercise plural copy missing');
assert(home.includes('_displayName(name)'), 'display name normalization missing');
assert(session.indexOf('FormCoachEntryCard(exercise: exercise') < session.indexOf('_coachCard(exercise)'), 'Form Coach card remains below Smart Coach');
assert(!entry.includes('تتبع العدات ومدى الحركة فقط'), 'implementation copy leaked into Form Coach UI');
assert(!entry.includes('مفيش تسجيل ولا رفع فيديو'), 'recording copy leaked into Form Coach UI');
for (const [name, content] of Object.entries({api, workout, home, entry, session})) {
  assert(!content.includes('\ufffd'), `${name} has a replacement character`);
}
console.log('current-day consistency and Form Coach UX contract: all assertions passed');
