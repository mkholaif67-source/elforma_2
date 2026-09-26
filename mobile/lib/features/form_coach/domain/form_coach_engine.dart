import 'package:elforma/features/form_coach/domain/tempo_coach.dart';
import 'package:elforma/features/form_coach/domain/correction_history.dart';
// Form Coach - the engine. Pure Dart: no Flutter, no camera, no IO.
//
// It takes one pose sample at a time and returns an immutable snapshot, so the
// whole judgement pipeline is unit-testable and replayable without a device.
//
// Per frame: smoothing -> scene stability -> readiness -> metrics -> phases/reps
//            -> rules (tolerance + persistence + consistency) -> cue arbitration
//            -> verdict.
// Stages: starting -> readyCheck -> countdown (warm-up + personal baselines)
//         -> live -> finished. If the situation becomes unassessable we go back
//         to readyCheck instead of guessing, keeping the rep count.

import 'dart:math' as math;

import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/fc_geometry.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/fc_tuning.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/pose_smoother.dart';
import 'package:elforma/features/form_coach/domain/pose_quality_gate.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';
import 'package:elforma/features/form_coach/domain/subject_tracker.dart';

/// Read-only copy of the set being watched. The engine never writes back.
class FormCoachSession {
  const FormCoachSession({
    required this.exerciseKey,
    required this.exerciseName,
    this.muscle = '',
    this.targetReps,
    this.targetSeconds,
    this.openEnded = false,
    this.tempo = '',
    this.prescribedRepMs,
    this.setLabelAr = '',
  });

  final String exerciseKey;
  final String exerciseName;
  final String muscle;

  /// Parsed from the plan ("8-12" -> 12). null + openEnded = AMRAP.
  final int? targetReps;
  final int? targetSeconds;
  final bool openEnded;

  final String tempo;

  /// Expected duration of one rep in ms, derived from tempo when available.
  final int? prescribedRepMs;

  final String setLabelAr;
}

/// Rolling min/max window used to detect which arm/leg is actually working.
class _RangeWindow {
  static const int windowMs = 2500;
  final List<List<double>> _samples = <List<double>>[];

  void add(int tMs, double value) {
    _samples.add(<double>[tMs.toDouble(), value]);
    while (_samples.isNotEmpty && tMs - _samples.first[0] > windowMs) {
      _samples.removeAt(0);
    }
  }

  double? get range {
    if (_samples.length < 4) return null;
    double low = double.infinity;
    double high = -double.infinity;
    for (final List<double> sample in _samples) {
      low = math.min(low, sample[1]);
      high = math.max(high, sample[1]);
    }
    return high - low;
  }

  void reset() => _samples.clear();
}

class FormCoachEngine {
  FormCoachEngine({required this.profile, required this.session}) {
    for (final FormProfileVariant variant in profile.variants) {
      _readiness[variant.id] = ReadinessEvaluator(variant.readiness);
      _evaluators[variant.id] = MetricEvaluator(variant.metrics);
    }
  }

  final FormProfile profile;
  final FormCoachSession session;

  static const Set<ReadinessIssue> _blockingIssues = <ReadinessIssue>{
    // Any quality failure makes the judgement untrustworthy in live mode too.
    ReadinessIssue.noPerson,
    ReadinessIssue.partialBody,
    ReadinessIssue.outOfFrame,
    ReadinessIssue.tooFar,
    ReadinessIssue.tooClose,
    ReadinessIssue.lowConfidence,
    ReadinessIssue.lowLight,
    ReadinessIssue.wrongViewSide,
    ReadinessIssue.wrongViewFront,
    ReadinessIssue.cameraMoving,
    ReadinessIssue.lowFps,
  };

  final PoseSmoother _smoother = PoseSmoother();
  late final PoseQualityGate _quality = PoseQualityGate(
      allowLowerBodyAnchor: profile.variants.isNotEmpty &&
          profile.variants.every((v) =>
              [FcJoint.hip, FcJoint.knee, FcJoint.ankle]
                  .every(v.readiness.requiredJoints.contains) &&
              !v.readiness.requiredJoints.contains(FcJoint.shoulder)));
  FcSide? _visibleSide;
  final PoseSmoother _visualSmoother = PoseSmoother(
    minCutoff: FcTuning.visualSmoothMinCutoff,
    beta: FcTuning.visualSmoothBeta,
    derivativeCutoff: FcTuning.visualSmoothDerivativeCutoff,
  );
  final SubjectTracker _subject = SubjectTracker();
  final Map<String, ReadinessEvaluator> _readiness =
      <String, ReadinessEvaluator>{};
  final Map<String, MetricEvaluator> _evaluators = <String, MetricEvaluator>{};

