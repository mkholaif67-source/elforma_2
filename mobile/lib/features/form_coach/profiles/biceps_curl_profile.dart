// Form Coach profile: biceps curl family - LIMITED tracking.
//
// The driver can estimate elbow-angle movement and repetitions. Form-warning
// rules are intentionally disabled until they are calibrated on real users and
// camera placements; this profile must not over-promise correction.
//
// Not measurable: grip, wrist position under load, muscle tension.

import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

const FormProfile bicepsCurlProfile = FormProfile(
  id: 'biceps_curl',
  titleAr: 'تمرين البايسبس (كيرل)',
  supportLevel: FormSupportLevel.limited,
  setupHintAr: 'حط الهاتف جانبك أو قصادك بحيث يبان الكتف والكوع والرسغ والورك',
  detectableAr: <String>[
    'مدى ثني وفتح الكوع (عدات كاملة وناقصة)',
    'تقدّم الكوع للأمام عن وضعه الطبيعي',
    'مرجحة الجسم لرفع الوزن',
    'العدات السريعة جدًا',
  ],
  notDetectableAr: <String>[
    'القبضة ووضع الرسغ تحت الحمل',
    'شد العضلة أو التنفس',
    'الوزن المستخدم',
  ],
  matchKeywords: <String>[
    'curl',
    'biceps',
    'bicep',
    'hammer',
    'bayesian',
    'preacher',
    'ez bar',
    'كيرل',
    'بايسبس',
  ],
  excludeKeywords: <String>[
    'leg curl',
    'lying leg',
    'hamstring',
    'wrist curl',
    'hammer strength',
    'skull',
    'tricep',
    'triceps',
    'cable overhead curl',
  ],
  completion: CompletionSpec(fallbackTargetReps: 12),
  variants: <FormProfileVariant>[
    FormProfileVariant(
      id: 'biceps_curl.default',
      titleAr: 'كيرل واقف / جلوس',
      supportLevel: FormSupportLevel.limited,
      readiness: ReadinessSpec(
        requiredJoints: <FcJoint>[
          FcJoint.shoulder,
          FcJoint.elbow,
          FcJoint.wrist,
          FcJoint.hip,
        ],
      ),
      sideSelection: SideSelection.activeSide,
      sideAmplitudeMetrics: <String>['elbow_angle_left', 'elbow_angle_right'],
      metrics: <MetricSpec>[
        MetricSpec(
          id: 'elbow_angle',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist],
          side: MetricSide.activeSide,
          labelAr: 'زاوية الكوع',
        ),
        MetricSpec(
          id: 'elbow_angle_left',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist],
          side: MetricSide.left,
          labelAr: 'كوع الشمال',
        ),
        MetricSpec(
          id: 'elbow_angle_right',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist],
          side: MetricSide.right,
          labelAr: 'كوع اليمين',
        ),
        MetricSpec(
          id: 'elbow_offset',
          kind: MetricKind.normalizedHorizontalOffset,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow],
          side: MetricSide.activeSide,
          labelAr: 'موقع الكوع من الكتف',
          unit: '×جسم',
          captureBaseline: true,
        ),
        MetricSpec(
          id: 'elbow_drift',
          kind: MetricKind.absoluteDeltaFromBaseline,
          sources: <String>['elbow_offset'],
          labelAr: 'انحراف الكوع',
          unit: '×جسم',
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
      repCycle: RepCycleSpec(
        driverMetricId: 'elbow_angle',
        topValue: 158,
        bottomValue: 55,
        enterMargin: 16,
        minAmplitude: 55,
        partialAmplitude: 30,
        topLabelAr: 'ذراع ممدودة',
        bottomLabelAr: 'أعلى الرفع',
      ),
      rules: const <FormRule>[],
      repFeedback: RepFeedbackSpec(
        partialCueAr: 'كمّل مدى الحركة',
        partialDetailAr: 'العدة ما وصلتش للمدى الكامل',
        fastTempoCueAr: 'هدّي الحركة شوية',
        fastTempoDetailAr: 'العدات أسرع من التيمبو المطلوب',
      ),
    ),
  ],
);
