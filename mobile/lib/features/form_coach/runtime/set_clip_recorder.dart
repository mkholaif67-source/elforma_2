// Form Coach - optional local-only set recording: structure prepared, OFF.
//
// Decision: recording video while running pose inference on the same camera
// stream is the main source of dropped frames and overheating on mid-range
// Android devices, and the core feature must not pay that price. So the seam is
// defined here and the shipped implementation is a no-op.
//
// A future implementation must keep these guarantees:
//  - files stay in the app's temporary directory (never the gallery, never a
//    server, never a database)
//  - the user reviews the clip after the set and either saves it to the device
//    or discards it
//  - discard deletes the temp file immediately; leaving the screen without a
//    decision also deletes it
//  - no upload path exists anywhere in the feature

abstract class SetClipRecorder {
  /// Whether recording can be offered at all on this device/build.
  bool get isAvailable;

  bool get isRecording;

  Future<void> start();

  /// Returns the local temp file path, or null when nothing was recorded.
  Future<String?> stop();

  /// Deletes the temporary file if it still exists.
  Future<void> discard();

  Future<void> dispose();
}

/// Shipped implementation: disabled, so privacy and performance are unaffected.
class DisabledSetClipRecorder implements SetClipRecorder {
  const DisabledSetClipRecorder();

  @override
  bool get isAvailable => false;

  @override
  bool get isRecording => false;

  @override
  Future<void> start() async {}

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> discard() async {}

  @override
  Future<void> dispose() async {}
}