  FormProfileVariant? _variant;
  RepCounter? _counter;
  List<FormRuleTracker> _trackers = <FormRuleTracker>[];
  final Map<String, double> _baselines = <String, double>{};
  final Map<String, List<double>> _baselineSamples = <String, List<double>>{};
  final Map<String, _RangeWindow> _sideWindows = <String, _RangeWindow>{};

  FormCoachStage _stage = FormCoachStage.starting;
  FcSide? _activeSide;
  PoseSample? _pose;
  ReadinessReport? _report;
  FormCue? _frameCue;
  FormCue? _lastCue;

  int _countdownStartMs = 0;
  int _liveStartMs = 0;
  int _heldMs = 0;
  int? _lastPoseMs;
  int? _lastHoldTickMs;
  int _lastMeaningfulMs = 0;
  int? _lastCueMs;
  int? _lastErrorCueMs;
  int? _lastRepFeedbackMs;
  final TempoCoach _tempoCoach = TempoCoach();
  int _partialsReported = 0;
  int _attempts = 0;
  int _valid = 0;
  int _incorrect = 0;
  int _incomplete = 0;
  int _cannotAssessAttempts = 0;
  int _completedBeforeVariant = 0;
  int _partialsBeforeVariant = 0;
  bool _cycleHadError = false;
  final CorrectionHistory _correctionHistory = CorrectionHistory();
  int _trackedReps = 0;

  List<FormRuleState> _ruleStates = <FormRuleState>[];
  MetricSet _metrics = MetricSet.empty;
  CannotAssessReason _reason = CannotAssessReason.none;
  FormVerdict _verdict = FormVerdict.cannotAssess;

  double _fps = 0;
  double _inferenceMs = 0;
  int _dropped = 0;

  FormProfileVariant? get activeVariant => _variant;
  FormCoachStage get stage => _stage;
  int get reps => _completedBeforeVariant + (_counter?.reps ?? 0);

  bool get _durationMode =>
      profile.completion.durationBased ||
      (session.targetReps == null && session.targetSeconds != null);

  int? get targetReps {
    if (session.openEnded || _durationMode) return null;
    return session.targetReps ?? profile.completion.fallbackTargetReps;
  }

  int? get targetSeconds {
    if (session.openEnded || !_durationMode) return null;
    return session.targetSeconds ?? profile.completion.fallbackTargetSeconds;
  }

  /// Feeds one analysed frame. Frames may be dropped by the runtime: the engine
  /// relies on timestamps only, never on a fixed frame rate.
  FormCoachSnapshot onFrame({
    required int tMs,
    PoseSample? rawPose,
    double? luma,
    double inferenceMs = 0,
    double fps = 0,
    int droppedFrames = 0,
  }) {
    _fps = fps;
    _inferenceMs = inferenceMs;
    _dropped = droppedFrames;

    PoseSample? pose;
    rawPose = _quality.filter(rawPose ?? PoseSample.empty(tMs));
    if (rawPose.isNotEmpty) {
      pose = _smoother.smooth(rawPose);
      // The overlay is allowed to be more responsive than the rep/form
      // decision stream. It uses the same captured frame, not a later UI-only
      // interpolation, so it cannot drift ahead of the camera.
      _pose = _visualSmoother.smooth(rawPose);
      _lastPoseMs = tMs;
    } else {
      _pose = null;
      _smoother.reset();
      _visualSmoother.reset();
    }

    if (_subject.update(pose?.metricSpace, tMs)) {
      for (final FormRuleTracker tracker in _trackers) {
        tracker.resetWindow();
      }
      _interruptAttempt(tMs);
    }
    final bool unstable = _subject.unstableAt(tMs);

    if (_stage == FormCoachStage.starting) _stage = FormCoachStage.readyCheck;
    // Select a visible side before evaluating a frame, never halfway through
    // a rep. The overlay and active-side metrics then use that same selection.
    _selectSide(pose);

    switch (_stage) {
      case FormCoachStage.starting:
      case FormCoachStage.readyCheck:
        _readyCheckFrame(pose, tMs, luma, unstable);
        break;
      case FormCoachStage.countdown:
        _countdownFrame(pose, tMs, luma, unstable);
        break;
      case FormCoachStage.live:
        _liveFrame(pose, tMs, luma, unstable);
        break;
      case FormCoachStage.finished:
        _frameCue = null;
        _verdict = FormVerdict.finished;
        _reason = CannotAssessReason.none;
        break;
    }

    _limitOverlay();
    return _buildSnapshot(tMs);
  }

  void _limitOverlay() {
    final pose = _pose;
    final variant = _variant;
    if (pose == null || variant == null) return;
    final joints = variant.readiness.requiredJoints;
    final both = variant.readiness.requireBothSides;
    final visible = _activeSide ?? _visibleSide ?? FcSide.left;
    final allowed = <FcLandmark>{
      for (final joint in joints)
        for (final side in (both ? FcSide.values : [visible]))
          fcLandmarkFor(joint, side),
    };
    _pose = PoseSample(
        timestampMs: pose.timestampMs,
        imageAspect: pose.imageAspect,
        points: {
          for (final e in pose.points.entries)
            if (allowed.contains(e.key)) e.key: e.value
        });
  }

