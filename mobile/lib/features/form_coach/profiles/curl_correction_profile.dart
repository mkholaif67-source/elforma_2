// Provisional side-view slice. Opt-in evaluation build only until independent
// per-error video precision and native-device gates pass. No learned model.
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';
import 'package:elforma/features/form_coach/profiles/biceps_curl_profile.dart';

const curlCorrectionEnabled =
    bool.fromEnvironment('FORM_COACH_CURL_CORRECTION');

final FormProfile curlCorrectionProfile = FormProfile(
  id: 'biceps_curl.side_correction',
  titleAr: 'كيرل — تصحيح جانبي تجريبي',
  supportLevel: FormSupportLevel.limited,
  setupHintAr:
      'للكيرل العادي فقط: الهاتف من الجانب، الكتف والكوع والرسغ والورك ظاهرين. ثبّت جسمك وذراعك بجانبك قبل البدء.',
  detectableAr: const [
    'تغيّر ميل الجذع الظاهر',
    'ابتعاد الكوع عن موضع البداية الظاهر'
  ],
  notDetectableAr: const [
    'قواعد تجريبية لم تثبت دقتها على مستخدمين مستقلين بعد',
    'القبضة والحمل وعمق الحركة',
    'تماس اليد أو الجسم مع الأداة أو المقعد'
  ],
  completion: bicepsCurlProfile.completion,
  variants: [
    FormProfileVariant(
      id: 'biceps_curl.side_correction',
      titleAr: 'كيرل عادي — جانب',
      supportLevel: FormSupportLevel.limited,
      readiness: const ReadinessSpec(
          requiredJoints: [
            FcJoint.shoulder,
            FcJoint.elbow,
            FcJoint.wrist,
            FcJoint.hip
          ],
          view: PreferredView.side,
          requireConfirmedView: true,
          minVisibility: 0.75),
      sideSelection: SideSelection.activeSide,
      driverMinConfidence: 0.75,
      calibrationLimits: const {
        'elbow_angle': [145, 180, 12],
        'elbow_offset': [-0.3, 0.3, 0.06],
        'torso_tilt': [-20, 20, 6],
      },
      metrics: [
        ...bicepsCurlProfile.variants.first.metrics
            .where((m) => m.id != 'torso_tilt'),
        const MetricSpec(
            id: 'torso_tilt',
            kind: MetricKind.signedSegmentTilt,
            joints: [FcJoint.hip, FcJoint.shoulder],
            side: MetricSide.activeSide,
            captureBaseline: true,
            labelAr: 'ميل الجذع'),
      ],
      repCycle: bicepsCurlProfile.variants.first.repCycle,
      rules: const [
        FormRule(
            id: 'curl.torso',
            metricId: 'torso_swing',
            max: 12,
            tolerance: 3,
            minConfidence: 0.75,
            persistenceMs: 350,
            priority: 1,
            phases: [
              RepPhase.towardBottom,
              RepPhase.bottom,
              RepPhase.towardTop
            ],
            cueAr: 'ثبّت جسمك أثناء الرفع',
            detailAr: 'ميل الجذع الظاهر بيتغير عن وضع البداية'),
        FormRule(
            id: 'curl.elbow',
            metricId: 'elbow_drift',
            max: 0.18,
            tolerance: 0.04,
            minConfidence: 0.75,
            persistenceMs: 350,
            priority: 2,
            phases: [
              RepPhase.towardBottom,
              RepPhase.bottom,
              RepPhase.towardTop
            ],
            cueAr: 'ثبّت الكوع بجانبك',
            detailAr: 'الكوع بيتحرك بعيدًا عن موضع البداية الظاهر'),
      ],
    )
  ],
);
