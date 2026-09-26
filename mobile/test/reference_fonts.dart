import 'package:flutter/services.dart';

/// Use the shipped typography when measuring Arabic layouts, not the square
/// glyphs of Flutter's default Ahem test font.
Future<void> loadReferenceFonts() async {
  final loader = FontLoader('Cairo')
    ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
  await loader.load();
}
