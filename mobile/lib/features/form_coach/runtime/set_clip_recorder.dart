// Form Coach - opt-in local-only set recording.
//
// The recording is started only when the user arms it. The returned camera file
// is copied byte-for-byte to the phone's Movies/ElForma/Form Coach folder by the
// Android MediaStore bridge. No upload, database write, server call, or video
// re-encoding exists in this feature.

import 'dart:io' show File, Platform;

import 'package:camera/camera.dart';
import 'package:elforma/features/form_coach/runtime/local_video_saver.dart';
import 'package:elforma/features/form_coach/runtime/serial_operations.dart';

abstract class SetClipRecorder {
  bool get isAvailable;
  bool get isRecording;

  Future<void> start(CameraController controller, {void Function(CameraImage)? onAvailable});
  Future<String?> stop(CameraController controller);
  Future<void> discard();
  Future<void> dispose();
}

class LocalSetClipRecorder implements SetClipRecorder {
  LocalSetClipRecorder({LocalVideoSaver saver = const LocalVideoSaver()})
      : _saver = saver;

  final LocalVideoSaver _saver;
  CameraController? _controller;
  String? _temporaryPath;
  bool _recording = false;
  bool _closed = false;
  final SerialOperations _operations = SerialOperations();

  @override
  bool get isAvailable => Platform.isAndroid;

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start(CameraController controller, {void Function(CameraImage)? onAvailable}) => _operations.run(() async {
    if (!isAvailable || _closed || _recording) return;
    if (!controller.value.isInitialized || controller.value.isRecordingVideo) return;
    await controller.startVideoRecording(onAvailable: onAvailable, enablePersistentRecording: false);
    _controller = controller;
    _recording = true;
  });

  @override
  Future<String?> stop(CameraController controller) => _operations.run(() async {
    if (!_recording) return null;
    final CameraController active = _controller ?? controller;
    final XFile clip = await active.stopVideoRecording();
    _recording = false;
    _controller = null;
    _temporaryPath = clip.path;
    final String? savedUri = await _saver.save(
      clip.path,
      displayName: 'elforma_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    if (savedUri != null) {
      await _deleteTemporary();
      return savedUri;
    }
    // Keep the temp path until dispose/discard so a failed MediaStore copy is
    // not silently destroyed.
    return null;
  });

  @override
  Future<void> discard() => _operations.run(() async {
    final CameraController? active = _controller;
    _recording = false;
    _controller = null;
    if (active != null && active.value.isRecordingVideo) {
      try {
        final XFile clip = await active.stopVideoRecording();
        _temporaryPath = clip.path;
      } catch (_) {
        // The camera may already have stopped during lifecycle interruption.
      }
    }
    await _deleteTemporary();
  });

  Future<void> _deleteTemporary() async {
    final String? path = _temporaryPath;
    _temporaryPath = null;
    if (path == null || path.isEmpty) return;
    try {
      final File file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cache cleanup is best effort; no user data is uploaded.
    }
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await discard();
  }
}

/// Used on unsupported platforms and in tests.
class DisabledSetClipRecorder implements SetClipRecorder {
  const DisabledSetClipRecorder();

  @override
  bool get isAvailable => false;

  @override
  bool get isRecording => false;

  @override
  Future<void> start(CameraController controller, {void Function(CameraImage)? onAvailable}) async {}

  @override
  Future<String?> stop(CameraController controller) async => null;

  @override
  Future<void> discard() async {}

  @override
  Future<void> dispose() async {}
}
