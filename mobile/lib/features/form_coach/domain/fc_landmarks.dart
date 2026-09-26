// Form Coach - neutral landmark model, independent of the pose library.
// Coordinates are normalized 0..1 in the rotation-corrected image.
// z is an estimate from a single view: debug/overlay only, never used by a rule.

import 'dart:math' as math;

enum FcJoint { nose, ear, shoulder, elbow, wrist, hip, knee, ankle, heel, footIndex }

enum FcSide { left, right }

String fcSideAr(FcSide side) => side == FcSide.left ? 'الشمال' : 'اليمين';

enum FcLandmark {
  nose,
  leftEar,
  rightEar,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

FcLandmark fcLandmarkFor(FcJoint joint, FcSide side) {
  final bool left = side == FcSide.left;
  switch (joint) {
    case FcJoint.nose:
      return FcLandmark.nose;
    case FcJoint.ear:
      return left ? FcLandmark.leftEar : FcLandmark.rightEar;
    case FcJoint.shoulder:
      return left ? FcLandmark.leftShoulder : FcLandmark.rightShoulder;
    case FcJoint.elbow:
      return left ? FcLandmark.leftElbow : FcLandmark.rightElbow;
    case FcJoint.wrist:
      return left ? FcLandmark.leftWrist : FcLandmark.rightWrist;
    case FcJoint.hip:
      return left ? FcLandmark.leftHip : FcLandmark.rightHip;
    case FcJoint.knee:
      return left ? FcLandmark.leftKnee : FcLandmark.rightKnee;
    case FcJoint.ankle:
      return left ? FcLandmark.leftAnkle : FcLandmark.rightAnkle;
    case FcJoint.heel:
      return left ? FcLandmark.leftHeel : FcLandmark.rightHeel;
    case FcJoint.footIndex:
      return left ? FcLandmark.leftFootIndex : FcLandmark.rightFootIndex;
  }
}

class FcPoint {
  const FcPoint({
    required this.x,
    required this.y,
    required this.visibility,
    this.z = 0,
  });

  final double x;
  final double y;
  final double z;

  /// 0..1 tracking confidence for this point.
  final double visibility;

  FcPoint copyWith({double? x, double? y, double? z, double? visibility}) => FcPoint(
        x: x ?? this.x,
        y: y ?? this.y,
        z: z ?? this.z,
        visibility: visibility ?? this.visibility,
      );

  @override
  String toString() =>
      '(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}) v=${visibility.toStringAsFixed(2)}';
}

class FcBounds {
  const FcBounds(this.minX, this.minY, this.maxX, this.maxY);

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;
  double get centerX => (minX + maxX) / 2;
  double get centerY => (minY + maxY) / 2;
}

/// One pose reading: points only, no image bytes are ever retained.
class PoseSample {
  const PoseSample({required this.timestampMs, required this.points, this.imageAspect = 1});

  factory PoseSample.empty(int timestampMs) =>
      PoseSample(timestampMs: timestampMs, points: const <FcLandmark, FcPoint>{});

  final int timestampMs;
  final Map<FcLandmark, FcPoint> points;
  final double imageAspect;

  /// Geometry needs equal units on both axes; overlay keeps normalized UVs.
  PoseSample get metricSpace => PoseSample(timestampMs: timestampMs, points: {
    for (final entry in points.entries)
      entry.key: entry.value.copyWith(x: entry.value.x * imageAspect),
  });

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  /// null means unknown, never zero.
  FcPoint? point(FcLandmark landmark, {double minVisibility = 0}) {
    final FcPoint? value = points[landmark];
    if (value == null || !value.x.isFinite || !value.y.isFinite ||
        !value.visibility.isFinite) return null;
    if (value.visibility < minVisibility) return null;
    return value;
  }

  FcPoint? joint(FcJoint joint, FcSide side, {double minVisibility = 0}) =>
      point(fcLandmarkFor(joint, side), minVisibility: minVisibility);

  /// A measurement is only as trustworthy as its weakest landmark.
  double confidenceOf(Iterable<FcLandmark> landmarks) {
    double minimum = 1;
    bool any = false;
    for (final FcLandmark landmark in landmarks) {
      final FcPoint? value = points[landmark];
      if (value == null) return 0;
      any = true;
      minimum = math.min(minimum, value.visibility);
    }
    return any ? minimum : 0;
  }

  FcBounds? boundsOf(Iterable<FcLandmark> landmarks, {double minVisibility = 0}) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    bool any = false;
    for (final FcLandmark landmark in landmarks) {
      final FcPoint? value = point(landmark, minVisibility: minVisibility);
      if (value == null) continue;
      any = true;
      minX = math.min(minX, value.x);
      minY = math.min(minY, value.y);
      maxX = math.max(maxX, value.x);
      maxY = math.max(maxY, value.y);
    }
    if (!any) return null;
    return FcBounds(minX, minY, maxX, maxY);
  }

  double get meanVisibility {
    if (points.isEmpty) return 0;
    double sum = 0;
    for (final FcPoint value in points.values) {
      sum += value.visibility;
    }
    return sum / points.length;
  }
}

/// Edges used by the debug skeleton overlay.
const List<List<FcLandmark>> kFcSkeletonEdges = <List<FcLandmark>>[
  <FcLandmark>[FcLandmark.leftShoulder, FcLandmark.rightShoulder],
  <FcLandmark>[FcLandmark.leftShoulder, FcLandmark.leftElbow],
  <FcLandmark>[FcLandmark.leftElbow, FcLandmark.leftWrist],
  <FcLandmark>[FcLandmark.rightShoulder, FcLandmark.rightElbow],
  <FcLandmark>[FcLandmark.rightElbow, FcLandmark.rightWrist],
  <FcLandmark>[FcLandmark.leftShoulder, FcLandmark.leftHip],
  <FcLandmark>[FcLandmark.rightShoulder, FcLandmark.rightHip],
  <FcLandmark>[FcLandmark.leftHip, FcLandmark.rightHip],
  <FcLandmark>[FcLandmark.leftHip, FcLandmark.leftKnee],
  <FcLandmark>[FcLandmark.leftKnee, FcLandmark.leftAnkle],
  <FcLandmark>[FcLandmark.rightHip, FcLandmark.rightKnee],
  <FcLandmark>[FcLandmark.rightKnee, FcLandmark.rightAnkle],
  <FcLandmark>[FcLandmark.leftAnkle, FcLandmark.leftHeel],
  <FcLandmark>[FcLandmark.leftHeel, FcLandmark.leftFootIndex],
  <FcLandmark>[FcLandmark.rightAnkle, FcLandmark.rightHeel],
  <FcLandmark>[FcLandmark.rightHeel, FcLandmark.rightFootIndex],
];
