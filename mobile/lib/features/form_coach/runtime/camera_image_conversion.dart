import 'dart:typed_data';

/// YUV_420_888 planes have independent row/pixel strides. Concatenating them
/// is not NV21: NV21 needs packed Y followed by interleaved V,U samples.
Uint8List packNv21({required int width, required int height,
  required List<Uint8List> planes, required List<int> rowStrides,
  required List<int> pixelStrides}) {
  final output = Uint8List(width * height * 3 ~/ 2);
  var offset = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      output[offset++] = planes[0][y * rowStrides[0] + x * pixelStrides[0]];
    }
  }
  for (var y = 0; y < height ~/ 2; y++) {
    for (var x = 0; x < width ~/ 2; x++) {
      output[offset++] = planes[2][y * rowStrides[2] + x * pixelStrides[2]];
      output[offset++] = planes[1][y * rowStrides[1] + x * pixelStrides[1]];
    }
  }
  return output;
}

int compensatedRotation(int sensor, int deviceDegrees, bool front) =>
    (sensor + (front ? deviceDegrees : -deviceDegrees) + 360) % 360;
