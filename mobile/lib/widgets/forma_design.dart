import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:elforma/theme.dart';

/// Soft depth shared by all interior cards, sheets and newly authored content.
class FormaDecoration extends BoxDecoration {
  const FormaDecoration({
    super.color,
    super.image,
    super.border,
    super.borderRadius,
    super.gradient,
    super.backgroundBlendMode,
    super.shape = BoxShape.rectangle,
    super.boxShadow = const [
      BoxShadow(color: Color(0x080B4229), blurRadius: 18, offset: Offset(0, 7)),
    ],
  });
}

class FormaIcon extends StatelessWidget {
  const FormaIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
    this.shadows,
  });
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final List<Shadow>? shadows;
  // ── Perf ─────────────────────────────────────────────────────────────
  // These two tables used to be rebuilt inside `build()`, so every FormaIcon on
  // screen allocated ~30 map entries on every frame it rebuilt. They are pure
  // constants, so they now live as `static final` and allocate once at class initialization.
  static final Map<IconData, String> _paths = {
      Icons.home_rounded: 'M3 10 12 3 21 10M5 9v12h5v-7h4v7h5V9',
      Icons.home_outlined: 'M3 10 12 3 21 10M5 9v12h5v-7h4v7h5V9',
      Icons.fitness_center_rounded:
          'm7 7 10 10M3 8l5-5M2 5l3-3M16 21l5-5M19 22l3-3M5 10l5-5M14 19l5-5',
      Icons.restaurant_rounded:
          'M4 3v6q0 3 3 3V3M10 3v6q0 3-3 3v9M20 3q-6 4-4 11h4M20 3v18',
      Icons.restaurant_menu_rounded:
          'M4 3v6q0 3 3 3V3M10 3v6q0 3-3 3v9M20 3q-6 4-4 11h4M20 3v18',
      Icons.person_rounded:
          'M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0ZM4 21v-2a8 6 0 0 1 16 0v2Z',
      Icons.person_outline_rounded:
          'M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0ZM4 21v-2a8 6 0 0 1 16 0v2Z',
      Icons.water_drop_rounded:
          'M12 2S5 10 5 15a7 7 0 0 0 14 0c0-5-7-13-7-13ZM8 15q0 4 4 4',
      Icons.notifications_active_rounded:
          'M6 17V9a6 6 0 0 1 12 0v8l2 2H4ZM10 22h4M2 8q0-4 3-6M22 8q0-4-3-6',
      Icons.notifications_outlined: 'M6 17V9a6 6 0 0 1 12 0v8l2 2H4ZM10 22h4',
      Icons.insights_rounded: 'm3 17 6-6 5 3 7-10M16 4h5v5M3 21h18',
      Icons.trending_up_rounded: 'm3 17 6-6 5 3 7-10M16 4h5v5',
      Icons.monitor_weight_outlined:
          'M5 3h14q2 0 2 2v14q0 2-2 2H5q-2 0-2-2V5q0-2 2-2ZM8 7q4-2 8 0l-1 4H9ZM12 7v2',
      Icons.favorite_rounded: 'M12 21 3 12C-3 3 9 0 12 7c3-7 15-4 9 5Z',
      Icons.favorite_border_rounded: 'M12 21 3 12C-3 3 9 0 12 7c3-7 15-4 9 5Z',
      Icons.emoji_events_rounded:
          'M7 3h10v7a5 5 0 0 1-10 0ZM7 5H3v3q0 4 4 4M17 5h4v3q0 4-4 4M12 15v6M8 21h8',
      Icons.flag_rounded: 'M4 22V3q4-3 8 0t8 0v10q-4 3-8 0t-8 0',
      Icons.directions_walk_rounded:
          'M15 4a2 2 0 1 1-4 0 2 2 0 0 1 4 0ZM8 22l3-9 3 4v5M4 12l5-4 5 1 3 4h4M11 9l-1 5',
      Icons.check_circle_rounded: 'M21 12a9 9 0 1 1-9-9M7 11l4 4L22 4',
      Icons.cloud_done_outlined:
          'M6 18H5a4 4 0 0 1 0-8 7 7 0 0 1 14-2 5 5 0 0 1 0 10M9 18l3 3 6-7',
      Icons.schedule_rounded:
          'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0ZM12 6v6l4 2',
      Icons.lock_outline_rounded:
          'M6 10h12v12H6ZM8 10V6a4 4 0 0 1 8 0v4M12 15v3',
      Icons.auto_awesome_rounded:
          'm12 2 3 7 7 3-7 3-3 7-3-7-7-3 7-3ZM3 2v4M1 4h4',
  };

  static final Map<IconData, IconData> _aliases = {
      Icons.home: Icons.home_rounded,
      Icons.fitness_center: Icons.fitness_center_rounded,
      Icons.restaurant: Icons.restaurant_rounded,
      Icons.restaurant_outlined: Icons.restaurant_rounded,
      Icons.person: Icons.person_rounded,
      Icons.person_outline: Icons.person_outline_rounded,
      Icons.notifications_rounded: Icons.notifications_outlined,
      Icons.favorite_border: Icons.favorite_border_rounded,
      Icons.fitness_center_outlined: Icons.fitness_center_rounded,
  };

  // `SvgPicture.string` re-parses the SVG document on every build. The markup
  // is fixed per icon, so each loader is created once and reused — which also
  // lets flutter_svg hit its own picture cache instead of re-rasterising.
  static final Map<String, SvgStringLoader> _loaders = {};

  static SvgStringLoader _loaderFor(String path) => _loaders.putIfAbsent(
    path,
    () => SvgStringLoader(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path d="$path" fill="none" stroke="#075B35" stroke-width="1.7" '
      'stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Read the inherited icon theme once instead of twice.
    final iconTheme = IconTheme.of(context);
    final c = color ?? iconTheme.color ?? AppColors.nu;
    final s = size ?? iconTheme.size ?? 24;
    final path = _paths[_aliases[icon] ?? icon];
    if (path == null) {
      return Icon(
        icon,
        size: s,
        color: c,
        semanticLabel: semanticLabel,
        textDirection: textDirection,
        shadows: shadows,
      );
    }
    return SvgPicture(
      _loaderFor(path),
      width: s,
      height: s,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
    );
  }
}

class FormaLoader extends StatelessWidget {
  const FormaLoader({
    super.key,
    this.color,
    this.strokeWidth = 3,
    this.value,
    this.backgroundColor,
    this.valueColor,
    this.semanticsLabel,
  });
  final Color? color, backgroundColor;
  final double strokeWidth;
  final double? value;
  final Animation<Color?>? valueColor;
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel ?? 'جار التحميل',
    child: SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            color: color ?? AppColors.nu,
            strokeWidth: strokeWidth,
            backgroundColor: backgroundColor ?? AppColors.line,
            valueColor: valueColor,
          ),
          const FormaIcon(
            Icons.auto_awesome_rounded,
            size: 13,
            color: AppColors.nu,
          ),
        ],
      ),
    ),
  );
}

class FormaReveal extends StatelessWidget {
  const FormaReveal({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      end: 1,
    ),
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 9 * (1 - value)),
        child: child,
      ),
    ),
  );
}