  // Select from the complete analysis pose; never splice limbs inside a cycle.
  void _selectSide(PoseSample? pose) {
    final variant = _variant;
    if (pose == null || variant == null || (_counter?.inCycle ?? false)) return;
    if (_stage == FormCoachStage.live && variant.rules.isNotEmpty) return;
    final joints = variant.readiness.requiredJoints;
    double confidence(FcSide side) =>
        pose.confidenceOf(joints.map((joint) => fcLandmarkFor(joint, side)));
    final selected = _activeSide ?? _visibleSide;
    if (selected == null ||
        confidence(selected) < variant.driverMinConfidence) {
      _visibleSide = confidence(FcSide.left) >= confidence(FcSide.right)
          ? FcSide.left
          : FcSide.right;
      if (_activeSide != _visibleSide) {
        _counter?.abortCycle();
        if (variant.rules.isNotEmpty) {
          _baselines.clear();
          _baselineSamples.clear();
          _countdownStartMs = pose.timestampMs;
          _correctionHistory.interrupt();
        }
      }
      _activeSide = _visibleSide;
    }
  }

  void _interruptAttempt(int tMs) {
    final event = _counter?.interrupt(tMs);
    if (event != null) {
      _attempts++;
      _cannotAssessAttempts++;
    }
    _cycleHadError = false;
    _correctionHistory.interrupt();
  }

  // --- ready check -----------------------------------------------------------

  void _readyCheckFrame(
      PoseSample? pose, int tMs, double? luma, bool unstable) {
    _frameCue = null;
    _verdict = FormVerdict.cannotAssess;
    _reason =
        pose == null ? CannotAssessReason.noPose : CannotAssessReason.warmingUp;

    ReadinessReport? best;
    FormProfileVariant? bestVariant;
    FormProfileVariant? ready;

    for (final FormProfileVariant variant in profile.variants) {
      final ReadinessReport report = _readiness[variant.id]!.update(
        sample: pose,
        tMs: tMs,
        luma: luma,
        fps: _fps,
        subjectUnstable: unstable,
      );
      if (best == null || report.issues.length < best.issues.length) {
        best = report;
        bestVariant = variant;
      }
      if (report.ok && ready == null) ready = variant;
    }

    _report = best;
    // While setting up we show the guidance of the closest-matching variant.
    if (_counter == null && bestVariant != null) _variant = bestVariant;

    if (ready != null) {
      final bool sameSet = _counter != null;
      _activate(ready, tMs, keepProgress: sameSet);
    }
  }

  void _activate(FormProfileVariant variant, int tMs,
      {bool keepProgress = false}) {
    final previousVariant = _variant;
    _variant = variant;
    if (keepProgress && previousVariant?.id != variant.id) {
      _completedBeforeVariant += _counter?.reps ?? 0;
      _partialsBeforeVariant += _counter?.partials ?? 0;
      _counter =
          variant.repCycle == null ? null : RepCounter(variant.repCycle!);
      _trackers = [for (final rule in variant.rules) FormRuleTracker(rule)];
      _baselines.clear();
    }
    if (!keepProgress) {
      _counter =
          variant.repCycle == null ? null : RepCounter(variant.repCycle!);
      _trackers = <FormRuleTracker>[
        for (final FormRule rule in variant.rules) FormRuleTracker(rule),
      ];
      _baselines.clear();
      _heldMs = 0;
      _partialsReported = 0;
      _attempts = 0;
      _valid = 0;
      _incorrect = 0;
      _incomplete = 0;
      _cannotAssessAttempts = 0;
      _completedBeforeVariant = 0;
      _partialsBeforeVariant = 0;
      _activeSide = null;
    } else {
      _counter?.abortCycle();
    }
    _baselineSamples.clear();
    _sideWindows.clear();
    _tempoCoach.reset();
    _lastHoldTickMs = null;
    _lastMeaningfulMs = tMs;
    _countdownStartMs = tMs;
    _stage = FormCoachStage.countdown;
  }

  // --- countdown / warm-up ---------------------------------------------------

