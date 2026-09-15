// Form Coach - measurements layer.
//
// Profiles contain no geometry code: they declare WHICH measurements they need
// and this evaluator produces them per frame, each with its own confidence.
// Rules then judge numbers, not pixels.

import 'dart:math' as math;

import 'package:elforma/features/form_coach/domain/fc_geometry.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/fc_tuning.dart';

enum MetricKind {
  /// Angle at joints[1] between joints[0] and joints[2] (degrees).
  jointAngle,

  /// Absolute tilt of joints[0]->joints[1] from vertical (degrees).
  segmentTilt,

  /// Signed tilt: + towards frame right.
  signedSegmentTilt,

  /// Limb angle from the torso axis: 0 = along torso, 90 = horizontal.
  limbAbductionFromTorso,

  /// (joints[1].x - joints[0].x) / body scale.
  normalizedHorizontalOffset,

  /// (joints[1].y - joints[0].y) / body scale.
  normalizedVerticalOffset,

  /// distance(joints[0], joints[1]) / body scale.
  normalizedDistance,

  /// |sources[0] - sources[1]| (left/right asymmetry).
  absoluteDifference,

  /// sources[0] - personal baseline of sources[0].
  deltaFromBaseline,

  /// |sources[0] - personal baseline of sources[0]|.
  absoluteDeltaFromBaseline,
}

enum MetricSide { left, right, mean, activeSide, maxValue, minValue }

class MetricSpec {
  const MetricSpec({
    required this.id,
    required this.kind,
    this.joints = const <FcJoint>[],
    this.sources = const <String>[],
    this.side = MetricSide.activeSide,
    this.labelAr = '',
    this.unit = '°',
    this.captureBaseline = false,
  });

  final String id;
  final MetricKind kind;
  final List<FcJoint> joints;

  /// Other metric ids, for derived kinds.
  final List<String> sources;

  final MetricSide side;
  final String labelAr;
  final String unit;

  /// Capture the user's own neutral value during warm-up.
  final bool captureBaseline;

  bool get isDerived =>
      kind == MetricKind.absoluteDifference ||
      kind == MetricKind.deltaFromBaseline ||
      kind == MetricKind.absoluteDeltaFromBaseline;
}

class MetricReading {
  const MetricReading({required this.value, required this.confidence, this.side});

  final double value;
  final double confidence;
  final FcSide? side;

  @override
  String toString() => '${value.toStringAsFixed(1)} (c=${confidence.toStringAsFixed(2)})';
}

class MetricSet {
  const MetricSet({required this.values, this.scale, this.activeSide});

  static const MetricSet empty = MetricSet(values: <String, MetricReading>{});

  final Map<String, MetricReading> values;
  final double? scale;
  final FcSide? activeSide;

  MetricReading? operator [](String id) => values[id];

  bool get isEmpty => values.isEmpty;
}

class _Raw {
  const _Raw(this.value, this.confidence, this.side);
  final double value;
  final double confidence;
  final FcSide? side;
}

class MetricEvaluator {
  MetricEvaluator(this.specs);

  final List<MetricSpec> specs;

  MetricSet evaluate(
    PoseSample sample, {
    FcSide? activeSide,
    Map<String, double> baselines = const <String, double>{},
    double minVisibility = FcTuning.landmarkHardFloor,
  }) {
    final double? scale = FcGeometry.bodyScale(sample, minVisibility: minVisibility);
    final Map<String, MetricReading> out = <String, MetricReading>{};

    for (final MetricSpec spec in specs) {
      if (spec.isDerived) continue;
      final _Raw? raw = _direct(spec, sample, activeSide, minVisibility, scale);
      if (raw != null) {
        out[spec.id] =
            MetricReading(value: raw.value, confidence: raw.confidence, side: raw.side);
      }
    }
    for (final MetricSpec spec in specs) {
      if (!spec.isDerived) continue;
      final MetricReading? derived = _derived(spec, out, baselines);
      if (derived != null) out[spec.id] = derived;
    }

    return MetricSet(values: out, scale: scale, activeSide: activeSide);
  }

  _Raw? _direct(
    MetricSpec spec,
    PoseSample sample,
    FcSide? activeSide,
    double minVisibility,
    double? scale,
  ) {
    switch (spec.side) {
      case MetricSide.left:
        return _forSide(spec, sample, FcSide.left, minVisibility, scale);
      case MetricSide.right:
        return _forSide(spec, sample, FcSide.right, minVisibility, scale);
      case MetricSide.activeSide:
        if (activeSide != null) {
          final _Raw? chosen = _forSide(spec, sample, activeSide, minVisibility, scale);
          if (chosen != null) return chosen;
        }
        return _bestConfidence(spec, sample, minVisibility, scale);
      case MetricSide.mean:
        final _Raw? left = _forSide(spec, sample, FcSide.left, minVisibility, scale);
        final _Raw? right = _forSide(spec, sample, FcSide.right, minVisibility, scale);
        if (left == null) return right;
        if (right == null) return left;
        return _Raw((left.value + right.value) / 2,
            math.min(left.confidence, right.confidence), null);
      case MetricSide.maxValue:
      case MetricSide.minValue:
        final _Raw? a = _forSide(spec, sample, FcSide.left, minVisibility, scale);
        final _Raw? b = _forSide(spec, sample, FcSide.right, minVisibility, scale);
        if (a == null) return b;
        if (b == null) return a;
        final bool takeA =
            spec.side == MetricSide.maxValue ? a.value >= b.value : a.value <= b.value;
        return takeA ? a : b;
    }
  }

