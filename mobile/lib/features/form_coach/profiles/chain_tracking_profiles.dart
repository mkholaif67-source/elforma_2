// Movement-specific visible proxies. Thresholds need independent video validation.
// These profiles never certify anatomical form or infer muscle activation.
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

FormProfile _chain(
        String id,
        String title,
        List<String> names,
        List<FcJoint> required,
        List<FcJoint> measured,
        MetricKind kind,
        double start,
        double end,
        double margin,
        double amplitude,
        double partial,
        String hint,
        {bool both = false}) =>
    FormProfile(
      id: 'chain.$id',
      titleAr: title,
      matchKeywords: names,
      supportLevel: FormSupportLevel.trackingOnly,
      setupHintAr: hint,
      detectableAr: const ['المدى الظاهر والعداد التقريبي'],
      notDetectableAr: const [
        'شد العضلة والوزن والقبضة',
        'جودة الأداء الكاملة أو الحركة خارج مستوى التصوير'
      ],
      variants: [
        FormProfileVariant(
          id: 'chain.$id.default',
          titleAr: title,
          supportLevel: FormSupportLevel.trackingOnly,
          readiness: ReadinessSpec(
              requiredJoints: required,
              requireBothSides: both,
              view: both ? PreferredView.front : PreferredView.side,
              minTorsoFraction: .08,
              maxTorsoFraction: .85),
          sideSelection:
              both ? SideSelection.bilateral : SideSelection.activeSide,
          sideAmplitudeMetrics:
              both ? const [] : const ['motion_left', 'motion_right'],
          metrics: [
            MetricSpec(id: 'motion', kind: kind, joints: measured),
            if (!both) ...[
              MetricSpec(
                  id: 'motion_left',
                  kind: kind,
                  joints: measured,
                  side: MetricSide.left),
              MetricSpec(
                  id: 'motion_right',
                  kind: kind,
                  joints: measured,
                  side: MetricSide.right),
            ],
          ],
          repCycle: RepCycleSpec(
              driverMetricId: 'motion',
              topValue: start,
              bottomValue: end,
              enterMargin: margin,
              minAmplitude: amplitude,
              partialAmplitude: partial),
        )
      ],
    );

final List<FormProfile> chainTrackingProfiles = [
  _chain(
      'reverse_fly',
      'رفرفة خلفية',
      ['rear delt', 'rear fly', 'reverse fly', 'reverse cable crossover'],
      [FcJoint.shoulder, FcJoint.elbow, FcJoint.hip],
      [FcJoint.elbow],
      MetricKind.bilateralDistance,
      .65,
      2.1,
      .2,
      .9,
      .5,
      'أظهر الكتفين والكوعين والوركين؛ المتابعة للمسافة الظاهرة بين الكوعين',
      both: true),
  _chain(
      'fly',
      'تفتيح الصدر',
      ['fly', 'crossover', 'pec deck'],
      [FcJoint.shoulder, FcJoint.elbow, FcJoint.hip],
      [FcJoint.elbow],
      MetricKind.bilateralDistance,
      2.1,
      .65,
      .2,
      .9,
      .5,
      'أظهر الكوعين والكتفين والوركين؛ زاوية التصوير تؤثر على المدى الظاهر',
      both: true),
  _chain(
      'calf',
      'رفع السمانة',
      ['calf raise', 'سمانة', 'سمانه'],
      [FcJoint.hip, FcJoint.knee, FcJoint.ankle, FcJoint.footIndex],
      [FcJoint.knee, FcJoint.ankle, FcJoint.footIndex],
      MetricKind.jointAngle,
      100,
      135,
      8,
      20,
      12,
      'صوّر من الجانب وأظهر الركبة والكاحل ومقدمة القدم'),
  _chain(
      'leg_curl',
      'ثني الرجل',
      ['leg curl', 'hamstring curl'],
      [FcJoint.hip, FcJoint.knee, FcJoint.ankle],
      [FcJoint.hip, FcJoint.knee, FcJoint.ankle],
      MetricKind.jointAngle,
      165,
      65,
      16,
      55,
      30,
      'أظهر الورك والركبة والكاحل من الجانب؛ اقتراب الكعب من الجسم جزء من الحركة'),
  _chain(
      'hip_adduction',
      'ضم الفخذ',
      ['hip adduction', 'ضم الفخذ'],
      [FcJoint.shoulder, FcJoint.hip, FcJoint.knee],
      [FcJoint.knee],
      MetricKind.bilateralDistance,
      1.4,
      .45,
      .16,
      .55,
      .3,
      'صوّر من الأمام وأظهر الركبتين والوركين والكتفين',
      both: true),
  _chain(
      'pullover',
      'بول أوفر',
      ['pullover', 'pull over'],
      [FcJoint.shoulder, FcJoint.elbow, FcJoint.hip],
      [FcJoint.shoulder, FcJoint.elbow],
      MetricKind.limbAbductionFromTorso,
      160,
      40,
      18,
      65,
      35,
      'صوّر من الجانب؛ المتابعة لحركة العضد بالنسبة للجذع'),
  _chain(
      'face_pull',
      'فيس بول',
      ['face pull'],
      [FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist, FcJoint.hip],
      [FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist],
      MetricKind.jointAngle,
      165,
      75,
      16,
      45,
      25,
      'أظهر الكتف والكوع والرسغ من الجانب؛ اتجاه الحبل غير قابل للتقييم'),
  _chain(
      'shrug',
      'رفع الكتفين',
      ['shrug'],
      [FcJoint.ear, FcJoint.shoulder, FcJoint.hip],
      [FcJoint.ear, FcJoint.shoulder],
      MetricKind.normalizedDistance,
      .45,
      .25,
      .035,
      .12,
      .07,
      'ثبّت الرأس وأظهر الأذنين والكتفين والوركين؛ حركة الرقبة تؤثر على العداد',
      both: true),
];
