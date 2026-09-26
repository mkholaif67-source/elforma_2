import 'dart:math' as math;
import 'package:elforma/features/form_coach/domain/assessment.dart';
import '../../../../tool/form_coach_regression.dart' as fixture;
import 'package:flutter_test/flutter_test.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/pose_quality_gate.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';
import 'package:elforma/features/form_coach/profiles/form_profile_registry.dart';

void main() {
  test('static support arm does not replace the moving right arm in rows', () {
    final e = fixture.engine(FormProfileRegistry.lookup(
        exerciseKey: '', exerciseName: 'One Arm Dumbbell Row')!);
    PoseSample pose(int t, double angle) {
      final original = fixture.curl(t, angle, right: true);
      final swap = <FcLandmark, FcLandmark>{};
      for (final joint in [
        FcJoint.shoulder,
        FcJoint.elbow,
        FcJoint.wrist,
        FcJoint.hip
      ]) {
        final left = fcLandmarkFor(joint, FcSide.left),
            right = fcLandmarkFor(joint, FcSide.right);
        swap[left] = right;
        swap[right] = left;
      }
      return PoseSample(timestampMs: t, points: {
        for (final p in original.points.entries) swap[p.key] ?? p.key: p.value
      });
    }

    late FormCoachSnapshot result;
    for (var t = 0; t <= 3000; t += 100) {
      result = e.onFrame(tMs: t, rawPose: pose(t, 165), fps: 15);
    }
    for (var n = 0; n < 3; n++) {
      for (var dt = 100; dt <= 2600; dt += 100) {
        final progress =
            dt <= 1100 ? dt / 1100 : math.max(0.0, (2200 - dt) / 1100);
        final t = 3000 + n * 2600 + dt;
        result =
            e.onFrame(tMs: t, rawPose: pose(t, 165 - 100 * progress), fps: 15);
      }
    }
    expect(result.activeSide, FcSide.right);
    expect(result.reps, greaterThanOrEqualTo(2));
    expect(result.incorrect, 0);
    expect(result.valid, 0);
  });
  test('machine leg extension can become ready with cropped shoulders', () {
    final e =
        fixture.engine(FormProfileRegistry.byId('leg_extension_machine')!);
    late FormCoachSnapshot result;
    for (var t = 0; t <= 4000; t += 100) {
      result = e.onFrame(
          tMs: t,
          fps: 15,
          rawPose: PoseSample(timestampMs: t, points: const {
            FcLandmark.leftHip: FcPoint(x: .35, y: .4, visibility: .99),
            FcLandmark.leftKnee: FcPoint(x: .55, y: .4, visibility: .99),
            FcLandmark.leftAnkle: FcPoint(x: .55, y: .6, visibility: .99),
          }));
    }
    expect(result.isLive, true);
  });
  for (final entry in {
    'Cable Hip Adduction': 'hip_adduction',
    'Lying Leg Curl Machine': 'leg_curl',
    'Standing Calf Raise (Machine)': 'calf',
    'Lat Pullover Machine': 'pullover',
    'Barbell Shrugs': 'shrug',
    'Rope Face Pull': 'face_pull',
    'Rear Delt Machine Fly': 'reverse_fly',
    'Reverse Cable Crossover': 'reverse_fly',
    'Seated Cable Fly': 'fly',
    'Pec Deck Machine': 'fly',
  }.entries) {
    test('${entry.key} uses its own observable body chain', () {
      final p =
          FormProfileRegistry.lookup(exerciseKey: '', exerciseName: entry.key)!;
      expect(p.id, 'chain.${entry.value}');
      expect(p.canCorrectForm, false);
    });
  }
  test(
      'bilateral distance needs both knees and cannot be changed by arm movement',
      () {
    final p = FormProfileRegistry.byId('chain.hip_adduction')!;
    final eval = MetricEvaluator(p.variants.single.metrics);
    const points = {
      FcLandmark.leftShoulder: FcPoint(x: .3, y: .2, visibility: .99),
      FcLandmark.leftHip: FcPoint(x: .3, y: .5, visibility: .99),
      FcLandmark.leftKnee: FcPoint(x: .3, y: .7, visibility: .99),
      FcLandmark.rightKnee: FcPoint(x: .7, y: .7, visibility: .99),
    };
    final first =
        eval.evaluate(const PoseSample(timestampMs: 0, points: points));
    expect(first['motion']!.value, closeTo(4 / 3, .001));
    final moved = eval.evaluate(PoseSample(timestampMs: 100, points: {
      ...points,
      FcLandmark.leftWrist: const FcPoint(x: .9, y: .1, visibility: .99)
    }));
    expect(moved['motion']!.value, first['motion']!.value);
    final hidden = {...points}..remove(FcLandmark.rightKnee);
    expect(
        eval.evaluate(PoseSample(timestampMs: 200, points: hidden))['motion'],
        isNull);
  });
  test('lower-body-only gate preserves visible toe without inventing a heel',
      () {
    final lower = PoseQualityGate(allowLowerBodyAnchor: true);
    final upper = PoseQualityGate();
    const points = {
      FcLandmark.leftHip: FcPoint(x: .4, y: .3, visibility: .99),
      FcLandmark.leftKnee: FcPoint(x: .4, y: .5, visibility: .99),
      FcLandmark.leftAnkle: FcPoint(x: .4, y: .7, visibility: .99),
      FcLandmark.leftFootIndex: FcPoint(x: .48, y: .7, visibility: .99),
    };
    for (var t = 0; t <= 300; t += 100) {
      final pose = PoseSample(timestampMs: t, points: points);
      final result = lower.filter(pose);
      if (t >= 200) {
        expect(result.points.containsKey(FcLandmark.leftFootIndex), true);
        expect(result.points.containsKey(FcLandmark.leftHeel), false);
      }
      expect(upper.filter(pose).points, isEmpty);
    }
  });
  for (final p in FormProfileRegistry.profiles) {
    for (final v in p.variants) {
      final spec = v.repCycle;
      if (spec == null) continue;
      test('${v.id}: unobserved endpoint and repeated timestamps never count',
          () {
        final c = RepCounter(spec);
        for (var t = 0; t <= 800; t += 100) {
          c.update(tMs: t, driver: spec.topValue, usable: true);
        }
        for (var t = 900; t <= 1500; t += 100) {
          c.update(
              tMs: t,
              driver: spec.topValue + (spec.bottomValue - spec.topValue) * .4,
              usable: true);
        }
        c.update(tMs: 1600, driver: null, usable: false);
        for (var t = 1700; t <= 2200; t += 100) {
          c.update(tMs: t, driver: spec.topValue, usable: true);
          c.update(tMs: t, driver: spec.topValue, usable: true);
        }
        expect(c.reps, 0);
      });
      test('${v.id}: normalized or angular driver counts one full cycle', () {
        final c = RepCounter(spec);
        for (var t = 0; t <= 2800; t += 50) {
          final f = t <= 1100 ? t / 1100 : math.max(0.0, (2200 - t) / 1100);
          c.update(
              tMs: t,
              driver: spec.topValue + (spec.bottomValue - spec.topValue) * f,
              usable: true);
        }
        expect(c.reps, 1);
      });
    }
  }
}
