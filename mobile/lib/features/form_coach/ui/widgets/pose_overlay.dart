// Form Coach - skeleton overlay.
//
// Landmarks are normalised (0..1) in the rotated image space, so the painter
// reproduces the BoxFit.cover math of the preview to stay aligned. Front camera
// previews are mirrored, so x is flipped for drawing only (landmark identity and
// every measurement stay anatomical).

import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:flutter/material.dart';

class PoseOverlay extends StatelessWidget {
  const PoseOverlay({
    super.key,
    required this.sample,
    required this.imageAspect,
    required this.mirror,
    required this.verdict,
    this.showConfidence = false,
    this.minVisibility = 0.4,
  });

  final PoseSample? sample;
  final double imageAspect;
  final bool mirror;
  final FormVerdict verdict;
  final bool showConfidence;
  final double minVisibility;

  @override
  Widget build(BuildContext context) {
    final PoseSample? pose = sample;
    if (pose == null || pose.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _PosePainter(
          sample: pose,
          imageAspect: imageAspect,
          mirror: mirror,
          color: _colorFor(verdict),
          showConfidence: showConfidence,
          minVisibility: minVisibility,
        ),
        size: Size.infinite,
      ),
    );
  }

  static Color _colorFor(FormVerdict verdict) {
    switch (verdict) {
      case FormVerdict.clearError:
        return const Color(0xFFE2703A);
      case FormVerdict.tracking:
      case FormVerdict.cannotAssess:
        return const Color(0xFF9BA7A0);
      case FormVerdict.finished:
        return const Color(0xFF8FD0A6);
      case FormVerdict.correct:
        return const Color(0xFFB4D565);
    }
  }
}

class _PosePainter extends CustomPainter {
  _PosePainter({
    required this.sample,
    required this.imageAspect,
    required this.mirror,
    required this.color,
    required this.showConfidence,
    required this.minVisibility,
  });

  final PoseSample sample;
  final double imageAspect;
  final bool mirror;
  final Color color;
  final bool showConfidence;
  final double minVisibility;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || imageAspect <= 0) return;

    final double boxAspect = size.width / size.height;
    double drawWidth;
    double drawHeight;
    if (boxAspect > imageAspect) {
      drawWidth = size.width;
      drawHeight = size.width / imageAspect;
    } else {
      drawHeight = size.height;
      drawWidth = size.height * imageAspect;
    }
    final double dx = (size.width - drawWidth) / 2;
    final double dy = (size.height - drawHeight) / 2;

    Offset? project(FcLandmark landmark) {
      final FcPoint? point =
          sample.point(landmark, minVisibility: minVisibility);
      if (point == null) return null;
      final double x = mirror ? 1 - point.x : point.x;
      return Offset(dx + x * drawWidth, dy + point.y * drawHeight);
    }

    final Paint bonePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final List<FcLandmark> edge in kFcSkeletonEdges) {
      final Offset? a = project(edge[0]);
      final Offset? b = project(edge[1]);
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, bonePaint);
    }

    final Paint jointPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92);

    for (final FcLandmark landmark in FcLandmark.values) {
      final FcPoint? point =
          sample.point(landmark, minVisibility: minVisibility);
      if (point == null) continue;
      final double x = mirror ? 1 - point.x : point.x;
      final Offset center =
          Offset(dx + x * drawWidth, dy + point.y * drawHeight);
      canvas.drawCircle(center, 4, jointPaint);

      if (showConfidence) {
        final TextPainter painter = TextPainter(
          text: TextSpan(
            text: point.visibility.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, center + const Offset(5, -12));
      }
    }
  }

  @override
  bool shouldRepaint(_PosePainter old) =>
      old.sample != sample ||
      old.color != color ||
      old.mirror != mirror ||
      old.showConfidence != showConfidence ||
      old.imageAspect != imageAspect;
}
