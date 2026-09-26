import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Supplied HTML: the last particle finishes at 1.95 + 1.5 seconds.
const brandIntroDuration = Duration(milliseconds: 3450);
const splashLogoAsset = 'assets/auth/splash_logo.png';

class BrandIntroScene extends StatelessWidget {
  const BrandIntroScene(
      {super.key, required this.progress, this.waiting = false});
  final double progress;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final t = (reduced ? 1.0 : progress.clamp(0.0, 1.0)) * 3.45;
    double phase(double start, double duration) =>
        ((t - start) / duration).clamp(0.0, 1.0);
    final ring = const Cubic(.4, .1, .2, 1).transform(phase(.15, 1.1));
    final pop = phase(.45, .85);
    const popCurve = Cubic(.34, 1.5, .62, 1);
    final popIn = popCurve.transform((pop / .65).clamp(0, 1));
    final popOut = popCurve.transform(((pop - .65) / .35).clamp(0, 1));
    final logoScale = pop < .65 ? .4 + .68 * popIn : 1.08 - .08 * popOut;
    final logoOpacity = popIn.clamp(0.0, 1.0);
    final glow = phase(.35, 1.6);
    final glowIn = Curves.easeOut.transform((glow / .45).clamp(0, 1));
    final glowOut = Curves.easeOut.transform(((glow - .45) / .55).clamp(0, 1));
    final glowOpacity = glow < .45 ? .6 * glowIn : .6 * (1 - glowOut);
    final glowScale = glow < .45 ? .6 + .45 * glowIn : 1.05 + .3 * glowOut;
    final shine = Curves.ease.transform(phase(1.35, 1));
    final shineOpacity = shine < .15
        ? .9 * shine / .15
        : shine > .85
            ? .9 * (1 - shine) / .15
            : .9;
    final tagline = Curves.ease.transform(phase(1.3, .6));
    return ColoredBox(
        color: Colors.white,
        child: LayoutBuilder(builder: (context, box) {
          // The artwork uses the original CSS dimensions; it is never stretched.
          final cx = box.maxWidth / 2, cy = box.maxHeight / 2;
          return Stack(children: [
            Positioned(
                left: cx - 110,
                top: cy - 110,
                width: 220,
                height: 220,
                child: Opacity(
                    opacity: glowOpacity.clamp(0, 1),
                    child: Transform.scale(
                        scale: glowScale,
                        child: const DecoratedBox(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  Color(0x668FC93B),
                                  Color(0x008FC93B)
                                ], stops: [
                                  0,
                                  .7
                                ])))))),
            Positioned(
                left: cx - 79,
                top: cy - 79,
                width: 158,
                height: 158,
                child: CustomPaint(
                    key: const ValueKey('splash-ring'),
                    painter: _RingPainter(ring))),
            Positioned(
                left: cx - 59,
                top: cy - 118 * 387 / 560 / 2,
                width: 118,
                height: 118 * 387 / 560,
                child: Opacity(
                    opacity: logoOpacity,
                    child: Transform.scale(
                        scale: logoScale,
                        child: Stack(fit: StackFit.expand, children: [
                          Transform.translate(
                              offset: const Offset(0, 10),
                              child: ImageFiltered(
                                  imageFilter: ui.ImageFilter.blur(
                                      sigmaX: 22, sigmaY: 22),
                                  child: Image.asset(splashLogoAsset,
                                      color: const Color(0x2E0B1F14),
                                      fit: BoxFit.contain))),
                          Image.asset(splashLogoAsset,
                              fit: BoxFit.contain, semanticLabel: 'الفورمة'),
                          if (shineOpacity > 0)
                            Opacity(
                                opacity: shineOpacity,
                                child: ShaderMask(
                                    blendMode: BlendMode.srcATop,
                                    shaderCallback: (rect) =>
                                        LinearGradient(
                                            begin:
                                                Alignment(-4 + shine * 8, -1),
                                            end: Alignment(-2 + shine * 8, 1),
                                            colors: const [
                                              Colors.transparent,
                                              Colors.white,
                                              Colors.transparent
                                            ],
                                            stops: const [
                                              .32,
                                              .48,
                                              .64
                                            ]).createShader(rect),
                                    child: Image.asset(splashLogoAsset,
                                        fit: BoxFit.contain))),
                        ])))),
            for (var i = 0; i < 5; i++)
              _particle(i, t, box.maxWidth, box.maxHeight),
            Positioned(
                top: cy + 132 + 10 * (1 - tagline),
                left: 0,
                right: 0,
                child: Opacity(
                    opacity: tagline,
                    child: const Text('مدربك في جيبك',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.875,
                            color: Color(0xFF0A5A34))))),
            Positioned(
                left: cx - 17.5,
                bottom: box.maxHeight * .13,
                width: 35,
                height: 7,
                child: BrandIntroConnection(
                    progress: progress, waiting: waiting || progress < 1)),
          ]);
        }));
  }

  Widget _particle(int i, double t, double w, double h) {
    const starts = [1.5, 1.65, 1.8, 1.55, 1.95];
    const durations = [1.5, 1.7, 1.4, 1.6, 1.5];
    const positions = [.30, .42, .58, .70, .50];
    final p = Curves.easeOut
        .transform(((t - starts[i]) / durations[i]).clamp(0.0, 1.0));
    final opacity = p < .18 ? p / .18 : ((.92 - p) / .74).clamp(0.0, 1.0);
    return Positioned(
        left: w * positions[i],
        bottom: h * .44 + 64 * p,
        width: 9,
        height: 9,
        child: Opacity(
            opacity: opacity,
            child: Transform.scale(
                scale: .5 + .5 * p,
                child: ClipPath(
                    clipper: _ParticleClipper(),
                    child: const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                          Color(0xFF8FC93B),
                          Color(0xFF12793F)
                        ])))))));
  }
}

