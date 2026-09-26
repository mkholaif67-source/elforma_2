import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:elforma/features/form_coach/runtime/camera_image_conversion.dart';

void main() {
  test('NV21 chroma cannot make a dark frame look bright', () {
    final bytes = Uint8List(24)..fillRange(16, 24, 255);
    expect(
        sampleFrameLuma(bytes, width: 4, height: 4, rowStride: 4, bgra: false),
        0);
  });
  test('BGRA alpha and row padding are excluded', () {
    final bytes = Uint8List(40)..fillRange(0, 40, 255);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 4; col++) {
        bytes.fillRange(row * 20 + col * 4, row * 20 + col * 4 + 3, 0);
      }
    }
    expect(
        sampleFrameLuma(bytes, width: 4, height: 2, rowStride: 20, bgra: true),
        0);
    expect(
        sampleFrameLuma(Uint8List(1),
            width: 4, height: 2, rowStride: 20, bgra: true),
        isNull);
  });
}
