/// Minimal scroll needed to reveal an authentication field, in logical pixels.
///
/// A field taller than the viewport cannot be fully exposed. Once it intersects
/// the usable area, leave caret visibility to EditableText rather than bouncing
/// between the field's top and bottom on successive keyboard metric updates.
double authFieldRevealOffset({
  required double offset,
  required double minOffset,
  required double maxOffset,
  required double viewportTop,
  required double viewportBottom,
  required double fieldTop,
  required double fieldBottom,
  double margin = 12,
}) {
  final top = viewportTop + margin;
  final bottom = viewportBottom - margin;
  if (bottom <= top) return offset;
  final oversized = fieldBottom - fieldTop > bottom - top;
  if (oversized && fieldTop < bottom && fieldBottom > top) return offset;
  final delta = oversized || fieldTop < top
      ? fieldTop - top
      : fieldBottom > bottom
      ? fieldBottom - bottom
      : 0.0;
  return (offset + delta).clamp(minOffset, maxOffset).toDouble();
}
