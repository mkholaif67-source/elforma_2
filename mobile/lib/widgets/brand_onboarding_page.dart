import 'package:flutter/material.dart';
import 'package:elforma/widgets/brand_experience_visual.dart';

/// Also used by the export test: it renders the same artwork and native text.
class BrandOnboardingPage extends StatelessWidget {
  const BrandOnboardingPage({super.key, required this.index, this.phase = 0});
  final int index;
  final double phase;
  static const titles = [
    'أنت تستحق الأفضل دائمًا',
    'جدول تمرين',
    'نظام غذائي',
    'عادات أفضل.. حياة أفضل',
  ];
  static const subtitles = [
    'رحلتك تبدأ بخطوة تناسبك',
    'خطة تدريب مخصصة تناسب مستواك وهدفك',
    'خطة تغذية متوازنة تناسب يومك وهدفك',
    'خطوات بسيطة تصنع فرقًا كل يوم',
  ];
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 0,
        top: 0,
        width: 432,
        height: 540,
        child: RepaintBoundary(
          child: BrandExperienceVisual(
            kind: BrandVisualKind.values[index],
            progress: phase,
          ),
        ),
      ),
      Positioned(
        left: 24,
        top: 545,
        width: 384,
        height: 66,
        child: Center(
          child: Text(
            titles[index],
            key: ValueKey('onboarding-title-$index'),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            maxLines: 2,
            style: TextStyle(
              fontFamily: 'ElFormaArabic',
              color: brandInk,
              fontSize: index == 1 || index == 2 ? 36 : 28,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ),
      Positioned(
        left: 22,
        top: 615,
        width: 388,
        height: 48,
        child: Text(
          subtitles[index],
          key: ValueKey('onboarding-subtitle-$index'),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          maxLines: 2,
          style: const TextStyle(
            fontFamily: 'ElFormaArabic',
            color: brandInk,
            fontSize: 18,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class BrandOnboardingSurface extends StatelessWidget {
  const BrandOnboardingSurface({
    super.key,
    required this.index,
    required this.pages,
    required this.onNext,
  });
  final int index;
  final Widget pages;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: brandIvory,
    body: BrandExperienceBackdrop(
      child: SafeArea(
        child: BrandDesignFrame(
          child: Stack(
            children: [
              Positioned.fill(child: pages),
              Positioned(
                left: 31,
                top: 664,
                width: 66,
                height: 66,
                child: Tooltip(
                  message: index == 3 ? 'ابدأ' : 'التالي',
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: brandInk,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    child: Icon(
                      index == 3
                          ? Icons.check_rounded
                          : Icons.arrow_back_rounded,
                      textDirection: TextDirection.ltr,
                      size: 34,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 177,
                top: 679,
                width: 78,
                height: 36,
                child: Semantics(
                  label: 'الصفحة ${index + 1} من 4',
                  child: Row(
                    textDirection: TextDirection.ltr,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      4,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == index
                              ? brandInk
                              : const Color(0xFFBED3B4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