class _ParticleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * .5, 0)
    ..lineTo(s.width, s.height * .4)
    ..lineTo(s.width * .78, s.height)
    ..lineTo(s.width * .22, s.height)
    ..lineTo(0, s.height * .4)
    ..close();
  @override
  bool shouldReclip(_ParticleClipper oldClipper) => false;
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final factor = size.width / 150;
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: 69.5 * factor);
    canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * factor
          ..color = const Color(0x140B1F14));
    if (progress == 0) return;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * factor
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [Color(0xFF8FC93B), Color(0xFF0A5A34)])
              .createShader(rect));
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Loading dots are the only repeating animation once the supplied entrance ends.
class BrandIntroConnection extends StatefulWidget {
  const BrandIntroConnection(
      {super.key, required this.progress, required this.waiting});
  final double progress;
  final bool waiting;
  @override
  State<BrandIntroConnection> createState() => _BrandIntroConnectionState();
}

class _BrandIntroConnectionState extends State<BrandIntroConnection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BrandIntroConnection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.waiting &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context)) {
      if (!_dots.isAnimating) _dots.repeat();
    } else {
      _dots.stop();
      _dots.value = 0;
    }
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _dots,
      builder: (context, _) => CustomPaint(
          key: const ValueKey('intro-connection'),
          painter: _DotsPainter(_dots.value)));
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter(this.phase);
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final p = (phase - i * .15 / 1.1) % 1.0;
      final pulse = p < .4
          ? Curves.easeInOut.transform(p / .4)
          : p < .8
              ? 1 - Curves.easeInOut.transform((p - .4) / .4)
              : 0.0;
      canvas.drawCircle(
          Offset(size.width / 2 + (i - 1) * 14, size.height / 2),
          3.5 * (.6 + .4 * pulse),
          Paint()
            ..color =
                const Color(0xFF12793F).withValues(alpha: .3 + .7 * pulse));
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => phase != oldDelegate.phase;
}
