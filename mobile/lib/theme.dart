import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared interior tokens. Exterior artwork keeps its own approved palette.
class AppColors {
  static const bg = Color(0xFFF7F9F1);
  static const bg2 = Color(0xFFEEF3E8);
  static const card = Color(0xFFFFFFFF);
  static const card2 = Color(0xFFF0F5EC);
  static const line = Color(0xFFDCE5D8);
  static const text = Color(0xFF173D2E);

  /// Secondary text. Measured contrast on the three surfaces this app actually
  /// uses: `card` 7.64:1 · `bg` 7.19:1 · `bg2` 6.77:1 — comfortably clear of the
  /// WCAG AA 4.5:1 floor at every size, which `muted` is not (it drops to
  /// 4.71:1 on `bg2`). Prefer this for body copy, captions and helper text.
  static const textSoft = Color(0xFF44584D);

  /// Low-emphasis text only: hints, disabled labels, decorative meta.
  /// AA for normal text on `card` (5.32:1); do not place it on `bg2`.
  static const muted = Color(0xFF5B7065);
  static const nu = Color(0xFF075B35);
  static const nu2 = Color(0xFF387548);
  static const wo = Color(0xFF24633D);
  static const wo2 = Color(0xFF587B28);
  static const water = Color(0xFF226B93);
  static const warning = Color(0xFF9A5C16);
  static const onBrand = Colors.white;
  static const lime = Color(0xFFB4D565);
}

ThemeData? _themeCache;

/// Cached: `MaterialApp.theme` is read on every rebuild of the app root, and
/// assembling this theme runs `ColorScheme.fromSeed` (a full Material tonal
/// palette solve) plus ~15 sub-theme objects. Building it once is free after
/// the first frame.
ThemeData buildTheme() => _themeCache ??= _buildTheme();

ThemeData _buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.nu,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.nu,
        onPrimary: Colors.white,
        secondary: AppColors.wo,
        onSecondary: Colors.white,
        surface: AppColors.card,
        onSurface: AppColors.text,
        outline: AppColors.line,
        error: const Color(0xFFAD3838),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'ElFormaArabic',
    fontFamilyFallback: const ['ElFormaLatin'],
    scaffoldBackgroundColor: AppColors.bg,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  final buttons = FilledButton.styleFrom(
    minimumSize: const Size(48, 50),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: const TextStyle(
      fontFamily: 'ElFormaArabic',
      fontFamilyFallback: const ['ElFormaLatin'],
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w700,
    ),
    shape: shape,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.bg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: buttons),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: AppColors.nu,
        minimumSize: const Size(48, 50),
        shape: shape,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.nu,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: AppColors.line),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: 'ElFormaArabic',
          fontFamilyFallback: const ['ElFormaLatin'],
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.nu,
        minimumSize: const Size(48, 48),
      ),
    ),
    // A single treatment for every Switch/SwitchListTile in the app.
    // OFF remains visibly interactive on white and pale-green surfaces, while
    // ON keeps the current forest-green identity.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.nu;
        if (states.contains(WidgetState.disabled)) return AppColors.bg;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.nu.withValues(alpha: .42);
        }
        if (states.contains(WidgetState.disabled)) {
          return const Color(0xFFD4DED5);
        }
        return const Color(0xFFC5D3C8);
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.nu;
        if (states.contains(WidgetState.disabled)) {
          return const Color(0xFFAEBCAF);
        }
        return const Color(0xFF8EA294);
      }),
      trackOutlineWidth: const WidgetStatePropertyAll(1),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.nu, width: 1.6),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontFamily: 'ElFormaArabic',
        fontFamilyFallback: const ['ElFormaLatin'],
      ),
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.bg2,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.nu
              : AppColors.muted,
          fontSize: 12,
          fontFamily: 'ElFormaArabic',
          fontFamilyFallback: const ['ElFormaLatin'],
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.nu,
      linearTrackColor: AppColors.line,
      circularTrackColor: AppColors.bg2,
    ),
    // Keep the SDK-provided platform transitions for compatibility.
  );
}
