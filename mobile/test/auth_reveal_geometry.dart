// Also executable with the standalone Dart SDK; no Flutter runtime required.
import 'package:elforma/widgets/auth_field_reveal.dart';

void verifyAuthRevealGeometry() {
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  double reveal(double top, double bottom, {double offset = 200}) =>
      authFieldRevealOffset(
        offset: offset,
        minOffset: 0,
        maxOffset: 1000,
        viewportTop: 24,
        viewportBottom: 344,
        fieldTop: top,
        fieldBottom: bottom,
      );

  check(reveal(80, 136) == 200, 'Visible fields must not move');
  check(reveal(310, 366) == 234, 'Only the obscured lower 34px must move');
  check(reveal(10, 66) == 174, 'Only the obscured upper 26px must move');
  check(reveal(-20, 500) == 200, 'Oversized field must not oscillate');
  check(reveal(100, 500) == 200, 'Let EditableText expose the caret');
  check(
    reveal(400, 900) == 564,
    'Entirely hidden oversized field must enter view',
  );
  check(reveal(-100, -44, offset: 0) == 0, 'Respect the first scroll extent');
  check(
    reveal(400, 456, offset: 990) == 1000,
    'Respect the last scroll extent',
  );
  check(
    authFieldRevealOffset(
          offset: 100,
          minOffset: 0,
          maxOffset: 1000,
          viewportTop: 0,
          viewportBottom: 20,
          fieldTop: 40,
          fieldBottom: 96,
        ) ==
        100,
    'Transient collapsed viewport must not trigger movement',
  );

  // Re-applying after the scroll must be stable, including oversized fields.
  // For fields that fit, both edges must be visible whenever extents permit it.
  for (final height in [56.0, 100.0, 296.0, 400.0]) {
    for (var y = -100.0; y <= 500; y += 5) {
      final target = reveal(y, y + height, offset: 400);
      final delta = target - 400;
      final next = reveal(y - delta, y + height - delta, offset: target);
      check(
        (next - target).abs() < .001,
        'Non-idempotent reveal: $y / $height',
      );
      if (height <= 296) {
        check(
          y - delta >= 36 && y + height - delta <= 332,
          'Field remains obscured: $y / $height',
        );
      }
    }
  }
}

void main() {
  verifyAuthRevealGeometry();
  print(
    'Auth reveal: 9 boundary cases and 484 stability/visibility cases passed.',
  );
}
