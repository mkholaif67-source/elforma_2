// Form Coach profile: bodyweight squat - FULL analysis, two camera views.
//
// Side and front views see different things, so the profile ships two variants
// and the engine activates whichever the camera actually satisfies:
//   - side  : depth (knee flexion range) + excessive forward torso lean
//   - front : depth + knee sliding in/out vs the user's own baseline
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
  supportLevel: FormSupportLevel.full,
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
      supportLevel: FormSupportLevel.full,
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
      rules: <FormRule>[
        FormRule(
          id: 'torso_lean',
          metricId: 'torso_lean',
          max: 45,
          tolerance: 8,
          cueAr: 'ارفع صدرك',
          detailAr: 'الجسم مايل للأمام أكتر من اللازم',
          measuresAr: 'زاوية خط الورك-الكتف عن الرأسي (درجة)',
          phases: <RepPhase>[RepPhase.towardBottom, RepPhase.bottom],
          priority: 2,
          persistenceMs: 500,
        ),
      ],
      repFeedback: _squatFeedback,
    ),
    FormProfileVariant(
      id: 'squat.front',
      titleAr: 'سكوات - تصوير أمامي',
      supportLevel: FormSupportLevel.full,
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
      rules: <FormRule>[
        FormRule(
          id: 'knee_shift_left',
          metricId: 'knee_shift_left',
          max: 0.12,
          tolerance: 0.05,
          cueAr: 'حافظ على وضع الركبة',
          detailAr: 'ركبة الشمال بتتحرك عن خط القدم',
          measuresAr: 'إزاحة الركبة أفقيًا عن الكاحل ÷ طول الجسم',
          phases: <RepPhase>[
            RepPhase.towardBottom,
            RepPhase.bottom,
            RepPhase.towardTop,
          ],
          priority: 2,
          persistenceMs: 450,
        ),
        FormRule(
          id: 'knee_shift_right',
          metricId: 'knee_shift_right',
          max: 0.12,
          tolerance: 0.05,
          cueAr: 'حافظ على وضع الركبة',
          detailAr: 'ركبة اليمين بتتحرك عن خط القدم',
          measuresAr: 'إزاحة الركبة أفقيًا عن الكاحل ÷ طول الجسم',
          phases: <RepPhase>[
            RepPhase.towardBottom,
            RepPhase.bottom,
            RepPhase.towardTop,
          ],
          priority: 2,
          persistenceMs: 450,
        ),
      ],
      repFeedback: _squatFeedback,
    ),
  ],
);