  void _countdownFrame(PoseSample? pose, int tMs, double? luma, bool unstable) {
    _frameCue = null;
    _verdict = FormVerdict.cannotAssess;
    _reason = CannotAssessReason.warmingUp;

    final FormProfileVariant variant = _variant!;
    final ReadinessReport report = _readiness[variant.id]!.update(
      sample: pose,
      tMs: tMs,
      luma: luma,
      fps: _fps,
      subjectUnstable: unstable,
    );
    _report = report;

    if (pose != null && report.ok) {
      // Personal baselines: the user's own neutral posture, not a fixed ideal.
      final MetricSet metrics =
          _evaluators[variant.id]!.evaluate(pose, activeSide: _activeSide);
      _metrics = metrics;
      final calibrationOk = variant.calibrationLimits.entries.every((entry) {
        final value = metrics[entry.key];
        return value != null &&
            value.value.isFinite &&
            value.confidence >= 0.75 &&
            value.value >= entry.value[0] &&
            value.value <= entry.value[1];
      });
      if (!calibrationOk) {
        _baselineSamples.clear();
        _countdownStartMs = tMs;
        return;
      }
      for (final String id in variant.baselineMetricIds) {
        final MetricReading? reading = metrics[id];
        if (reading == null) continue;
        if (reading.confidence < FcTuning.landmarkMinVisibility) continue;
        final samples = _baselineSamples.putIfAbsent(id, () => <double>[]);
        samples.add(reading.value);
        if (samples.length > 40) samples.removeAt(0);
      }
    }

    final int? lastPose = _lastPoseMs;
    final bool poseLost =
        lastPose == null || tMs - lastPose > FcTuning.poseLostGraceMs * 2;
    if (poseLost || _isBlocking(report)) {
      _returnToSetup(tMs);
      return;
    }

    if (tMs - _countdownStartMs >= FcTuning.liveWarmupMs) {
      if (!_finalizeBaselines()) {
        _baselineSamples.clear();
        _countdownStartMs = tMs;
        return;
      }
      _stage = FormCoachStage.live;
      _liveStartMs = tMs;
      _lastMeaningfulMs = tMs;
      _lastHoldTickMs = tMs;
      for (final FormRuleTracker tracker in _trackers) {
        tracker.resetWindow();
      }
    }
  }

  bool _finalizeBaselines() {
    final variant = _variant!;
    if (variant.rules.isNotEmpty) {
      for (final id in variant.baselineMetricIds) {
        final samples = _baselineSamples[id];
        if (samples == null || samples.length < 6) return false;
        final limit = variant.calibrationLimits[id];
        if (limit != null &&
            samples.reduce(math.max) - samples.reduce(math.min) > limit[2])
          return false;
      }
    }
    for (final MapEntry<String, List<double>> entry
        in _baselineSamples.entries) {
      final double? median = FcGeometry.median(entry.value);
      if (median != null) _baselines[entry.key] = median;
    }
    return true;
  }

  // --- live ------------------------------------------------------------------

