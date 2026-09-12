import 'dart:math' as math;
import 'package:elforma/widgets/brand_experience_visual.dart';
import 'package:flutter/material.dart';

const brandIntroDuration = Duration(milliseconds: 5500);

/// Seconds, rather than network progress, drive every track.
class BrandIntroTiming {
  static double fraction(double seconds, double start, double end) =>
      ((seconds - start) / (end - start)).clamp(0.0, 1.0);
  static double ease(double seconds, double start, double end) {
    final t = fraction(seconds, start, end);
    return t * t * (3 - 2 * t);
  }
}

class BrandIntroScene extends StatelessWidget {
  const BrandIntroScene({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final sec = reduced ? 5.5 : progress.clamp(0.0, 1.0) * 5.5;
    double ease(double start, double end) =>
        BrandIntroTiming.ease(sec, start, end);
    Widget object(
      String id,
      String asset,
      Rect rect,
      double start,
      double end,
      Offset from, {
      double angle = 0,
      double turn = 0,
    }) {
      final p = ease(start, end);
      return BrandObject(
        key: ValueKey(id),
        asset: asset,
        rect: rect,
        offset: from * (1 - p),
        angle: angle + turn * (1 - p),
        opacity: ease(start, start + .18),
        scale: .94 + .06 * p,
      );
    }

    // Motion eases to zero before the 1-second final hold; never repeats.
    final phase = ease(1.15, 4.3) * math.pi;
    final ribbon = ease(1.2, 3.65);
    final leafRects = <Rect>[
      const Rect.fromLTWH(62, 354, 55, 44),
      const Rect.fromLTWH(294, 366, 52, 36),
      const Rect.fromLTWH(368, 493, 41, 52),
      const Rect.fromLTWH(59, 622, 51, 40),
      const Rect.fromLTWH(328, 658, 49, 48),
      const Rect.fromLTWH(17, 447, 28, 33),
      const Rect.fromLTWH(248, 691, 31, 23),
    ];
    return BrandExperienceBackdrop(
      child: SafeArea(
        child: BrandDesignFrame(
          height: 900,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Logo segments become the exact whole logo at the end of assembly.
              Positioned(
                left: 98,
                top: 77,
                width: 242,
                height: 153,
                child: _AssemblingLogo(progress: ease(.12, 1.12)),
              ),
              Positioned(
                left: 37,
                top: 247,
                width: 358,
                height: 40,
                child: Opacity(
                  opacity: ease(.75, 1.35),
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - ease(.75, 1.35))),
                    child: const Text(
                      'أنت تستحق الأفضل دائمًا',
                      key: ValueKey('intro-tagline'),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'ElFormaArabic',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: brandInk,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 163,
                top: 293,
                width: 108,
                height: 20,
                child: Opacity(
                  opacity: ease(1, 1.5),
                  child: CustomPaint(painter: _SignaturePainter()),
                ),
              ),
              BrandGroundShadow(
                rect: const Rect.fromLTWH(105, 705, 260, 30),
                opacity: .2 * ease(.6, 2.1),
              ),
              Positioned(
                left: 22,
                top: 380,
                width: 390,
                height: 314,
                child: BrandRibbons(
                  front: false,
                  reveal: ribbon,
                  phase: phase,
                  variant: 4,
                ),
              ),
              object(
                'intro-dumbbell',
                BrandExperienceAssets.introDumbbell,
                const Rect.fromLTWH(35, 460, 202, 164),
                .68,
                1.85,
                const Offset(-135, 28),
                turn: -.2,
              ),
              object(
                'intro-shaker',
                BrandExperienceAssets.introShaker,
                const Rect.fromLTWH(137, 371, 149, 268),
                .95,
                2.1,
                const Offset(20, -95),
                turn: .14,
              ),
              object(
                'intro-bowl',
                BrandExperienceAssets.introBowl,
                const Rect.fromLTWH(193, 527, 210, 155),
                1.28,
                2.5,
                const Offset(130, 60),
                turn: .13,
              ),
              object(
                'intro-avocado',
                BrandExperienceAssets.avocado,
                const Rect.fromLTWH(354, 437, 35, 43),
                1.6,
                2.85,
                const Offset(28, -145),
                angle: .2,
                turn: .8,
              ),
              object(
                'intro-tomato',
                BrandExperienceAssets.tomato,
                const Rect.fromLTWH(107, 634, 35, 38),
                1.85,
                3.1,
                const Offset(-48, -155),
                angle: -.12,
                turn: -.8,
              ),
              Positioned(
                left: 22,
                top: 380,
                width: 390,
                height: 314,
                child: BrandRibbons(
                  front: true,
                  reveal: ribbon,
                  phase: phase,
                  variant: 4,
                ),
              ),
              for (var i = 0; i < leafRects.length; i++)
                object(
                  'intro-leaf-$i',
                  BrandExperienceAssets.leaf,
                  leafRects[i],
                  1.45 + i * .12,
                  2.95 + i * .13,
                  Offset(i.isEven ? -55 : 55, -65 - i * 7.0),
                  angle: i * .8,
                  turn: i.isEven ? -.45 : .45,
                ),
              Positioned(
                left: 81,
                top: 757,
                width: 276,
                height: 48,
                child: CustomPaint(painter: _PulsePainter(ease(3.1, 4.3))),
              ),
              for (var i = 0; i < 3; i++) ...[
                Positioned(
                  left: 84 + i * 132.0 - 27,
                  top: 750,
                  width: 54,
                  height: 54,
                  child: Opacity(
                    opacity: ease(2.9 + i * .25, 3.45 + i * .25),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        12 * (1 - ease(2.9 + i * .25, 3.55 + i * .25)),
                      ),
                      child: BrandBadge(kind: BrandVisualKind.values[i + 1]),
                    ),
                  ),
                ),
                Positioned(
                  left: 34 + i * 132.0,
                  top: 813,
                  width: 100,
                  height: 34,
                  child: Opacity(
                    opacity: ease(3.15 + i * .25, 3.7 + i * .25),
                    child: Text(
                      const ['رياضة', 'تغذية', 'صحة أفضل'][i],
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'ElFormaArabic',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: brandInk,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssemblingLogo extends StatelessWidget {
  const _AssemblingLogo({required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      BrandExperienceAssets.illuminatedLogo,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    if (progress >= 1) return image;
    return Opacity(
      opacity: (progress * 4).clamp(0.0, 1.0),
      child: LayoutBuilder(
        builder: (_, box) => Stack(
          children: [
            for (var i = 0; i < 3; i++)
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(
                    (i == 1 ? -15.0 : 10.0) * (1 - progress),
                    (i - 1) * 12 * (1 - progress),
                  ),
                  child: ClipRect(
                    clipper: _LogoPart(i),
                    child: Image.asset(
                      BrandExperienceAssets.illuminatedLogo,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogoPart extends CustomClipper<Rect> {
  const _LogoPart(this.part);
  final int part;
  @override
  Rect getClip(Size s) {
    const cuts = [0.0, .46, .83, 1.0];
    return Rect.fromLTRB(
      0,
      s.height * cuts[part],
      s.width,
      s.height * cuts[part + 1],
    );
  }

  @override
  bool shouldReclip(covariant _LogoPart old) => old.part != part;
}

class _SignaturePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = brandInk
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    c.drawPath(
      Path()
        ..moveTo(0, 5)
        ..quadraticBezierTo(4, 10, 8, 10)
        ..lineTo(36, 10),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(72, 10)
        ..lineTo(100, 10)
        ..quadraticBezierTo(104, 10, 108, 5),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(47, 17)
        ..quadraticBezierTo(43, 3, 62, 1)
        ..quadraticBezierTo(63, 17, 47, 17),
      Paint()..color = const Color(0xFF5B9C23),
    );
    c.drawLine(
      const Offset(47, 20),
      const Offset(58, 5),
      Paint()
        ..color = brandInk
        ..strokeWidth = .8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter(this.progress);
  final double progress;
  @override
  void paint(Canvas c, Size s) {
    final path = Path()
      ..moveTo(0, 27)
      ..cubicTo(42, 27, 49, 15, 76, 15)
      ..lineTo(90, 15)
      ..lineTo(96, 8)
      ..lineTo(103, 33)
      ..lineTo(112, 8)
      ..lineTo(119, 18)
      ..cubicTo(154, 18, 183, 37, 207, 37)
      ..cubicTo(228, 37, 252, 19, 276, 19);
    final metric = path.computeMetrics().first;
    c.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = const Color(0xFF468F58)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.progress != progress;
}
