// Dependency-free behavioral regressions against the production Dart engine.
// After flutter pub get: dart --packages=.dart_tool/package_config.json tool/form_coach_regression.dart
import 'dart:math' as math;
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_coach_engine.dart';
import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/profiles/form_profile_registry.dart';
import 'package:elforma/features/form_coach/profiles/biceps_curl_profile.dart';
import 'package:elforma/features/form_coach/profiles/fallback_form_engine.dart';

void check(bool condition, String message) { if (!condition) throw StateError(message); }
RepCounter counter() => RepCounter(const RepCycleSpec(driverMetricId:'angle',
    topValue:160,bottomValue:100,enterMargin:5,minAmplitude:40,partialAmplitude:20));
List<RepEvent> feed(RepCounter c,List<(int,double?)> points) => [
  for(final p in points) ...c.update(tMs:p.$1,driver:p.$2,usable:p.$2!=null),
];
PoseSample curl(int t,double degrees,{double visibility=.98,bool right=false,double scale=1,double aspect=1}) {
  final angle=(180-degrees)*math.pi/180;
  FcPoint point(double x,double y,[double v=.98]) => FcPoint(
    x:.5+(x-.5)*scale/aspect,y:.5+(y-.5)*scale,visibility:v);
  return PoseSample(timestampMs:t,imageAspect:aspect,points:{
    FcLandmark.nose:point(.45,.16),
    FcLandmark.leftShoulder:point(.45,.30),FcLandmark.leftHip:point(.45,.63),
    FcLandmark.leftElbow:point(.45,.46),
    FcLandmark.leftWrist:point(.45+.14*math.sin(angle),.46+.14*math.cos(angle),visibility),
    if(right)...{
      FcLandmark.rightShoulder:point(.55,.30),FcLandmark.rightHip:point(.55,.63),
      FcLandmark.rightElbow:point(.55,.46),FcLandmark.rightWrist:point(.55,.60),
    },
  });
}
FormCoachEngine engine([FormProfile profile=bicepsCurlProfile])=>FormCoachEngine(profile:profile,
  session:const FormCoachSession(exerciseKey:'test',exerciseName:'test',openEnded:true));
