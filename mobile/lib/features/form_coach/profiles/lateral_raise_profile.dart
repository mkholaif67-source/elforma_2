// Form Coach profile: lateral raise - LIMITED tracking (front view).
//
// The driver can estimate arm-elevation movement and repetitions. Form-warning
// rules remain disabled until the measurements are calibrated on real users.
//
// Not measurable: shoulder rotation, scapular mechanics, trap takeover.

import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

const FormProfile lateralRaiseProfile = FormProfile(
  id: 'lateral_raise',
  titleAr: 'الرفع الجانبي',
  supportLevel: FormSupportLevel.limited,
  setupHintAr: 'حط الهاتف قصادك على مستوى الصدر بحيث تبان الذراعين والورك',
  detectableAr: <String>[
    'مدى رفع الذراع عن الجسم',
  ],
  notDetectableAr: <String>[
    'تصحيح وضع الجسم والمفاصل غير مفعّل في وضع متابعة العدات',
    'دوران الكتف الداخلي/الخارجي',
    'حركة لوح الكتف أو اشتراك الترابيز',
    'الوزن المستخدم',
  ],
  matchKeywords: <String>[
    'lateral raise',
    'side raise',
    'lateral',
    'رفع جانبي',
  ],
  excludeKeywords: <String>[
    'front raise',
    'rear',
    'reverse',
    'pulldown',
    'pull-down',
    'pull down',
  ],
  completion: CompletionSpec(fallbackTargetReps: 12),
  variants: <FormProfileVariant>[
    FormProfileVariant(
      id: 'lateral_raise.front',
      titleAr: 'رفع جانبي - تصوير أمامي',
      supportLevel: FormSupportLevel.limited,
      readiness: ReadinessSpec(
        requiredJoints: <FcJoint>[
          FcJoint.shoulder,
          FcJoint.elbow,
          FcJoint.wrist,
          FcJoint.hip,
        ],
        requireBothSides: true,
        view: PreferredView.front,
      ),
      metrics: <MetricSpec>[
        MetricSpec(
          id: 'abduction',
          kind: MetricKind.limbAbductionFromTorso,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow],
          side: MetricSide.mean,
          labelAr: 'ارتفاع الذراع',
        ),
        MetricSpec(
          id: 'abduction_max',
          kind: MetricKind.limbAbductionFromTorso,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow],
          side: MetricSide.maxValue,
          labelAr: 'أعلى ارتفاع',
        ),
        MetricSpec(
          id: 'abduction_left',
          kind: MetricKind.limbAbductionFromTorso,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow],
          side: MetricSide.left,
          labelAr: 'ارتفاع الشمال',
        ),
        MetricSpec(
          id: 'abduction_right',
          kind: MetricKind.limbAbductionFromTorso,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow],
          side: MetricSide.right,
          labelAr: 'ارتفاع اليمين',
        ),
        MetricSpec(
          id: 'arm_asymmetry',
          kind: MetricKind.absoluteDifference,
          sources: <String>['abduction_left', 'abduction_right'],
          labelAr: 'فرق الذراعين',
        ),
        MetricSpec(
          id: 'elbow_angle',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist],
          side: MetricSide.minValue,
          labelAr: 'زاوية الكوع',
        ),
        MetricSpec(
          id: 'torso_tilt',
          kind: MetricKind.signedSegmentTilt,
          joints: <FcJoint>[FcJoint.hip, FcJoint.shoulder],
          side: MetricSide.mean,
          labelAr: 'ميل الجسم',
          captureBaseline: true,
        ),
        MetricSpec(
          id: 'torso_swing',
          kind: MetricKind.absoluteDeltaFromBaseline,
          sources: <String>['torso_tilt'],
          labelAr: 'مرجحة الجسم',
        ),
      ],
      // Ascending driver: arms start down (~14) and rise (~82).
      repCycle: RepCycleSpec(
        driverMetricId: 'abduction',
        topValue: 14,
        bottomValue: 82,
        enterMargin: 15,
        minAmplitude: 45,
        partialAmplitude: 25,
        topLabelAr: 'الذراع لأسفل',
        bottomLabelAr: 'أعلى الرفع',
      ),
      rules: const <FormRule>[],
      repFeedback: RepFeedbackSpec(
        partialCueAr: 'ارفع لمستوى الكتف',
        partialDetailAr: 'الرفع أقل من المدى المعتاد',
        fastTempoCueAr: 'هدّي الحركة',
        fastTempoDetailAr: 'في استخدام ممومنتم أكتر من اللازم',
      ),
    ),
  ],
);
