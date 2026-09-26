'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const cycle = read('mobile/lib/features/form_coach/domain/rep_cycle.dart');
const pipeline = read('mobile/lib/features/form_coach/runtime/camera_pose_pipeline.dart');
const controller = read('mobile/lib/features/form_coach/runtime/form_coach_controller.dart');
const screen = read('mobile/lib/features/form_coach/ui/form_coach_screen.dart');
const engine = read('mobile/lib/features/form_coach/domain/form_coach_engine.dart');

const checks = [
  ['the first trusted sample anchors a new rep cycle', () => {
    assert(cycle.includes('final bool firstTrustedSample = _previousDriver == null;'));
    assert(cycle.includes('_zone = candidate;'));
    assert(cycle.includes('_pendingZone = candidate;'));
    assert(cycle.includes('_returnSinceMs ??= tMs'));
    assert(cycle.includes('(_returnSinceMs ?? tMs) - _cycleStartMs'));
  }],
  ['full reps require ROM, bottom crossing and duration', () => {
    assert(cycle.includes('_reachedBottom'));
    assert(cycle.includes('amplitude >= spec.minAmplitude'));
    assert(cycle.includes('FcTuning.hardMinRepMs'));
    assert(/_zone == _Zone.top\s*&&\s*candidate == _Zone.top/.test(cycle));
    assert(cycle.includes('tMs - _returnSinceMs! >= spec.minPhaseMs'));
    assert(cycle.includes('(_returnSinceMs ?? tMs) - _cycleStartMs'));
  }],
  ['partial and confidence-loss paths stay separate from valid reps', () => {
    assert(cycle.includes('RepEventKind.partialRep'));
    assert(cycle.includes('RepEventKind.cycleAborted'));
    assert(cycle.includes('_gapInCycle'));
    assert(cycle.includes('abortCycle()'));
  }],
  ['camera inference is single flight without a stale frame queue', () => {
    assert(!pipeline.includes('_latestPending'));
    assert(pipeline.includes('if (_inFlight || _detector.isBusy)'));
    assert(pipeline.includes('_analysis = _analyse'));
    assert(pipeline.includes('await _analysis'));
  }],
  ['pause and resume invalidate stale results', () => {
    assert(pipeline.includes('_streamGeneration++'));
    assert(pipeline.includes('generation != _streamGeneration'));
    assert(pipeline.includes('!_streaming'));
    const pause = pipeline.indexOf('Future<void> pause()');
    const generation = pipeline.indexOf('stopAcceptingFrames();', pause);
    const drain = pipeline.indexOf('await _analysis', pause);
    assert(pause >= 0 && generation > pause && drain > generation);
  }],
  ['camera switch preserves lifecycle and quality tier', () => {
    const switchStart = pipeline.indexOf('Future<void> switchCamera()');
    const switchEnd = pipeline.indexOf('/// Recording uses', switchStart);
    const section = pipeline.slice(switchStart, switchEnd);
    assert(section.includes('await pause()'));
    assert(section.includes('await previous?.dispose()'));
    assert(section.includes('ResolutionPreset.high'));
    assert(section.includes('await _detector.resetTracking()'));
    assert(section.includes('if (resumeAfter) await resume()'));
  }],
  ['set completion stops work and a new set resets engine state', () => {
    assert(controller.includes('if (snapshot.isFinished)'));
    assert(controller.includes('_finishRecordingAndPause'));
    assert(controller.includes('await _pipeline?.pause()'));
    assert(controller.includes('_engine.reset()'));
    assert(controller.includes('await pipeline.start()'));
  }],
  ['UI counter and overlay use the immutable snapshot independently', () => {
    assert(screen.includes("'${snapshot.reps}'"));
    assert(screen.includes('sample: snapshot.pose'));
    assert(controller.includes('snapshot.isFinished ? null : snapshot') && screen.includes('valueListenable: _controller.poseFrames'));
    assert(engine.includes('_pose = _visualSmoother.smooth(rawPose)'));
  }],
];

for (const [name, check] of checks) {
  check();
  console.log(`  ✓ ${name}`);
}
console.log(`Form Coach Phase 1 contracts: ${checks.length} passed`);
