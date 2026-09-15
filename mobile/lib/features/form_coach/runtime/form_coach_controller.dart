// Form Coach - runtime coordinator.
//
// Owns the camera pipeline, the engine and the cue player, and exposes a single
// immutable snapshot to the UI through ChangeNotifier. It is created and
// destroyed with the Form Coach screen only: the app's own state management,
// stores and session flow are untouched.

import 'dart:async';

import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/form_coach_engine.dart';
import 'package:elforma/features/form_coach/integration/form_coach_request.dart';
import 'package:elforma/features/form_coach/runtime/camera_pose_pipeline.dart';
import 'package:elforma/features/form_coach/runtime/form_coach_debug_flag.dart';
import 'package:elforma/features/form_coach/runtime/form_cue_player.dart';
import 'package:elforma/features/form_coach/runtime/pose_detection_service.dart';
import 'package:elforma/features/form_coach/runtime/set_clip_recorder.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class FormCoachController extends ChangeNotifier {
  FormCoachController({
    required this.request,
    SetClipRecorder recorder = const DisabledSetClipRecorder(),
  })  : _recorder = recorder,
        _engine = FormCoachEngine(
          profile: request.profile,
          session: request.session,
        );

  final FormCoachRequest request;
  final SetClipRecorder _recorder;
  final FormCoachEngine _engine;
  final FormCuePlayer _cues = FormCuePlayer();

  CameraPosePipeline? _pipeline;
  StreamSubscription<PoseFrame>? _subscription;

  FormCoachSnapshot? _snapshot;
  String? _errorTextAr;
  CameraFailure? _failure;
  bool _starting = false;
  bool _disposed = false;
  bool _debug = false;
  bool _muted = false;
  int _lastTMs = 0;

  FormCoachSnapshot? get snapshot => _snapshot;
  String? get errorTextAr => _errorTextAr;
  CameraFailure? get failure => _failure;
  bool get isStarting => _starting;
  bool get debugEnabled => _debug;
  bool get muted => _muted;
  bool get voiceAvailable => _cues.voiceAvailable;
  bool get recordingAvailable => _recorder.isAvailable;
  CameraController? get cameraController => _pipeline?.controller;
  bool get isMirrored => _pipeline?.isMirrored ?? false;
  FormCoachEngine get engine => _engine;

  Future<void> start() async {
    if (_starting || _disposed) return;
    _starting = true;
    _errorTextAr = null;
    _failure = null;
    notifyListeners();

    _debug = await FormCoachDebugFlag.isEnabled();
    await _cues.init();

    final CameraPosePipeline pipeline =
        CameraPosePipeline(detector: PoseDetectionService());
    _pipeline = pipeline;

    try {
      _subscription = pipeline.frames.listen(_onFrame, onError: (Object _) {});
      await pipeline.start();
    } on FormCoachCameraException catch (error) {
      _failure = error.failure;
      _errorTextAr = error.messageAr;
    } catch (error) {
      _failure = CameraFailure.unavailable;
      _errorTextAr = 'مش قادر أفتح الكاميرا دلوقتي';
    } finally {
      _starting = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _onFrame(PoseFrame frame) {
    if (_disposed) return;
    _lastTMs = frame.tMs;

    final FormCoachSnapshot snapshot = _engine.onFrame(
      tMs: frame.tMs,
      rawPose: frame.pose,
      luma: frame.luma,
      inferenceMs: frame.inferenceMs,
      fps: frame.fps,
      droppedFrames: frame.droppedFrames,
    );
    _snapshot = snapshot;

    final FormCue? cue = snapshot.cue;
    if (cue != null) {
      // Fire and forget: audio must never block frame handling.
      unawaited(_cues.play(cue));
    }

    if (snapshot.isFinished) {
      unawaited(_pipeline?.pause() ?? Future<void>.value());
    }

    notifyListeners();
  }

  /// Called by the screen on app lifecycle changes, phone calls and camera
  /// interruptions: stop judging, re-run the setup check when we come back.
  Future<void> handleLifecycle(AppLifecycleState state) async {
    if (_disposed) return;
    final CameraPosePipeline? pipeline = _pipeline;
    if (pipeline == null) return;

    if (state == AppLifecycleState.resumed) {
      if (_snapshot?.isFinished ?? false) return;
      try {
        await pipeline.resume();
      } on FormCoachCameraException catch (error) {
        _failure = error.failure;
        _errorTextAr = error.messageAr;
        notifyListeners();
      }
      return;
    }

    await pipeline.pause();
    _engine.onInterrupted(_lastTMs);
    await _cues.setMuted(_muted);
    notifyListeners();
  }

  Future<void> toggleMuted() async {
    _muted = !_muted;
    await _cues.setMuted(_muted);
    notifyListeners();
  }

  Future<void> toggleDebug() async {
    _debug = await FormCoachDebugFlag.toggle();
    notifyListeners();
  }

  /// Restarts the temporary set counter. Nothing is saved anywhere.
  Future<void> restartSet() async {
    _engine.reset();
    _snapshot = null;
    notifyListeners();
    final CameraPosePipeline? pipeline = _pipeline;
    if (pipeline == null) return;
    try {
      await pipeline.resume();
    } on FormCoachCameraException catch (error) {
      _failure = error.failure;
      _errorTextAr = error.messageAr;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    _subscription = null;
    unawaited(_pipeline?.dispose() ?? Future<void>.value());
    _pipeline = null;
    unawaited(_cues.dispose());
    unawaited(_recorder.dispose());
    _engine.reset();
    super.dispose();
  }
}
