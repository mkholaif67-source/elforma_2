// ── ElForma · screens/auth_screen.dart ──
// شاشات تسجيل الدخول / إنشاء الحساب — بالتصميم الجديد:
//  • دخول بحقل واحد (بريد أو رقم هاتف) + كلمة مرور.
//  • إنشاء حساب: الاسم + البريد + رقم الهاتف (مع كود الدولة) +
//    كلمة المرور + تأكيدها.
//  • دخول مباشر بحساب Google.
// الرقم بيتاخد في التسجيل، فالباقة المجانية بتتفعل مباشرة،
// وتأكيد الرقم في بيانات الحساب زي ما هو.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:elforma/widgets/auth_reference_header.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:elforma/api.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/auth_field_reveal.dart';
import 'package:elforma/country_codes.dart';
import 'package:elforma/screens/shell_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.loadGeo = true});
  final bool loadGeo;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  final _authScroll = ScrollController();
  final _passwordKey = GlobalKey();
  final _confirmationKey = GlobalKey();
  final _authViewportKey = GlobalKey();
  final _identKey = GlobalKey();
  final _nameKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _phoneKey = GlobalKey();
  final _identFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  Timer? _revealTimer;
  bool _keyboardWasOpen = false;

  Map<FocusNode, GlobalKey> get _focusTargets => {
        _identFocus: _identKey,
        _nameFocus: _nameKey,
        _emailFocus: _emailKey,
        _phoneFocus: _phoneKey,
        _passwordFocus: _passwordKey,
        _confirmationFocus: _confirmationKey,
      };

  void _revealFocusedField() {
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 300), () {
      // Metrics notifications arrive before MediaQuery and the scroll viewport
      // rebuild. Read both only after layout, never from the timer callback.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_authScroll.hasClients) return;
        if (MediaQuery.viewInsetsOf(context).bottom <= 0) {
          if (!_keyboardWasOpen) return;
          _keyboardWasOpen = false;
          unawaited(
            _authScroll.animateTo(
              0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            ),
          );
          return;
        }
        _keyboardWasOpen = true;
        final viewport = _authViewportKey.currentContext?.findRenderObject();
        if (viewport is! RenderBox || !viewport.hasSize) return;
        final viewportTop = viewport.localToGlobal(Offset.zero).dy;
        final viewportBottom = viewportTop + viewport.size.height;
        for (final entry in _focusTargets.entries) {
          if (!entry.key.hasFocus) continue;
          final field = entry.value.currentContext?.findRenderObject();
          if (field is! RenderBox || !field.hasSize) return;
          final top = field.localToGlobal(Offset.zero).dy;
          final bottom = top + field.size.height;
          final position = _authScroll.position;
          final target = authFieldRevealOffset(
            offset: position.pixels,
            minOffset: position.minScrollExtent,
            maxOffset: position.maxScrollExtent,
            viewportTop: viewportTop,
            viewportBottom: viewportBottom,
            fieldTop: top,
            fieldBottom: bottom,
          );
          if ((target - position.pixels).abs() < .5) return;
          unawaited(
            _authScroll.animateTo(
              target,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            ),
          );
          return;
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  @override
  void didChangeMetrics() => _revealFocusedField();
  bool _login = true;
  bool _busy = false;
  bool _rememberMe = true;
  bool _hide = true;
  bool _hide2 = true;
  bool _showConfirmation = false;
  final _passwordFocus = FocusNode();
  final _confirmationFocus = FocusNode();
  String _countryIso = 'EG';
  String? _error;
  final _ident = TextEditingController(); // الدخول: بريد أو رقم
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  Country get _country => kCountries.firstWhere(
        (e) => e.iso == _countryIso,
        orElse: () => kCountries.first,
      );

  @override
  void initState() {
    super.initState();
    _pass.addListener(_onPasswordChanged);
    WidgetsBinding.instance.addObserver(this);
    for (final focus in _focusTargets.keys) {
      focus.addListener(_revealFocusedField);
    }
    if (widget.loadGeo) _loadGeo();
  }

  void _onPasswordChanged() {
    if (!mounted || _login) return;
    setState(() {
      // Reveal only after the first password is complete. Keep the field
      // visible while either password is subsequently edited.
      if (_passwordProblem(_pass.text) == null) _showConfirmation = true;
    });
  }

  void _continueToConfirmation() {
    if (_passwordProblem(_pass.text) != null) {
      _passwordFocus.requestFocus();
      return;
    }
    setState(() => _showConfirmation = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confirmationFocus.requestFocus();
    });
  }

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
    WidgetsBinding.instance.removeObserver(this);
    _revealTimer?.cancel();
    for (final focus in _focusTargets.keys) {
      focus.removeListener(_revealFocusedField);
      focus.dispose();
    }
    _authScroll.dispose();
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
        title: const Text(
          'استعادة كلمة المرور',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اكتب بريد حسابك وهنبعتلك رابط لتعيين كلمة مرور جديدة',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
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
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text(
              'ابعت الرابط',
              style: TextStyle(
                color: AppColors.nu,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    setState(() => _busy = true);
    await Api.I.forgotPassword(email);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'لو البريد مسجل عندنا هتوصلك رسالة فيها رابط تعيين كلمة مرور جديدة خلال دقايق',
        ),
      ),
    );
  }

  // قاعدة أمان كلمة المرور (متوافقة مع السيرفر: 8 أحرف + حروف + أرقام).
  String? _passwordProblem(String pw) {
    if (pw.length < 8) return 'كلمة المرور لازم تكون 8 أحرف على الأقل';
    if (pw.length > 200) return 'كلمة المرور طويلة جدا';
    if (!RegExp(r'[A-Za-z]').hasMatch(pw))
      return 'كلمة المرور لازم تحتوي على حروف وأرقام';
    if (!RegExp(r'[0-9]').hasMatch(pw))
      return 'لازم تحتوي على رقم واحد على الأقل';
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
      setState(() {
        _busy = true;
        _error = null;
      });
      final res = await Api.I.login(
        identifier,
        _pass.text,
        remember: _rememberMe,
      );
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
    if (_pass2.text.isEmpty) {
      _continueToConfirmation();
      return;
    }
    if (_pass.text != _pass2.text) {
      setState(() => _error = 'تأكيد كلمة المرور مش مطابق');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
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
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ShellScreen()));
    } else {
      setState(() => _error = res.friendlyError('حصل خطأ حاول تاني'));
    }
  }

  // دخول/تسجيل بحساب Google. بياخد idToken من جوجل ويبعته للسيرفر.
  // الربط الأصلي (OAuth Client ID) بيتعمل في إعدادات المنصة لاحقا.
  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // [GOOGLE-AUD] الـ Web Client ID (من نوع Web application في Google Cloud)
      // بيتمرر وقت البناء بـ --dart-define=GOOGLE_WEB_CLIENT_ID=... عشان الـ idToken
      // يتصدر باسم تطبيقنا (aud=تطبيقنا) ويفضل صالح للتحقق في /api/auth/google.
      // لما تكون فاضية بنرجع للسلوك القديم من غير ما حاجة تتكسر.
      const webClientId = String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue: '',
      );
      final gsi = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: webClientId.isEmpty ? null : webClientId,
      );
      try {
        await gsi.signOut();
      } catch (_) {}
      final acc = await gsi.signIn();
      if (acc == null) {
        if (mounted) setState(() => _busy = false);
        return; // المستخدم لغى
      }
      final authd = await acc.authentication;
      final idToken = authd.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted)
          setState(() {
            _busy = false;
            _error = 'تعذر الدخول بجوجل، جرب تاني';
          });
        return;
      }
      final res = await Api.I.googleAuth(
        idToken,
        name: acc.displayName,
        email: acc.email,
        remember: !_login || _rememberMe,
      );
      _afterAuth(res);
    } catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = 'تعذر الدخول بجوجل — تأكد من إعداد جوجل لاحقا';
        });
    }
  }

  void _switchMode(bool login) {
    if (_login == login) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _login = login;
      _error = null;
      _showConfirmation = !login && _passwordProblem(_pass.text) == null;
    });
  }

  void _pickCountry() {
    final search = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = search.text.trim().toLowerCase();
            final list = q.isEmpty
                ? kCountries
                : kCountries
                    .where(
                      (c) =>
                          c.name.toLowerCase().contains(q) ||
                          c.iso.toLowerCase().contains(q) ||
                          c.dial.contains(q),
                    )
                    .toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * .72,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: search,
                        autofocus: true,
                        onChanged: (_) => setSheet(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'ابحث عن الدولة أو الكود',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          return ListTile(
                            leading: Text(
                              c.flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: Text(
                              c.name,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: Text(
                              '+${c.dial}',
                              style: TextStyle(
                                color: c.iso == _countryIso
                                    ? AppColors.nu
                                    : AppColors.muted,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            onTap: () {
                              setState(() => _countryIso = c.iso);
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static const Color _authCanvas = Colors.white;
  static const Color _forest = Color(0xFF1F4E3D);
  static const Color _fieldText = Color(0xFF1F2A24);
  static const Color _fieldBorder = Color(0xFFE2E8E4);
  static const Color _hintColor = Color(0xFF9AA69F);

  @override
  Widget build(BuildContext context) {
    const overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Theme(
        data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Cairo')),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: _authCanvas,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
                top: false,
                child: LayoutBuilder(
                    builder: (context, constraints) =>
                        _buildReflowAuth(constraints))),
          ),
        ),
      ),
    );
  }

  Widget _buildReflowAuth(BoxConstraints viewport) {
    final passwordProblem =
        _login || _pass.text.isEmpty ? null : _passwordProblem(_pass.text);
    final width = math.min(viewport.maxWidth, 520.0);
    final editing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final headerHeight = editing && viewport.maxHeight < 844
        ? 96.0
        : (_login ? 296.0 : 176.0) + math.max(0, textScale - 1) * 160;
    final formMinHeight = math.max(0.0, viewport.maxHeight - headerHeight);
    final gap = _login ? 18.0 : 14.0;
    final groupGap = _login ? 7.0 : 6.0;
    Widget group(String label, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: _fieldText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 24 / 13)),
            SizedBox(height: groupGap),
            child
          ],
        );
    return ColoredBox(
        color: _authCanvas,
        child: SingleChildScrollView(
          key: _authViewportKey,
          controller: _authScroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          child: Center(
              child: SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthReferenceHeader(
                          login: _login,
                          height: headerHeight,
                          compact: headerHeight == 96),
                      ConstrainedBox(
                        constraints: BoxConstraints(minHeight: formMinHeight),
                        child: IntrinsicHeight(
                            child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              24, _login ? 28 : 20, 24, _login ? 22 : 18),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_login)
                                  group(
                                      'البريد الإلكتروني أو الهاتف',
                                      _authField(
                                          controller: _ident,
                                          focusNode: _identFocus,
                                          fieldLabel:
                                              'ادخل بريدك الإلكتروني أو رقم هاتفك',
                                          icon: 'mail',
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          autofillHints: const [
                                            AutofillHints.username,
                                            AutofillHints.email
                                          ],
                                          textInputAction: TextInputAction.next,
                                          onSubmitted: (_) =>
                                              _passwordFocus.requestFocus()))
                                else ...[
                                  group(
                                      'الاسم الكامل',
                                      _authField(
                                          controller: _name,
                                          focusNode: _nameFocus,
                                          fieldLabel: 'اكتب اسمك بالكامل',
                                          icon: 'person',
                                          autofillHints: const [
                                            AutofillHints.name
                                          ],
                                          textInputAction: TextInputAction.next,
                                          onSubmitted: (_) =>
                                              _emailFocus.requestFocus())),
                                  SizedBox(height: gap),
                                  group(
                                      'البريد الإلكتروني',
                                      _authField(
                                          controller: _email,
                                          focusNode: _emailFocus,
                                          fieldLabel: 'name@example.com',
                                          icon: 'mail',
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          autofillHints: const [
                                            AutofillHints.email,
                                            AutofillHints.username
                                          ],
                                          textInputAction: TextInputAction.next,
                                          onSubmitted: (_) =>
                                              _phoneFocus.requestFocus())),
                                  SizedBox(height: gap),
                                  group('رقم الهاتف', _phoneField()),
                                ],
                                SizedBox(height: gap),
                                group(
                                    'كلمة المرور',
                                    _authPasswordField(
                                        controller: _pass,
                                        focusNode: _passwordFocus,
                                        fieldLabel: _login
                                            ? 'ادخل كلمة المرور'
                                            : 'اكتب كلمة المرور',
                                        hidden: _hide,
                                        onToggle: () =>
                                            setState(() => _hide = !_hide),
                                        autofillHints: _login
                                            ? const [AutofillHints.password]
                                            : const [AutofillHints.newPassword],
                                        textInputAction: _login
                                            ? TextInputAction.done
                                            : TextInputAction.next,
                                        onSubmitted: (_) => _login
                                            ? _submit()
                                            : _continueToConfirmation())),
                                if (passwordProblem != null) ...[
                                  const SizedBox(height: 8),
                                  Text(passwordProblem,
                                      style: const TextStyle(
                                          color: Color(0xFFB23A32),
                                          fontSize: 13,
                                          height: 1.4)),
                                ],
                                if (!_login && _showConfirmation) ...[
                                  SizedBox(height: gap),
                                  group(
                                      'تأكيد كلمة المرور',
                                      _authPasswordField(
                                          controller: _pass2,
                                          focusNode: _confirmationFocus,
                                          fieldLabel: 'تأكيد كلمة المرور',
                                          hidden: _hide2,
                                          onToggle: () =>
                                              setState(() => _hide2 = !_hide2),
                                          autofillHints: const [
                                            AutofillHints.newPassword
                                          ],
                                          onSubmitted: (_) => _submit())),
                                ],
                                if (_login) ...[
                                  SizedBox(height: gap),
                                  _rememberAndForgot()
                                ],
                                if (_error != null) ...[
                                  const SizedBox(height: 8),
                                  _inlineErrorBanner()
                                ],
                                SizedBox(height: gap + 4),
                                SizedBox(height: 52, child: _primaryButton()),
                                SizedBox(height: gap),
                                _orDivider(),
                                SizedBox(height: gap),
                                SizedBox(height: 50, child: _googleButton()),
                                SizedBox(height: gap),
                                Expanded(
                                    child: SizedBox(height: _login ? 8 : 6)),
                                SizedBox(height: gap),
                                _switchFooter(),
                              ]),
                        )),
                      ),
                    ],
                  ))),
        ));
  }

  Widget _rememberAndForgot() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
            child: InkWell(
                onTap: _busy ? null : _forgotPassword,
                child: const Text('نسيت كلمة المرور؟',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: _forest,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 24 / 12.5)))),
        const SizedBox(width: 8),
        Semantics(
            checked: _rememberMe,
            label: 'تذكرني',
            child: InkWell(
              onTap: _busy
                  ? null
                  : () => setState(() => _rememberMe = !_rememberMe),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('تذكرني',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: _fieldText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        height: 24 / 12.5)),
                const SizedBox(width: 6),
                SizedBox(
                    width: 16,
                    height: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _rememberMe = v ?? true),
                      activeColor: _forest,
                      checkColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF777777)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    )),
              ]),
            )),
      ]);

  Widget _inlineErrorBanner() => Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF2EF),
            borderRadius: BorderRadius.circular(14)),
        child: Text(_error!,
            style: const TextStyle(color: Color(0xFF8F3028), fontSize: 13)),
      ));

  Widget _authField(
      {required TextEditingController controller,
      FocusNode? focusNode,
      required String fieldLabel,
      required String icon,
      bool obscure = false,
      Widget? suffix,
      TextInputType? keyboardType,
      List<String>? autofillHints,
      TextInputAction? textInputAction,
      List<TextInputFormatter>? formatters,
      ValueChanged<String>? onSubmitted}) {
    final height = _login ? 54.0 : 52.0;
    return Semantics(
        label: fieldLabel,
        child: TextField(
          key: _focusTargets[focusNode],
          controller: controller,
          focusNode: focusNode,
          scrollPadding: const EdgeInsets.all(12),
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          inputFormatters: formatters,
          onSubmitted: onSubmitted,
          textAlign: TextAlign.right,
          textDirection: keyboardType == TextInputType.emailAddress
              ? TextDirection.ltr
              : TextDirection.rtl,
          textAlignVertical: TextAlignVertical.center,
          cursorColor: _forest,
          style: const TextStyle(
              fontFamily: 'Cairo',
              color: _fieldText,
              fontSize: 14,
              height: 1.5),
          decoration: InputDecoration(
            constraints: BoxConstraints(minHeight: height),
            prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                child: SvgPicture.asset('assets/auth/$icon.svg',
                    width: _login ? 19 : 18, height: _login ? 19 : 18)),
            prefixIconConstraints: BoxConstraints(
                minWidth: 40, minHeight: height, maxHeight: height),
            suffixIcon: suffix,
            suffixIconConstraints: BoxConstraints(
                minWidth: 44, minHeight: height, maxHeight: height),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
                horizontal: 14, vertical: (height - 23) / 2),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _fieldBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _forest, width: 1.5)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _fieldBorder)),
          ),
        ));
  }

  Widget _authPasswordField(
          {required TextEditingController controller,
          FocusNode? focusNode,
          required String fieldLabel,
          required bool hidden,
          required VoidCallback onToggle,
          List<String>? autofillHints,
          TextInputAction? textInputAction,
          ValueChanged<String>? onSubmitted}) =>
      _authField(
        controller: controller,
        focusNode: focusNode,
        fieldLabel: fieldLabel,
        icon: 'lock',
        obscure: hidden,
        autofillHints: autofillHints,
        textInputAction: textInputAction ?? TextInputAction.done,
        onSubmitted: onSubmitted,
        suffix: IconButton(
            tooltip: hidden ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
            onPressed: onToggle,
            icon: SvgPicture.asset(
                'assets/auth/${hidden ? 'eye_off' : 'eye'}.svg',
                width: 19,
                height: 19)),
      );

  Widget _phoneField() => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _fieldBorder)),
        child: IntrinsicHeight(
            child: Row(textDirection: TextDirection.rtl, children: [
          Semantics(
              button: true,
              label: 'اختيار كود الدولة',
              child: InkWell(
                onTap: _busy ? null : _pickCountry,
                child: SizedBox(
                    width: 113,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset('assets/auth/phone.svg',
                              width: 16, height: 16),
                          const SizedBox(width: 6),
                          Flexible(
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('+${_country.dial}',
                                      style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          color: _fieldText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)))),
                          const SizedBox(width: 6),
                          _country.iso == 'EG'
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: SvgPicture.asset(
                                      'assets/auth/egypt.svg',
                                      width: 20,
                                      height: 14))
                              : Text(_country.flag,
                                  style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          SvgPicture.asset('assets/auth/chevron.svg',
                              width: 12, height: 12),
                        ])),
              )),
          const VerticalDivider(width: 1, thickness: 1, color: _fieldBorder),
          Expanded(
              child: Semantics(
                  label: 'رقم الهاتف',
                  child: TextField(
                    key: _phoneKey,
                    controller: _phone,
                    focusNode: _phoneFocus,
                    scrollPadding: const EdgeInsets.all(12),
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    textAlignVertical: TextAlignVertical.center,
                    cursorColor: _forest,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: _fieldText,
                        fontSize: 14,
                        height: 1.5),
                    decoration: const InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14.5),
                        constraints: BoxConstraints(minHeight: 50),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none),
                  ))),
        ])),
      );

  Widget _primaryButton() => Semantics(
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient:
                const LinearGradient(colors: [_forest, Color(0xFF3E8F63)]),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x471F4E3D),
                  blurRadius: 18,
                  offset: Offset(0, 8))
            ]),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: _busy ? null : _submit,
              child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.3, color: Colors.white))
                      : Text(_login ? 'تسجيل الدخول' : 'إنشاء حساب',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800))),
            )),
      ));

  Widget _orDivider() => const Row(children: [
        Expanded(
            child: Divider(color: Color(0xFFE7ECE9), thickness: 1, height: 24)),
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('أو',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: _hintColor,
                    fontSize: 12,
                    height: 2))),
        Expanded(
            child: Divider(color: Color(0xFFE7ECE9), thickness: 1, height: 24)),
      ]);

  Widget _googleButton() => Semantics(
      button: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(color: _fieldBorder)),
        child: InkWell(
          onTap: _busy ? null : _google,
          borderRadius: BorderRadius.circular(26),
          child: Center(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      SvgPicture.asset('assets/auth/google.svg',
                          width: 18, height: 18),
                      const SizedBox(width: 10),
                      const Text('المتابعة باستخدام Google',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              color: _fieldText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ))),
        ),
      ));

  Widget _switchFooter() => Semantics(
      button: true,
      label: _login ? 'إنشاء حساب' : 'تسجيل الدخول',
      child: InkWell(
        onTap: _busy ? null : () => _switchMode(!_login),
        borderRadius: BorderRadius.circular(12),
        child: Center(
            child: Wrap(alignment: WrapAlignment.center, children: [
          Text(_login ? 'ليس لديك حساب؟ ' : 'لديك حساب بالفعل؟ ',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF5B6961),
                  fontSize: 13,
                  height: 24 / 13)),
          Text(_login ? 'إنشاء حساب' : 'تسجيل الدخول',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: _forest,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 24 / 13)),
        ])),
      ));
}
