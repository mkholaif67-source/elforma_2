import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/pose_quality_gate.dart';
import 'package:elforma/features/form_coach/domain/pose_smoother.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/form_coach_engine.dart';
import 'package:elforma/features/form_coach/profiles/catalog_form_profiles.dart';
import 'package:elforma/features/form_coach/runtime/camera_image_conversion.dart';

FcPoint p(double x, double y, [double visibility = .95]) => FcPoint(x:x,y:y,visibility:visibility);
PoseSample body(int t, {double angle = 0, double confidence = .95}) => PoseSample(timestampMs:t, points: {
  FcLandmark.nose:p(.35,.18), FcLandmark.leftShoulder:p(.4,.3),
  FcLandmark.leftHip:p(.4,.65), FcLandmark.leftElbow:p(.4,.47),
  FcLandmark.leftWrist:p(.4+.17*math.sin(angle), .47+.17*math.cos(angle), confidence),
  FcLandmark.leftKnee:p(.4,.82), FcLandmark.leftAnkle:p(.4,.97),
});

void main() {
  test('acquire a body, remove an occluded joint immediately, reacquire after exit', () {
    final gate = PoseQualityGate();
    expect(gate.filter(body(0)).isEmpty, true);
    expect(gate.filter(body(100)).isEmpty, true);
    expect(gate.filter(body(200)).isNotEmpty, true);
    expect(gate.filter(body(300, confidence:.1)).point(FcLandmark.leftWrist), isNull);
    expect(gate.filter(PoseSample.empty(400)).isEmpty, true);
    expect(gate.filter(body(500)).isEmpty, true);
    expect(gate.filter(body(700)).isNotEmpty, true);
  });
  test('background, nonfinite joints and an impossible limb cannot pass', () {
    final gate = PoseQualityGate();
    for(var t=0;t<1500;t+=100) {
      expect(gate.filter(PoseSample(timestampMs:t, points:{
        for(final k in FcLandmark.values) k:p(.5,.5,.9),
      })).isEmpty, true);
    }
    gate.filter(body(1600)); gate.filter(body(1800));
    final points = Map<FcLandmark,FcPoint>.of(body(1900).points);
    points[FcLandmark.leftWrist] = p(.99,.01);
    points[FcLandmark.rightWrist] = p(double.nan, .2);
    final filtered = gate.filter(PoseSample(timestampMs:1900,points:points));
    expect(filtered.point(FcLandmark.leftWrist), isNull);
    expect(filtered.point(FcLandmark.rightWrist), isNull);
  });
  test('slow, natural and fast anatomically valid movement stays responsive', () {
    for (final speed in [.5, 2.0, 5.0]) {
      final gate = PoseQualityGate(); final smoother = PoseSmoother();
      for (var t=0;t<2000;t+=67) {
        final raw=body(t,angle:math.sin(t/1000*speed));
        final accepted=gate.filter(raw);
        if(t<201) continue;
        expect(accepted.point(FcLandmark.leftWrist), isNotNull);
        final actual=smoother.smooth(accepted).point(FcLandmark.leftWrist)!;
        expect((actual.x-raw.points[FcLandmark.leftWrist]!.x).abs(), lessThan(.08));
      }
    }
  });
  test('smoothing never promotes low raw confidence or holds ghost joints', () {
    final s=PoseSmoother();
    s.smooth(body(0));
    expect(s.smooth(body(67,confidence:.1)).point(FcLandmark.leftWrist), isNull);
    expect(s.smooth(PoseSample.empty(134)).isEmpty,true);
  });
  test('metric angles use image aspect, not stretched normalized coordinates', () {
    final evaluator=MetricEvaluator([const MetricSpec(id:'a',kind:MetricKind.jointAngle,
      joints:[FcJoint.shoulder,FcJoint.elbow,FcJoint.wrist])]);
    final sample=PoseSample(timestampMs:0,imageAspect:.5,points:{
      FcLandmark.leftShoulder:p(.2,.4),FcLandmark.leftElbow:p(.4,.4),FcLandmark.leftWrist:p(.6,.5)});
    expect(evaluator.evaluate(sample)['a']!.value,closeTo(135,.001));
    expect(evaluator.evaluate(sample,activeSide:FcSide.right)['a'],isNull);
  });
  test('side-view overlay contains only required visible chain and clears on loss/switch', () {
    final engine=FormCoachEngine(profile:catalogFormProfiles.first,
      session:const FormCoachSession(exerciseKey:'bench',exerciseName:'Bench'));
    for(var t=0;t<3000;t+=100) { engine.onFrame(tMs:t,rawPose:body(t),fps:15); }
    final visible=engine.onFrame(tMs:3000,rawPose:body(3000),fps:15);
    expect(visible.pose!.points.keys.toSet(), {FcLandmark.leftShoulder,FcLandmark.leftElbow,FcLandmark.leftWrist});
    final lost=engine.onFrame(tMs:3100,rawPose:PoseSample.empty(3100),fps:15);
    expect(lost.pose,isNull); expect(lost.reps,0);
    engine.onInterrupted(3200);
    expect(engine.onFrame(tMs:3300,rawPose:body(3300)).pose,isNull);
  });
  test('YUV row and pixel padding produces packed NV21 VU order', () {
    final bytes=packNv21(width:4,height:2,
      planes:[Uint8List.fromList([1,2,3,4,99,99,5,6,7,8,99,99]),
        Uint8List.fromList([10,99,11,99]), Uint8List.fromList([20,99,21,99])],
      rowStrides:[6,4,4],pixelStrides:[1,2,2]);
    expect(bytes,[1,2,3,4,5,6,7,8,20,10,21,11]);
  });
  test('front and back rotation compensation covers every device orientation', () {
    expect([0,90,180,270].map((d)=>compensatedRotation(90,d,false)),[90,0,270,180]);
    expect([0,90,180,270].map((d)=>compensatedRotation(270,d,true)),[270,0,90,180]);
  });
}
