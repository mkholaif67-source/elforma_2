import 'package:elforma/screens/auth_screen.dart';
import 'package:elforma/widgets/brand_experience_visual.dart';
import 'package:elforma/widgets/brand_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const brandOnboardingSeenKey = 'brand_onboarding_seen_v1';

class ResponsiveBrandOnboardingScreen extends StatefulWidget {
  const ResponsiveBrandOnboardingScreen({super.key, this.initialPage = 0});
  final int initialPage;
  @override
  State<ResponsiveBrandOnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends State<ResponsiveBrandOnboardingScreen> {
  late final PageController _controller;
  late int _index;
  bool _finishing = false;
  @override
  void initState() {
    super.initState();
    _index = widget.initialPage.clamp(0, 3);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_finishing) return;
    if (_index < 3) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
      return;
    }
    _finishing = true;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(brandOnboardingSeenKey, true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, a, b) => const AuthScreen(),
          transitionsBuilder: (_, a, b, child) => ColoredBox(
            color: brandIvory,
            child: FadeTransition(opacity: a, child: child),
          ),
        ),
      );
    } catch (_) {
      _finishing = false;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('حاول تاني')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => BrandOnboardingSurface(
    index: _index,
    onNext: _next,
    pages: PageView.builder(
      controller: _controller,
      itemCount: 4,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (_, i) => _AnimatedCard(index: i, active: i == _index),
    ),
  );
}

class _AnimatedCard extends StatefulWidget {
  const _AnimatedCard({required this.index, required this.active});
  final int index;
  final bool active;
  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void didUpdateWidget(covariant _AnimatedCard old) {
    super.didUpdateWidget(old);
    _updateMotion();
  }

  void _updateMotion() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (_, child) =>
        BrandOnboardingPage(index: widget.index, phase: _motion.value),
  );
}
