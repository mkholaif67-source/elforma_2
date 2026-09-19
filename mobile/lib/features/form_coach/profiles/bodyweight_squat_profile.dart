// Form Coach profile: bodyweight squat - LIMITED tracking, two camera views.
//
// Side and front variants expose the required landmarks and a rep driver. Form
// warnings remain disabled until the measurements are calibrated on real users.
//
// Not measurable: foot arch, spine segment detail, ankle mobility.

import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

const List<FcJoint> _squatJoints = <FcJoint>[
  FcJoint.shoulder,
  FcJoint.hip,
  FcJoint.knee,
  FcJoint.ankle,
];

const RepCycleSpec _squatCycle = RepCycleSpec(
  driverMetricId: 'knee_angle',
  topValue: 168,
  bottomValue: 88,
  enterMargin: 14,
  minAmplitude: 55,
  partialAmplitude: 30,
  topLabelAr: 'وقوف',
  bottomLabelAr: 'أقصى نزول',
);

const RepFeedbackSpec _squatFeedback = RepFeedbackSpec(
  partialCueAr: 'انزل أكتر شوية',
  partialDetailAr: 'النزول أقل من المدى المعتاد',
  fastTempoCueAr: 'هدّي النزول',
  fastTempoDetailAr: 'العدات سريعة جدًا',
);

const FormProfile bodyweightSquatProfile = FormProfile(
  id: 'squat',
  titleAr: 'السكوات',
  supportLevel: FormSupportLevel.limited,
  setupHintAr: 'حط الهاتف جانبك أو قصادك على بعد خطوتين بحيث يبان جسمك بالكامل',
  detectableAr: <String>[
    'عمق النزول (زاوية الركبة)',
    'العدات الناقصة',
    'ميل الجسم للأمام الزايد (تصوير جانبي)',
    'دخول الركبة للداخل (تصوير أمامي)',
  ],
  notDetectableAr: <String>[
    'تقوّس الظهر بالتفصيل',
    'توزيع الوزن على القدم',
    'مرونة الكاحل',
  ],
  matchKeywords: <String>['squat', 'goblet', 'سكوات'],
  excludeKeywords: <String>[
    'split',
    'bulgarian',
    'sissy',
    'jump',
    'hack',
    'بلغاري',
  ],
  completion: CompletionSpec(fallbackTargetReps: 12),
  variants: <FormProfileVariant>[
    FormProfileVariant(
      id: 'squat.side',
      titleAr: 'سكوات - تصوير من الجنب',
      supportLevel: FormSupportLevel.limited,
      readiness: ReadinessSpec(
        requiredJoints: _squatJoints,
        view: PreferredView.side,
        minTorsoFraction: 0.14,
        maxTorsoFraction: 0.45,
      ),
      metrics: <MetricSpec>[
        MetricSpec(
          id: 'knee_angle',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.hip, FcJoint.knee, FcJoint.ankle],
          side: MetricSide.minValue,
          labelAr: 'زاوية الركبة',
        ),
        MetricSpec(
          id: 'torso_lean',
          kind: MetricKind.segmentTilt,
          joints: <FcJoint>[FcJoint.hip, FcJoint.shoulder],
          side: MetricSide.mean,
          labelAr: 'ميل الجسم',
        ),
      ],
      repCycle: _squatCycle,
      rules: const <FormRule>[],
      repFeedback: _squatFeedback,
    ),
    FormProfileVariant(
      id: 'squat.front',
      titleAr: 'سكوات - تصوير أمامي',
      supportLevel: FormSupportLevel.limited,
      readiness: ReadinessSpec(
        requiredJoints: _squatJoints,
        requireBothSides: true,
        view: PreferredView.front,
        minTorsoFraction: 0.14,
        maxTorsoFraction: 0.45,
      ),
      metrics: <MetricSpec>[
        MetricSpec(
          id: 'knee_angle',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.hip, FcJoint.knee, FcJoint.ankle],
          side: MetricSide.mean,
          labelAr: 'زاوية الركبة',
        ),
        MetricSpec(
          id: 'knee_track_left',
          kind: MetricKind.normalizedHorizontalOffset,
          joints: <FcJoint>[FcJoint.ankle, FcJoint.knee],
          side: MetricSide.left,
          labelAr: 'مسار ركبة الشمال',
          unit: '×جسم',
          captureBaseline: true,
        ),
        MetricSpec(
          id: 'knee_track_right',
          kind: MetricKind.normalizedHorizontalOffset,
          joints: <FcJoint>[FcJoint.ankle, FcJoint.knee],
          side: MetricSide.right,
          labelAr: 'مسار ركبة اليمين',
          unit: '×جسم',
          captureBaseline: true,
        ),
        MetricSpec(
          id: 'knee_shift_left',
          kind: MetricKind.absoluteDeltaFromBaseline,
          sources: <String>['knee_track_left'],
          labelAr: 'انحراف ركبة الشمال',
          unit: '×جسم',
        ),
        MetricSpec(
          id: 'knee_shift_right',
          kind: MetricKind.absoluteDeltaFromBaseline,
          sources: <String>['knee_track_right'],
          labelAr: 'انحراف ركبة اليمين',
          unit: '×جسم',
        ),
      ],
      repCycle: _squatCycle,
      rules: const <FormRule>[],
      repFeedback: _squatFeedback,
    ),
  ],
);