  _Raw? _bestConfidence(
    MetricSpec spec,
    PoseSample sample,
    double minVisibility,
    double? scale,
  ) {
    final _Raw? left = _forSide(spec, sample, FcSide.left, minVisibility, scale);
    final _Raw? right = _forSide(spec, sample, FcSide.right, minVisibility, scale);
    if (left == null) return right;
    if (right == null) return left;
    return left.confidence >= right.confidence ? left : right;
  }

  _Raw? _forSide(
    MetricSpec spec,
    PoseSample sample,
    FcSide side,
    double minVisibility,
    double? scale,
  ) {
    final List<FcLandmark> used = <FcLandmark>[];
    FcPoint? at(int index) {
      if (index >= spec.joints.length) return null;
      final FcLandmark landmark = fcLandmarkFor(spec.joints[index], side);
      final FcPoint? point = sample.point(landmark, minVisibility: minVisibility);
      if (point != null) used.add(landmark);
      return point;
    }

    double? value;
    switch (spec.kind) {
      case MetricKind.jointAngle:
        value = FcGeometry.angleAt(at(0), at(1), at(2));
        break;
      case MetricKind.segmentTilt:
        value = FcGeometry.tiltFromVertical(at(0), at(1));
        break;
      case MetricKind.signedSegmentTilt:
        value = FcGeometry.signedTiltFromVertical(at(0), at(1));
        break;
      case MetricKind.limbAbductionFromTorso:
        final FcPoint? root = at(0);
        final FcPoint? tip = at(1);
        FcPoint? hip = sample.joint(FcJoint.hip, side, minVisibility: minVisibility);
        if (hip != null) {
          used.add(fcLandmarkFor(FcJoint.hip, side));
        } else {
          final List<FcPoint>? axis =
              FcGeometry.torsoAxis(sample, minVisibility: minVisibility);
          hip = axis == null ? null : axis[0];
        }
        value = FcGeometry.angleBetweenSegments(root, hip, root, tip);
        break;
      case MetricKind.normalizedHorizontalOffset:
        final FcPoint? a = at(0);
        final FcPoint? b = at(1);
        if (a != null && b != null && scale != null && scale > 1e-3) {
          value = (b.x - a.x) / scale;
        }
        break;
      case MetricKind.normalizedVerticalOffset:
        final FcPoint? a = at(0);
        final FcPoint? b = at(1);
        if (a != null && b != null && scale != null && scale > 1e-3) {
          value = (b.y - a.y) / scale;
        }
        break;
      case MetricKind.normalizedDistance:
        final FcPoint? a = at(0);
        final FcPoint? b = at(1);
        if (a != null && b != null && scale != null && scale > 1e-3) {
          value = FcGeometry.distance(a, b) / scale;
        }
        break;
      case MetricKind.absoluteDifference:
      case MetricKind.deltaFromBaseline:
      case MetricKind.absoluteDeltaFromBaseline:
        return null;
    }

    if (value == null) return null;
    if (used.length < _expectedLandmarkCount(spec)) return null;
    return _Raw(value, sample.confidenceOf(used), side);
  }

  static int _expectedLandmarkCount(MetricSpec spec) {
    switch (spec.kind) {
      case MetricKind.jointAngle:
        return 3;
      case MetricKind.limbAbductionFromTorso:
      case MetricKind.segmentTilt:
      case MetricKind.signedSegmentTilt:
      case MetricKind.normalizedHorizontalOffset:
      case MetricKind.normalizedVerticalOffset:
      case MetricKind.normalizedDistance:
        return 2;
      case MetricKind.absoluteDifference:
      case MetricKind.deltaFromBaseline:
      case MetricKind.absoluteDeltaFromBaseline:
        return 0;
    }
  }

  MetricReading? _derived(
    MetricSpec spec,
    Map<String, MetricReading> computed,
    Map<String, double> baselines,
  ) {
    if (spec.sources.isEmpty) return null;
    final MetricReading? first = computed[spec.sources.first];
    if (first == null) return null;

    switch (spec.kind) {
      case MetricKind.absoluteDifference:
        if (spec.sources.length < 2) return null;
        final MetricReading? second = computed[spec.sources[1]];
        if (second == null) return null;
        return MetricReading(
          value: (first.value - second.value).abs(),
          confidence: math.min(first.confidence, second.confidence),
        );
      case MetricKind.deltaFromBaseline:
      case MetricKind.absoluteDeltaFromBaseline:
        final double? baseline = baselines[spec.sources.first];
        if (baseline == null) return null;
        final double delta = first.value - baseline;
        return MetricReading(
          value: spec.kind == MetricKind.deltaFromBaseline ? delta : delta.abs(),
          confidence: first.confidence,
          side: first.side,
        );
      case MetricKind.jointAngle:
      case MetricKind.segmentTilt:
      case MetricKind.signedSegmentTilt:
      case MetricKind.limbAbductionFromTorso:
      case MetricKind.normalizedHorizontalOffset:
      case MetricKind.normalizedVerticalOffset:
      case MetricKind.normalizedDistance:
        return null;
    }
  }
}
