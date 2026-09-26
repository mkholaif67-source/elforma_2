import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reference layout with quiet fitness and nutrition artwork at the edges.
class AuthReferenceHeader extends StatelessWidget {
  const AuthReferenceHeader(
      {super.key,
      required this.login,
      required this.height,
      this.compact = false});
  final bool login;
  final double height;
  final bool compact;
  @override
  Widget build(BuildContext context) => SizedBox(
        key: const ValueKey('auth-header'),
        height: height,
        child: LayoutBuilder(builder: (context, box) {
          // CSS 150deg uses a projected line through the rectangle.
          final length = box.maxWidth * .5 + height * .8660254;
          final end =
              Alignment(length * .5 / box.maxWidth, length * .8660254 / height);
          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(36)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment(-end.x, -end.y),
                      end: end,
                      colors: const [
                    Color(0xFF1F4E3D),
                    Color(0xFF274F3E),
                    Color(0xFF1B3A2D)
                  ],
                      stops: const [
                    0,
                    .6,
                    1
                  ])),
              child: Stack(fit: StackFit.expand, children: [
                SvgPicture.asset(
                    'assets/auth/${login ? 'login' : 'register'}_fitness.svg',
                    fit: BoxFit.cover,
                    excludeFromSemantics: true),
                if (compact)
                  Center(
                      child: Image.asset('assets/auth/reference_logo.png',
                          width: 72, height: 72))
                else
                  Column(children: [
                    SizedBox(height: login ? 30 : 18),
                    Image.asset('assets/auth/reference_logo.png',
                        width: login ? 108 : 72,
                        height: login ? 108 : 72,
                        fit: BoxFit.contain,
                        semanticLabel: 'الفورمة'),
                    const SizedBox(height: 2),
                    Text(login ? 'مرحبا بعودتك' : 'إنشاء حساب',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontSize: login ? 22 : 20,
                            fontWeight: FontWeight.w800,
                            height: 1.875)),
                    SizedBox(height: login ? 5 : 2),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Text(
                            login
                                ? 'سجل دخولك لمتابعة رحلتك نحو حياة أكثر صحة ونشاط'
                                : 'ابدأ رحلتك نحو أفضل نسخة منك',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: const Color(0xFFD8E7DE),
                                fontSize: login ? 13 : 12.5,
                                fontWeight: FontWeight.w400,
                                height: login ? 1.5 : 1.875))),
                  ]),
              ]),
            ),
          );
        }),
      );
}
