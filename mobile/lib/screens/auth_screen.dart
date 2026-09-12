
// ── ElForma · screens/auth_screen.dart ──
// شاشات تسجيل الدخول / إنشاء الحساب — بالتصميم الجديد:
//  • دخول بحقل واحد (بريد أو رقم هاتف) + كلمة مرور.
//  • إنشاء حساب: الاسم + البريد + رقم الهاتف (مع كود الدولة) +
//    كلمة المرور + تأكيدها.
//  • دخول مباشر بحساب Google.
// الرقم بيتاخد في التسجيل، فالباقة المجانية بتتفعل مباشرة،
// وتأكيد الرقم في بيانات الحساب زي ما هو.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:elforma/api.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/country_codes.dart';
import 'package:elforma/screens/shell_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _login = true;
  bool _busy = false;
  bool _hide = true;
  bool _hide2 = true;
  String _countryIso = 'EG';
  String? _error;
  final _ident = TextEditingController(); // الدخول: بريد أو رقم
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  Country get _country =>
      kCountries.firstWhere((e) => e.iso == _countryIso, orElse: () => kCountries.first);

  @override
  void initState() {
    super.initState();
    _pass.addListener(_onPasswordChanged);
    _loadGeo();
  }

  void _onPasswordChanged() { if (mounted && !_login) setState(() {}); }

  Future<void> _loadGeo() async {
    try {
      final r = await Api.I.plans();
      if (!mounted || !r.ok) return;
      final geo = (r.data['geo'] as Map?)?.cast<String, dynamic>() ?? {};
      final iso = (geo['country']?.toString().toUpperCase() ?? '');
      if (iso.isNotEmpty && kCountries.any((c) => c.iso == iso)) {
        setState(() => _countryIso = iso);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ident.dispose();
    _email.dispose();
    _phone.dispose();
    _name.dispose();
    _pass.removeListener(_onPasswordChanged);
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _ident.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('استعادة كلمة المرور', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اكتب بريد حسابك وهنبعتلك رابط لتعيين كلمة مرور جديدة',
                style: TextStyle(color: AppColors.muted, height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'البريد الإلكتروني'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('ابعت الرابط', style: TextStyle(color: AppColors.nu, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    setState(() => _busy = true);
    await Api.I.forgotPassword(email);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لو البريد مسجل عندنا هتوصلك رسالة فيها رابط تعيين كلمة مرور جديدة خلال دقايق')));
  }

  // قاعدة أمان كلمة المرور (متوافقة مع السيرفر: 8 أحرف + حروف + أرقام).
  String? _passwordProblem(String pw) {
    if (pw.length < 8) return 'كلمة المرور لازم تكون 8 أحرف على الأقل';
    if (pw.length > 200) return 'كلمة المرور طويلة جدا';
    if (!RegExp(r'[A-Za-z]').hasMatch(pw)) return 'كلمة المرور لازم تحتوي على حروف وأرقام';
    if (!RegExp(r'[0-9]').hasMatch(pw)) return 'لازم تحتوي على رقم واحد على الأقل';
    return null;
  }

  Future<void> _submit() async {
    if (_login) {
      final identifier = _ident.text.trim();
      if (identifier.isEmpty) {
        setState(() => _error = 'اكتب البريد أو رقم الهاتف');
        return;
      }
      if (_pass.text.isEmpty) {
        setState(() => _error = 'اكتب كلمة المرور');
        return;
      }
      setState(() { _busy = true; _error = null; });
      final res = await Api.I.login(identifier, _pass.text);
      _afterAuth(res);
      return;
    }

    // إنشاء حساب
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'الاسم مطلوب');
      return;
    }
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'اكتب بريد إلكتروني صحيح');
      return;
    }
    // [OWNER-RULE] رقم الهاتف اختياري تماما — الحساب والتجربة المجانية
    // مش محتاجين رقم هاتف. لو اتكتب رقم بنتحقق من طوله بس، ولو فاضي عادي.
    final c = _country;
    // [FIX-PHONE] تحقق موحد: يشيل كود الدولة والصفر الأولاني ويتأكد من الطول
    // والبادئة الصح (شبكات مصر 010/011/012/015)، فرقم غلط زي 2532542225 يترفض.
    final phoneProblem = phoneError(c, _phone.text);
    if (phoneProblem != null) {
      setState(() => _error = phoneProblem);
      return;
    }
    final national = phoneNational(c, _phone.text);
    final pwProblem = _passwordProblem(_pass.text);
    if (pwProblem != null) {
      setState(() => _error = pwProblem);
      return;
    }
    if (_pass.text != _pass2.text) {
      setState(() => _error = 'تأكيد كلمة المرور مش مطابق');
      return;
    }

    setState(() { _busy = true; _error = null; });
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'email': email,
      if (national.isNotEmpty) 'phone': '+${c.dial}$national',
      'password': _pass.text,
    };
    final res = await Api.I.signup(body);
    _afterAuth(res);
  }

  void _afterAuth(ApiResult res) {
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok && res.data['user'] != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ShellScreen()));
    } else {
      setState(() => _error = res.friendlyError('حصل خطأ حاول تاني'));
    }
  }

  // دخول/تسجيل بحساب Google. بياخد idToken من جوجل ويبعته للسيرفر.
  // الربط الأصلي (OAuth Client ID) بيتعمل في إعدادات المنصة لاحقا.
  Future<void> _google() async {
    setState(() { _busy = true; _error = null; });
    try {
      // [GOOGLE-AUD] الـ Web Client ID (من نوع Web application في Google Cloud)
      // بيتمرر وقت البناء بـ --dart-define=GOOGLE_WEB_CLIENT_ID=... عشان الـ idToken
      // يتصدر باسم تطبيقنا (aud=تطبيقنا) ويفضل صالح للتحقق في /api/auth/google.
      // لما تكون فاضية بنرجع للسلوك القديم من غير ما حاجة تتكسر.
      const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');
      final gsi = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: webClientId.isEmpty ? null : webClientId,
      );
      try { await gsi.signOut(); } catch (_) {}
      final acc = await gsi.signIn();
      if (acc == null) {
        if (mounted) setState(() => _busy = false);
        return; // المستخدم لغى
      }
      final authd = await acc.authentication;
      final idToken = authd.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) setState(() { _busy = false; _error = 'تعذر الدخول بجوجل، جرب تاني'; });
        return;
      }
      final res = await Api.I.googleAuth(idToken, name: acc.displayName, email: acc.email);
      _afterAuth(res);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = 'تعذر الدخول بجوجل — تأكد من إعداد جوجل لاحقا'; });
    }
  }

  void _switchMode(bool login) {
    if (_login == login) return;
    setState(() {
      _login = login;
      _error = null;
    });
  }

  void _pickCountry() {
    final search = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final q = search.text.trim().toLowerCase();
          final list = q.isEmpty
              ? kCountries
              : kCountries.where((c) => c.name.toLowerCase().contains(q) || c.iso.toLowerCase().contains(q) || c.dial.contains(q)).toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * .72,
              child: Column(children: [
                const SizedBox(height: 12),
                Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: search,
                    autofocus: true,
                    onChanged: (_) => setSheet(() {}),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث عن الدولة أو الكود'),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return ListTile(
                        leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(c.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                        trailing: Text('+${c.dial}', style: TextStyle(color: c.iso == _countryIso ? AppColors.nu : AppColors.muted, fontWeight: FontWeight.w900)),
                        onTap: () {
                          setState(() => _countryIso = c.iso);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ]),
            ),
          );
        });
      },
    );
  }

  static const double _designWidth = 390;
  static const double _designHeight = 844;
  static const Color _authCanvas = Color(0xFFF5F9EF);
  static const Color _forest = Color(0xFF075B35);
  static const Color _fieldText = Color(0xFF526278);
  static const Color _fieldBorder = Color(0xFFD7E0DF);
  static const Color _subtleText = Color(0xFF174F3B);

  @override
  Widget build(BuildContext context) {
    const overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: _authCanvas,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: _authCanvas,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final canvasWidth = constraints.maxWidth > 430
                ? 430.0
                : constraints.maxWidth;
            final scale = canvasWidth / _designWidth;
            final canvasHeight = _designHeight * scale;
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final canScroll = keyboardInset > 0 || canvasHeight > constraints.maxHeight;

            return SingleChildScrollView(
              physics: canScroll
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: canvasWidth,
                    height: canvasHeight,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: _designWidth,
                        height: _designHeight,
                        child: _buildAuthCanvas(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthCanvas() {
    final logoTop = _login ? 203.0 : 195.0;
    const heroHeight = 284.0;
    // Finish the photo before the logo, keeping its size and the form fixed.
    final photoFadeEnd = logoTop - 10.0;
    final photoFadeStart = photoFadeEnd - 30.0;
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _forest,
          selectionColor: Color(0x332F8B57),
          selectionHandleColor: _forest,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFAFCF6), _authCanvas],
                  stops: [0.46, 1],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _AuthBackdropPainter())),
          Positioned(
            left: 0,
            top: 0,
            width: _designWidth,
            height: heroHeight,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                  Colors.transparent,
                ],
                stops: [
                  0,
                  photoFadeStart / heroHeight,
                  photoFadeEnd / heroHeight,
                  1,
                ],
              ).createShader(bounds),
              child: Image.asset(
                _login
                    ? 'assets/auth/hero_login.webp'
                    : 'assets/auth/hero_signup.webp',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _login ? 114 : 88,
            child: IgnorePointer(
              child: Image.asset(
                _login
                    ? 'assets/auth/bottom_login.png'
                    : 'assets/auth/bottom_signup.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          if (!_login)
            Positioned(
              left: 12,
              top: 48,
              width: 50,
              height: 50,
              child: Semantics(
                button: true,
                label: 'الرجوع إلى تسجيل الدخول',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : () => _switchMode(true),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          Positioned(
            top: logoTop,
            left: _login ? 116 : 120,
            width: _login ? 158 : 150,
            height: _login ? 97 : 91,
            child: IgnorePointer(
              child: Image.asset(
                'assets/auth/brand_logo.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          ...(_login ? _buildLoginContent() : _buildSignupContent()),
        ],
      ),
    );
  }

  List<Widget> _buildLoginContent() {
    final errorShift = _error == null ? 0.0 : 44.0;
    return [
      _positionedText(
        top: 306,
        height: 43,
        text: 'مرحباً بعودتك',
        fontSize: 30,
        weight: FontWeight.w700,
      ),
      _positionedText(
        top: 354,
        height: 27,
        text: 'سجل دخولك لمتابعة رحلتك نحو حياة أكثر صحة ونشاط',
        fontSize: 13.5,
        weight: FontWeight.w400,
        color: _subtleText,
      ),
      Positioned(
        top: 399,
        left: 20,
        right: 20,
        height: 50,
        child: _authField(
          controller: _ident,
          hint: 'البريد الإلكتروني أو رقم الهاتف',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
      ),
      Positioned(
        top: 458,
        left: 20,
        right: 20,
        height: 50,
        child: _authPasswordField(
          controller: _pass,
          hint: 'كلمة المرور',
          hidden: _hide,
          onToggle: () => setState(() => _hide = !_hide),
          onSubmitted: (_) => _submit(),
        ),
      ),
      Positioned(
        top: 511,
        right: 18,
        height: 34,
        child: TextButton(
          onPressed: _busy ? null : _forgotPassword,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 34),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            foregroundColor: _forest,
            textStyle: const TextStyle(
              fontFamily: 'ElFormaArabic',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('نسيت كلمة المرور؟'),
        ),
      ),
      if (_error != null) _errorBanner(top: 547),
      Positioned(
        top: 554 + errorShift,
        left: 20,
        right: 20,
        height: 52,
        child: _primaryButton(),
      ),
      Positioned(
        top: 625 + errorShift,
        left: 20,
        right: 20,
        height: 25,
        child: _orDivider(),
      ),
      Positioned(
        top: 657 + errorShift,
        left: 20,
        right: 20,
        height: 50,
        child: _googleButton(),
      ),
      Positioned(
        top: 737 + errorShift,
        left: 30,
        right: 30,
        height: 48,
        child: _switchFooter(),
      ),
    ];
  }

  List<Widget> _buildSignupContent() {
    final passwordProblem = _pass.text.isEmpty ? null : _passwordProblem(_pass.text);
    final passwordShift = passwordProblem == null ? 0.0 : 18.0;
    final errorShift = _error == null ? 0.0 : 42.0;
    final lowerShift = passwordShift + errorShift;

    return [
      _positionedText(
        top: 278,
        height: 42,
        text: 'إنشاء حساب',
        fontSize: 27,
        weight: FontWeight.w700,
      ),
      _positionedText(
        top: 319,
        height: 26,
        text: 'ابدأ رحلتك نحو أفضل نسخة منك',
        fontSize: 13.5,
        weight: FontWeight.w400,
        color: _subtleText,
      ),
      Positioned(
        top: 354,
        left: 24,
        right: 24,
        height: 44,
        child: _authField(
          controller: _name,
          hint: 'الاسم الكامل',
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
        ),
      ),
      Positioned(
        top: 404,
        left: 24,
        right: 24,
        height: 44,
        child: _authField(
          controller: _email,
          hint: 'البريد الإلكتروني',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
      ),
      Positioned(
        top: 454,
        left: 24,
        right: 24,
        height: 44,
        child: _phoneField(),
      ),
      Positioned(
        top: 504,
        left: 24,
        right: 24,
        height: 44,
        child: _authPasswordField(
          controller: _pass,
          hint: 'كلمة المرور',
          hidden: _hide,
          onToggle: () => setState(() => _hide = !_hide),
          textInputAction: TextInputAction.next,
        ),
      ),
      if (passwordProblem != null)
        Positioned(
          top: 548,
          left: 28,
          right: 28,
          height: 18,
          child: Text(
            passwordProblem,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'ElFormaArabic',
              color: Color(0xFFB23A32),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      Positioned(
        top: 554 + passwordShift,
        left: 24,
        right: 24,
        height: 44,
        child: _authPasswordField(
          controller: _pass2,
          hint: 'تأكيد كلمة المرور',
          hidden: _hide2,
          onToggle: () => setState(() => _hide2 = !_hide2),
          onSubmitted: (_) => _submit(),
        ),
      ),
      if (_error != null) _errorBanner(top: 603 + passwordShift),
      Positioned(
        top: 610 + lowerShift,
        left: 24,
        right: 24,
        height: 48,
        child: _primaryButton(),
      ),
      Positioned(
        top: 670 + lowerShift,
        left: 24,
        right: 24,
        height: 24,
        child: _orDivider(),
      ),
      Positioned(
        top: 695 + lowerShift,
        left: 24,
        right: 24,
        height: 48,
        child: _googleButton(),
      ),
      Positioned(
        top: 757 + lowerShift,
        left: 22,
        right: 22,
        height: 46,
        child: _switchFooter(),
      ),
    ];
  }

  Positioned _positionedText({
    required double top,
    required double height,
    required String text,
    required double fontSize,
    required FontWeight weight,
    Color color = _forest,
  }) {
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      height: height,
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'ElFormaArabic',
            color: color,
            fontSize: fontSize,
            fontWeight: weight,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _authField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onSubmitted,
  }) {
    final radius = BorderRadius.circular(22);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B5636),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: formatters,
        onSubmitted: onSubmitted,
        textAlign: TextAlign.start,
        textDirection: TextDirection.rtl,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: _forest,
        style: const TextStyle(
          fontFamily: 'ElFormaArabic',
          color: _fieldText,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintTextDirection: TextDirection.rtl,
          hintStyle: const TextStyle(
            fontFamily: 'ElFormaArabic',
            color: _fieldText,
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, color: _forest, size: 21),
          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          filled: true,
          fillColor: const Color(0xF9FFFFFF),
          isDense: true,
          contentPadding: const EdgeInsetsDirectional.only(
            start: 6,
            end: 2,
            top: 10,
            bottom: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: _fieldBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: Color(0xFF7BAA54), width: 1.25),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: _fieldBorder, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _authPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool hidden,
    required VoidCallback onToggle,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return _authField(
      controller: controller,
      hint: hint,
      icon: Icons.lock_outline_rounded,
      obscure: hidden,
      textInputAction: textInputAction ?? TextInputAction.done,
      onSubmitted: onSubmitted,
      suffix: IconButton(
        tooltip: hidden ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
        splashRadius: 18,
        padding: EdgeInsets.zero,
        icon: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFF243A5A),
          size: 20,
        ),
        onPressed: onToggle,
      ),
    );
  }

  Widget _phoneField() {
    final c = _country;
    final radius = BorderRadius.circular(22);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF9FFFFFF),
        borderRadius: radius,
        border: Border.all(color: _fieldBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B5636),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _busy ? null : _pickCountry,
                child: SizedBox(
                  width: 104,
                  height: 44,
                  child: Row(
                    textDirection: TextDirection.ltr,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(c.flag, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 7),
                      Text(
                        '+${c.dial}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontFamily: 'ElFormaArabic',
                          color: Color(0xFF111827),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF1F2937), size: 19),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 44, color: _fieldBorder),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlignVertical: TextAlignVertical.center,
                  cursorColor: _forest,
                  style: const TextStyle(
                    fontFamily: 'ElFormaArabic',
                    color: _fieldText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'رقم الهاتف',
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: TextStyle(
                      fontFamily: 'ElFormaArabic',
                      color: _fieldText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(Icons.phone_outlined, color: _forest, size: 21),
                    prefixIconConstraints: BoxConstraints(minWidth: 42, minHeight: 44),
                    filled: true,
                    fillColor: Color(0xF9FFFFFF),
                    isDense: true,
                    contentPadding: EdgeInsetsDirectional.only(
                      start: 4,
                      end: 0,
                      top: 9,
                      bottom: 9,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton() {
    final label = _login ? 'تسجيل الدخول' : 'إنشاء حساب';
    final radius = BorderRadius.circular(25);
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF075A35), Color(0xFF86B91D)],
            stops: [0.08, 1],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3D2A7E3D),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: _busy ? null : _submit,
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'ElFormaArabic',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0xFFCFD9D5), thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 17),
          child: Text(
            'أو',
            style: TextStyle(
              fontFamily: 'ElFormaArabic',
              color: Color(0xFF15261F),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFCFD9D5), thickness: 1)),
      ],
    );
  }

  Widget _googleButton() {
    final radius = BorderRadius.circular(25);
    return Semantics(
      button: true,
      label: 'المتابعة باستخدام Google',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFCFFFFFF),
          borderRadius: radius,
          border: Border.all(color: _fieldBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C0B5636),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: _busy ? null : _google,
            child: Center(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/auth/google_g.png',
                      width: 24,
                      height: 24,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(width: 13),
                    const Text(
                      'المتابعة باستخدام Google',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'ElFormaArabic',
                        color: Color(0xFF132653),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _switchFooter() {
    return Semantics(
      button: true,
      label: _login ? 'إنشاء حساب' : 'تسجيل الدخول',
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _busy ? null : () => _switchMode(!_login),
        child: Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _login ? 'ليس لديك حساب؟' : 'لديك حساب بالفعل؟',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: 'ElFormaArabic',
                color: Color(0xFF315344),
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              _login ? 'إنشاء حساب' : 'تسجيل الدخول',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: 'ElFormaArabic',
                color: _forest,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),

          ],
        ),
      ),
    );
  }

  Positioned _errorBanner({required double top}) {
    return Positioned(
      top: top,
      left: 24,
      right: 24,
      height: 38,
      child: Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2EF),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0x55C94D3F)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFC04438), size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'ElFormaArabic',
                      color: Color(0xFF8F3028),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
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
}