  void _liveFrame(PoseSample? pose, int tMs, double? luma, bool unstable) {
    _frameCue = null;
    final FormProfileVariant variant = _variant!;

    final ReadinessReport report = _readiness[variant.id]!.update(
      sample: pose,
      tMs: tMs,
      luma: luma,
      fps: _fps,
      subjectUnstable: unstable,
    );
    _report = report;

    final bool blocking = _isBlocking(report);
    final bool poseUsable = pose != null &&
        !blocking &&
        !unstable &&
        (_fps == 0 || _fps >= FcTuning.minUsableFps);

    CannotAssessReason reason = CannotAssessReason.none;
    if (pose == null) {
      reason = CannotAssessReason.noPose;
    } else if (unstable) {
      reason = CannotAssessReason.subjectChanged;
    } else if (blocking) {
      reason = _reasonFromReadiness(report);
    } else if (_fps > 0 && _fps < FcTuning.minUsableFps) {
      reason = CannotAssessReason.lowFps;
    }

    MetricSet metrics = MetricSet.empty;
    if (pose != null) {
      metrics = _evaluators[variant.id]!.evaluate(
        pose,
        activeSide: _activeSide,
        baselines: _baselines,
      );
      final previousSide = _activeSide;
      _updateActiveSide(variant, metrics, tMs);
      if (previousSide != _activeSide) {
        metrics = _evaluators[variant.id]!
            .evaluate(pose, activeSide: _activeSide, baselines: _baselines);
      }
    }
    _metrics = metrics;

    final List<RepEvent> events = <RepEvent>[];
    final RepCounter? counter = _counter;
    final wasInCycle = counter?.inCycle ?? false;
    if (counter != null) {
      final MetricReading? driver = metrics[counter.spec.driverMetricId];
      final bool driverUsable = poseUsable &&
          driver != null &&
          driver.confidence >= variant.driverMinConfidence;
      if (!driverUsable && reason == CannotAssessReason.none) {
        reason = CannotAssessReason.lowVisibility;
      }
      events.addAll(counter.update(
        tMs: tMs,
        driver: driverUsable ? driver.value : null,
        usable: driverUsable,
      ));
      if (events.isNotEmpty || counter.inCycle) _lastMeaningfulMs = tMs;
    }

    if (_durationMode) {
      final int previousTick = _lastHoldTickMs ?? tMs;
      final int delta = (tMs - previousTick)
          .clamp(0, FcTuning.maxFrameIntervalMs * 2)
          .toInt();
      _lastHoldTickMs = tMs;
      bool inPosition = poseUsable;
      final HoldSpec? hold = variant.hold;
      if (hold != null) {
        final MetricReading? reading = metrics[hold.metricId];
        inPosition = poseUsable &&
            reading != null &&
            reading.confidence >= FcTuning.ruleMinConfidence &&
            hold.inPosition(reading.value);
      }
      if (inPosition) {
        _heldMs += delta;
        _lastMeaningfulMs = tMs;
      }
    }

    final int? lastCueMs = _lastCueMs;
    final bool globalCooldownOk =
        lastCueMs == null || tMs - lastCueMs >= FcTuning.globalCueCooldownMs;

    final List<FormCue> candidates = <FormCue>[];
    final List<FormRuleState> states = <FormRuleState>[];
    for (final FormRuleTracker tracker in _trackers) {
      final FormRuleState state = tracker.update(
        tMs: tMs,
        reading: metrics[tracker.rule.metricId],
        phase: counter?.phase ?? RepPhase.unknown,
        poseUsable: poseUsable,
        // Tracking-only profiles may never speak about form.
        allowFire: false,
      );
      states.add(state);
      if (state.candidate &&
          state.blockedReason == 'global-cooldown' &&
          globalCooldownOk &&
          profile.canCorrectForm) {
        candidates.add(FormCue(
          id: tracker.rule.id,
          textAr: tracker.rule.cueAr,
          detailAr: tracker.rule.detailAr,
          kind: FormCueKind.formError,
          severity: tracker.rule.severity,
          priority: tracker.rule.priority,
          tMs: tMs,
        ));
      }
    }
    _ruleStates = states;

    if (!wasInCycle && (counter?.inCycle ?? false))
      _correctionHistory.resetCycle();
    if (wasInCycle || (counter?.inCycle ?? false)) {
      _correctionHistory.observe(
          tMs, counter?.phase ?? RepPhase.unknown, states,
          usable: poseUsable);
    }

    // Runtime-only outcomes: completed cycles are valid unless a persistent
    // form rule fired on that cycle; partial/aborted cycles are incomplete.
    if (!wasInCycle && (counter?.inCycle ?? false)) _cycleHadError = false;
    if (wasInCycle || (counter?.inCycle ?? false)) {
      _cycleHadError = _cycleHadError ||
          states.any((state) => state.evaluable && state.candidate);
    }
    if (!poseUsable) _tempoCoach.interrupt();
    for (final RepEvent event in events) {
      _tempoCoach.observe(event, session.prescribedRepMs);
      if (!event.assessable) {
        _attempts++;
        _cannotAssessAttempts++;
        _cycleHadError = false;
        _correctionHistory.finish(variant.rules, assessable: false);
        continue;
      }
      switch (event.kind) {
        case RepEventKind.repCompleted:
          _attempts++;
          final quality =
              _correctionHistory.finish(variant.rules, assessable: true);
          switch (quality.quality) {
            case RepQuality.supportedError:
              _incorrect++;
            case RepQuality.supportedChecksPassed:
              _valid++;
            case RepQuality.cannotAssess:
              _cannotAssessAttempts++;
            case RepQuality.trackingOnly:
              _trackedReps++;
          }
          if (quality.improved.isNotEmpty && globalCooldownOk) {
            final rule = variant.rules
                .firstWhere((r) => quality.improved.contains(r.id));
            candidates.add(FormCue(
                id: 'improved.${rule.id}',
                textAr: 'الحركة اتحسنت في آخر عدتين',
                detailAr: rule.cueAr,
                kind: FormCueKind.info,
                severity: RuleSeverity.minor,
                priority: 9,
                tMs: tMs));
          }
        case RepEventKind.partialRep:
          _attempts++;
          _incomplete++;
          _correctionHistory.finish(variant.rules, assessable: false);
        case RepEventKind.cycleAborted:
          _attempts++;
          _incomplete++;
          _correctionHistory.finish(variant.rules, assessable: false);
      }
    }

    if (events.isNotEmpty) _cycleHadError = false;
    if (reason == CannotAssessReason.none)
      candidates
          .addAll(_repFeedbackCues(variant, events, tMs, globalCooldownOk));

    if (reason == CannotAssessReason.none &&
        poseUsable &&
        counter != null &&
        tMs - _lastMeaningfulMs > FcTuning.unknownMovementAfterMs) {
      // Pose is fine but nothing that looks like this exercise is happening.
      reason = CannotAssessReason.unknownMovement;
    }
    _reason = reason;

    final FormCue? chosen =
        reason == CannotAssessReason.none ? _arbitrate(candidates) : null;
    if (chosen != null) {
      if (chosen.id == 'tempo_fast') {
        _tempoCoach.markWarningSpoken();
        _lastRepFeedbackMs = tMs;
      }
      if (chosen.id == 'tempo_improved') {
        _tempoCoach.markImprovementSpoken();
        _lastRepFeedbackMs = tMs;
      }
      if (chosen.id == 'range_short') {
        _partialsReported = counter?.partials ?? 0;
        _lastRepFeedbackMs = tMs;
      }
      if (chosen.kind == FormCueKind.formError) {
        _trackers
            .firstWhere((tracker) => tracker.rule.id == chosen.id)
            .commitFire(tMs);
      }
      _frameCue = chosen;
      _lastCue = chosen;
      _lastCueMs = tMs;
      if (chosen.kind == FormCueKind.formError) _lastErrorCueMs = tMs;
    }

    final int? lastErrorMs = _lastErrorCueMs;
    if (reason != CannotAssessReason.none) {
      _verdict = FormVerdict.cannotAssess;
    } else if (lastErrorMs != null && tMs - lastErrorMs < 2500) {
      _verdict = FormVerdict.clearError;
    } else if (variant.rules.isEmpty) {
      _verdict = FormVerdict.tracking;
    } else if (states.isEmpty || states.any((state) => !state.evaluable)) {
      _verdict = FormVerdict.cannotAssess;
    } else {
      _verdict = FormVerdict.correct;
    }

    if (blocking && tMs - _lastMeaningfulMs > FcTuning.returnToSetupAfterMs) {
      _returnToSetup(tMs);
      return;
    }

    _checkCompletion(tMs);
  }

