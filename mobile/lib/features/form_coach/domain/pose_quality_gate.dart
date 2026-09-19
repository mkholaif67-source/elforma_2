import 'dart:math' as math;
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/fc_geometry.dart';

/// Reject before smoothing: likelihood describes visibility, not a guarantee
/// of human anatomy. Never fabricate a missing joint or carry it into judging.
class PoseQualityGate {
  int? _candidateSince;
  int? _lastMs;
  FcPoint? _center;
  double? _scale;
  bool _tracked = false;
  Map<FcLandmark, FcPoint> _previous = {};

  PoseSample filter(PoseSample sample) {
    final points = <FcLandmark, FcPoint>{
      for (final e in sample.points.entries)
        if (e.value.x.isFinite && e.value.y.isFinite && e.value.z.isFinite &&
            e.value.visibility.isFinite && e.value.visibility >= .65 &&
            e.value.x >= 0 && e.value.x <= 1 && e.value.y >= 0 && e.value.y <= 1)
          e.key: e.value,
    };
    final aspect = sample.imageAspect;
    double distance(FcPoint a, FcPoint b) => math.sqrt(
      math.pow((a.x - b.x) * aspect, 2) + math.pow(a.y - b.y, 2));
    final torsos = <double>[];
    final centers = <FcPoint>[];
    for (final side in FcSide.values) {
      final shoulder = points[fcLandmarkFor(FcJoint.shoulder, side)];
      final hip = points[fcLandmarkFor(FcJoint.hip, side)];
      if (shoulder == null || hip == null) continue;
      final length = distance(shoulder, hip);
      if (length >= .06 && length <= .85) {
        torsos.add(length);
        centers.add(FcGeometry.midpoint(shoulder, hip));
      } else {
        points.remove(fcLandmarkFor(FcJoint.hip, side));
      }
    }
    // Required arm/torso landmarks may be visible while the head is cropped.
    if (torsos.isEmpty || points.length < 4 || !aspect.isFinite || aspect <= 0) {
      reset();
      return PoseSample.empty(sample.timestampMs);
    }
    final scale = FcGeometry.median(torsos)!;
    final dt = _lastMs == null ? 0.0 : (sample.timestampMs - _lastMs!) / 1000;
    if (dt > 0 && dt < .5) {
      points.removeWhere((key, point) {
        final previous = _previous[key];
        return previous != null && distance(previous, point) > scale * (.35 + 8 * dt);
      });
    }
    // Reject disconnected/impossible chains; a hidden distal joint cannot
    // become a free-floating dot or a bone connected through a missing parent.
    for (final side in FcSide.values) {
      for (final chain in [
        [FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist],
        [FcJoint.hip, FcJoint.knee, FcJoint.ankle, FcJoint.heel, FcJoint.footIndex],
      ]) {
        for (var i = 1; i < chain.length; i++) {
          final parent = points[fcLandmarkFor(chain[i - 1], side)];
          final key = fcLandmarkFor(chain[i], side);
          final child = points[key];
          final maxRatio = i >= 3 ? .65 : 1.6;
          if (parent == null || (child != null && distance(parent, child) > scale * maxRatio)) {
            points.remove(key);
          }
        }
      }
    }
    final center = centers.first;
    final discontinuity = _lastMs != null &&
        (sample.timestampMs <= _lastMs! || sample.timestampMs - _lastMs! > 500 ||
         distance(center, _center!) > scale * .8 ||
         (scale - _scale!).abs() / _scale! > .45);
    if (discontinuity) {
      _tracked = false;
      _candidateSince = null;
    }
    _center = center;
    _scale = scale;
    _lastMs = sample.timestampMs;
    _previous = Map.of(points);
    _candidateSince ??= sample.timestampMs;
    _tracked = _tracked || sample.timestampMs - _candidateSince! >= 200;
    return PoseSample(timestampMs: sample.timestampMs,
        imageAspect: aspect, points: _tracked ? points : const {});
  }

  void reset() {
    _candidateSince = null;
    _lastMs = null;
    _center = null;
    _scale = null;
    _tracked = false;
    _previous = {};
  }
}
