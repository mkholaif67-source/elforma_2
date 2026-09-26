import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';

/// Visual tokens from the supplied Stitch home HTML. Data and actions are
/// provided by the existing home/community controllers.
class HomeDesign {
  static const canvas = Color(0xFFF4F7F5);
  static const ink = Color(0xFF0F172A);
  static const forest = Color(0xFF0B3523);
  static const green = Color(0xFF047857);
  static const emerald = Color(0xFF059669);
  static const muted = Color(0xFF94A3B8);
  static const slate = Color(0xFF64748B);
  static const line = Color(0xFFF1F5F9);

  static Widget badge(IconData icon,
          {double size = 28,
          Color color = green,
          Color background = const Color(0xFFECFDF5),
          double radius = 8,
          double iconSize = 16}) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(radius)),
        child: Center(
            child: SvgPicture.asset('assets/home/${_iconName(icon)}.svg',
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn))),
      );
  static String _iconName(IconData icon) => switch (icon) {
        Icons.water_drop_rounded => 'water',
        Icons.restaurant_rounded => 'nutrition',
        Icons.trending_up_rounded => 'progress',
        Icons.monitor_weight_outlined => 'weight',
        Icons.directions_walk_rounded => 'walk',
        _ => 'flag',
      };
}

class HomeSurface extends StatelessWidget {
  const HomeSurface(
      {super.key,
      required this.child,
      this.onTap,
      this.padding = const EdgeInsets.all(16),
      this.radius = 24});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0D0B3523),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: Offset(0, 2)),
              BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 3,
                  offset: Offset(0, 1)),
            ]),
        child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
                side: const BorderSide(color: HomeDesign.line)),
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: Padding(padding: padding, child: child))),
      );
}

class HomeGreetingHeader extends StatelessWidget {
  const HomeGreetingHeader(
      {super.key,
      required this.name,
      required this.greeting,
      required this.message,
      required this.pro});
  final String name, greeting, message;
  final bool pro;
  static String firstName(String value) {
    final first = value.trim().split(RegExp(r'\s+')).first;
    if (first.isEmpty || !RegExp(r'^[A-Za-z]').hasMatch(first)) return first;
    return first[0].toUpperCase() + first.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final first = firstName(name);
    return Row(textDirection: TextDirection.ltr, children: [
      Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF145A3C),
                    HomeDesign.forest,
                    Color(0xFF062015)
                  ]),
              border: Border.all(color: const Color(0x4D34D399)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x26062F20),
                    blurRadius: 6,
                    offset: Offset(0, 4))
              ]),
          child: Image.asset('assets/logo_lockup.png',
              fit: BoxFit.contain, cacheWidth: 144, semanticLabel: 'الفورمة')),
      const SizedBox(width: 12),
      Expanded(
          child: Directionality(
              textDirection: TextDirection.rtl,
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: pro ? const Color(0xFFD7EFE3) : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0x996EE7B7))),
                    child: Text(pro ? 'PRO' : 'مجاني',
                        style: TextStyle(
                            fontFamily: pro ? 'Outfit' : 'Cairo',
                            fontSize: 11,
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: pro ? .55 : 0,
                            color: const Color(0xFF065F46)))),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      // A single intrinsic line scales down only when the available width
                      // requires it, including mixed Arabic/Latin and long first names.
                      Semantics(
                          label:
                              first.isEmpty ? greeting : '$greeting يا $first',
                          excludeSemantics: true,
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text.rich(
                                  key: const ValueKey('home-greeting'),
                                  TextSpan(children: [
                                    TextSpan(
                                        text: first.isEmpty
                                            ? greeting
                                            : '$greeting يا '),
                                    if (first.isNotEmpty)
                                      TextSpan(
                                          text: first,
                                          style: TextStyle(
                                              fontFamily: RegExp(r'^[A-Za-z]')
                                                      .hasMatch(first)
                                                  ? 'Outfit'
                                                  : 'Cairo',
                                              color: HomeDesign.green,
                                              fontWeight: FontWeight.w900)),
                                  ]),
                                  maxLines: 1,
                                  softWrap: false,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      color: HomeDesign.forest,
                                      fontSize: 17,
                                      height: 1.375,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.3)))),
                      const SizedBox(height: 2),
                      Row(children: [
                        Flexible(
                            child: Text(message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: HomeDesign.slate))),
                        const SizedBox(width: 4),
                        const Icon(Icons.bolt_rounded,
                            color: Color(0xFFF59E0B), size: 14)
                      ]),
                    ])),
              ]))),
    ]);
  }
}

class HomeMetricCard extends StatelessWidget {
  const HomeMetricCard(
      {super.key,
      required this.water,
      required this.value,
      required this.subtitle,
      required this.onTap,
      this.progress = 0});
  final bool water;
  final String value, subtitle;
  final double progress;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => HomeSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(water ? 'المياه' : 'التغذية',
              style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w700)),
          HomeDesign.badge(
              water ? Icons.water_drop_rounded : Icons.restaurant_rounded,
              size: 20,
              radius: 10,
              iconSize: 14,
              color: water ? const Color(0xFF0EA5E9) : HomeDesign.emerald,
              background:
                  water ? const Color(0xFFF0F9FF) : const Color(0xFFECFDF5)),
        ]),
        const SizedBox(height: 8),
        Text.rich(
            TextSpan(children: [
              TextSpan(text: value),
              if (water)
                const TextSpan(
                    text: ' لتر',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: HomeDesign.slate,
                        fontWeight: FontWeight.w700)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: water ? 18 : 16,
                fontFamily: water ? 'Outfit' : 'Cairo',
                fontFamilyFallback: const ['Cairo'],
                height: 1.5,
                fontWeight: FontWeight.w900,
                color: HomeDesign.ink)),
        const SizedBox(height: 2),
        Text(subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 10,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: HomeDesign.muted)),
        const SizedBox(height: 8),
        if (water)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.5),
              child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(99),
                  color: const Color(0xFF38BDF8),
                  backgroundColor: HomeDesign.line))
        else
          const Row(children: [
            Flexible(
                child: Text('تسجيل الوجبة',
                    style: TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                        color: HomeDesign.green))),
            SizedBox(width: 4),
            Icon(Icons.chevron_left_rounded,
                textDirection: TextDirection.ltr,
                size: 12,
                color: HomeDesign.green)
          ]),
      ]));
}

