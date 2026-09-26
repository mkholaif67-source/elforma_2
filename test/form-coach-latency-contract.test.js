'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const pipeline = read('mobile/lib/features/form_coach/runtime/camera_pose_pipeline.dart');
const tuning = read('mobile/lib/features/form_coach/domain/fc_tuning.dart');
const smoother = read('mobile/lib/features/form_coach/domain/pose_smoother.dart');
// This is a source boundary check, not a behavioral camera test. The actual
// delayed-inference and camera-switch regressions run in Flutter tests in CI.
assert(!pipeline.includes('_latestPending'), 'do not buffer a second stale image');
assert(pipeline.includes('if (_inFlight || _detector.isBusy)'), 'single-flight guard missing');
assert(pipeline.includes('generation != _streamGeneration'), 'stale-result guard missing');
assert(pipeline.includes('identical(controller, _controller)'), 'camera identity guard missing');
assert(pipeline.includes('await _analysis'), 'camera disposed before inference drained');
assert(tuning.includes('smoothMinCutoff = 1.6'), 'low-lag cutoff missing');
assert(tuning.includes('smoothBeta = 0.12'), 'low-lag beta missing');
assert(tuning.includes('smoothDerivativeCutoff = 1.2'), 'low-lag derivative cutoff missing');
assert(smoother.includes('OneEuroFilter'), 'smoothing removed');
console.log('Form Coach single-flight/low-lag source contract passed (behavior verified by Flutter tests)');