FormCoachSnapshot warm(FormCoachEngine e) {
  late FormCoachSnapshot s;
  for(var t=0;t<=3000;t+=100) {s=e.onFrame(tMs:t,rawPose:curl(t,160),fps:15);}
  check(s.isLive,'fixture not live: ${s.stage} ${s.statusTextAr}');return s;
}
FormCoachSnapshot move(FormCoachEngine e,int start,{bool loss=false,double end=45}) {
  late FormCoachSnapshot s;
  for(var dt=100;dt<=2200;dt+=100) {
    final f=dt<=1000 ? dt/1000 : math.max(0.0,(2000-dt)/1000);
    s=e.onFrame(tMs:start+dt,rawPose:curl(start+dt,160-(160-end)*f,
      visibility:loss&&dt==1000 ? .1 : .98),fps:15);
  }
  return s;
}
void main() {
  var passed=0;final failures=<String>[];
  void test(String name,void Function() body) {
    try {body();passed++;print('PASS $name');}
    catch(e) {failures.add('$name: $e');print('FAIL $name: $e');}
  }
  test('brief loss produces one outcome, never a silent discarded attempt',(){
    final c=counter();final e=feed(c,[(0,160),(100,130),(200,100),(300,null),(450,130),(600,160),(700,160)]);
    check(e.length==1&&e.single.kind==RepEventKind.cycleAborted,'motion silently lost');
    check(c.reps==0&&!e.single.assessable,'lost evidence credited');
  });
  test('missing callbacks cannot stitch disconnected movements',(){
    final c=counter();final e=feed(c,[(0,160),(100,130),(200,100),(1500,160),(1600,160)]);
    check(c.reps==0&&e.length==1,'timestamp gap credited or discarded motion');
  });
  test('one-frame impulse plus waiting is not a fast rep',(){
    final c=counter();feed(c,[(0,160),(70,100),(140,160),(600,160),(700,160)]);
    check(c.reps==0,'stationary wait inflated movement duration');
  });
  test('trusted partial return is incomplete exactly once',(){
    final c=counter();final e=feed(c,[(0,160),(100,130),(250,125),(500,145),(650,160),(750,160),(900,160)]);
    check(e.length==1&&e.single.kind==RepEventKind.partialRep&&c.reps==0&&c.partials==1,'partial lost');
  });
  for(final p in FormProfileRegistry.profiles) {
    for(final v in p.variants) {
      final spec=v.repCycle;if(spec==null)continue;
      for(final duration in [800,2200,8000]) {
        test('${v.id}: ${duration}ms complete, stationary, no double count',(){
          final c=RepCounter(spec);final out=<RepEvent>[];
          for(var t=0;t<=duration+500;t+=50) {
            final progress=t<=duration/2?t/(duration/2):math.max(0.0,(duration-t)/(duration/2));
            out.addAll(c.update(tMs:t,driver:spec.topValue+(spec.bottomValue-spec.topValue)*progress,usable:true));
          }
          check(c.reps==1&&out.length==1,'${c.reps} reps ${out.length} events');
          for(var t=duration+550;t<duration+1500;t+=50){c.update(tMs:t,driver:spec.topValue,usable:true);}
          check(c.reps==1,'double count');
        });
      }
      test('${v.id}: no motion / threshold jitter',(){
        final c=RepCounter(spec);
        for(var t=0;t<=4000;t+=50) {
          c.update(tMs:t,driver:spec.topValue+(spec.descending?-1:1)*(spec.enterMargin+(t%100==0?1:-1)*math.min(1.0,spec.fullRange*.01)),usable:true);
        }
        check(c.reps==0&&c.partials==0,'noise counted');
      });
    }
  }
  test('end-to-end pose -> metrics -> completion -> counters',(){
    final e=engine();warm(e);final s=move(e,3000);
    check(s.reps==1&&s.attempts==1&&s.valid==0&&s.trackedReps==1,'${s.reps}/${s.attempts}/${s.valid}');
  });
  test('end-to-end landmark loss -> cannot assess, no correction',(){
    final e=engine();warm(e);final s=move(e,3000,loss:true);
    check(s.reps==1&&s.attempts==1&&s.trackedReps==1&&s.valid==0&&s.incorrect==0,'short continuous gap incorrectly handled');
  });
  test('end-to-end partial -> incomplete',(){
    final e=engine();warm(e);final s=move(e,3000,end:105);
    check(s.reps==0&&s.attempts==1&&s.incomplete==1,'partial lost');
  });
  test('camera/lifecycle interruption preserves progress and classifies open motion once',(){
    final e=engine();warm(e);move(e,3000);
    for(var t=5300;t<=5800;t+=100){e.onFrame(tMs:t,rawPose:curl(t,100),fps:15);}
    e.onInterrupted(5900);var s=e.onFrame(tMs:6000,rawPose:curl(6000,160),fps:15);
    check(s.reps==1&&s.stage==FormCoachStage.readyCheck,'progress lost');
    check(s.cannotAssessAttempts==1&&s.attempts==2,'interrupted motion lost');
    e.onInterrupted(6100);s=e.onFrame(tMs:6200,rawPose:curl(6200,160),fps:15);
    check(s.attempts==2,'interruption double counted');
    e.reset();s=e.onFrame(tMs:0,rawPose:curl(0,160),fps:15);
    check(s.reps==0&&s.attempts==0,'restart retained counters');
  });
  test('body proportion / image aspect preserve geometry',(){
    const m=MetricSpec(id:'a',kind:MetricKind.jointAngle,joints:[FcJoint.shoulder,FcJoint.elbow,FcJoint.wrist]);
    for(final scale in [.6,1.0,1.3])for(final aspect in [.5625,1.0,1.77]) {
      final value=MetricEvaluator([m]).evaluate(curl(0,105,scale:scale,aspect:aspect))['a']!.value;
      check((value-105).abs()<.0001,'distorted angle');
    }
  });
  test('poor visibility never changes verified mapping or fires correction',(){
    final p=FormProfileRegistry.lookup(exerciseKey:'curl',exerciseName:'EZ Bar Preacher Curl')!;
    check(p.id=='biceps_curl','verified mapping changed');final e=engine(p);
    for(var t=0;t<5000;t+=100) {
      final s=e.onFrame(tMs:t,rawPose:curl(t,70,visibility:.1),fps:15);
      check(s.reps==0&&s.cue==null&&s.verdict==FormVerdict.cannotAssess,'unsafe assessment');
    }
  });
  test('fallback hinge measures hip, no form correction authority',(){
    final f=FormFallbackEngine.resolve(exerciseKey:'new',exerciseName:'Dumbbell Good Morning',muscle:'hamstrings');
    check(f.isUsable&&f.profile!.variants.first.metrics.first.joints[1]==FcJoint.hip,'wrong hinge driver');
    check(!f.profile!.canCorrectForm,'fallback corrections');
  });
  test('exercise switch creates independent session',(){
    final e=engine();warm(e);move(e,3000);final next=engine(FormProfileRegistry.byId('squat')!);
    check(next.reps==0&&next.stage==FormCoachStage.starting,'state leaked');
  });
  test('persistent error classification survives return and audio cooldown',(){
    final v=bicepsCurlProfile.variants.first;
    final p=FormProfile(id:'rule-test',titleAr:'test',supportLevel:FormSupportLevel.full,variants:[
      FormProfileVariant(id:'rule-test',titleAr:'test',supportLevel:FormSupportLevel.full,
        readiness:v.readiness,metrics:v.metrics,repCycle:v.repCycle,
        rules:const[FormRule(id:'persistent',metricId:'elbow_angle',min:120,persistenceMs:200,cueAr:'test',cooldownMs:6000)])]);
    final e=engine(p);warm(e);final a=move(e,3000),b=move(e,5200);
    check(a.incorrect==1&&a.valid==0,'persistent error forgotten');
    check(b.incorrect==2&&b.valid==0,'audio cooldown altered classification');
  });
  test('camera-view variant revalidation preserves previous counters',(){
    final v=bicepsCurlProfile.variants.first;
    final p=FormProfile(id:'views',titleAr:'test',supportLevel:FormSupportLevel.limited,variants:[
      for(final both in [true,false])FormProfileVariant(id:'view-$both',titleAr:'test',supportLevel:FormSupportLevel.limited,
        readiness:ReadinessSpec(requiredJoints:v.readiness.requiredJoints,requireBothSides:both),metrics:v.metrics,repCycle:v.repCycle)]);
    final e=engine(p);late FormCoachSnapshot s;
    for(var t=0;t<=3000;t+=100){e.onFrame(tMs:t,rawPose:curl(t,160,right:true),fps:15);}
    for(var dt=100;dt<=2200;dt+=100) {
      final f=dt<=1000?dt/1000:math.max(0.0,(2000-dt)/1000);
      s=e.onFrame(tMs:3000+dt,rawPose:curl(3000+dt,160-115*f,right:true),fps:15);
    }
    check(s.reps==1,'fixture rep failed');e.onInterrupted(5300);
    for(var t=5400;t<=8400;t+=100){s=e.onFrame(tMs:t,rawPose:curl(t,160),fps:15);}
    check(s.isLive&&s.activeVariantId=='view-false'&&s.reps==1&&s.attempts==1,'variant reset counters');
  });
  test('nonfinite / reordered input cannot generate a rep',(){
    final c=counter();feed(c,[(0,160),(100,130),(90,100),(200,double.nan),(300,160),(500,160)]);
    check(c.reps==0,'invalid input counted');
  });
  test('cropped head does not block the required visible arm chain',(){
    final e=engine();late FormCoachSnapshot s;
    for(var t=0;t<=3000;t+=100) {
      final points=Map<FcLandmark,FcPoint>.of(curl(t,160).points)..remove(FcLandmark.nose);
      s=e.onFrame(tMs:t,rawPose:PoseSample(timestampMs:t,points:points),fps:15);
    }
    check(s.isLive,'unrequired head blocked readiness');
  });
  test('raise metric follows shoulder elevation, not elbow flexion',(){
    final v=FormProfileRegistry.byId('catalog_raise_family')!.variants.first;
    for(final a in [15.0,82.0,15.0]) {
      final rad=a*math.pi/180;
      final sample=PoseSample(timestampMs:0,points:{
        FcLandmark.leftShoulder:const FcPoint(x:.4,y:.3,visibility:.98),FcLandmark.leftHip:const FcPoint(x:.4,y:.65,visibility:.98),
        FcLandmark.leftElbow:FcPoint(x:.4+.15*math.sin(rad),y:.3+.15*math.cos(rad),visibility:.98),
        FcLandmark.leftWrist:FcPoint(x:.4+.3*math.sin(rad),y:.3+.3*math.cos(rad),visibility:.98)});
      final value=MetricEvaluator(v.metrics).evaluate(sample)[v.repCycle!.driverMetricId]!.value;
      check((value-a).abs()<.001,'elbow proxy ignores straight-arm elevation');
    }
  });
  test('hinge metric follows hip with a straight knee',(){
    final v=FormProfileRegistry.byId('catalog_hinge_family')!.variants.first;
    for(final a in [168.0,100.0,168.0]) {
      final rad=(180-a)*math.pi/180;
      final sample=PoseSample(timestampMs:0,points:{
        FcLandmark.leftHip:const FcPoint(x:.4,y:.5,visibility:.98),
        FcLandmark.leftShoulder:FcPoint(x:.4+.3*math.sin(rad),y:.5-.3*math.cos(rad),visibility:.98),
        FcLandmark.leftKnee:const FcPoint(x:.4,y:.7,visibility:.98),FcLandmark.leftAnkle:const FcPoint(x:.4,y:.9,visibility:.98)});
      final value=MetricEvaluator(v.metrics).evaluate(sample)[v.repCycle!.driverMetricId]!.value;
      check((value-a).abs()<.001,'knee proxy ignores hip movement');
    }
  });
  if(failures.isNotEmpty)throw StateError('${failures.length} failures / ${passed+failures.length}\n${failures.join('\n')}');
  print('$passed domain cases passed');
}
