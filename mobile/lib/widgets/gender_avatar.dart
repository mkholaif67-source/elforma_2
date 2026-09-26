import 'package:elforma/widgets/forma_design.dart';
// ── ElForma · widgets/gender_avatar.dart ──
// [OWNER-RULE] أفاتارات حديثة/شيك حسب جنس المستخدم، وأفاتار مدرب
// FORMA مستقل للمحادثة (ممنوع لوجو الشركة كبديل).

import 'package:flutter/material.dart';

/// بترجع مسار الأفاتار المناسب لجنس المستخدم.
/// بتدعم قيم متعددة (male/female/ذكر/أنثى/m/f) وبتفترض الذكر لو مش واضح.
String genderAvatarAsset(dynamic gender) {
  final g = (gender ?? '').toString().trim().toLowerCase();
  final isFemale = g == 'female' ||
      g == 'f' ||
      g == 'woman' ||
      g.contains('أنث') ||
      g.contains('انث') ||
      g.contains('سيد') ||
      g.contains('بنت') ||
      g.contains('مرا');
  return isFemale ? 'assets/avatars/female.webp' : 'assets/avatars/male.webp';
}

/// أفاتار دائري للمستخدم حسب الجنس.
class GenderAvatar extends StatelessWidget {
  final dynamic gender;
  final double size;
  final Color? ringColor;
  const GenderAvatar(
      {super.key, required this.gender, this.size = 40, this.ringColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: FormaDecoration(
        shape: BoxShape.circle,
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!.withValues(alpha: .6), width: 1.5),
      ),
      child: ClipOval(
        child: Image.asset(
          genderAvatarAsset(gender),
          fit: BoxFit.cover,
          // Avatars are 40dp by default. Decoding the full-resolution source
          // into memory for a 40dp circle is pure waste, and these appear in
          // lists where that waste multiplies by every visible row.
          cacheWidth: (size * 3).round(),
          cacheHeight: (size * 3).round(),
        ),
      ),
    );
  }
}

/// أفاتار مدرب FORMA للمحادثة (مستقل ومصمم — مش لوجو الشركة).
class CoachAvatar extends StatelessWidget {
  final double size;
  const CoachAvatar({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          'assets/avatars/coach.webp',
          fit: BoxFit.cover,
          cacheWidth: (size * 3).round(),
          cacheHeight: (size * 3).round(),
        ),
      ),
    );
  }
}
