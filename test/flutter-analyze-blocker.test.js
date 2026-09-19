'use strict';
const assert=require('assert');
const fs=require('fs');
const engine=fs.readFileSync('mobile/lib/models/engine_contracts.dart','utf8');
const err=fs.readFileSync('mobile/lib/widgets/error_view.dart','utf8');
const pub=fs.readFileSync('mobile/pubspec.yaml','utf8');
const api=fs.readFileSync('mobile/lib/api.dart','utf8');
assert(!engine.includes('static String _videoId('),'unused _videoId must not return');
assert(err.includes("import 'package:elforma/theme.dart';"),'lib imports must use package URI');
const release = pub.match(/version:\s*([0-9.]+)\+(\d+)/);
assert(release && release[1] === require('../package.json').version,'pubspec version drift');
assert(api.includes("kAppVersionName = '"+release[1]+"'")&&api.includes('kAppBuild = '+release[2]),'api version drift');
// Source regressions for the warnings reported by the user's real Flutter CI.
const setup=fs.readFileSync('mobile/lib/screens/profile_setup_screen.dart','utf8');
const workout=fs.readFileSync('mobile/lib/screens/workout_screen.dart','utf8');
assert(!api.includes('if (retryStale) return _send(') && (api.match(/if \(retryStale\) return await _send\(/g)||[]).length===2,'retry must await the request in both branches');
assert(!setup.includes('_fastingLabels'),'unused summary-only field must remain removed');
assert(workout.includes('PlanStore.I.markChanged();\n      await _boot();'),'plan switching must await reload');
console.log('flutter analyze blocker source checks: 7 passed, 0 failed (not a Flutter analyze run)');
