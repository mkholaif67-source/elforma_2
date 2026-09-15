// Form Coach profile for the exercise shown in the supplied session reference.
// Tracking-only: bar path, grip width, bench angle and load are not visible
// reliably from one pose stream.
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

const FormProfile inclineBarbellPressProfile = FormProfile(
  id: 'incline_barbell_press',
  titleAr: 'ضغط البنش المائل',
  supportLevel: FormSupportLevel.trackingOnly,
  setupHintAr: 'ضع الهاتف من الجانب بحيث يظهر الكتف والكوع والرسغ والورك',
  detectableAr: <String>['العدات التقريبية', 'مدى ثني الكوع', 'مرحلة النزول والرجوع'],
  notDetectableAr: <String>[
    'مسار البار وعرض القبضة',
    'زاوية البنش وملامسة البار للصدر',
    'الوزن وثبات لوح الكتف',
  ],
  matchKeywords: <String>['incline barbell press'],
  completion: CompletionSpec(fallbackTargetReps: 10),
  variants: <FormProfileVariant>[
    FormProfileVariant(
      id: 'incline_barbell_press.side',
      titleAr: 'ضغط مائل - متابعة العدات',
      supportLevel: FormSupportLevel.trackingOnly,
      readiness: ReadinessSpec(
        requiredJoints: <FcJoint>[
          FcJoint.shoulder,
          FcJoint.elbow,
          FcJoint.wrist,
          FcJoint.hip,
        ],
        view: PreferredView.side,
      ),
      metrics: <MetricSpec>[
        MetricSpec(
          id: 'elbow_angle',
          kind: MetricKind.jointAngle,
          joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist],
          side: MetricSide.activeSide,
          labelAr: 'زاوية الكوع',
        ),
      ],
      repCycle: RepCycleSpec(
        driverMetricId: 'elbow_angle',
        topValue: 165,
        bottomValue: 78,
        enterMargin: 18,
        minAmplitude: 45,
        partialAmplitude: 25,
        topLabelAr: 'الذراع ممدودة',
        bottomLabelAr: 'نهاية النزول',
      ),
      driverMinConfidence: 0.52,
    ),
  ],
);
