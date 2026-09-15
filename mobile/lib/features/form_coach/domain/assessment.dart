// Form Coach - the single read-only snapshot the UI renders.
// Four states only: correct | clearError | cannotAssess | finished.
// cannotAssess is never presented to the user as a mistake.

import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

enum FormCoachStage { starting, readyCheck, countdown, live, finished }

enum FormVerdict { correct, clearError, cannotAssess, finished }

enum CannotAssessReason {
  none,
  warmingUp,
  noPose,
  lowVisibility,
  outOfFrame,
  subjectChanged,
  wrongView,
  lowFps,
  unknownMovement,
}

String cannotAssessReasonAr(CannotAssessReason reason) {
  switch (reason) {
    case CannotAssessReason.none:
      return '';
    case CannotAssessReason.warmingUp:
      return 'بستعد...';
    case CannotAssessReason.noPose:
      return 'مش شايفك دلوقتي';
    case CannotAssessReason.lowVisibility:
      return 'الرؤية مش واضحة كفاية';
    case CannotAssessReason.outOfFrame:
      return 'جسمك خارج الكادر';
    case CannotAssessReason.subjectChanged:
      return 'المشهد اتغير';
    case CannotAssessReason.wrongView:
      return 'زاوية التصوير مش مناسبة';
    case CannotAssessReason.lowFps:
      return 'الأداء منخفض على الجهاز';
    case CannotAssessReason.unknownMovement:
      return 'الحركة مش مطابقة للتمرين';
  }
}

enum FormCueKind { formError, rangeShort, tempo, setFinished, info }

class FormCue {
  const FormCue({
    required this.id,
    required this.textAr,
    required this.kind,
    required this.severity,
    required this.priority,
    required this.tMs,
    this.detailAr = '',
  });

  final String id;
  final String textAr;
  final String detailAr;
  final FormCueKind kind;
  final RuleSeverity severity;
  final int priority;
  final int tMs;
}

class FormCoachSnapshot {
  const FormCoachSnapshot({
    required this.stage,
    required this.verdict,
    required this.cannotAssessReason,
    required this.phase,
    required this.reps,
    required this.partialReps,
    required this.targetReps,
    required this.targetSeconds,
    required this.heldMs,
    required this.elapsedMs,
    required this.readiness,
    required this.cue,
    required this.lastCue,
    required this.ruleStates,
    required this.metrics,
    required this.activeSide,
    required this.activeVariantId,
    required this.pose,
    required this.fps,
    required this.inferenceMs,
    required this.droppedFrames,
    required this.statusTextAr,
    this.countdownRemainingMs = 0,
  });

  final FormCoachStage stage;
  final FormVerdict verdict;
  final CannotAssessReason cannotAssessReason;
  final RepPhase phase;

  /// Runtime only: never written to the database or to progress.
  final int reps;
  final int partialReps;
  final int? targetReps;
  final int? targetSeconds;
  final int heldMs;
  final int elapsedMs;

  final ReadinessReport? readiness;

  /// Cue produced on this frame; null most of the time (silence is normal).
  final FormCue? cue;
  final FormCue? lastCue;

  final List<FormRuleState> ruleStates;
  final Map<String, MetricReading> metrics;
  final FcSide? activeSide;
  final String? activeVariantId;

  /// Smoothed pose for the overlay: points only, no image data.
  final PoseSample? pose;

  final double fps;
  final double inferenceMs;
  final int droppedFrames;
  final int countdownRemainingMs;
  final String statusTextAr;

  bool get isLive => stage == FormCoachStage.live;
  bool get isFinished => stage == FormCoachStage.finished;

  double get repProgress {
    final int? target = targetReps;
    if (target != null && target > 0) return (reps / target).clamp(0.0, 1.0);
    final int? seconds = targetSeconds;
    if (seconds != null && seconds > 0) {
      return (heldMs / (seconds * 1000)).clamp(0.0, 1.0);
    }
    return 0;
  }
}