class _AuthBackdropPainter extends CustomPainter {
  const _AuthBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final back = Paint()..color = const Color(0xFFEAF2E4);
    final mid = Paint()..color = const Color(0xFFDDEADA).withValues(alpha: .75);
    final front = Paint()..color = const Color(0xFFD2E4D0).withValues(alpha: .62);

    final p1 = Path()
      ..moveTo(0, size.height - 64)
      ..cubicTo(
        size.width * .19,
        size.height - 127,
        size.width * .42,
        size.height - 16,
        size.width * .64,
        size.height - 65,
      )
      ..cubicTo(
        size.width * .79,
        size.height - 96,
        size.width * .90,
        size.height - 91,
        size.width,
        size.height - 117,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(p1, back);

    final p2 = Path()
      ..moveTo(0, size.height - 26)
      ..cubicTo(
        size.width * .20,
        size.height - 90,
        size.width * .41,
        size.height + 8,
        size.width * .61,
        size.height - 30,
      )
      ..cubicTo(
        size.width * .77,
        size.height - 61,
        size.width * .89,
        size.height - 58,
        size.width,
        size.height - 88,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(p2, mid);

    final p3 = Path()
      ..moveTo(size.width * .42, size.height)
      ..cubicTo(
        size.width * .58,
        size.height - 22,
        size.width * .73,
        size.height - 30,
        size.width,
        size.height - 57,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p3, front);
  }

  @override
  bool shouldRepaint(covariant _AuthBackdropPainter oldDelegate) => false;
}
