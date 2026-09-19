// Form Coach - runtime coordinator.
//
// Owns the camera pipeline, the engine and the cue player, and exposes a single
// immutable snapshot to the UI through ChangeNotifier. It is created and
// destroyed with the Form Coach screen only: the app's own state management,
// stores and session flow are untouched.

import 'dart:async';

import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_coach_engine.dart';
import 'package:elforma/features/form_coach/integration/form_coach_request.dart';
import 'package:elforma/features/form_coach/runtime/camera_pose_pipeline.dart';
import 'package:elforma/features/form_coach/runtime/form_coach_debug_flag.dart';
import 'package:elforma/features/form_coach/runtime/form_cue_player.dart';
import 'package:elforma/features/form_coach/runtime/pose_detection_service.dart';
import 'package:elforma/features/form_coach/runtime/set_clip_recorder.dart';
import 'package:camera/camera.dart';
import 'package:elforma/features/form_coach/runtime/serial_operations.dart';
import 'package:flutter/widgets.dart';

class FormCoachController extends ChangeNotifier {
  FormCoachController({
    required this.request,
    SetClipRecorder? recorder,
  })  : _recorder = recorder ?? LocalSetClipRecorder(),
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
  final ValueNotifier<FormCoachSnapshot?> poseFrames = ValueNotifier(null);
  int _lastUiMs = -1000;
  Future<void>? _audioInit;
  String? _errorTextAr;
  CameraFailure? _failure;
  bool _starting = false;
  bool _disposed = false;
  bool _debug = false;
  bool _muted = false;
  int _lastTMs = 0;
  int _pipelineOffsetMs = 0;
  bool _recordRequested = false;
  bool _recordFinishing = false;
  Future<void>? _recordStartFuture;
  String? _recordingMessage;
  final SerialOperations _operations = SerialOperations();
  bool get isTransitioning => _operations.busy;
  bool _foreground = true;

  Future<void> _serial(Future<void> Function() operation) => _operations.run(() async {
    if (_disposed) return;
    await operation();
  }).whenComplete(notifyListeners);

  @override
  void notifyListeners() { if (!_disposed) super.notifyListeners(); }

  FormCoachSnapshot? get snapshot => _snapshot;
  String? get errorTextAr => _errorTextAr;
  CameraFailure? get failure => _failure;
  bool get isStarting => _starting;
  bool get debugEnabled => _debug;
  bool get muted => _muted;
  FormAudioMode get audioMode => _cues.mode;
  bool get voiceAvailable => _cues.voiceAvailable;
  bool get recordingAvailable => _recorder.isAvailable;
  bool get recordingRequested => _recordRequested;
  bool get recordingInProgress => _recorder.isRecording;
  String? get recordingMessage => _recordingMessage;
  CameraController? get cameraController => _pipeline?.controller;
  bool get canSwitchCamera => _pipeline?.canSwitchCamera ?? false;
  bool get isMirrored => _pipeline?.isMirrored ?? false;
  FormCoachEngine get engine => _engine;

