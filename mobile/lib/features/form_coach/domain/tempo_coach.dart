import 'package:elforma/features/form_coach/domain/rep_cycle.dart';
import 'package:elforma/features/form_coach/domain/fc_tuning.dart';

/// Session-prescribed timing only. No biomechanical judgments or guessed target.
class TempoCoach {
  int fastReps = 0;
  int _fastStreak = 0;
  int _cleanStreak = 0;
  bool improved = false;
  bool improvementPending = false;
  bool get warningReady => _fastStreak >= FcTuning.fastRepsBeforeCue;

  void observe(RepEvent event, int? prescribed) {
    if (prescribed == null ||
        prescribed <= 0 ||
        !event.assessable ||
        event.kind != RepEventKind.repCompleted) {
      interrupt();
      return;
    }
    if (event.durationMs < prescribed * FcTuning.tempoFastRatio) {
      fastReps++;
      _fastStreak++;
      _cleanStreak = 0;
      improved = false;
      improvementPending = false;
    } else {
      _fastStreak = 0;
      if (fastReps > 0 && ++_cleanStreak >= 2 && !improved) {
        improved = true;
        improvementPending = true;
      }
    }
  }

  void markWarningSpoken() => _fastStreak = 0;
  void markImprovementSpoken() => improvementPending = false;
  void interrupt() {
    _fastStreak = 0;
    _cleanStreak = 0;
    improvementPending = false;
  }

  void reset() {
    interrupt();
    fastReps = 0;
    improved = false;
  }
}
