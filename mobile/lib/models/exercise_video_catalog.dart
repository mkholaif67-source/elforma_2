import 'dart:convert';
import 'package:flutter/services.dart';

/// The exact exercise -> YouTube id catalogue bundled with the APK.
///
/// It is generated from app/workout/engine/db.js. There is no search, muscle
/// fallback, or guessed replacement. An explicit online admin override wins;
/// otherwise the APK's authored id wins even when the backend is unavailable.
class ExerciseVideoCatalog {
  ExerciseVideoCatalog._();
  static final ExerciseVideoCatalog I = ExerciseVideoCatalog._();

  Map<String, String> _videos = const {};
  bool _loaded = false;

  bool get loaded => _loaded;
  int get count => _videos.length;

  Future<void> load() async {
    if (_loaded) return;
    final text = await rootBundle.loadString(
      'assets/catalog/exercise_videos.json',
      cache: true,
    );
    final decoded = jsonDecode(text);
    if (decoded is! Map || decoded['videos'] is! Map) {
      throw const FormatException('invalid bundled exercise video catalogue');
    }
    final out = <String, String>{};
    for (final entry in (decoded['videos'] as Map).entries) {
      final key = normalize(entry.key.toString());
      final id = extractId(entry.value);
      if (key.isNotEmpty && id.isNotEmpty) out[key] = id;
    }
    if (out.isEmpty) {
      throw const FormatException('empty bundled exercise video catalogue');
    }
    _videos = Map.unmodifiable(out);
    _loaded = true;
  }

  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  static String extractId(dynamic raw) {
    final value = '${raw ?? ''}'.trim();
    if (value.isEmpty || value == 'null' || value == 'undefined' || value == 'none') {
      return '';
    }
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isEmpty ? '' : _valid(uri.pathSegments.first);
      }
      final queryId = uri.queryParameters['v'];
      if (queryId != null && queryId.isNotEmpty) return _valid(queryId);
      final parts = uri.pathSegments;
      final marker = parts.indexWhere((p) => p == 'embed' || p == 'shorts');
      if (marker >= 0 && marker + 1 < parts.length) return _valid(parts[marker + 1]);
      return '';
    }
    return _valid(value);
  }

  static String _valid(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{8,14}$').hasMatch(value) ? value : '';

  String resolve({required String exerciseName, required Map raw}) {
    final source = '${raw['videoSource'] ?? ''}'.trim().toLowerCase();
    if (source == 'removed') return '';

    // An admin override is an intentional owner edit, not an automatic fallback.
    if (source == 'override') {
      for (final key in const ['videoId', 'videoUrl', 'vid', 'v', 'video']) {
        final id = extractId(raw[key]);
        if (id.isNotEmpty) return id;
      }
    }

    final bundled = _videos[normalize(exerciseName)];
    if (bundled != null && bundled.isNotEmpty) return bundled;

    // Newly added exercises may not exist in an older APK. Use only the exact
    // authored id sent for that exercise; never substitute another exercise.
    for (final key in const ['videoId', 'videoUrl', 'vid', 'v', 'video']) {
      final id = extractId(raw[key]);
      if (id.isNotEmpty) return id;
    }
    return '';
  }
}