  Future<void> start() => _serial(_start);
  Future<void> _start() async {
    if (_starting || _disposed) return;
    _starting = true;
    _errorTextAr = null;
    _failure = null;
    notifyListeners();

    // Audio setup does not block camera preview or inference.
    _audioInit ??= _cues.init();
    unawaited(FormCoachDebugFlag.isEnabled().then((value) {
      if (!_disposed) { _debug = value; notifyListeners(); }
    }).catchError((Object _) {}));
    await _subscription?.cancel();
    await _pipeline?.dispose();
    if (_disposed) return;

    _engine.onInterrupted(_lastTMs);
    _pipelineOffsetMs = _lastTMs + 1;
    _snapshot = null; poseFrames.value = null;
    final CameraPosePipeline pipeline =
        CameraPosePipeline(detector: PoseDetectionService());
    _pipeline = pipeline;

    try {
      _subscription = pipeline.frames.listen(_onFrame, onError: _onPipelineError);
      await pipeline.start();
      if (!_foreground || _disposed) { await pipeline.suspend(); return; }
      if (_recordRequested) await pipeline.setRecordingQuality(true);
    } on FormCoachCameraException catch (error) {
      _failure = error.failure;
      _errorTextAr = error.messageAr;
    } catch (error) {
      _failure = CameraFailure.unavailable;
      _errorTextAr = 'مش قادر أفتح الكاميرا دلوقتي';
    } finally {
      if (_errorTextAr != null) {
        await _subscription?.cancel(); _subscription = null;
        await pipeline.dispose();
        if (identical(_pipeline, pipeline)) _pipeline = null;
      }
      _starting = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _onPipelineError(Object error) {
    if (_disposed) return;
    _pipeline?.stopAcceptingFrames();
    _engine.onInterrupted(_lastTMs); poseFrames.value = null;
    _failure = CameraFailure.unavailable;
    _errorTextAr = error is FormCoachCameraException ? error.messageAr
        : 'التتبع وقف — جرّب فتح الكاميرا تاني';
    unawaited(_cues.stop()); notifyListeners();
    unawaited(_serial(() async {
      _recordRequested = false;
      await _recorder.discard(); await _pipeline?.suspend();
    }).catchError((Object _) {}));
  }

  void _onFrame(PoseFrame frame) {
    if (_disposed || !_foreground || _operations.busy) return;
    final tMs = frame.tMs + _pipelineOffsetMs;
    _lastTMs = tMs;
    final raw = frame.pose;
    final pose = raw == null ? null : PoseSample(timestampMs: tMs,
        points: raw.points, imageAspect: raw.imageAspect);

    final FormCoachSnapshot snapshot = _engine.onFrame(
      tMs: tMs,
      rawPose: pose,
      luma: frame.luma,
      inferenceMs: frame.inferenceMs,
      fps: frame.fps,
      droppedFrames: frame.droppedFrames,
    );
    final previous = _snapshot;
    _snapshot = snapshot;
    poseFrames.value = snapshot.isFinished ? null : snapshot;

    if (snapshot.isLive && _recordRequested && !_recorder.isRecording) {
      unawaited(_startRecording());
    }

    if (snapshot.verdict == FormVerdict.cannotAssess &&
        previous?.verdict != FormVerdict.cannotAssess) unawaited(_cues.stop());
    final FormCue? cue = snapshot.cue;
    if (cue != null) {
      // Fire and forget: audio must never block frame handling.
      unawaited(_cues.play(cue));
    }

    if (snapshot.isFinished) {
      _pipeline?.stopAcceptingFrames(); unawaited(_finishRecordingAndPause());
    }
    // Skeleton gets every sample. Counter/safety transitions are immediate;
    // ordinary elapsed-time/metric text is limited to five updates per second.
    final important = previous == null || previous.stage != snapshot.stage ||
        previous.attempts != snapshot.attempts || previous.reps != snapshot.reps ||
        previous.verdict != snapshot.verdict || snapshot.cue != null ||
        previous.statusTextAr != snapshot.statusTextAr;
    if (important || tMs - _lastUiMs >= 200) {
      _lastUiMs = tMs; notifyListeners();
    }
  }

  /// Called by the screen on app lifecycle changes, phone calls and camera
  /// interruptions: stop judging, re-run the setup check when we come back.
  Future<void> handleLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && !_disposed) {
      _pipeline?.stopAcceptingFrames(); _engine.onInterrupted(_lastTMs);
      if (!(_snapshot?.isFinished ?? false)) _snapshot = null;
      poseFrames.value = null; unawaited(_cues.stop());
    }
    return _serial(() => _handleLifecycle(state));
  }
  Future<void> _handleLifecycle(AppLifecycleState state) async {
    if (_disposed) return;
    final CameraPosePipeline? pipeline = _pipeline;
    if (pipeline == null) return;

    if (state == AppLifecycleState.resumed) {
      if (!_foreground) return;
      if (_engine.stage == FormCoachStage.finished) return;
      try {
        await pipeline.start();
      } catch (error) {
        _failure = error is FormCoachCameraException ? error.failure : CameraFailure.unavailable;
        _errorTextAr = error is FormCoachCameraException ? error.messageAr : 'تعذر تشغيل الكاميرا — حاول تاني';
        notifyListeners();
      }
      return;
    }

    _recordRequested = false;
    await _recorder.discard();
    await pipeline.suspend();
    _engine.onInterrupted(_lastTMs);
    if (!(_snapshot?.isFinished ?? false)) _snapshot = null;
    await _cues.stop();
    notifyListeners();
  }

  Future<void> toggleCamera() => _serial(_toggleCamera);
  Future<void> _toggleCamera() async {
    final CameraPosePipeline? pipeline = _pipeline;
    if (pipeline == null || !pipeline.canSwitchCamera) return;
    try {
      _recordRequested = false;
      await _recorder.discard();
      if (_disposed) return;
      _recordingMessage = null;
      _engine.onInterrupted(_lastTMs);
      _snapshot = null;
      poseFrames.value = null;
      await _cues.stop();
      notifyListeners();
      await pipeline.switchCamera();
      notifyListeners();
    } catch (error) {
      _failure = error is FormCoachCameraException ? error.failure : CameraFailure.unavailable;
      _errorTextAr = error is FormCoachCameraException ? error.messageAr : 'تعذر تشغيل الكاميرا — حاول تاني';
      notifyListeners();
    }
  }

  Future<void> setAudioMode(FormAudioMode mode) async {
    await _cues.setMode(mode);
    _muted = mode == FormAudioMode.mute;
    notifyListeners();
  }

  Future<void> toggleMuted() async {
    await setAudioMode(_muted ? FormAudioMode.coach : FormAudioMode.mute);
  }

