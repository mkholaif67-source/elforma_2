const assert = require('assert');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const history = fs.readFileSync(path.join(root, 'mobile/lib/screens/workout_history_screen.dart'), 'utf8');
const pubspec = fs.readFileSync(path.join(root, 'mobile/pubspec.yaml'), 'utf8');
const api = fs.readFileSync(path.join(root, 'mobile/lib/api.dart'), 'utf8');

assert.doesNotMatch(history, /models\/engine_contracts\.dart/, 'workout history must not keep an unused engine_contracts import');
assert.doesNotMatch(history, /\b_groupSets\s*\(/, 'removed helper must not return as an unused element');
assert.doesNotMatch(history, /\b_exerciseSets\s*\(/, 'removed widget helper must not return as an unused element');
assert.doesNotMatch(pubspec, /assets\/onboarding_v6\//, 'pubspec must not register a missing onboarding_v6 directory');
assert.match(api, /_commitProfileToBootstrap\(/, 'profile mutations must patch or invalidate bootstrap snapshots');
assert.match(api, /final\s+previousBootstrap\s*=\s*\n?\s*_bootstrapCached/, 'profile mutation must capture the complete snapshot before invalidation');

console.log('Flutter CI warning regressions are guarded');
