// Form Coach profile: leg extension machine - LIMITED analysis on purpose.
//
// On a machine the seat already controls most of the posture, and the frame
// (pad, weight stack, seat back) hides the hip/torso in many gyms. What stays
// reliably measurable from pose is the knee range of motion and the tempo, so
// this profile declares FormSupportLevel.limited and ships with NO form rules
// rather than inventing checks we cannot defend.
//
// It exists mainly to prove the engine is not curl/squat shaped: a seated,
// partially occluded, ascending-driver movement works through the same pipeline
// with data only.

import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

const FormProfile legExtensionMachineProfile = FormProfile(
  id: 'leg_extension_machine',
  titleAr: 'جهاز تمديد الرجل',
  supportLevel: FormSupportLevel.limited,
  setupHintAr:
      'حط الهاتف على جنب الجهاز بحيث تبان الورك والركبة والكاحل',
  detectableAr: <String>[
    'مدى فتح الركبة (ROM)',
    'العدات الناقصة',
    'العدات السريعة جدًا',
  ],
  notDetectableAr: <String>[
    'وضع الظهر والحوض على الكرسي (محجوب عادةً)',
    'الوزن المستخدم أو سرعة النزول المتحكم فيها بدقة',
    'ضبط الوسادة أو وضع القدم',
  ],
  matchKeywords: <String>[
    'leg extension',
    'extension machine',
    'تمديد الرجل',
  ],
  excludeKeywords: <String>['leg curl', 'lying leg', 'hip extension', 'back extension'],
  completion: CompletionSpec(fallbackTargetReps: 12),
  variants: <FormProfileVariant>[
    FormProfileVariant(
      id: 'leg_extension_machine.side',
      titleAr: 'تمديد الرجل - تصوير من الجنب',
      supportLevel: FormSupportLevel.limited,
      readiness: ReadinessSpec(
        // Legs only: on machines the torso is frequently occluded, so requiring
        // it would block the feature for no analytical gain.
        requiredJoints: <FcJoint>[FcJoint.hip, FcJoint.knee, FcJoint.ankle],
        minTorsoFraction: 0.08,
        maxTorsoFraction: 0.7,
        checkLighting: true,
      ),
      sideSelection: SideSelection.activeSide,
      sideAmplitudeMetrics: <String>['knee_angle_left', 'knee_angle_right'],
      metrics: <MetricSpec>[
        MetricSpec(
          id: 'knee_angle',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.hip, FcJoint.knee, FcJoint.ankle],
          side: MetricSide.activeSide,
          labelAr: 'زاوية الركبة',
        ),
        MetricSpec(
          id: 'knee_angle_left',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.hip, FcJoint.knee, FcJoint.ankle],
          side: MetricSide.left,
          labelAr: 'ركبة الشمال',
        ),
        MetricSpec(
          id: 'knee_angle_right',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.hip, FcJoint.knee, FcJoint.ankle],
          side: MetricSide.right,
          labelAr: 'ركبة اليمين',
        ),
      ],
      // Ascending driver: starts bent (~90) and extends (~168).
      repCycle: RepCycleSpec(
        driverMetricId: 'knee_angle',
        topValue: 92,
        bottomValue: 168,
        enterMargin: 14,
        minAmplitude: 45,
        partialAmplitude: 24,
        topLabelAr: 'ركبة مثنية',
        bottomLabelAr: 'رجل ممدودة',
      ),
      repFeedback: RepFeedbackSpec(
        partialCueAr: 'مدّ الرجل أكتر',
        partialDetailAr: 'العدة ما وصلتش للمدى المعتاد',
        fastTempoCueAr: 'هدّي الحركة شوية',
        fastTempoDetailAr: 'العدات أسرع من التيمبو المطلوب',
        partialsBeforeCue: 2,
      ),
      // No geometry rules: nothing else here is measurable with confidence.
      driverMinConfidence: 0.5,
    ),
  ],
);
