// Form Coach profile: lateral raise - FULL analysis (front view).
//
// Measurable: arm elevation range from the torso axis (reps + partials), left vs
// right asymmetry, raising above shoulder height, collapsed/bent elbow, and
// torso swing vs the user's own warm-up baseline.
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
  supportLevel: FormSupportLevel.full,
  setupHintAr: 'حط الهاتف قصادك على مستوى الصدر بحيث تبان الذراعين والورك',
  detectableAr: <String>[
    'مدى رفع الذراع عن الجسم',
    'فرق الارتفاع بين اليمين والشمال',
    'الرفع أعلى من اللازم',
    'ثني الكوع الزايد',
    'مرجحة الجسم',
  ],
  notDetectableAr: <String>[
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
      supportLevel: FormSupportLevel.full,
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
      rules: <FormRule>[
        FormRule(
          id: 'body_swing',
          metricId: 'torso_swing',
          max: 10,
          tolerance: 5,
          cueAr: 'ثبّت جسمك',
          detailAr: 'في مرجحة مع الرفع',
          measuresAr: 'فرق ميل الجسم عن وضعك الطبيعي (درجة)',
          priority: 1,
          severity: RuleSeverity.critical,
          persistenceMs: 500,
        ),
        FormRule(
          id: 'arm_asymmetry',
          metricId: 'arm_asymmetry',
          max: 15,
          tolerance: 7,
          cueAr: 'وازن بين الذراعين',
          detailAr: 'ذراع أعلى من التانية',
          measuresAr: 'فرق ارتفاع الذراعين (درجة)',
          phases: <RepPhase>[RepPhase.towardBottom, RepPhase.bottom],
          priority: 2,
          persistenceMs: 420,
        ),
        FormRule(
          id: 'too_high',
          metricId: 'abduction_max',
          max: 108,
          tolerance: 8,
          cueAr: 'ما ترفعش أعلى من كتفك',
          detailAr: 'الذراع طالعة فوق مستوى الكتف',
          measuresAr: 'زاوية الذراع عن محور الجسم (درجة)',
          phases: <RepPhase>[RepPhase.bottom],
          priority: 3,
          persistenceMs: 380,
        ),
        FormRule(
          id: 'elbow_bend',
          metricId: 'elbow_angle',
          min: 140,
          tolerance: 12,
          cueAr: 'مدّ الكوع شوية',
          detailAr: 'الكوع مثني أكتر من اللازم',
          measuresAr: 'زاوية الكتف-الكوع-الرسغ (درجة)',
          phases: <RepPhase>[RepPhase.towardBottom, RepPhase.bottom],
          priority: 4,
          severity: RuleSeverity.minor,
          persistenceMs: 600,
          maxFiresPerSet: 2,
        ),
      ],
      repFeedback: RepFeedbackSpec(
        partialCueAr: 'ارفع لمستوى الكتف',
        partialDetailAr: 'الرفع أقل من المدى المعتاد',
        fastTempoCueAr: 'هدّي الحركة',
        fastTempoDetailAr: 'في استخدام ممومنتم أكتر من اللازم',
      ),
    ),
  ],
);
