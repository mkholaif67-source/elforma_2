// Form Coach - scene/subject stability.
//
// Single-person tracking cannot distinguish the user from someone walking in
// front of the camera, nor a body movement from the phone being moved. Both look
// the same: a sudden jump in body scale or hip position. When that happens we ask
// the engine to stay silent until the scene settles rather than blaming the user
// for an error we did not really observe.

import 'package:elforma/features/form_coach/domain/fc_geometry.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/fc_tuning.dart';

class SubjectTracker {
  double? _scale;
  FcPoint? _hip;
  int _settleUntilMs = 0;
  int _changes = 0;

  int get changeCount => _changes;

  bool unstableAt(int tMs) => tMs < _settleUntilMs;

  /// Returns true when a scene change was detected on this frame.
  bool update(PoseSample? sample, int tMs) {
    if (sample == null || sample.isEmpty) {
      // Pose loss is handled elsewhere; re-acquisition just re-seeds the reference.
      _scale = null;
      _hip = null;
      return false;
    }

    final double? scale = FcGeometry.bodyScale(sample);
    final List<FcPoint>? axis = FcGeometry.torsoAxis(sample);
    final FcPoint? hip = axis == null ? null : axis[0];
    if (scale == null || hip == null) return false;

    final double? previousScale = _scale;
    final FcPoint? previousHip = _hip;
    _scale = scale;
    _hip = hip;
    if (previousScale == null || previousHip == null) return false;

    final double scaleJump =
        (scale - previousScale).abs() / (previousScale <= 1e-3 ? 1e-3 : previousScale);
    final double shiftInTorso = FcGeometry.distance(hip, previousHip) / scale;

    final bool changed = scaleJump > FcTuning.subjectScaleJumpRatio ||
        shiftInTorso > FcTuning.subjectShiftInTorso;
    if (changed) {
      _changes++;
      _settleUntilMs = tMs + FcTuning.subjectSettleMs;
    }
    return changed;
  }

  void reset() {
    _scale = null;
    _hip = null;
    _settleUntilMs = 0;
    _changes = 0;
  }
}
