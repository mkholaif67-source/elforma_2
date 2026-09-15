import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum BrandVisualKind { brand, sport, nutrition, health }

enum BrandBackdropVariant {
  brand,
  onboardingBrand,
  onboardingSport,
  onboardingNutrition,
  onboardingHealth,
}

/// Every animated item has its own file; no ingredient atlas is displayed.
class BrandExperienceAssets {
  const BrandExperienceAssets._();
  static const root = 'assets/brand_experience_v5';
  static const lightBackdrop = '$root/backdrop.webp';
  static const illuminatedLogo = '$root/logo.png';
  static const introShaker = '$root/shaker.png';
  static const introDumbbell = '$root/intro_dumbbell.png';
  static const introBowl = '$root/intro_bowl.png';
  static const tomato = '$root/tomato.png';
  static const avocado = '$root/avocado.png';
  static const leaf = '$root/leaf.png';
  static const sprout = '$root/sprout.png';
  static const athlete = '$root/athlete.png';
  static const onboardingSport = '$root/dumbbell.png';
  static const onboardingNutrition = '$root/bowl.png';
  static const onboardingHealth = '$root/stones.png';
  static const all = <String>[
    lightBackdrop,
    illuminatedLogo,
    introShaker,
    introDumbbell,
    introBowl,
    tomato,
    avocado,
    leaf,
    sprout,
    athlete,
    onboardingSport,
    onboardingNutrition,
    onboardingHealth,
  ];
}

const brandInk = Color(0xFF005438);
const brandIvory = Color(0xFFF6F8ED);

class BrandExperienceBackdrop extends StatelessWidget {
  const BrandExperienceBackdrop({
    super.key,
    this.child,
    this.variant = BrandBackdropVariant.brand,
    this.motion = 0,
  });
  final Widget? child;
  final BrandBackdropVariant variant;
  final double motion;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: brandIvory,
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Static plate, independent of all animation clocks.
        RepaintBoundary(
          child: Image.asset(
            BrandExperienceAssets.lightBackdrop,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
        if (child != null) child!,
      ],
    ),
  );
}

class BrandDesignFrame extends StatelessWidget {
  const BrandDesignFrame({super.key, this.height = 768, required this.child});
  final double height;
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(width: 432, height: height, child: child),
    ),
  );
}

class BrandObject extends StatelessWidget {
  const BrandObject({
    super.key,
    required this.asset,
    required this.rect,
    this.angle = 0,
    this.opacity = 1,
    this.offset = Offset.zero,
    this.scale = 1,
    this.fadeFoot = false,
  });
  final String asset;
  final Rect rect;
  final double angle, opacity, scale;
  final Offset offset;
  final bool fadeFoot;
  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    );
    if (fadeFoot) {
      image = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, .7, 1],
        ).createShader(r),
        child: image,
      );
    }
    return Positioned.fromRect(
      rect: rect.shift(offset),
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(scale: scale, child: image),
        ),
      ),
    );
  }
}

class BrandGroundShadow extends StatelessWidget {
  const BrandGroundShadow({super.key, required this.rect, this.opacity = .25});
  final Rect rect;
  final double opacity;
  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: rect,
    child: CustomPaint(painter: _GroundShadowPainter(opacity)),
  );
}

class _GroundShadowPainter extends CustomPainter {
  const _GroundShadowPainter(this.opacity);
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(Rect.fromLTWH(size.width * .07, size.height * .28,
      size.width * .86, size.height * .44), Paint()
      ..color = const Color(0xFF344325).withValues(alpha: opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * .22));
  }
  @override
  bool shouldRepaint(covariant _GroundShadowPainter old) => old.opacity != opacity;
}