  /// Range-of-motion and tempo feedback, which are not geometry rules.
  List<FormCue> _repFeedbackCues(
    FormProfileVariant variant,
    List<RepEvent> events,
    int tMs,
    bool globalCooldownOk,
  ) {
    final RepFeedbackSpec spec = variant.repFeedback;
    final RepCounter? counter = _counter;
    if (counter == null) return const <FormCue>[];

    final int? lastFeedback = _lastRepFeedbackMs;
    final bool cooldownOk =
        lastFeedback == null || tMs - lastFeedback >= spec.cooldownMs;
    if (!globalCooldownOk || !cooldownOk) return const <FormCue>[];

    final List<FormCue> cues = <FormCue>[];

    if (profile.canCorrectForm &&
        spec.hasPartialCue &&
        events.any((RepEvent event) => event.kind == RepEventKind.partialRep) &&
        counter.partials - _partialsReported >= spec.partialsBeforeCue) {
      cues.add(FormCue(
        id: 'range_short',
        textAr: spec.partialCueAr,
        detailAr: spec.partialDetailAr,
        kind: FormCueKind.rangeShort,
        severity: RuleSeverity.minor,
        priority: spec.partialPriority,
        tMs: tMs,
      ));
      return cues;
    }

    if (_tempoCoach.warningReady) {
      cues.add(FormCue(
          id: 'tempo_fast',
          textAr: spec.hasTempoCue ? spec.fastTempoCueAr : 'هدّي الحركة شوية',
          detailAr: 'العدات أسرع من التيمبو المحدد في التمرين',
          kind: FormCueKind.tempo,
          severity: RuleSeverity.minor,
          priority: spec.tempoPriority,
          tMs: tMs));
    } else if (_tempoCoach.improvementPending) {
      cues.add(FormCue(
          id: 'tempo_improved',
          textAr: 'التيمبو اتحسّن في آخر عدتين',
          kind: FormCueKind.info,
          severity: RuleSeverity.minor,
          priority: 9,
          tMs: tMs));
    }

    return cues;
  }

  /// One cue at a time: lowest priority number wins, severity breaks ties.
  FormCue? _arbitrate(List<FormCue> candidates) {
    if (candidates.isEmpty) return null;
    FormCue best = candidates.first;
    for (final FormCue cue in candidates.skip(1)) {
      if (cue.priority < best.priority ||
          (cue.priority == best.priority &&
              cue.severity.index < best.severity.index)) {
        best = cue;
      }
    }
    return best;
  }

