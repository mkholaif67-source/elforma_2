import 'dart:math' as math;
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/form_coach_engine.dart';
import 'package:elforma/features/form_coach/profiles/curl_correction_profile.dart';
import '../tool/form_coach_regression.dart' as fixture;

FormCoachEngine coach() => fixture.engine(curlCorrectionProfile);

void main() {
  test('observable sway is corrected, then verified on two later clean reps', () {
    final engine = coach();
    late FormCoachSnapshot result;
    for (var t = 0; t <= 3000; t += 100) {
      result = engine.onFrame(tMs: t, rawPose: fixture.curl(t, 160, right: true), fps: 15);
    }
    final cues = <String>[];
    for (var rep = 0; rep < 3; rep++) {
      for (var dt = 100; dt <= 4400; dt += 100) {
        final t = 3000 + rep * 4400 + dt;
        final progress = dt <= 2000 ? dt / 2000 : math.max(0.0, (4000 - dt) / 2000);
        final pose = fixture.curl(t, 160 - 115 * progress, right: true);
        final shift = rep == 0 ? .15 * math.min(1.0, progress * 2) : 0.0;
        final points = <FcLandmark, FcPoint>{
          for (final entry in pose.points.entries)
            entry.key: entry.key == FcLandmark.leftHip || entry.key == FcLandmark.rightHip
                ? entry.value : FcPoint(x: entry.value.x + shift, y: entry.value.y,
                    visibility: entry.value.visibility),
        };
        result = engine.onFrame(tMs: t, rawPose: PoseSample(timestampMs: t, points: points), fps: 15);
        if (result.cue != null) cues.add(result.cue!.id);
      }
    }
    expect(result.reps, 3);
    expect(result.incorrect, 1);
    expect(result.valid, 2);
    expect(cues, contains('curl.torso'));
    expect(result.corrections.firstWhere((c) => c.ruleId == 'curl.torso').improved, true);
  });
  test('a bent arm cannot be learned as the neutral curl posture', () {
    final engine = coach();
    late FormCoachSnapshot result;
    for (var t = 0; t < 6000; t += 100) {
      result = engine.onFrame(tMs: t, rawPose: fixture.curl(t, 65, right: true), fps: 15);
    }
    expect(result.isLive, false);
    expect(result.valid, 0);
  });
  test('an unobservable camera view never enables correction', () {
    final engine = coach();
    late FormCoachSnapshot result;
    for (var t = 0; t < 5000; t += 100) {
      result = engine.onFrame(tMs: t, rawPose: fixture.curl(t, 160), fps: 15);
    }
    expect(result.isLive, false);
    expect(result.cue, isNull);
  });
  test('stable side-view neutral pose calibrates; view loss stops judgment', () {
    final engine = coach();
    late FormCoachSnapshot result;
    for (var t = 0; t <= 3000; t += 100) {
      result = engine.onFrame(tMs: t, rawPose: fixture.curl(t, 160, right: true), fps: 15);
    }
    expect(result.isLive, true);
    result = engine.onFrame(tMs: 3100, rawPose: fixture.curl(3100, 120), fps: 15);
    expect(result.verdict, FormVerdict.cannotAssess);
    expect(result.cue, isNull);
  });
}
