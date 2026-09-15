// Form Coach profile: lat pulldown - TRACKING ONLY.
//
// The things that actually matter in a pulldown (scapular movement, how far the
// torso leans back under load, grip width, bar path behind/in front of the head)
// are either invisible to a single-view pose model or hidden by the machine
// frame and the user's own arms. So this profile counts reps and shows the
// movement, and the UI explicitly tells the user that form correction is off.
//
// Because supportLevel is trackingOnly, FormProfile.canCorrectForm is false and
// the engine blocks every form cue for it - by construction, not by convention.

import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

const FormProfile latPulldownProfile = FormProfile(
  id: 'lat_pulldown',
  titleAr: 'سحب أمامي (لات بولداون)',
  supportLevel: FormSupportLevel.trackingOnly,
  setupHintAr: 'حط الهاتف قصادك بحيث يبان الكتفين والكوعين والرسغين',
  detectableAr: <String>[
    'عدد العدات التقريبي',
    'مدى ثني الكوع أثناء السحب',
  ],
  notDetectableAr: <String>[
    'حركة لوح الكتف (Scapula)',
    'ميل الجسم للخلف تحت الحمل بدقة',
    'عرض القبضة أو مسار البار وراء الرأس',
    'الوزن أو شد العضلة',
  ],
  matchKeywords: <String>['lat pulldown', 'pulldown', 'pull-down', 'سحب أمامي'],
  completion: CompletionSpec(fallbackTargetReps: 10),
  variants: <FormProfileVariant>[
    FormProfileVariant(
      id: 'lat_pulldown.front',
      titleAr: 'سحب أمامي - متابعة عدات',
      supportLevel: FormSupportLevel.trackingOnly,
      readiness: ReadinessSpec(
        requiredJoints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist],
        minTorsoFraction: 0.1,
        maxTorsoFraction: 0.7,
      ),
      metrics: <MetricSpec>[
        MetricSpec(
          id: 'elbow_angle',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist],
          side: MetricSide.mean,
          labelAr: 'زاوية الكوع',
        ),
      ],
      repCycle: RepCycleSpec(
        driverMetricId: 'elbow_angle',
        topValue: 160,
        bottomValue: 80,
        enterMargin: 18,
        minAmplitude: 45,
        partialAmplitude: 25,
        topLabelAr: 'ذراع ممدودة',
        bottomLabelAr: 'نهاية السحب',
      ),
      // No rules and no rep cues: tracking only means we stay quiet.
      driverMinConfidence: 0.5,
    ),
  ],
);