  /// Unilateral work: the side with the bigger recent range is the working one.
  void _updateActiveSide(
      FormProfileVariant variant, MetricSet metrics, int tMs) {
    if (variant.rules.isNotEmpty ||
        variant.sideSelection != SideSelection.activeSide) return;
    if (variant.sideAmplitudeMetrics.length < 2) return;

    for (final String id in variant.sideAmplitudeMetrics) {
      final MetricReading? reading = metrics[id];
      if (reading == null ||
          reading.confidence < FcTuning.landmarkMinVisibility) {
        continue;
      }
      _sideWindows
          .putIfAbsent(id, () => _RangeWindow())
          .add(tMs, reading.value);
    }

    if (_counter?.inCycle ?? false) return;
    final double? left = _sideWindows[variant.sideAmplitudeMetrics[0]]?.range;
    final double? right = _sideWindows[variant.sideAmplitudeMetrics[1]]?.range;
    if (left == null || right == null) return;
    // Require a clear difference so we do not flip side on noise.
    final range = variant.repCycle?.fullRange ?? 100;
    if ((left - right).abs() < (range < 5 ? range * .08 : 8)) return;
    final next = left > right ? FcSide.left : FcSide.right;
    final candidate =
        metrics[variant.sideAmplitudeMetrics[next == FcSide.left ? 0 : 1]];
    if (candidate == null || candidate.confidence < variant.driverMinConfidence)
      return;
    if (next != _activeSide) {
      _counter?.abortCycle();
      _activeSide = next;
    }
  }

  void _checkCompletion(int tMs) {
    final int? reps = targetReps;
    final int? seconds = targetSeconds;
    bool done = false;
    if (reps != null && this.reps >= reps) done = true;
    if (seconds != null && _heldMs >= seconds * 1000) done = true;
    if (!done) return;
    if (_durationMode && _attempts == 0) {
      _attempts = 1;
      if (_variant?.rules.isNotEmpty ?? false) {
        _cannotAssessAttempts = 1;
      } else {
        _trackedReps = 1;
      }
    }

    // The set is finished: do not leave the last body pose under the result
    // card, and let the controller stop the camera stream.
    _pose = null;
    _stage = FormCoachStage.finished;
    _verdict = FormVerdict.finished;
    _reason = CannotAssessReason.none;
    final FormCue cue = FormCue(
      id: 'set_finished',
      textAr: _finishedTextAr(),
      kind: FormCueKind.setFinished,
      severity: RuleSeverity.critical,
      priority: 0,
      tMs: tMs,
    );
    _frameCue = cue;
    _lastCue = cue;
    _lastCueMs = tMs;
  }

  bool _isBlocking(ReadinessReport report) {
    if (report.unknown) return true;
    for (final ReadinessIssue issue in report.issues) {
      if (_blockingIssues.contains(issue)) return true;
    }
    return false;
  }

  CannotAssessReason _reasonFromReadiness(ReadinessReport report) {
    for (final ReadinessIssue issue in report.issues) {
      switch (issue) {
        case ReadinessIssue.noPerson:
          return CannotAssessReason.noPose;
        case ReadinessIssue.partialBody:
        case ReadinessIssue.outOfFrame:
          return CannotAssessReason.outOfFrame;
        case ReadinessIssue.lowConfidence:
        case ReadinessIssue.lowLight:
          return CannotAssessReason.lowVisibility;
        case ReadinessIssue.wrongViewSide:
        case ReadinessIssue.wrongViewFront:
          return CannotAssessReason.wrongView;
        case ReadinessIssue.cameraMoving:
          return CannotAssessReason.subjectChanged;
        case ReadinessIssue.lowFps:
          return CannotAssessReason.lowFps;
        case ReadinessIssue.tooFar:
        case ReadinessIssue.tooClose:
          return CannotAssessReason.lowVisibility;
      }
    }
    return CannotAssessReason.none;
  }

  /// Back to setup guidance without losing the rep count.
  void _returnToSetup(int tMs) {
    _stage = FormCoachStage.readyCheck;
    _verdict = FormVerdict.cannotAssess;
    _interruptAttempt(tMs);
    _lastCue = null;
    _frameCue = null;
    _lastErrorCueMs = null;
    for (final FormRuleTracker tracker in _trackers) {
      tracker.resetWindow();
    }
    for (final ReadinessEvaluator evaluator in _readiness.values) {
      evaluator.reset();
    }
    _sideWindows.clear();
    _lastHoldTickMs = null;
    _lastMeaningfulMs = tMs;
  }

  String _finishedTextAr() {
    if (_durationMode) {
      final int seconds = (_heldMs / 1000).round();
      return 'خلصت المدة — $seconds ثانية';
    }
    return 'خلصت المجموعة — ${reps} عدة';
  }

  String _liveTextAr() {
    if (_reason != CannotAssessReason.none) {
      return _report?.primaryIssue != null
          ? _report!.cueAr
          : cannotAssessReasonAr(_reason);
    }
    if (_counter != null && _counter!.phase == RepPhase.unknown) {
      final label = _counter!.spec.topLabelAr;
      return label.isEmpty
          ? 'ارجع لوضع البداية عشان أتابع العدة'
          : 'ابدأ من: $label';
    }
    if (_verdict == FormVerdict.clearError) {
      return _lastCue?.textAr ?? 'ركز في الأداء';
    }
    return 'بتابع حركتك';
  }

