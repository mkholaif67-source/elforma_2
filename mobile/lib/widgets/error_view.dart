import 'package:flutter/material.dart';
import 'package:elforma/theme.dart';

String efErrorMessage(int status, [dynamic data]) {
  final code = (data is Map && data['error'] != null) ? '${data['error']}' : '';

  if (status == 0) {
    return 'الاتصال مش مستقر دلوقتي. تأكد من الإنترنت وحاول مرة تانية.';
  }
  if (status == 408) {
    return 'الاتصال استغرق وقتا أطول من المعتاد. جرّب مرة تانية بعد لحظات.';
  }
  if (status == 401 || code == 'unauthenticated') {
    return 'انتهت جلسة الدخول. سجّل دخولك مرة تانية.';
  }
  if (status == 403) {
    if (code == 'subscription_required' || code == 'forbidden') {
      return 'الجزء ده محتاج اشتراك فعّال.';
    }
    return 'مش متاح الوصول للجزء ده حاليًا.';
  }
  if (status == 429) {
    return 'في محاولات كتير ورا بعض. استنى دقيقة وجرّب مرة تانية.';
  }
  if (status >= 500) {
    return 'حصلت مشكلة مؤقتة أثناء التحميل. جرّب مرة تانية.';
  }
  if (status == 404) return 'المحتوى المطلوب مش متاح حاليًا.';
  return 'حصلت مشكلة غير متوقعة. جرّب مرة تانية.';
}

bool efIsOffline(int status) => status == 0;

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.offline = false,
    this.retryLabel = 'إعادة المحاولة',
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool offline;
  final String retryLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return _compactView();

    final icon = offline ? Icons.wifi_off_rounded : Icons.sync_problem_rounded;
    final title = offline ? 'الاتصال مش مستقر' : 'معلش، حصلت مشكلة مؤقتة';

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FCF5), Color(0xFFF1F7EA)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -50,
              child: _SoftLeafBlob(size: 220, opacity: .11),
            ),
            Positioned(
              bottom: -90,
              left: -70,
              child: _SoftLeafBlob(size: 250, opacity: .08),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/auth/brand_logo.png',
                          width: 146,
                          height: 90,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(height: 26),
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFFFFF),
                            border: Border.all(color: const Color(0x1F0B6A3A)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F0B6A3A),
                                blurRadius: 28,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Icon(icon, size: 38, color: const Color(0xFF0A6A3B)),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          title,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'ElFormaArabic',
                            color: Color(0xFF0B5F38),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'ElFormaArabic',
                            color: Color(0xFF4E665B),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w400,
                            height: 1.7,
                          ),
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(27),
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [Color(0xFF075A35), Color(0xFF86B91D)],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x332A7E3D),
                                    blurRadius: 18,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(27),
                                  onTap: onRetry,
                                  child: Center(
                                    child: Text(
                                      retryLabel,
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(
                                        fontFamily: 'ElFormaArabic',
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        const Text(
                          'بياناتك محفوظة، ومش محتاج تعمل أي خطوة إضافية.',
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'ElFormaArabic',
                            color: Color(0xFF789083),
                            fontSize: 11.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactView() {
    final icon = offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x140A6A3B),
              ),
              child: Icon(icon, size: 29, color: const Color(0xFF0A6A3B)),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'ElFormaArabic',
                color: AppColors.text,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0A6A3B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Text(
                  retryLabel,
                  style: const TextStyle(fontFamily: 'ElFormaArabic', fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SoftLeafBlob extends StatelessWidget {
  const _SoftLeafBlob({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: .65,
        child: Container(
          width: size,
          height: size * .58,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(180),
              bottomRight: Radius.circular(180),
              topRight: Radius.circular(36),
              bottomLeft: Radius.circular(36),
            ),
            gradient: LinearGradient(
              colors: [Color(0xFF69A927), Color(0xFF0A6A3B)],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.6),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.nu,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared lightweight loading surface used across the app.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.nu),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(
              label!,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

