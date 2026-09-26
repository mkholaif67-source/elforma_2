import 'dart:math' as math;
import 'package:elforma/features/form_coach/domain/fc_tuning.dart';

/// Bounded local metrics; no camera bytes, disk writes, or telemetry.
class AnalysisPacing {
  AnalysisPacing({int requestedFps = FcTuning.targetAnalysisFps})
      : baseIntervalMs = 1000 ~/
            (const [8, 10, 12, 15].contains(requestedFps)
                ? requestedFps
                : FcTuning.targetAnalysisFps) {
    intervalMs = baseIntervalMs;
  }
  final int baseIntervalMs;
  late int intervalMs;
  double? _costEma;
  int _slow = 0, _fast = 0;
  final List<double> _costs = [];
  double get p50Ms => _percentile(0.5);
  double get p95Ms => _percentile(0.95);

  void observe(double processingMs, {bool recording = false}) {
    if (!processingMs.isFinite || processingMs < 0) return;
    _costs.add(processingMs);
    if (_costs.length > 120) _costs.removeAt(0);
    _costEma =
        _costEma == null ? processingMs : _costEma! * 0.8 + processingMs * 0.2;
    // Recording has extra encoder work that is not represented by ML latency.
    // A sustained high duty cycle backs off; one isolated spike does not.
    final budget = recording ? 0.65 : 0.8;
    final overloaded =
        _costEma! > FcTuning.slowInferenceMs && _costEma! / intervalMs > budget;
    if (overloaded) {
      _fast = 0;
      if (++_slow >= 3) {
        intervalMs = math.min(FcTuning.maxFrameIntervalMs, intervalMs + 15);
        _slow = 0;
      }
    } else {
      _slow = 0;
      if (_costEma! / intervalMs < budget - 0.15) {
        if (++_fast >= 15) {
          intervalMs = math.max(baseIntervalMs, intervalMs - 5);
          _fast = 0;
        }
      } else {
        _fast = 0;
      }
    }
  }

  double _percentile(double p) {
    if (_costs.isEmpty) return 0;
    final sorted = List<double>.of(_costs)..sort();
    return sorted[((sorted.length - 1) * p).ceil()];
  }
}