  FormCoachSnapshot _buildSnapshot(int tMs) {
    String status;
    switch (_stage) {
      case FormCoachStage.starting:
        status = 'بفتح الكاميرا...';
        break;
      case FormCoachStage.readyCheck:
        status = _report?.cueAr ?? 'بستعد...';
        break;
      case FormCoachStage.countdown:
        status = (_variant?.calibrationLimits.isNotEmpty ?? false)
            ? 'قف أو اجلس مستقيمًا، ذراعك بجانبك وممدودة، وثبّت الهاتف'
            : 'استعد... ابدأ الحركة بهدوء';
        break;
      case FormCoachStage.live:
        status = _liveTextAr();
        break;
      case FormCoachStage.finished:
        status = _finishedTextAr();
        break;
    }

    final int countdownRemaining = _stage == FormCoachStage.countdown
        ? math.max(0, FcTuning.liveWarmupMs - (tMs - _countdownStartMs))
        : 0;

    return FormCoachSnapshot(
      stage: _stage,
      verdict: _verdict,
      cannotAssessReason: _reason,
      phase: _counter?.phase ?? RepPhase.unknown,
      reps: reps,
      partialReps: _partialsBeforeVariant + (_counter?.partials ?? 0),
      attempts: _attempts,
      valid: _valid,
      incorrect: _incorrect,
      incomplete: _incomplete,
      cannotAssessAttempts: _cannotAssessAttempts,
      trackedReps: _trackedReps,
      tooFastReps: _tempoCoach.fastReps,
      tempoImproved: _tempoCoach.improved,
      corrections: _correctionHistory.summary(_variant?.rules ?? const []),
      targetReps: targetReps,
      targetSeconds: targetSeconds,
      heldMs: _heldMs,
      elapsedMs: _stage == FormCoachStage.starting || _liveStartMs == 0
          ? 0
          : math.max(0, tMs - _liveStartMs),
      readiness: _report,
      cue: _frameCue,
      lastCue: _lastCue,
      ruleStates: _ruleStates,
      metrics: _metrics.values,
      activeSide: _activeSide,
      activeVariantId: _variant?.id,
      pose: _pose,
      fps: _fps,
      inferenceMs: _inferenceMs,
      droppedFrames: _dropped,
      countdownRemainingMs: countdownRemaining,
      statusTextAr: status,
    );
  }

  /// Phone call, backgrounding, or any camera interruption: stop judging and
  /// re-run the setup check when the user comes back.
  void onInterrupted(int tMs) {
    _quality.reset();
    _correctionHistory.reset();
    _trackedReps = 0;
    _visibleSide = null;
    _activeSide = null;
    _pose = null;
    _lastPoseMs = null;
    _metrics = MetricSet.empty;
    _report = null;
    _smoother.reset();
    _visualSmoother.reset();
    _subject.reset();
    if (_stage == FormCoachStage.live || _stage == FormCoachStage.countdown) {
      _returnToSetup(tMs);
    }
  }

  void reset() {
    _quality.reset();
    _correctionHistory.reset();
    _trackedReps = 0;
    _visibleSide = null;
    _smoother.reset();
    _visualSmoother.reset();
    _subject.reset();
    for (final ReadinessEvaluator evaluator in _readiness.values) {
      evaluator.reset();
    }
    for (final FormRuleTracker tracker in _trackers) {
      tracker.resetSet();
    }
    for (final _RangeWindow window in _sideWindows.values) {
      window.reset();
    }
    _counter?.reset();
    _counter = null;
    _trackers = <FormRuleTracker>[];
    _variant = null;
    _baselines.clear();
    _baselineSamples.clear();
    _sideWindows.clear();
    _stage = FormCoachStage.starting;
    _verdict = FormVerdict.cannotAssess;
    _reason = CannotAssessReason.none;
    _activeSide = null;
    _pose = null;
    _report = null;
    _frameCue = null;
    _lastCue = null;
    _metrics = MetricSet.empty;
    _ruleStates = <FormRuleState>[];
    _heldMs = 0;
    _liveStartMs = 0;
    _countdownStartMs = 0;
    _lastPoseMs = null;
    _lastHoldTickMs = null;
    _lastMeaningfulMs = 0;
    _lastCueMs = null;
    _lastErrorCueMs = null;
    _lastRepFeedbackMs = null;
    _tempoCoach.reset();
    _partialsReported = 0;
    _attempts = 0;
    _valid = 0;
    _incorrect = 0;
    _incomplete = 0;
    _cannotAssessAttempts = 0;
    _completedBeforeVariant = 0;
    _partialsBeforeVariant = 0;
    _cycleHadError = false;
    _fps = 0;
    _inferenceMs = 0;
    _dropped = 0;
  }
}
