import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

enum RepQuality {
  supportedChecksPassed,
  supportedError,
  cannotAssess,
  trackingOnly
}

class RepQualityResult {
  const RepQualityResult(this.quality, this.errors, this.improved);
  final RepQuality quality;
  final Set<String> errors;
  final Set<String> improved;
}

class CorrectionSummary {
  const CorrectionSummary(
      this.ruleId, this.cueAr, this.errorReps, this.improved);
  final String ruleId;
  final String cueAr;
  final int errorReps;
  final bool improved;
}

/// Session-local evidence, independent of speech cooldown or cue budgets.
/// Silence is never evidence of correct technique.
class CorrectionHistory {
  final Map<String, int> _errors = {};
  final List<RepQualityResult> _recent = [];
  List<RepQualityResult> get recentReps => List.unmodifiable(_recent);
  final Map<String, int> _cleanStreak = {};
  final Set<String> _improved = {};
  final Set<String> _cycleErrors = {};
  final Map<String, int> _observedMs = {};
  final Map<String, Set<RepPhase>> _phases = {};
  final Set<String> _previousEvaluable = {};
  int? _lastMs;
  bool _gap = false;

  void observe(int tMs, RepPhase phase, List<FormRuleState> states,
      {required bool usable}) {
    final delta = _lastMs == null ? 0 : tMs - _lastMs!;
    _lastMs = tMs;
    if (!usable || delta < 0 || delta > 250) _gap = true;
    final current = <String>{};
    for (final state in states) {
      if (!state.evaluable && state.blockedReason != 'phase') _gap = true;
      if (!usable || !state.evaluable) continue;
      current.add(state.ruleId);
      if (_previousEvaluable.contains(state.ruleId) &&
          delta > 0 &&
          delta <= 250) {
        _observedMs.update(state.ruleId, (n) => n + delta,
            ifAbsent: () => delta);
      }
      _phases.putIfAbsent(state.ruleId, () => {}).add(phase);
      if (state.candidate) _cycleErrors.add(state.ruleId);
    }
    _previousEvaluable
      ..clear()
      ..addAll(current);
  }

  RepQualityResult finish(List<FormRule> rules, {required bool assessable}) {
    final improved = <String>{};
    final errors = Set<String>.of(_cycleErrors);
    bool allCovered = rules.isNotEmpty && assessable && !_gap;
    for (final rule in rules) {
      final phases = _phases[rule.id] ?? {};
      final covered = assessable &&
          !_gap &&
          (_observedMs[rule.id] ?? 0) >= 250 &&
          phases.contains(RepPhase.towardBottom) &&
          phases.contains(RepPhase.towardTop);
      allCovered = allCovered && covered;
      if (errors.contains(rule.id)) {
        _errors.update(rule.id, (n) => n + 1, ifAbsent: () => 1);
        _cleanStreak[rule.id] = 0;
        _improved.remove(rule.id);
      } else if (covered && _errors.containsKey(rule.id)) {
        final streak = (_cleanStreak[rule.id] ?? 0) + 1;
        _cleanStreak[rule.id] = streak;
        if (streak >= 2 && _improved.add(rule.id)) improved.add(rule.id);
      } else {
        _cleanStreak[rule.id] = 0;
      }
    }
    final quality = !assessable
        ? RepQuality.cannotAssess
        : rules.isEmpty
            ? RepQuality.trackingOnly
            : errors.isNotEmpty
                ? RepQuality.supportedError
                : allCovered
                    ? RepQuality.supportedChecksPassed
                    : RepQuality.cannotAssess;
    resetCycle();
    final result = RepQualityResult(
        quality, Set.unmodifiable(errors), Set.unmodifiable(improved));
    _recent.add(result);
    if (_recent.length > 100) _recent.removeAt(0);
    return result;
  }

  List<CorrectionSummary> summary(List<FormRule> rules) => [
        for (final rule in rules)
          if (_errors.containsKey(rule.id))
            CorrectionSummary(rule.id, rule.cueAr, _errors[rule.id]!,
                _improved.contains(rule.id)),
      ];

  void resetCycle() {
    _cycleErrors.clear();
    _observedMs.clear();
    _phases.clear();
    _previousEvaluable.clear();
    _lastMs = null;
    _gap = false;
  }

  void interrupt() {
    resetCycle();
    _cleanStreak.clear();
  }

  void reset() {
    interrupt();
    _errors.clear();
    _improved.clear();
    _recent.clear();
  }
}