/// Art-only 432 x 540 canvas; text and controls are native parent widgets.
class BrandExperienceVisual extends StatelessWidget {
  const BrandExperienceVisual({
    super.key,
    required this.kind,
    this.progress = 0,
  });
  final BrandVisualKind kind;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final phase = progress * math.pi * 2;
    final isBrand = kind == BrandVisualKind.brand;
    final ribbonRect = switch (kind) {
      BrandVisualKind.brand => const Rect.fromLTWH(67, 257, 302, 242),
      BrandVisualKind.sport => const Rect.fromLTWH(42, 235, 351, 240),
      BrandVisualKind.nutrition => const Rect.fromLTWH(27, 286, 380, 228),
      BrandVisualKind.health => const Rect.fromLTWH(48, 283, 338, 210),
    };
    final leaves = switch (kind) {
      BrandVisualKind.brand => const [
        Rect.fromLTWH(77, 265, 64, 48),
        Rect.fromLTWH(274, 259, 45, 48),
        Rect.fromLTWH(56, 391, 40, 46),
        Rect.fromLTWH(281, 436, 66, 51),
        Rect.fromLTWH(343, 367, 42, 46),
        Rect.fromLTWH(110, 468, 35, 32),
      ],
      BrandVisualKind.sport => const [
        Rect.fromLTWH(176, 203, 69, 62),
        Rect.fromLTWH(73, 264, 37, 46),
        Rect.fromLTWH(349, 342, 39, 49),
        Rect.fromLTWH(35, 365, 48, 53),
        Rect.fromLTWH(187, 448, 47, 39),
        Rect.fromLTWH(305, 255, 29, 32),
      ],
      BrandVisualKind.nutrition => const [
        Rect.fromLTWH(62, 278, 63, 48),
        Rect.fromLTWH(285, 277, 68, 44),
        Rect.fromLTWH(367, 334, 35, 53),
        Rect.fromLTWH(57, 475, 55, 34),
        Rect.fromLTWH(303, 510, 51, 29),
        Rect.fromLTWH(386, 449, 28, 36),
      ],
      BrandVisualKind.health => const [
        Rect.fromLTWH(65, 333, 36, 50),
        Rect.fromLTWH(333, 401, 39, 44),
        Rect.fromLTWH(55, 464, 56, 25),
        Rect.fromLTWH(310, 472, 63, 27),
        Rect.fromLTWH(296, 283, 24, 31),
        Rect.fromLTWH(114, 275, 24, 30),
      ],
    };
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 432,
        height: 540,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            BrandGroundShadow(
              rect: isBrand
                  ? const Rect.fromLTWH(110, 492, 219, 35)
                  : kind == BrandVisualKind.nutrition
                  ? const Rect.fromLTWH(68, 501, 293, 35)
                  : const Rect.fromLTWH(66, 467, 310, 40),
              opacity: isBrand ? .15 : .28,
            ),
            Positioned.fromRect(
              rect: ribbonRect,
              child: BrandRibbons(
                phase: phase,
                front: false,
                variant: kind.index,
              ),
            ),
            if (isBrand) ...[
              const BrandObject(
                asset: BrandExperienceAssets.illuminatedLogo,
                rect: Rect.fromLTWH(110, 79, 220, 140),
              ),
              const BrandObject(
                asset: BrandExperienceAssets.athlete,
                rect: Rect.fromLTWH(143, 243, 145, 243),
                fadeFoot: true,
              ),
            ] else if (kind == BrandVisualKind.sport)
              const BrandObject(
                asset: BrandExperienceAssets.onboardingSport,
                rect: Rect.fromLTWH(75, 292, 291, 188),
              )
            else if (kind == BrandVisualKind.nutrition)
              const BrandObject(
                asset: BrandExperienceAssets.onboardingNutrition,
                rect: Rect.fromLTWH(53, 280, 326, 250),
              )
            else ...[
              const BrandObject(
                asset: BrandExperienceAssets.onboardingHealth,
                rect: Rect.fromLTWH(96, 282, 242, 211),
              ),
              BrandObject(
                asset: BrandExperienceAssets.sprout,
                rect: const Rect.fromLTWH(134, 170, 155, 121),
                angle: math.sin(phase) * .014,
              ),
            ],
            Positioned.fromRect(
              rect: ribbonRect,
              child: BrandRibbons(
                phase: phase,
                front: true,
                variant: kind.index,
              ),
            ),
            for (var i = 0; i < leaves.length; i++)
              BrandObject(
                asset: BrandExperienceAssets.leaf,
                rect: leaves[i],
                angle: i * .87 + math.sin(phase + i) * .055,
                offset: Offset(
                  math.sin(phase + i) * 2,
                  math.cos(phase + i) * 2,
                ),
              ),
            if (isBrand) ...[
              const Positioned(
                left: 69,
                top: 326,
                width: 72,
                height: 72,
                child: BrandBadge(kind: BrandVisualKind.sport),
              ),
              const Positioned(
                left: 277,
                top: 299,
                width: 76,
                height: 76,
                child: BrandBadge(kind: BrandVisualKind.nutrition),
              ),
              const Positioned(
                left: 179,
                top: 422,
                width: 78,
                height: 78,
                child: BrandBadge(kind: BrandVisualKind.health),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tapered translucent mesh bands. Two passes give real foreground occlusion.
class BrandRibbons extends StatelessWidget {
  const BrandRibbons({
    super.key,
    this.phase = 0,
    this.reveal = 1,
    required this.front,
    this.variant = 0,
  });
  final double phase, reveal;
  final bool front;
  final int variant;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _RibbonPainter(phase, reveal, front, variant)),
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter(this.phase, this.reveal, this.front, this.variant);
  final double phase, reveal;
  final bool front;
  final int variant;
  // Each band folds and tapers independently. Its upper half is behind the
  // subject and its lower half crosses the foreground in the same coordinate space.
  Offset point(double t, Size s, double band) {
    final a = -math.pi + t * math.pi * 2;
    final wave = math.sin(t * math.pi * 3 + band * 1.7 + phase * .08);
    final x = math.cos(a) * (.46 - .025 * band + .015 * wave);
    final y = math.sin(a) * (.36 - .09 * band);
    final tilt = variant == 3
        ? .42
        : variant == 4
        ? .24
        : -.10;
    return Offset(
      s.width * (.5 + x),
      s.height *
          (.5 + y + x * tilt + .06 * band * wave + math.sin(phase) * .008),
    );
  }

  @override
  void paint(Canvas c, Size s) {
    if (reveal <= 0) return;
    final start = front ? .5 : 0.0;
    final end = math.min(front ? 1.0 : .5, reveal);
    if (end <= start) return;
    for (var band = 0; band < 2; band++) {
      final positions = <Offset>[];
      final colors = <Color>[];
      final edge = Path();
      const slices = 100, across = 6;
      Offset at(double t, int k) {
        final p = point(t, s, band.toDouble());
        final d = point(t + .0001, s, band.toDouble()) - p;
        final n = Offset(-d.dy, d.dx) / d.distance;
        final taper = math.pow(math.sin(math.pi * t), .6).toDouble();
        final fold =
            .16 + .84 * math.pow(math.sin(t * math.pi * 2.7 + band * 1.8), 2);
        final width = s.width * (band == 0 ? .065 : .041) * taper * fold;
        return p + n * ((k / across - .5) * width * 2);
      }

      Color color(int k, double t) {
        const tones = [
          Color(0x28AEDD42),
          Color(0xB178C018),
          Color(0xCD57A719),
          Color(0xBCAADE39),
          Color(0xB8D9F98A),
          Color(0xDDF3FFC9),
          Color(0x75B8E739),
        ];
        final light = math.pow(math.sin(t * 11 + band), 16).toDouble() * .42;
        return Color.lerp(tones[k], const Color(0xFFFFFAD7), light)!;
      }

      for (var i = 0; i < slices; i++) {
        final a = start + (end - start) * i / slices;
        final b = start + (end - start) * (i + 1) / slices;
        for (var j = 0; j < across; j++) {
          positions.addAll([
            at(a, j),
            at(a, j + 1),
            at(b, j),
            at(a, j + 1),
            at(b, j + 1),
            at(b, j),
          ]);
          colors.addAll([
            color(j, a),
            color(j + 1, a),
            color(j, b),
            color(j + 1, a),
            color(j + 1, b),
            color(j, b),
          ]);
        }
        final p = at(a, 5);
        if (i == 0) {
          edge.moveTo(p.dx, p.dy);
        } else {
          edge.lineTo(p.dx, p.dy);
        }
      }
      c.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0x667BCB19)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      c.drawVertices(
        ui.Vertices(ui.VertexMode.triangles, positions, colors: colors),
        BlendMode.srcOver,
        Paint(),
      );
      c.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65
          ..color = const Color(0xB9FFFFD7),
      );
    }
    for (var i = 0; i < 6; i++) {
      final t = start + (end - start) * ((i * .163 + .07) % 1);
      final p = point(t, s, 0);
      c.drawCircle(
        p,
        3.5,
        Paint()
          ..color = const Color(0x99D8EF68)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      c.drawCircle(p, .85, Paint()..color = const Color(0xFFFFFDE1));
    }
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter old) =>
      old.phase != phase ||
      old.reveal != reveal ||
      old.front != front ||
      old.variant != variant;
}

class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, required this.kind});
  final BrandVisualKind kind;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BadgePainter(kind));
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter(this.kind);
  final BrandVisualKind kind;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 100, s.height / 100);
    c.drawCircle(
      const Offset(50, 50),
      47,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xF9FFFFFF),
            Color(0xDAF7FFE5),
            Color(0x8CD7F398),
            Color(0xEEF9FFF0),
          ],
          stops: [0, .72, .88, 1],
        ).createShader(const Rect.fromLTWH(2, 2, 96, 96)),
    );
    c.drawCircle(
      const Offset(50, 50),
      46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFACCE67),
    );
    c.drawArc(
      const Rect.fromLTWH(7, 7, 86, 86),
      3.4,
      2.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
    final p = Paint()..color = brandInk;
    if (kind == BrandVisualKind.sport) {
      c.save();
      c.translate(50, 50);
      c.rotate(-.35);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-24, -4, 48, 8),
          const Radius.circular(2),
        ),
        p,
      );
      for (final x in [-29.0, -20.0, 14.0, 23.0]) {
        final h = x.abs() > 22 ? 26.0 : 42.0;
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, -h / 2, 6, h),
            const Radius.circular(2),
          ),
          p,
        );
      }
      c.restore();
    } else if (kind == BrandVisualKind.nutrition) {
      c.drawPath(
        Path()
          ..moveTo(22, 50)
          ..lineTo(78, 50)
          ..quadraticBezierTo(75, 79, 50, 79)
          ..quadraticBezierTo(25, 79, 22, 50),
        p,
      );
      c.drawPath(
        Path()
          ..moveTo(49, 46)
          ..cubicTo(18, 47, 25, 16, 27, 18)
          ..cubicTo(47, 18, 51, 31, 49, 46),
        p,
      );
      c.drawPath(
        Path()
          ..moveTo(51, 46)
          ..cubicTo(53, 18, 75, 16, 77, 18)
          ..cubicTo(77, 39, 64, 46, 51, 46),
        p,
      );
      final vein = Paint()
        ..color = const Color(0xFFF3FBE8)
        ..strokeWidth = 2.4;
      c.drawLine(const Offset(34, 28), const Offset(44, 39), vein);
      c.drawLine(const Offset(67, 28), const Offset(56, 40), vein);
    } else {
      c.drawPath(
        Path()
          ..moveTo(50, 78)
          ..cubicTo(43, 71, 20, 53, 20, 36)
          ..cubicTo(20, 16, 44, 14, 50, 30)
          ..cubicTo(58, 13, 81, 17, 81, 36)
          ..cubicTo(81, 52, 59, 72, 50, 78),
        p,
      );
      c.drawPath(
        Path()
          ..moveTo(20, 49)
          ..lineTo(36, 49)
          ..lineTo(42, 40)
          ..lineTo(49, 60)
          ..lineTo(57, 43)
          ..lineTo(63, 49)
          ..lineTo(80, 49),
        Paint()
          ..color = const Color(0xFFF5FCEB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.7,
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _BadgePainter old) => old.kind != kind;
}
