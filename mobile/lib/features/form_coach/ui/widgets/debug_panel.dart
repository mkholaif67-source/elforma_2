// Form Coach - developer calibration panel (hidden from normal users).
//
// Enabled by a long press on the screen title. It exposes exactly what is needed
// to calibrate a Form Profile without touching the engine: live measurements,
// per-rule state (candidate vs fired vs blocked and why), phase, counters,
// readiness diagnostics and frame performance.

import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';
import 'package:flutter/material.dart';

class DebugPanel extends StatelessWidget {
  const DebugPanel({super.key, required this.snapshot, required this.variantId});

  final FormCoachSnapshot snapshot;
  final String variantId;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontFamily: 'monospace',
            height: 1.45,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('variant: $variantId'),
                Text(
                  'stage=${snapshot.stage.name} verdict=${snapshot.verdict.name} '
                  'reason=${snapshot.cannotAssessReason.name}',
                ),
                Text(
                  'phase=${snapshot.phase.name} (${repPhaseAr(snapshot.phase)}) '
                  'side=${snapshot.activeSide == null ? '-' : snapshot.activeSide!.name}',
                ),
                Text(
                  'reps=${snapshot.reps}/${snapshot.targetReps ?? '-'} '
                  'partials=${snapshot.partialReps} '
                  'held=${(snapshot.heldMs / 1000).toStringAsFixed(1)}s '
                  'elapsed=${(snapshot.elapsedMs / 1000).toStringAsFixed(1)}s',
                ),
                Text(
                  'fps=${snapshot.fps.toStringAsFixed(1)} '
                  'inference=${snapshot.inferenceMs.toStringAsFixed(0)}ms '
                  'dropped=${snapshot.droppedFrames}',
                ),
                Text(
                  'readiness ok=${snapshot.readiness.ok} '
                  'view=${snapshot.readiness.detectedView.name} '
                  'torso=${snapshot.readiness.torsoFraction.toStringAsFixed(2)} '
                  'spread=${snapshot.readiness.spreadRatio.toStringAsFixed(2)} '
                  'vis=${snapshot.readiness.meanVisibility.toStringAsFixed(2)}',
                ),
                if (snapshot.readiness.issues.isNotEmpty)
                  Text('issues=${snapshot.readiness.issues.map((Object i) => (i as Enum).name).join(',')}'),
                const SizedBox(height: 6),
                const Text('-- metrics --'),
                ..._metricLines(),
                const SizedBox(height: 6),
                const Text('-- rules --'),
                ..._ruleLines(),
                const SizedBox(height: 6),
                Text(
                  'candidate=${_candidate() ?? '-'}  fired=${snapshot.lastCue?.id ?? '-'}',
                ),
                Text('landmarks=${snapshot.pose?.points.length ?? 0}/${FcLandmark.values.length}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _metricLines() {
    final MetricSet metrics = snapshot.metrics;
    if (metrics.isEmpty) return <Widget>[const Text('(none)')];
    final List<Widget> lines = <Widget>[
      Text('scale=${metrics.scale.toStringAsFixed(3)}'),
    ];
    final List<String> keys = metrics.values.keys.toList()..sort();
    for (final String key in keys) {
      final MetricReading? reading = metrics[key];
      if (reading == null) continue;
      lines.add(Text(
        '$key = ${reading.value.toStringAsFixed(2)} '
        '(conf ${reading.confidence.toStringAsFixed(2)}'
        '${reading.side == null ? '' : ', ${reading.side!.name}'})',
      ));
    }
    return lines;
  }

  List<Widget> _ruleLines() {
    if (snapshot.ruleStates.isEmpty) {
      return <Widget>[const Text('(profile has no form rules)')];
    }
    return snapshot.ruleStates.map((FormRuleState state) {
      final String value =
          state.value == null ? '-' : state.value!.toStringAsFixed(2);
      return Text(
        '${state.ruleId}: val=$value mag=${state.magnitude.toStringAsFixed(2)} '
        'conf=${state.confidence.toStringAsFixed(2)} '
        'hold=${state.violationMs}ms cons=${state.consistency.toStringAsFixed(2)} '
        '${state.candidate ? 'CANDIDATE ' : ''}${state.fired ? 'FIRED ' : ''}'
        'fires=${state.firesThisSet}'
        '${state.blockedReason == null ? '' : ' blocked=${state.blockedReason}'}',
      );
    }).toList();
  }

  String? _candidate() {
    for (final FormRuleState state in snapshot.ruleStates) {
      if (state.candidate) return state.ruleId;
    }
    return null;
  }
}
