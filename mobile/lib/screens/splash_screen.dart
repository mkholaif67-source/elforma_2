// ── ElForma · screens/splash_screen.dart ──
// Branded app entry. Startup/network work runs behind the visual sequence.

import 'dart:async';

import 'package:elforma/api.dart';
import 'package:elforma/models/profile_store.dart';
import 'package:elforma/screens/auth_screen.dart';
import 'package:elforma/screens/responsive_brand_onboarding_screen.dart';
import 'package:elforma/screens/shell_screen.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/brand_experience_visual.dart';
import 'package:elforma/widgets/brand_intro_scene.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final Completer<void> _introComplete = Completer<void>();

  String? _bootError;
  bool _booting = false;
  bool _introFinished = false;
  int _bootAttempts = 0;
  bool _experienceAssetsPrecached = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: brandIntroDuration,
      animationBehavior: AnimationBehavior.preserve);
    _boot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_experienceAssetsPrecached) return;
    _experienceAssetsPrecached = true;
    unawaited(_prepareIntro());
  }

  Future<void> _prepareIntro() async {
    await Future.wait(
      BrandExperienceAssets.all.map(
        (asset) => precacheImage(AssetImage(asset), context),
      ),
    );
    if (!mounted) return;
    try {
      await _c.forward().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    setState(() => _introFinished = true);
    _introComplete.complete();
  }

  Future<void> _retryBoot() {
    _bootAttempts = 0;
    setState(() => _bootError = null);
    return _boot();
  }

  Future<void> _boot() async {
    if (_booting) return;
    _booting = true;

    // Keep the real startup flow exactly as it was. The intro is presentation
    // only; server warmup and session checks run in parallel behind it.
    unawaited(Api.I.warmup());
    try {
      await Api.I.init();

      const bootTimeout = Duration(seconds: 12);
      final checks = await Future.wait<dynamic>([
        UpdateGate.check(timeout: bootTimeout),
        Api.I.me(timeout: bootTimeout),
      ]);
      final gate = checks[0] as UpdateGate;
      final res = checks[1] as ApiResult;

      // The approved entry is always allowed to complete even on a very fast
      // connection. The final composition stays on screen if startup is slow;
      // it never stretches or restarts the 5.5-second animation timeline.
      await _introComplete.future;
      if (!mounted) return;

      if (gate.maintenance) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => _MaintenanceScreen(gate: gate)),
        );
        return;
      }

      if (gate.verdict == UpdateVerdict.required) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => _ForcedUpdateScreen(gate: gate)),
        );
        return;
      }

      if (!res.ok &&
          (res.status == 0 ||
              res.status == 408 ||
              res.status == 429 ||
              res.status == 409 ||
              res.status >= 500)) {
        if (_bootAttempts < 5 &&
            (res.status == 0 || res.status == 408 || res.status >= 500)) {
          _bootAttempts++;
          const delays = [3, 4, 6, 8, 10];
          Timer(Duration(seconds: delays[_bootAttempts - 1]), () {
            if (mounted) _boot();
          });
          return;
        }
        setState(() {
          _bootError = (res.status == 0 || res.status == 408)
              ? 'مشكلة في الاتصال بالإنترنت'
              : 'تعذر الاتصال بالخادم';
        });
        return;
      }

      final user = res.data['user'];
      if (user != null) {
        unawaited(ProfileStore.I.ensureLoaded(force: true));
      }
      if (!mounted) return;

      // Onboarding is a first-time experience only. The branded entry above is
      // the piece that intentionally appears on every app launch.
      if (user == null) {
        final sp = await SharedPreferences.getInstance();
        final seen = sp.getBool(brandOnboardingSeenKey) ?? false;
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          _brandFadeRoute(
            seen ? const AuthScreen() : const ResponsiveBrandOnboardingScreen(),
          ),
        );
      } else {
        Navigator.of(
          context,
        ).pushReplacement(_brandFadeRoute(const ShellScreen()));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _bootError = 'تعذر فتح التطبيق');
      }
    } finally {
      _booting = false;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_introFinished && _bootError != null) {
      return _SimpleConnectionError(title: _bootError!, onRetry: _retryBoot);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF1),
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => BrandIntroScene(progress: _c.value),
      ),
    );
  }
}

Route<T> _brandFadeRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 580),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (_, animation, secondaryAnimation) => child,
    transitionsBuilder: (_, animation, secondaryAnimation, page) => Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0, .45, curve: Curves.easeInOut),
          ),
          child: const BrandExperienceBackdrop(),
        ),
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(.45, 1, curve: Curves.easeOut),
          ),
          child: page,
        ),
      ],
    ),
  );
}

class _SimpleConnectionError extends StatelessWidget {
  const _SimpleConnectionError({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF1),
      body: BrandExperienceBackdrop(
        variant: BrandBackdropVariant.brand,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 170,
                    height: 130,
                    child: Image.asset(
                      BrandExperienceAssets.illuminatedLogo,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFF08733F),
                    size: 48,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Color(0xFF075D36),
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF08733F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: onRetry,
                      child: const Text(
                        'إعادة المحاولة',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while the admin has the app switched off from the dashboard. Unlike
/// the forced-update screen this is a TEMPORARY dead end, so the single action
/// it offers is a fresh boot: the moment maintenance is turned off in the
/// dashboard, tapping retry lets the trainee straight back in with no reinstall
/// and no store trip.
class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.gate});
  final UpdateGate gate;

  @override
  Widget build(BuildContext context) {
    final title = gate.maintenanceTitle.trim().isEmpty
        ? 'صيانة مؤقتة'
        : gate.maintenanceTitle.trim();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.wo.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppColors.wo.withValues(alpha: 0.40),
                      width: 1.4,
                    ),
                  ),
                  child: const Icon(
                    Icons.build_circle_rounded,
                    color: AppColors.wo,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  gate.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.nu,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                    ),
                    child: const Text(
                      'جرب تاني',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'بياناتك واشتراكك محفوظين زي ما هما',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown ONLY when the server has retired this build. There is deliberately no
/// way past it: the whole point is that a release we know is broken stops
/// writing data. It is a dead end by design, so it must explain itself clearly
/// and hand the user a single obvious action.
class _ForcedUpdateScreen extends StatelessWidget {
  const _ForcedUpdateScreen({required this.gate});
  final UpdateGate gate;

  Future<void> _openStore(BuildContext context) async {
    final url = gate.storeUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح المتجر حدث التطبيق يدويا')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.wo.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppColors.wo.withValues(alpha: 0.40),
                      width: 1.4,
                    ),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppColors.wo,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'محتاج تحديث',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  gate.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                if (gate.storeUrl.trim().isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.nu,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _openStore(context),
                      child: const Text(
                        'حدث دلوقتي',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  const Text(
                    'حدث التطبيق من المتجر وافتحه تاني',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 13.5),
                  ),
                const SizedBox(height: 18),
                Text(
                  'نسختك الحالية: $kAppBuild',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