class HomeWeeklyProgress extends StatelessWidget {
  const HomeWeeklyProgress(
      {super.key, required this.count, required this.target});
  final int count, target;
  @override
  Widget build(BuildContext context) {
    final segments = target.clamp(1, 7);
    return HomeSurface(
        child: Column(children: [
      Row(children: [
        HomeDesign.badge(Icons.trending_up_rounded),
        const SizedBox(width: 8),
        const Expanded(
            child: Text('تقدم التدريب هذا الأسبوع',
                style: TextStyle(
                    color: HomeDesign.ink,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w900))),
        const SizedBox(width: 6),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6)),
            child: Text('$count / $target',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: HomeDesign.green,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w900))),
      ]),
      const SizedBox(height: 12),
      Semantics(
          label: 'أكملت $count من $target أيام التدريب',
          child: Row(children: [
            for (var i = 0; i < segments; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                  child: Container(
                      key: ValueKey('weekly-segment-$i'),
                      height: 8,
                      decoration: BoxDecoration(
                          color:
                              i < count ? HomeDesign.emerald : HomeDesign.line,
                          borderRadius: BorderRadius.circular(99)))),
            ],
          ])),
    ]));
  }
}

class HomeWeightCard extends StatelessWidget {
  const HomeWeightCard(
      {super.key,
      required this.current,
      required this.target,
      required this.onTap});
  final num current, target;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => HomeSurface(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        HomeDesign.badge(Icons.monitor_weight_outlined,
            size: 32,
            radius: 12,
            color: const Color(0xFF475569),
            background: HomeDesign.line),
        const SizedBox(width: 10),
        const Expanded(
            flex: 3,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الوزن والمتابعة',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w800,
                      color: HomeDesign.ink)),
              Text('الوزن والقياسات واتجاه التقدم',
                  style: TextStyle(
                      fontSize: 10,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: HomeDesign.muted)),
            ])),
        const SizedBox(width: 8),
        Flexible(
            flex: 2,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                    TextSpan(children: [
                      if (target > 0)
                        TextSpan(
                            text: '${target.toStringAsFixed(0)} ← ',
                            style: const TextStyle(
                                color: HomeDesign.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      TextSpan(
                          text: current > 0
                              ? current.toStringAsFixed(1)
                              : 'سجل وزنك'),
                      if (current > 0)
                        const TextSpan(
                            text: ' كجم',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                color: HomeDesign.slate)),
                    ]),
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: ['Cairo'],
                        color: HomeDesign.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w900)))),
      ]));
}

class HomeStepsCard extends StatelessWidget {
  const HomeStepsCard(
      {super.key,
      required this.count,
      required this.goal,
      required this.label,
      required this.onTap});
  final int? count;
  final int goal;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => HomeSurface(
      onTap: onTap,
      child: Column(children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: count == null ? '—' : '$count',
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: HomeDesign.ink,
                          fontSize: 24,
                          height: 1.3,
                          fontWeight: FontWeight.w900)),
                  const TextSpan(
                      text: ' خطوة',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: HomeDesign.slate))
                ])),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: HomeDesign.muted)),
              ])),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('خطوات اليوم',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w900,
                      color: HomeDesign.ink))),
          const SizedBox(width: 8),
          HomeDesign.badge(Icons.directions_walk_rounded,
              size: 40,
              radius: 16,
              iconSize: 24,
              color: const Color(0xFF065F46),
              background: const Color(0xB3D1FAE5)),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(
            value: count == null || goal <= 0 ? 0 : (count! / goal).clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
            color: HomeDesign.emerald,
            backgroundColor: HomeDesign.line),
      ]));
}

class HomeChallengeCard extends StatelessWidget {
  const HomeChallengeCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.progress});
  final String title, subtitle;
  final int? progress;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => HomeSurface(
      onTap: onTap,
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w800,
                  color: HomeDesign.ink)),
          const SizedBox(height: 2),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: HomeDesign.muted)),
        ])),
        if (progress != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('$progress٪',
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w800,
                      color: HomeDesign.green))),
        const SizedBox(width: 8),
        HomeDesign.badge(Icons.flag_rounded,
            size: 44,
            radius: 16,
            iconSize: 24,
            background: const Color(0xFFEAF5EE)),
      ]));
}

class HomeKitchenCard extends StatelessWidget {
  const HomeKitchenCard({super.key, required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => HomeSurface(
      onTap: onTap,
      radius: 26,
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/community/kitchen_hero.webp',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                alignment: Alignment.centerLeft,
                cacheWidth: 288,
                excludeFromSemantics: true)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFEAF5EE),
                  borderRadius: BorderRadius.circular(6)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.restaurant_rounded,
                    size: 12, color: HomeDesign.green),
                SizedBox(width: 6),
                Flexible(
                    child: Text('من مطبخ الفورمة',
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46))))
              ])),
          const SizedBox(height: 4),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  color: HomeDesign.ink)),
          const SizedBox(height: 4),
          const Text('اكتشف الوصفات وطريقة التحضير',
              style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: HomeDesign.green)),
        ])),
      ]));
}
