import 'package:flutter/services.dart';

/// Android-only bridge for saving the camera's original MP4 into MediaStore.
/// The native side copies bytes; it never decodes or recompresses the video.
class LocalVideoSaver {
  const LocalVideoSaver();

  static const MethodChannel _channel = MethodChannel('elforma/local_video');

  Future<String?> save(String path, {required String displayName}) async {
    try {
      final bool? permission =
          await _channel.invokeMethod<bool>('requestWritePermission');
      if (permission != true) return null;
      return await _channel.invokeMethod<String>('saveVideo', <String, dynamic>{
        'path': path,
        'displayName': displayName,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