  Future<void> toggleDebug() async {
    _debug = await FormCoachDebugFlag.toggle();
    notifyListeners();
  }

  /// Arms/disarms recording for this set. Arming upgrades the camera before
  /// capture; the actual video starts when the engine enters the live stage.
  Future<void> toggleRecording() => _serial(_toggleRecording);
  Future<void> _toggleRecording() async {
    if (_disposed || !recordingAvailable) return;

    if (_recordRequested || _recorder.isRecording) {
      _recordRequested = false;
      await _pipeline?.pause();
      await _recorder.discard();
      try {
        await _pipeline?.setRecordingQuality(false);
        await _pipeline?.resume();
      } catch (_) {
        // The recording has already been cancelled; camera recovery is best effort.
      }
      _recordingMessage = 'التسجيل اتلغى';
      notifyListeners();
      return;
    }

    _recordRequested = true;
    _recordingMessage = 'التسجيل هيتحفظ على الموبايل بعد المجموعة';
    try {
      await _pipeline?.setRecordingQuality(true);
      if (_snapshot?.isLive == true) await _startRecordingNow();
    } catch (_) {
      _recordRequested = false;
      _recordingMessage = 'التسجيل غير متاح على الكاميرا دي';
    }
    notifyListeners();
  }

  Future<void> _startRecording() {
    final Future<void>? existing = _recordStartFuture;
    if (existing != null) return existing;
    final Future<void> future = _serial(_startRecordingNow);
    _recordStartFuture = future;
    return future.whenComplete(() {
      if (identical(_recordStartFuture, future)) _recordStartFuture = null;
    });
  }

  Future<void> _startRecordingNow() async {
      if (!_foreground || !_recordRequested || _recorder.isRecording) return;
      final CameraController? camera = _pipeline?.controller;
      if (camera == null) return;
      try {
        final callback = await _pipeline!.prepareRecording();
        await _recorder.start(camera, onAvailable: callback);
        _recordingMessage = 'جاري تسجيل المجموعة';
      } catch (_) {
        _recordRequested = false;
        _recordingMessage = 'تعذر بدء التسجيل — التمرين مستمر عادي';
        try {
          await _pipeline?.setRecordingQuality(false);
          await _pipeline?.pause();
          await _pipeline?.resume();
        } catch (_) {
          // Camera recovery is best effort; the Form Coach remains usable.
        }
      }
      notifyListeners();
  }

  Future<void> _finishRecordingAndPause() {
    if (_recordFinishing) return Future<void>.value();
    _recordFinishing = true;
    return _serial(_finishRecording).whenComplete(() => _recordFinishing = false);
  }
  Future<void> _finishRecording() async {
    try {
      if (_recorder.isRecording) {
        final CameraController? camera = _pipeline?.controller;
        if (camera != null) {
          final String? uri = await _recorder.stop(camera);
          _recordingMessage = uri == null
              ? 'المجموعة خلصت لكن تعذر حفظ الفيديو على الموبايل'
              : 'الفيديو اتحفظ على الموبايل';
        }
      }
      _recordRequested = false;
      await _pipeline?.pause();
    } catch (_) {
      _recordRequested = false;
      _recordingMessage = 'المجموعة خلصت لكن تعذر حفظ الفيديو على الموبايل';
      await _recorder.discard();
      await _pipeline?.pause();
    } finally {
      _recordFinishing = false;
      notifyListeners();
    }
  }

  /// Restarts the temporary set counter. Nothing is saved anywhere.
  Future<void> restartSet() => _serial(_restartSet);
  Future<void> _restartSet() async {
    _recordRequested = false;
    _recordingMessage = null;
    await _recorder.discard();
    await _pipeline?.pause();
    if (_disposed) return;
    _engine.reset();
    _snapshot = null;
    poseFrames.value = null;
    await _cues.stop();
    notifyListeners();
    final CameraPosePipeline? pipeline = _pipeline;
    if (pipeline == null) return;
    try {
      await pipeline.setRecordingQuality(false);
      await pipeline.resume();
    } catch (error) {
      _failure = error is FormCoachCameraException ? error.failure : CameraFailure.unavailable;
      _errorTextAr = error is FormCoachCameraException ? error.messageAr : 'تعذر تشغيل الكاميرا — حاول تاني';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pipeline?.stopAcceptingFrames();
    poseFrames.dispose();
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    _subscription = null;
    final CameraPosePipeline? pipeline = _pipeline;
    _pipeline = null;
    unawaited(_cues.dispose());
    unawaited(_disposeRecordingAndPipeline(pipeline));
    _engine.reset();
    super.dispose();
  }

  Future<void> _disposeRecordingAndPipeline(CameraPosePipeline? pipeline) async {
    // The recorder must release video capture before the camera controller is
    // disposed; otherwise the platform can leave a partial temp file behind.
    await _operations.settled;
    await _recorder.dispose();
    await pipeline?.dispose();
  }
}
