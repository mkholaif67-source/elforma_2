'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const check = (name, fn) => {
  try {
    fn();
    console.log(`  ✓ ${name}`);
  } catch (error) {
    console.error(`  ✗ ${name}`);
    throw error;
  }
};

console.log('[Form Coach performance contracts]');

check('validation and visual pose use separate adaptive smoothers', () => {
  const source = read('mobile/lib/features/form_coach/domain/form_coach_engine.dart');
  assert(source.includes('final PoseSmoother _visualSmoother'));
  assert(source.includes('FcTuning.visualSmoothMinCutoff'));
  assert(source.includes('_pose = _visualSmoother.smooth(rawPose)'));
});

check('low-confidence joints are removed before geometry and overlay', () => {
  const smoother = read('mobile/lib/features/form_coach/domain/pose_smoother.dart');
  const overlay = read('mobile/lib/features/form_coach/ui/widgets/pose_overlay.dart');
  assert(smoother.includes('_filters.remove(landmark)'));
  assert(!smoother.includes('held ?? raw'));
  assert(overlay.includes('sample.point(landmark, minVisibility: minVisibility)'));
});

check('fast return-to-top can commit only after full ROM and duration gates', () => {
  const cycle = read('mobile/lib/features/form_coach/domain/rep_cycle.dart');
  assert(cycle.includes('if (_zone == _Zone.top && candidate == _Zone.top)'));
  assert(cycle.includes('_returnSinceMs ??= tMs'));
  assert(cycle.includes('(_returnSinceMs ?? tMs) - _cycleStartMs'));
  assert(cycle.includes('_reachedBottom'));
  assert(cycle.includes('amplitude >= spec.minAmplitude'));
  assert(cycle.includes('FcTuning.hardMinRepMs'));
  assert(read('mobile/lib/features/form_coach/domain/fc_tuning.dart').includes('hardMinRepMs = 450'));
});

check('latest-frame processing is bounded and stale results are rejected', () => {
  const source = read('mobile/lib/features/form_coach/runtime/camera_pose_pipeline.dart');
  assert(source.includes('if (_inFlight || _detector.isBusy)'));
  assert(source.includes('int _streamGeneration = 0'));
  assert(source.includes('generation != _streamGeneration'));
  assert(source.includes('!_streaming'));
  const pacing = source.indexOf('now - _lastAcceptedMs < _minIntervalMs');
  const pending = source.indexOf('if (_inFlight || _detector.isBusy)');
  assert(pacing >= 0 && pending > pacing, 'pacing must happen before pending-frame preparation');
});

check('completion stops camera work and hides the overlay', () => {
  const controller = read('mobile/lib/features/form_coach/runtime/form_coach_controller.dart');
  const screen = read('mobile/lib/features/form_coach/ui/form_coach_screen.dart');
  assert(controller.includes('if (snapshot.isFinished)'));
  assert(controller.includes('_pipeline?.pause()'));
  assert(controller.includes('snapshot.isFinished ? null : snapshot') && screen.includes('valueListenable: _controller.poseFrames'));
});

check('framing remains exercise-aware', () => {
  const readiness = read('mobile/lib/features/form_coach/domain/readiness.dart');
  const profiles = read('mobile/lib/features/form_coach/profiles/incline_barbell_press_profile.dart');
  assert(readiness.includes('requiredJoints'));
  assert(readiness.includes('sample.boundsOf(used)'));
  assert(profiles.includes('FcJoint.shoulder'));
  assert(profiles.includes('FcJoint.elbow'));
  assert(profiles.includes('FcJoint.wrist'));
});

check('camera code has no fake digital zoom-out', () => {
  const source = read('mobile/lib/features/form_coach/runtime/camera_pose_pipeline.dart');
  assert(!/setZoomLevel|zoomOut|digital.?zoom/i.test(source));
  assert(source.includes('ResolutionPreset.high'));
  assert(!source.includes('ResolutionPreset.max'));
  assert(source.includes('adaptive pacing'));
});

console.log('7 passed, 0 failed');
