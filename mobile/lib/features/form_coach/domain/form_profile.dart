// Form Coach - the extension point.
//
// Adding an exercise = adding a FormProfile (data only). A profile can expose
// several variants (e.g. squat from the side and from the front); the engine
// activates the first variant whose setup the camera actually satisfies.

import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

enum FormSupportLevel { full, limited, trackingOnly, unsupported }

String formSupportLevelAr(FormSupportLevel level) {
  switch (level) {
    case FormSupportLevel.full:
      return 'تحليل كامل';
    case FormSupportLevel.limited:
      return 'تحليل محدود';
    case FormSupportLevel.trackingOnly:
      return 'متابعة عدات فقط';
    case FormSupportLevel.unsupported:
      return 'غير مدعوم';
  }
}

enum SideSelection { bilateral, activeSide }

class CompletionSpec {
  const CompletionSpec({
    this.durationBased = false,
    this.fallbackTargetReps = 10,
    this.fallbackTargetSeconds = 45,
  });

  /// true for holds (plank): progress is time in position, not reps.
  final bool durationBased;

  /// Used only when the workout data has no explicit target.
  final int fallbackTargetReps;
  final int fallbackTargetSeconds;
}

/// Hold exercises: time only accumulates while the metric stays in range.
class HoldSpec {
  const HoldSpec({required this.metricId, this.min, this.max});

  final String metricId;
  final double? min;
  final double? max;

  bool inPosition(double value) {
    if (min != null && value < min!) return false;
    if (max != null && value > max!) return false;
    return true;
  }
}

/// Rep-level feedback (range of motion, tempo) that is not a geometry rule.
class RepFeedbackSpec {
  const RepFeedbackSpec({
    this.partialCueAr = '',
    this.partialDetailAr = '',
    this.partialsBeforeCue = 2,
    this.partialPriority = 3,
    this.fastTempoCueAr = '',
    this.fastTempoDetailAr = '',
    this.tempoPriority = 6,
    this.cooldownMs = 8000,
  });

  final String partialCueAr;
  final String partialDetailAr;
  final int partialsBeforeCue;
  final int partialPriority;
  final String fastTempoCueAr;
  final String fastTempoDetailAr;
  final int tempoPriority;
  final int cooldownMs;

  bool get hasPartialCue => partialCueAr.isNotEmpty;
  bool get hasTempoCue => fastTempoCueAr.isNotEmpty;
}

class FormProfileVariant {
  const FormProfileVariant({
    required this.id,
    required this.titleAr,
    required this.readiness,
    required this.metrics,
    required this.supportLevel,
    this.repCycle,
    this.hold,
    this.rules = const <FormRule>[],
    this.sideSelection = SideSelection.bilateral,
    this.sideAmplitudeMetrics = const <String>[],
    this.repFeedback = const RepFeedbackSpec(),
    this.driverMinConfidence = 0.55,
    this.calibrationLimits = const <String, List<double>>{},
  });

  final String id;
  final String titleAr;

  /// Setup requirements: landmarks, view, distance, visibility.
  final ReadinessSpec readiness;

  final List<MetricSpec> metrics;
  final FormSupportLevel supportLevel;
  final RepCycleSpec? repCycle;
  final HoldSpec? hold;
  final List<FormRule> rules;
  final SideSelection sideSelection;

  /// [leftMetricId, rightMetricId] used to detect the working side.
  final List<String> sideAmplitudeMetrics;

  final RepFeedbackSpec repFeedback;

  /// Confidence needed before the driver may move the state machine.
  final double driverMinConfidence;

  /// Per metric: minimum, maximum, maximum spread during neutral calibration.
  /// Fixed profile invariants; never adapted from exercise repetitions.
  final Map<String, List<double>> calibrationLimits;

  /// Metrics whose personal baseline is captured during warm-up.
  List<String> get baselineMetricIds => <String>[
        for (final MetricSpec metric in metrics)
          if (metric.captureBaseline) metric.id,
      ];
}

class FormProfile {
  const FormProfile({
    required this.id,
    required this.titleAr,
    required this.variants,
    required this.supportLevel,
    this.detectableAr = const <String>[],
    this.notDetectableAr = const <String>[],
    this.setupHintAr = '',
    this.matchKeywords = const <String>[],
    this.excludeKeywords = const <String>[],
    this.completion = const CompletionSpec(),
  });

  final String id;
  final String titleAr;
  final List<FormProfileVariant> variants;
  final FormSupportLevel supportLevel;

  /// Shown to the user so the feature never over-promises.
  final List<String> detectableAr;
  final List<String> notDetectableAr;

  final String setupHintAr;
  final List<String> matchKeywords;
  final List<String> excludeKeywords;
  final CompletionSpec completion;

  bool get isSupported => supportLevel != FormSupportLevel.unsupported;

  /// A label alone is not permission to warn. Correction requires at least
  /// one reviewed rule; otherwise UI and engine stay in tracking mode.
  bool get canCorrectForm =>
      (supportLevel == FormSupportLevel.full ||
          supportLevel == FormSupportLevel.limited) &&
      variants.any((FormProfileVariant variant) => variant.rules.isNotEmpty);
}
