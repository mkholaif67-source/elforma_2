import 'package:flutter_test/flutter_test.dart';
import 'package:elforma/features/form_coach/domain/correction_history.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';
import 'package:elforma/features/form_coach/runtime/analysis_pacing.dart';
import 'package:elforma/features/form_coach/profiles/fallback_form_engine.dart';

const rule = FormRule(id: 'swing', metricId: 'tilt', max: 15,
  cueAr: 'ثبّت جسمك', persistenceMs: 300);
MetricReading reading(double value) => MetricReading(value: value, confidence: .95);
FormRuleState state({bool error = false}) => FormRuleState(ruleId: 'swing',
  evaluable: true, value: error ? 30 : 5, confidence: .95,
  magnitude: error ? 15 : 0, violationMs: error ? 400 : 0,
  consistency: 1, candidate: error, fired: false, firesThisSet: 0, blockedReason: '');

RepQualityResult cycle(CorrectionHistory history, {bool error = false, bool gap = false}) {
  for (var t = 0; t <= 800; t += 100) {
    history.observe(t, t < 400 ? RepPhase.towardBottom : RepPhase.towardTop,
      [state(error: error)], usable: !(gap && t == 400));
  }
  return history.finish([rule], assessable: true);
}

void main() {
  test('single-frame spike, NaN and sparse frames cannot become sustained errors', () {
    final tracker = FormRuleTracker(rule);
    expect(tracker.update(tMs: 0, reading: reading(30), phase: RepPhase.towardBottom,
      poseUsable: true).candidate, false);
    expect(tracker.update(tMs: 100, reading: reading(double.nan), phase: RepPhase.towardBottom,
      poseUsable: true).evaluable, false);
    expect(tracker.update(tMs: 600, reading: reading(30), phase: RepPhase.towardBottom,
      poseUsable: true).candidate, false);
  });
  test('observation does not consume speech budget; only selected cue commits', () {
    final trackers = [FormRuleTracker(rule), FormRuleTracker(rule)];
    for (var t = 0; t <= 400; t += 100) {
      for (final tracker in trackers) {
        tracker.update(tMs: t, reading: reading(30), phase: RepPhase.towardBottom,
          poseUsable: true, allowFire: false);
      }
    }
    expect(trackers.map((t) => t.fires), [0, 0]);
    expect(trackers.first.commitFire(400), true);
    expect(trackers.map((t) => t.fires), [1, 0]);
    expect(trackers.first.commitFire(500), false);
  });
  test('timestamp reversal cannot add violation evidence', () {
    final tracker = FormRuleTracker(rule);
    tracker.update(tMs: 200, reading: reading(30), phase: RepPhase.bottom, poseUsable: true);
    expect(tracker.update(tMs: 100, reading: reading(30), phase: RepPhase.bottom,
      poseUsable: true).blockedReason, 'timestamp');
  });
  test('two subsequent observable clean reps verify improvement once', () {
    final h = CorrectionHistory();
    expect(cycle(h, error: true).quality, RepQuality.supportedError);
    expect(cycle(h).improved, isEmpty);
    expect(cycle(h).improved, {'swing'});
    expect(cycle(h).improved, isEmpty);
    expect(h.summary([rule]).single.errorReps, 1);
    expect(h.summary([rule]).single.improved, true);
  });
  test('occlusion interrupts improvement; silence cannot prove correctness', () {
    final h = CorrectionHistory();
    cycle(h, error: true); cycle(h);
    expect(cycle(h, gap: true).quality, RepQuality.cannotAssess);
    expect(cycle(h).improved, isEmpty);
    expect(cycle(h).improved, {'swing'});
  });
  test('no rules means tracking only and interruption never confirms improvement', () {
    final h = CorrectionHistory();
    expect(h.finish([], assessable: true).quality, RepQuality.trackingOnly);
    cycle(h, error: true); cycle(h); h.interrupt();
    expect(cycle(h).improved, isEmpty);
  });
  test('only observing one movement phase does not certify a repetition', () {
    final h = CorrectionHistory();
    for (var t = 0; t < 1000; t += 100) {
      h.observe(t, RepPhase.towardBottom, [state()], usable: true);
    }
    expect(h.finish([rule], assessable: true).quality, RepQuality.cannotAssess);
  });
  test('pacing backs off sustained load, has hysteresis and bounded metrics', () {
    final p = AnalysisPacing();
    final initial = p.intervalMs;
    p.observe(150);
    expect(p.intervalMs, initial);
    for (var i = 0; i < 200; i++) { p.observe(150); }
    expect(p.intervalMs, greaterThan(initial));
    expect(p.intervalMs, lessThanOrEqualTo(200));
    final busy = p.intervalMs;
    p.observe(10); expect(p.intervalMs, busy);
    for (var i = 0; i < 1000; i++) { p.observe(10); }
    expect(p.intervalMs, initial);
    expect(p.p95Ms, 10);
    expect(AnalysisPacing(requestedFps: 10).intervalMs, 100);
    expect(AnalysisPacing(requestedFps: -1).intervalMs, initial);
  });
  test('ambiguous contact poses never gain fallback form authority', () {
    for (final name in ['Chest supported dumbbell row', 'Barbell bench press',
      'Single leg machine curl', 'Cable triceps extension', 'Seated machine row',
      'Single leg squat', 'Bench dip']) {
      final resolution = FormFallbackEngine.resolve(exerciseKey: name,
        exerciseName: name, muscle: '');
      expect(resolution.profile?.canCorrectForm ?? false, false, reason: name);
    }
  });
}
