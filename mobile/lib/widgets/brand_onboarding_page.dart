import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:elforma/widgets/brand_experience_visual.dart';

class BrandOnboardingPage extends StatelessWidget {
  const BrandOnboardingPage({super.key, required this.index, this.phase = 0});
  final int index;
  final double phase;
  static const assets = [
    'assets/onboarding_v6/health.webp',
    'assets/onboarding_v6/sport.webp',
    'assets/onboarding_v6/nutrition.webp',
    'assets/onboarding_v6/habits.webp',
  ];
  static const _labelStyle = TextStyle(
      fontFamily: 'ElFormaArabic',
      color: Color(0xFF648349),
      fontSize: 13,
      fontWeight: FontWeight.w700);
  static const _titleStyle = TextStyle(
      fontFamily: 'ElFormaArabic',
      color: brandInk,
      fontSize: 27,
      fontWeight: FontWeight.w700,
      height: 1.45);
  static const _subtitleStyle = TextStyle(
      fontFamily: 'ElFormaArabic',
      color: Color(0xFF52695D),
      fontSize: 16,
      height: 1.7);
  static const labels = [
    'صحتك أولًا',
    'قوة على قدّك',
    'أكل يناسب حياتك',
    'كل خطوة بتفرق'
  ];
  static const titles = [
    'خطة تبدأ منك',
    'اعرف تتمرّن إزاي',
    'أكل تحبّه ويناسبك',
    'شوف تقدّمك خطوة بخطوة',
  ];
  static const subtitles = [
    'هدفك ومستواك وحالتك الصحية، بداية اختيار خطة تناسبك.',
    'جدول يناسب مستواك، وفيديوهات توضّح لك أداء التمارين.',
    'وجبات من أكل تعرفه، بكميات تناسب هدفك ويومك.',
    'تابع وزنك وحركتك وشرب المياه، وابنِ عاداتك واحدة واحدة.',
  ];
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        double textHeight(String text, TextStyle style, double width) {
          final painter = TextPainter(
              text: TextSpan(
                  text: text,
                  style: DefaultTextStyle.of(context).style.merge(style)),
              textDirection: TextDirection.rtl,
              textScaler: MediaQuery.textScalerOf(context))
            ..layout(maxWidth: width);
          final height = painter.height;
          painter.dispose();
          return height;
        }

        final textWidth = math.max(1.0, bounds.maxWidth - 48);
        final textSpace = textHeight(labels[index], _labelStyle, textWidth) +
            textHeight(titles[index], _titleStyle, textWidth) +
            textHeight(
                subtitles[index], _subtitleStyle, math.min(360, textWidth)) +
            48;
        final artHeight = math
            .min(bounds.maxHeight * .65, bounds.maxHeight - textSpace)
            .clamp(100.0, 440.0);
        final motion = MediaQuery.disableAnimationsOf(context)
            ? 0.0
            : math.sin(phase * math.pi * 2) * 2;
        return SingleChildScrollView(
          key: ValueKey('onboarding-scroll-$index'),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: math.max(0, bounds.maxHeight - 16)),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                height: artHeight,
                width: double.infinity,
                child: RepaintBoundary(
                    child: Transform.translate(
                  offset: Offset(0, motion),
                  child: Center(
                      child: AspectRatio(
                          aspectRatio: 4 / 5,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Image.asset(assets[index],
                                  key: ValueKey('onboarding-art-$index'),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  excludeFromSemantics: true)))),
                )),
              ),
              const SizedBox(height: 10),
              Text(labels[index],
                  textAlign: TextAlign.center, style: _labelStyle),
              const SizedBox(height: 8),
              Text(titles[index],
                  key: ValueKey('onboarding-title-$index'),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: _titleStyle),
              const SizedBox(height: 10),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(subtitles[index],
                      key: ValueKey('onboarding-subtitle-$index'),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: _subtitleStyle)),
            ]),
          ),
        );
      });
}

class BrandOnboardingSurface extends StatelessWidget {
  const BrandOnboardingSurface(
      {super.key,
      required this.index,
      required this.pages,
      required this.onNext});
  final int index;
  final Widget pages;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: brandIvory,
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(children: [
            const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 4),
                child: Text('الفورمة',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: 'ElFormaArabic',
                        fontSize: 22,
                        color: brandInk,
                        fontWeight: FontWeight.w800))),
            Expanded(child: pages),
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Row(textDirection: TextDirection.rtl, children: [
                  Expanded(
                      child: Semantics(
                          label: 'الصفحة ${index + 1} من 4',
                          child: ExcludeSemantics(
                              child: Row(
                                  textDirection: TextDirection.rtl,
                                  children: List.generate(
                                      4,
                                      (i) => AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            width: i == index ? 26 : 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                                color: i == index
                                                    ? brandInk
                                                    : const Color(0xFFCCD9C3),
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          )))))),
                  Tooltip(
                      message: index == 3 ? 'ابدأ' : 'التالي',
                      child: SizedBox(
                          width: 62,
                          height: 62,
                          child: FilledButton(
                            onPressed: onNext,
                            style: FilledButton.styleFrom(
                                backgroundColor: brandInk,
                                foregroundColor: Colors.white,
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                                elevation: 0),
                            child: Icon(
                                index == 3
                                    ? Icons.check_rounded
                                    : Icons.arrow_back_rounded,
                                textDirection: TextDirection.ltr,
                                size: 29),
                          ))),
                ])),
          ]),
        ))),
      );
}
