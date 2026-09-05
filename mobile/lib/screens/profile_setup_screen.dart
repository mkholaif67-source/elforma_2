// ── ElForma · screens/profile_setup_screen.dart ──
// Conversational onboarding: a real chat thread with the "ElForma coach" that collects
// the profile answers. The SAVE payload is identical to the old form (same keys/engine contract);
// only the presentation changed. Stages + skip logic live in _stages / _after().
// أونبوردنج محادثي بنبرة مدرب — عقد الحفظ نفسه بالضبط، الشكل فقط اختلف.

import 'package:flutter/material.dart';
import '../api.dart';
import '../models/profile_store.dart';
import '../theme.dart';
import '../widgets/gender_avatar.dart';
import 'analysis_screen.dart';

/// A single line in the onboarding conversation.
class _Msg {
  final bool coach; // true = coach bubble, false = the user's own answer
  final String text;
  const _Msg(this.coach, this.text);
}

/// Fix 10-ج → item #4: the onboarding is no longer a 4-step form dressed up
/// with a persona. It is a REAL conversation: the coach asks ONE thing at a
/// time, the user replies with a quick-reply chip / types a single number like
/// sending a chat message / a multi-pick, their answer appears as a bubble, and
/// the coach acknowledges before asking the next thing.
///
/// Nothing about WHAT we collect changed: every field still maps to the exact
/// same saveMobileProfile payload that feeds BOTH engines (workout + diet).
class ProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const ProfileSetupScreen({super.key, this.initial});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // ── conversation state ─────────────────────────────────────
  // Every question is standalone (one input per screen), and age/height/weight
  // are three separate steps — not one crowded row.
  // المخاطبة الأول بعدين الاسم: كده المدرب يقدر ينادي على المتدرب باسمه
  // وبالصيغة الصح من ثاني سؤال، بدل ما يسأل «إنت ذكر ولا أنثى؟» برود.
  static const List<String> _stages = [
    'intro', 'gender', 'name', 'age', 'height', 'weight', 'target', 'goal', 'rate', 'activity',
    'sleep', 'stress', 'steps', 'cardioGate', 'cardio', 'cardioInt', 'waist', 'neck', 'hips',
    // [TRAINS-GATE] سؤال «بتتمرن؟» أولا، وهو اللي بيفتح/يقفل كل أسئلة التمرين
    // (بدل خيار الـ 0 القديم في عدد الأيام وعبارة «مش بتمرن» في الجيم/البيت).
    'trains', 'days', 'equip', 'exp', 'preferredDays', 'minutes', 'injuriesGate', 'injuries', 'weakGate',
    // الوحدات المساعدة اتشالت من أسئلة التسجيل وبقت قسم مستقل في حسابي.
    'weak', 'diet', 'meals', 'healthGate', 'health', 'review',
  ];
  final List<_Msg> _thread = [];
  final List<int> _visited = []; // answered stage indices (for one-step back)
  final ScrollController _scroll = ScrollController();
  int _stage = 0;
  bool saving = false;
  String? error;
  // Yes/no gates decide whether we even show the injury / weak-point / health
  // option lists — a human coach asks "any injuries?" before listing joints.
  bool hasInjuries = false;
  bool hasWeak = false;
  bool hasHealth = false;
  // Edit mode: reopened on a complete profile → jump to a pre-filled review and
  // let the user edit single fields; _editReturn routes the next answer back to
  // the review instead of walking the flow forward.
  bool _editReturn = false;
  bool _fromScratch = false;

  // ── answers (identical set + payload as before) ──────────────────
  /// اسم المتدرب زي ما يحب يتنادى بيه — بنستخدمه جوا الأسئلة نفسها.
  late final TextEditingController displayName;
  late final TextEditingController age;
  late final TextEditingController height;
  late final TextEditingController weight;
  late final TextEditingController targetWeight;
  late final TextEditingController steps;
  late final TextEditingController waist;
  late final TextEditingController neck;
  late final TextEditingController hips;
  // Must be one of the offered chips (2-5) so the answer is always valid.
  int cardioSessions = 3;
  // Target kg per week. Feeds `inp-weekly-rate` in the website engine, where
  // the daily deficit/surplus is rate * 7700 / 7. 0.5 is the safe default the
  // engine itself falls back to.
  double weeklyRate = 0.5;
  String cardioIntensity = 'moderate';
  bool doesCardio = true;
  String gender = 'male';
  // [OWNER-RULE] مؤشر كتابة المدرب: يظهر لحظة قبل رد المدرب
  // عشان المحادثة تحس حية وكأنه بيرد فعليا.
  bool _coachThinking = false;
  String goal = 'lose';
  String dailyActivity = 'moderate';
  String sleep = 'ok';
  String stress = 'low';
  String experience = 'beginner';
  String equipment = 'gym';
  int trainingDays = 4;
  // [TRAINS-GATE] حالة التمرين الفعلية: بتتحول لـ trainingDays=0 وهي المصدر
  // الوحيد اللي السيرفر والمحركات بتقرأ منه (مفيش duplicate logic).
  bool trains = true;
  // الأيام المفضلة للتمرين (السبت=0 .. الجمعة=6).
  final Set<int> preferredDays = {};
  int trainingMinutes = 60;
  String diet = 'balanced';
  int mealCount = 4;
  String fastingMode = 'normal';
  final Set<String> injuries = {};
  // Helper units. Seeded from the goal the first time the question is shown,
  // then owned by the user.
  final Set<String> activeModules = {};
  bool modulesSeeded = false;
  final Set<String> weakPoints = {};
  final Set<String> healthConditions = {};

  // [OWNER-RULE] Hint lines under the answers were removed on purpose:
  // the questions stay one-word choices with no explanation text.

  // ── label dictionaries (keys stay engine-aligned, labels are Arabic) ─
  // صيغة المخاطبة بدل «ذكر/أنثى» الجافة. السيستم بيفهم النوع منها لوحده
  // وبيبعته للمحرك زي ما هو — المستخدم مايحسش إنه بيملا استمارة.
  static const Map<String, String> _genderLabels = {
    'male': 'بصيغة المذكر',
    'female': 'بصيغة المؤنث',
  };

  /// الاسم الأول بس — مناسب للنداء جوا السؤال.
  String get _firstName {
    final raw = displayName.text.trim();
    if (raw.isEmpty) return '';
    return raw.split(RegExp(r'\s+')).first;
  }
  // الترتيب مقصود خسارة دهون الأول لأنه أكتر هدف مطلوب والثبات في الأخر
  static const Map<String, String> _goalLabels = {'lose': 'خسارة دهون', 'gain': 'بناء عضلات', 'strength': 'قوة', 'fitness': 'لياقة', 'maintain': 'ثبات'};
  static const Map<String, String> _activityLabels = {'sedentary': 'محدودة', 'light': 'خفيفة', 'moderate': 'متوسطة', 'active': 'عالية'};
  // إجابة كلمة واحدة من غير أي وصف تحتيها.
  static const Map<String, String> _sleepLabels = {
    'poor': 'متقطع',
    'ok': 'جيد',
    'good': 'مثالي'
  };
  static const Map<String, String> _stressLabels = {'low': 'قليل', 'mid': 'متوسط', 'high': 'عال'};
  static const Map<String, String> _intLabels = {'light': 'خفيف', 'moderate': 'متوسط', 'vigorous': 'عالي'};
  static const Map<String, String> _expLabels = {'beginner': 'مبتدئ', 'intermediate': 'متوسط', 'advanced': 'متقدم'};
  // [TRAINS-GATE] خيار «مش بتمرن» اتشال من هنا لأن له سؤال مستقل دلوقتي.
  static const Map<String, String> _equipLabels = {'gym': 'الجيم', 'home': 'البيت'};
  static const Map<String, String> _dietLabels = {
    'balanced': 'متوازن',
    'lowcarb': 'قليل الكارب',
    'carbcycle': 'تدوير الكارب',
    'mediterranean': 'البحر المتوسط',
    'carnivore': 'كارنيفور دايت',
    'keto': 'كيتو دايت'
  };
  static const Map<String, String> _fastingLabels = {'normal': 'أكل عادي على مدار اليوم', 'ramadan': 'صيام رمضان (إفطار/سحور)', 'if16': 'صيام متقطع 16:8'};
  static const Map<String, String> _injLabels = {'shoulder': 'كتف', 'back': 'ظهر', 'knee': 'ركبة', 'elbow': 'كوع', 'wrist': 'رسغ', 'neck': 'رقبة'};
  // The eight helper units the website engine can weave into a plan.
  static const Map<String, String> _moduleLabels = {
    'warmup': 'الإحماء',
    'cardio': 'الكارديو',
    'core': 'الكور',
    'stretch': 'الإطالة',
    'yoga': 'اليوجا',
    'breath': 'التنفس',
    'recovery': 'التعافي',
    'kegel': 'الكيجل',
  };
  static const Map<String, String> _weakLabels = {'chest': 'صدر', 'back': 'ظهر', 'shoulders': 'أكتاف', 'arms': 'ذراع', 'quads': 'رجل أمامية', 'hamstrings': 'رجل خلفية', 'glutes': 'جلوتس', 'calves': 'سمانة', 'core': 'بطن/كور'};
  static const Map<String, String> _healthLabels = {'diabetes': 'سكري', 'insulin': 'مقاومة إنسولين', 'bp': 'ضغط', 'cholesterol': 'كوليسترول', 'kidney': 'كلى', 'gerd': 'ارتجاع', 'gout': 'نقرس', 'ibs': 'قولون عصبي'};

  // Fields exposed for targeted editing when reopening a complete profile.
  static const Map<String, String> _editTargets = {
    'gender': 'الجنس',
    'age': 'السن',
    'height': 'الطول',
    'weight': 'الوزن',
    'target': 'الوزن المستهدف',
    'goal': 'الهدف',
    'rate': 'معدل التغيير الأسبوعي',
    'activity': 'النشاط',
    'sleep': 'النوم',
    'stress': 'التوتر',
    'steps': 'الخطوات',
    'cardio': 'الكارديو',
    'waist': 'قياس الخصر',
    'neck': 'قياس الرقبة',
    'exp': 'الخبرة',
    'equip': 'مكان التمرين',
    'days': 'أيام التمرين',
    'minutes': 'مدة الجلسة',
    'injuriesGate': 'الإصابات',
    'weakGate': 'نقاط التركيز',
    'diet': 'نظام الأكل',
    'meals': 'عدد الوجبات',
    'healthGate': 'الحالة الصحية',
  };

  bool get _editMode => initial['onboardingComplete'] == true;

  Map<String, dynamic> get initial => widget.initial ?? const {};

  @override
  void initState() {
    super.initState();
    displayName = TextEditingController(text: _text(initial['name']));
    age = TextEditingController(text: _text(initial['age']));
    height = TextEditingController(text: _text(initial['height']));
    weight = TextEditingController(text: _text(initial['weight']));
    targetWeight = TextEditingController(text: _text(initial['targetWeight']));
    steps = TextEditingController(text: _text(initial['steps']));
    waist = TextEditingController(text: _text(initial['waist']));
    neck = TextEditingController(text: _text(initial['neck']));
    hips = TextEditingController(text: _text(initial['hips']));
    cardioSessions = _integer('cardioSessions', cardioSessions);
    if (initial['activeModules'] is List) {
      activeModules
        ..clear()
        ..addAll((initial['activeModules'] as List).map((e) => e.toString()));
      modulesSeeded = true;
    }
    if (initial['weeklyRate'] is num) {
      weeklyRate = (initial['weeklyRate'] as num).toDouble();
    }
    cardioIntensity = _string('cardioIntensity', cardioIntensity);
    gender = _string('gender', gender);
    goal = _string('goal', goal);
    dailyActivity = _string('dailyActivity', dailyActivity);
    sleep = _string('sleep', sleep);
    stress = _string('stress', stress);
    experience = _string('experience', experience);
    equipment = _string('equipment', equipment);
    trainingDays = _integer('trainingDays', trainingDays);
    // [TRAINS-GATE] لو البروفايل فيه trains نقرأه، وإلا نستنتجه من عدد الأيام.
    trains = initial['trains'] is bool
        ? initial['trains'] as bool
        : trainingDays > 0;
    if (!trains) trainingDays = 0;
    trainingMinutes = _integer('trainingMinutes', trainingMinutes);
    diet = _string('diet', diet);
    mealCount = _integer('mealCount', mealCount);
    fastingMode = _string('fastingMode', fastingMode);
    injuries.addAll(_strings(initial['injuries']));
    weakPoints.addAll(_strings(initial['weakPoints']));
    healthConditions.addAll(_strings(initial['healthConditions']));
    hasInjuries = injuries.isNotEmpty;
    hasWeak = weakPoints.isNotEmpty;
    hasHealth = healthConditions.isNotEmpty;
    if (_editMode) {
      // Reopened on a saved profile → show a pre-filled review, ready to edit
      // any single field, instead of replaying the whole conversation.
      _visited.addAll(List<int>.generate(_idx('review'), (i) => i));
      _stage = _idx('review');
      _thread.add(const _Msg(true,
          'أهلا بيك تاني. دي بياناتك المحفوظة. تقدر تعدل أي حاجة على طول من غير ما تبدأ من الأول أو تعمل إعداد جديد بالكامل لو حابب'));
      _thread.add(_Msg(true, _summary()));
    } else {
      // A chic opening — warm, clear, and promises value in under two minutes.
      _thread.add(const _Msg(true,
          'أهلا بيك في تيم الفورمة\nقبل ما أجهزلك نظامك الغذائي وخطة تمرينك، هسألك شوية أسئلة بسيطة عشان أصمملك خطة مناسبة ليك ولأهدافك بالظبط. الموضوع مش هياخد أكتر من دقيقتين. جاهز نبدأ؟'));
    }
  }

  String _text(dynamic value) => value == null ? '' : '$value'.replaceFirst(RegExp(r'\.0$'), '');
  String _string(String key, String fallback) => initial[key] is String ? initial[key] as String : fallback;
  int _integer(String key, int fallback) => initial[key] is num ? (initial[key] as num).toInt() : fallback;
  Iterable<String> _strings(dynamic value) => value is List ? value.whereType<String>() : const [];

  @override
  void dispose() {
    age.dispose();
    height.dispose();
    weight.dispose();
    targetWeight.dispose();
    steps.dispose();
    waist.dispose();
    neck.dispose();
    hips.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int _idx(String s) => _stages.indexOf(s);
  String _stageName(int s) => _stages[s];

  bool _validateBasics() {
    final a = int.tryParse(age.text.trim());
    final h = double.tryParse(height.text.trim());
    final w = double.tryParse(weight.text.trim());
    // السن مفتوح من 7 ل 80 سنة. الأمان بييجي من قواعد التدريب والتغذية
    // حسب الشريحة (طفل / مراهق / بالغ / كبير سن) مش من منع التسجيل.
    if (a == null || a < 7 || a > 80 || h == null || h < 100 || h > 250 || w == null || w < 30 || w > 350) {
      return false;
    }
    return true;
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // Compute the next stage, skipping questions that don't apply.
  int _after(int s) {
    var n = s + 1;
    while (n < _stages.length) {
      final name = _stageName(n);
      // The rate question only makes sense when there is a direction to move
      // in. Maintenance, strength and fitness goals have no deficit/surplus.
      if (name == 'rate' && goal != 'lose' && goal != 'gain') { n++; continue; }
      // [TRAINS-GATE] اللي بيقول «لأ مش بتمرن» مايتسألش على أي سؤال تمرين.
      if ((name == 'days' || name == 'equip' || name == 'exp' ||
              name == 'preferredDays' || name == 'minutes') &&
          !trains) { n++; continue; }
      if ((name == 'cardio' || name == 'cardioInt') && !doesCardio) { n++; continue; }
      if (name == 'cardioInt' && cardioSessions == 0) { n++; continue; }
      if (name == 'hips' && gender != 'female') { n++; continue; }
      if (name == 'injuries' && !hasInjuries) { n++; continue; }
      if (name == 'weak' && !hasWeak) { n++; continue; }
      if (name == 'health' && !hasHealth) { n++; continue; }
      break;
    }
    return n.clamp(0, _stages.length - 1);
  }

  /// Show a gentle inline hint (e.g. an out-of-range number) without advancing.
  void _hint(String msg) {
    setState(() => _thread.add(_Msg(true, msg)));
    _scrollToEnd();
  }

  /// [OWNER-RULE] رد المدرب مع مؤشر كتابة قصير قبل ما الرسالة تظهر،
  /// عشان المحادثة تحس حية وكأن المدرب بيرد فعليا.
  Future<void> _coachSay(String text, {int delayMs = 550}) async {
    if (!mounted) return;
    setState(() => _coachThinking = true);
    _scrollToEnd();
    await Future.delayed(Duration(milliseconds: delayMs));
    if (!mounted) return;
    setState(() {
      _coachThinking = false;
      _thread.add(_Msg(true, text));
    });
    _scrollToEnd();
  }

  /// Record the user's answer bubble, then move the coach to the next question.
  void _commit(String userLabel) {
    setState(() {
      _thread.add(_Msg(false, userLabel));
      error = null;
    });
    _scrollToEnd();
    if (_editReturn) {
      // Came from a single-field edit. Gates that turned "yes" still need
      // their detail question; everything else routes back to review.
      final answered = _stageName(_stage);
      if (answered == 'injuriesGate' && hasInjuries) {
        _stage = _idx('injuries');
        _coachSay(_prompt(_stage));
      } else if (answered == 'weakGate' && hasWeak) {
        _stage = _idx('weak');
        _coachSay(_prompt(_stage));
      } else if (answered == 'healthGate' && hasHealth) {
        _stage = _idx('health');
        _coachSay(_prompt(_stage));
      } else {
        _editReturn = false;
        _stage = _idx('review');
        _coachSay('تمام حدثت البيانات دي. كده تبقى:');
        _coachSay(_summary(), delayMs: 1100);
      }
    } else {
      _visited.add(_stage);
      _stage = _after(_stage);
      // Last question answered: no closing summary speech at all. Go straight
      // to the analysis preparation screen, then the analysis itself.
      if (_stageName(_stage) == 'review') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _save();
        });
      } else {
        _coachSay(_prompt(_stage));
      }
    }
  }

  /// Jump to a single question for targeted editing (edit mode only).
  void _editField(String stageKey) {
    setState(() {
      _editReturn = true;
      _stage = _idx(stageKey);
      _thread.add(_Msg(true, _prompt(_stage)));
    });
    _scrollToEnd();
  }

  /// Discard the review and walk the full conversation again from scratch.
  void _restartFromScratch() {
    setState(() {
      _fromScratch = true;
      _editReturn = false;
      _visited.clear();
      _thread.clear();
      _stage = 0;
      _thread.add(const _Msg(true,
          'تمام هنعيد الإعداد من الأول. كل إجابة هتبني خطتك من جديد. نبدأ؟'));
    });
    _scrollToEnd();
  }

  void _start() {
    _visited.add(0);
    _stage = 1;
    _coachSay(_prompt(1));
  }

  void _back() {
    if (_visited.isEmpty) return;
    setState(() {
      if (_thread.isNotEmpty && _thread.last.coach) _thread.removeLast(); // pending question
      if (_thread.isNotEmpty && !_thread.last.coach) _thread.removeLast(); // last answer
      _stage = _visited.removeLast();
      error = null;
    });
    _scrollToEnd();
  }

  String _prompt(int s) {
    switch (_stageName(s)) {
      case 'gender':
        return 'قبل ما نبدأ تحب أخاطبك إزاي؟';
      case 'name':
        return 'حضرتك اسمك ايه؟';
      case 'age':
        return 'كم عمرك؟';
      case 'height':
        return 'طولك اقد ايه بالسنتي؟';
      case 'weight':
        return 'وزنك الحالي بالكيلو؟';
      case 'target':
        return 'هدفك توصل لوزن كام؟';
      case 'goal':
        // أول نداء بالاسم: في أهم سؤال في المحادثة كلها.
        return _firstName.isEmpty
            ? 'إيه هدفك الأساسي؟'
            : 'طيب يا $_firstName إيه هدفك الأساسي؟';
      case 'rate':
        // The wording flips with the goal: nobody should be asked how fast
        // they want to lose weight while they are bulking.
        return goal == 'gain'
            ? 'طموحك تزيد كام في الأسبوع؟'
            : 'طموحك تخس كام في الأسبوع؟';
      case 'activity':
        return 'حركتك في اليوم إزاي؟';
      case 'sleep':
        // ثاني نداء بالاسم — متوسط مش مكرر في كل سؤال عشان مايبقاش مفتعل.
        return _firstName.isEmpty
            ? 'نومك عامل إزاي؟'
            : 'نومك عامل إزاي يا $_firstName؟';
      case 'stress':
        return 'مستوى التوتر عندك إيه؟';
      case 'steps':
        return 'بتمشي كام خطوة في اليوم؟';
      case 'cardioGate':
        return 'بتلعب كارديو؟';
      case 'cardio':
        return 'كام مرة في الأسبوع؟';
      case 'cardioInt':
        return 'شدة الكارديو إيه؟';
      case 'waist':
        return 'قياس خصرك كام بالسم؟ (اختياري)';
      case 'neck':
        return 'وقياس رقبتك بالسم؟ (اختياري)';
      case 'hips':
        return 'وقياس الأرداف بالسم؟ (اختياري)';
      case 'exp':
        return 'خبرتك في التمرين إيه؟';
      case 'equip':
        return 'بتتمرن فين؟';
      case 'trains':
        return 'بتتمرن حاليا؟';
      case 'days':
        return 'كام يوم تمرين في الأسبوع؟';
      case 'preferredDays':
        return 'بتفضل تتمرن أيام إيه؟ اختار $trainingDays أيام تحب تتمرن فيهم وهنوزع جدولك عليهم';
      case 'minutes':
        return 'الجلسة الواحدة كام دقيقة؟';
      case 'injuriesGate':
        return 'عندك إصابة أو ألم؟';
      case 'injuries':
        return 'مكان الإصابة؟';
      case 'weakGate':
        return 'حاسس إن في عضلات محتاجة تركيز أكتر؟';
      case 'weak':
        return 'عضلات ايه تحديدا؟';
      case 'modules':
        return 'تحب نضيف وحدات مساعدة لبرنامجك؟ دي إضافات بتتحط جوة جدولك نفسه مش جلسات زيادة';
      case 'diet':
        return 'بتفضل الدايت ايه؟';
      case 'meals':
        return 'كام وجبة في اليوم؟';
      case 'healthGate':
        return 'في مشكلة صحية لازم نراعيها؟';
      case 'health':
        return 'إيه الحالة بالظبط؟';
      case 'review':
        return _summary();
      default:
        return '';
    }
  }

  /// A world-class, convincing coach analysis at the end of onboarding: reads
  /// the trainee's own numbers back to them (BMI, goal realism, capacity,
  /// recovery, nutrition) and closes with motivation. Reused as the edit-mode
  /// review summary.
  String _summary() {
    final w = double.tryParse(weight.text.trim());
    final h = double.tryParse(height.text.trim());
    final tw = double.tryParse(targetWeight.text.trim());
    final b = StringBuffer();
    b.writeln('تمام يا بطل خلصنا التعارف وبقى عندي صورة واضحة عنك:');
    b.writeln('');
    if (w != null && h != null && h > 0) {
      final bmi = w / ((h / 100) * (h / 100));
      String cat;
      if (bmi < 18.5) {
        cat = 'وزنك تحت الطبيعي شوية فهنبني كتلة صحية';
      } else if (bmi < 25) {
        cat = 'وزنك في النطاق الصحي وده أساس ممتاز';
      } else if (bmi < 30) {
        cat = 'فيه زيادة بسيطة نقدر نتحكم فيها بسهولة';
      } else {
        cat = 'فيه وزن زائد هنشتغل عليه بذكاء وبالتدريج';
      }
      b.writeln('• مؤشر كتلة جسمك ≈ ${bmi.toStringAsFixed(1)} $cat');
      if (tw != null && w > 0 && (w - tw).abs() >= 1) {
        final diff = (w - tw).abs().toStringAsFixed(0);
        final dir = tw < w ? 'تنزل' : 'تزود';
        b.writeln('• هدفك إنك $dir حوالي $diff كجم هدف واقعي هنوصله بمعدل آمن ونثبته');
      }
    }
    b.writeln('• هدفك «${_goalLabels[goal]}» مع نشاط يومي ${_activityLabels[dailyActivity]} على الأساس ده هظبط سعراتك وتوزيع الماكروز بالظبط');
    if (trainingDays == 0) {
      b.writeln('• إنت مش بتتمرن حاليا فالتركيز معاك على التغذية والحركة اليومية — ولما تحب تبدأ تمرين الجدول جاهز في أي وقت');
    } else {
      b.writeln('• بتقدر تلتزم ب $trainingDays أيام × $trainingMinutes دقيقة في ${_equipLabels[equipment]} وإنت ${_expLabels[experience]} كفاية أبني منها برنامج متدرج يكبر معاك');
    }
    b.writeln('• نومك ${_sleepLabels[sleep]} وتوترك ${_stressLabels[stress]} دول بيحكموا استشفاءك فهراعيهم في حجم وشدة التمرين');
    if (injuries.isNotEmpty) {
      b.writeln('• هختار تمارينك بحيث تحمي: ${injuries.map((k) => _injLabels[k] ?? k).join('، ')}.');
    }
    if (weakPoints.isNotEmpty) {
      b.writeln('• هزود شغل مركز على: ${weakPoints.map((k) => _weakLabels[k] ?? k).join('، ')}.');
    }
    final safe = healthConditions.isNotEmpty
        ? 'وآمن تماما مع ${healthConditions.map((k) => _healthLabels[k] ?? k).join('، ')}'
        : '';
    b.writeln('• أكلك هيكون «${_dietLabels[diet]}» مقسم على $mealCount وجبات بأصناف مصرية متاحة$safe');
    if (fastingMode != 'normal') b.writeln('• هظبط مواعيد وجباتك على «${_fastingLabels[fastingMode]}» بنفس السعرات والماكروز');
    b.writeln('');
    b.writeln('جاهز أبني لك خطة التمرين والتغذية على المقاس؟');
    return b.toString().trimRight();
  }

  // ── save (payload identical to the previous version) ──────────────
  Future<void> _save() async {
    // مادام السؤال اتشال، نبدأ بمجموعة افتراضية ذكية بدل ما يبقى فاضي.
    _seedModules();
    if (!_validateBasics()) {
      setState(() {
        _stage = _idx('age');
        _thread.add(const _Msg(true, 'محتاج أراجع سنك وطولك ووزنك الأول. اكتبهم صح ونكمل'));
      });
      _scrollToEnd();
      return;
    }
    final profile = <String, dynamic>{
      if (displayName.text.trim().isNotEmpty) 'name': displayName.text.trim(),
      'gender': gender,
      'age': int.parse(age.text.trim()),
      'height': double.parse(height.text.trim()),
      'weight': double.parse(weight.text.trim()),
      if (double.tryParse(targetWeight.text.trim()) != null)
        'targetWeight': double.parse(targetWeight.text.trim()),
      'goal': goal,
      // Drives the daily deficit/surplus in the engine (rate * 7700 / 7).
      // Only meaningful for lose/gain, so it is omitted otherwise rather than
      // sent as a misleading number.
      if (goal == 'lose' || goal == 'gain') 'weeklyRate': weeklyRate,
      'activeModules': activeModules.toList(),
      'dailyActivity': dailyActivity,
      'sleep': sleep,
      'stress': stress,
      'experience': experience,
      'equipment': equipment,
      // [TRAINS-GATE] بنبعت الحالة ومعاها 0 أيام عشان كل الحسابات تفضل متسقة.
      'trains': trains,
      'trainingDays': trains ? trainingDays : 0,
      'preferredDays': (preferredDays.toList()..sort()),
      'trainingMinutes': trainingMinutes,
      // Real engine inputs: steps drive NEAT, cardio drives the activity burn,
      // and waist/neck/hips let us derive body fat instead of guessing it.
      if (double.tryParse(steps.text.trim()) != null) 'steps': double.parse(steps.text.trim()),
      'cardioSessions': cardioSessions,
      'cardioIntensity': cardioIntensity,
      if (double.tryParse(waist.text.trim()) != null) 'waist': double.parse(waist.text.trim()),
      if (double.tryParse(neck.text.trim()) != null) 'neck': double.parse(neck.text.trim()),
      if (double.tryParse(hips.text.trim()) != null) 'hips': double.parse(hips.text.trim()),
      'injuries': injuries.toList(),
      'weakPoints': weakPoints.toList(),
      'diet': diet,
      'mealCount': mealCount,
      'fastingMode': fastingMode,
      'healthConditions': healthConditions.toList(),
      'onboardingComplete': true,
    };
    // Fresh onboarding (or a full redo): hand off to the analysis reveal, which
    // saves instantly on appear, shows the animated dashboard, then auto-starts
    // the journey into the Home shell after 30s. Edit-mode (reopening a complete
    // profile just to tweak a field) keeps the quiet inline save + pop below.
    if (!(_editMode && !_fromScratch)) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => AnalysisScreen(payload: profile),
      ));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final response = await Api.I.saveMobileProfile(profile);
    if (!mounted) return;
    setState(() => saving = false);
    if (response.ok) {
      // Refresh the single source of truth so every other screen flips to
      // results mode instantly instead of running its own bootstrap call.
      await ProfileStore.I.ensureLoaded(force: true);
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      setState(() {
        error = response.error.isNotEmpty ? response.error : 'تعذر حفظ بياناتك';
        _thread.add(_Msg(true, 'حصلت مشكلة وأنا بحفظ: $error جرب تاني'));
      });
      _scrollToEnd();
    }
  }

  // ── build ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final answered = _visited.length;
    final total = _stages.length - 1; // excludes intro
    final progress = (answered / total).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(_editMode && !_fromScratch ? 'مراجعة وتعديل بياناتك' : 'تعارف مع مدربك',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        centerTitle: true,
        actions: [
          if (_visited.isNotEmpty && !saving && !(_editMode && !_fromScratch) && !_editReturn)
            TextButton(
              onPressed: _back,
              child: const Text('تعديل إجابة سابقة'),
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: progress == 0 ? null : progress,
            minHeight: 4,
            color: _stageName(_stage) == 'review' ? AppColors.nu : AppColors.wo,
            backgroundColor: AppColors.line,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              itemCount: _thread.length + (_coachThinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= _thread.length) return _typingBubble();
                return _bubble(_thread[i], i);
              },
            ),
          ),
          _composerBar(),
        ]),
      ),
    );
  }

  Widget _bubble(_Msg m, int seq) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: m.coach ? AppColors.card : AppColors.wo,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(m.coach ? 4 : 16),
          topRight: Radius.circular(m.coach ? 16 : 4),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
      ),
      child: Text(m.text,
          style: TextStyle(
              color: m.coach ? AppColors.text : Colors.white,
              height: 1.6,
              fontSize: 13.5,
              fontWeight: m.coach ? FontWeight.w500 : FontWeight.w700)),
    );
    // [OWNER-RULE] رسائل المتدرب: أفاتاره حسب الجنس عاليمين.
    if (!m.coach) {
      return _entrance(
        seq: seq,
        fromRight: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(child: bubble),
            Container(
              margin: const EdgeInsets.only(top: 2, right: 9),
              child: GenderAvatar(gender: gender, size: 34, ringColor: AppColors.wo),
            ),
          ],
        ),
      );
    }
    // [OWNER-RULE] رسائل المدرب: أفاتار مدرب FORMA (مش لوجو الشركة).
    return _entrance(
      seq: seq,
      fromRight: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2, left: 9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.nu.withValues(alpha: .3), blurRadius: 10)],
            ),
            child: const CoachAvatar(size: 34),
          ),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  /// [OWNER-RULE] ظهور تدريجي ناعم للرسائل (fade + slide) مع ظهور
  /// الأفاتار مع الرسالة بشكل طبيعي وبدون مبالغة.
  Widget _entrance({required Widget child, required bool fromRight, required int seq}) {
    // [OWNER-RULE] المفتاح ثابت لكل رسالة حسب ترتيبها، عشان كل رسالة
    // تتحرك مرة واحدة بس أول ما تظهر. قبل كده المفتاح كان
    // بيتغير مع طول المحادثة فكل الرسائل كانت تعيد الأنيميشن مع كل
    // رسالة جديدة — ده اللي كان بيعمل الفلاشات والحركة المزعجة.
    // وكمان خففنا الحركة (مدة أطول + إزاحة أقل) عشان تبقى ناعمة.
    return TweenAnimationBuilder<double>(
      key: ValueKey('entrance_$seq'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, w) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset((fromRight ? 8 : -8) * (1 - t), 4 * (1 - t)),
          child: w,
        ),
      ),
      child: child,
    );
  }

  /// [OWNER-RULE] مؤشر كتابة بسيط (ثلاث نقط متحركة) بجوار أفاتار المدرب.
  Widget _typingBubble() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2, left: 9),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.nu.withValues(alpha: .3), blurRadius: 10)],
          ),
          child: const CoachAvatar(size: 34),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: const _TypingDots(),
        ),
      ],
    );
  }

  // The composer changes with the current question. Single-choice questions are
  // uniform quick-reply chips (all the SAME shape); numbers are typed like a
  // chat message; steppers/multi have their own inline control.
  Widget _composerBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: _composer(),
    );
  }

  Widget _composer() {
    switch (_stageName(_stage)) {
      case 'intro':
        return _primaryButton('يلا نبدأ', _start, color: AppColors.wo, fg: Colors.white);
      case 'gender':
        return _quickReplies(_genderLabels, (k) { setState(() => gender = k); _commit(_genderLabels[k]!); });
      case 'name':
        return _chatInput(displayName, 'اكتب اسمك',
            keyboard: TextInputType.name, onSend: () {
          final v = displayName.text.trim();
          // الاسم لازم يكون حروف فعلا. قبل كده كان أي رقم بيعدي وييتخزن كاسم
          final letters = RegExp(r'[A-Za-z\u0621-\u064A]');
          final digits = RegExp(r'[0-9\u0660-\u0669]');
          final lettersOnly = v.replaceAll(RegExp(r'[^A-Za-z\u0621-\u064A]'), '');
          if (v.length < 2 || lettersOnly.length < 2 || !letters.hasMatch(v)) {
            _hint('اكتب اسمك بالحروف مش بالأرقام');
            return;
          }
          if (digits.hasMatch(v)) {
            _hint('الاسم من غير أرقام لو سمحت');
            return;
          }
          _commit(v);
        });
      case 'age':
        return _chatInput(age, 'اكتب سنك', onSend: () {
          final a = int.tryParse(age.text.trim());
          if (a == null || a < 7 || a > 80) { _hint('اكتب سن صحيح بين 7 و 80'); return; }
          _commit('$a سنة');
        });
      case 'height':
        return _chatInput(height, 'طولك بالسنتيمتر', onSend: () {
          final h = double.tryParse(height.text.trim());
          if (h == null || h < 100 || h > 250) { _hint('اكتب طول صحيح بين 100 و 250 سم'); return; }
          _commit('${height.text.trim()} سم');
        });
      case 'weight':
        return _chatInput(weight, 'وزنك بالكيلو', onSend: () {
          final w = double.tryParse(weight.text.trim());
          if (w == null || w < 30 || w > 350) { _hint('اكتب وزن صحيح بين 30 و 350 كجم'); return; }
          _commit('${weight.text.trim()} كجم');
        });
      case 'target':
        return _chatInput(targetWeight, 'وزنك المستهدف',
            optional: true, skipLabel: 'لسه مش محدد',
            onSkip: () => _commit('مش محدد لسه'),
            onSend: () => _commit(targetWeight.text.trim().isEmpty ? 'مش محدد لسه' : '${targetWeight.text.trim()} كجم'));
      case 'goal':
        return _quickReplies(_goalLabels, (k) { setState(() => goal = k); _commit(_goalLabels[k]!); });
      case 'rate':
        return _quickReplies(_rateLabels(), (k) {
          setState(() => weeklyRate = double.parse(k));
          _commit(_rateLabels()[k]!);
        });
      case 'activity':
        return _quickReplies(_activityLabels, (k) { setState(() => dailyActivity = k); _commit(_activityLabels[k]!); });
      case 'sleep':
        return _quickReplies(_sleepLabels, (k) { setState(() => sleep = k); _commit(_sleepLabels[k]!); });
      case 'stress':
        return _quickReplies(_stressLabels, (k) { setState(() => stress = k); _commit(_stressLabels[k]!); });
      case 'steps':
        return _chatInput(steps, 'خطواتك في اليوم',
            optional: true, skipLabel: 'مش متأكد',
            onSkip: () => _commit('هقدرها من حركتي'),
            onSend: () => _commit(steps.text.trim().isEmpty ? 'هقدرها من حركتي' : '${steps.text.trim()} خطوة/يوم'));
      case 'cardioGate':
        return _gateComposer(
          yesLabel: 'نعم',
          noLabel: 'لا',
          onYes: () { setState(() { doesCardio = true; if (cardioSessions <= 0) cardioSessions = 3; }); _commit('نعم'); },
          onNo: () { setState(() { doesCardio = false; cardioSessions = 0; }); _commit('لا'); },
        );
      case 'cardio':
        return _numberComposer(const [2, 3, 4, 5], cardioSessions, (v) {
          setState(() => cardioSessions = v);
          _commit('$v مرة في الأسبوع');
        });
      case 'cardioInt':
        return _quickReplies(_intLabels, (k) { setState(() => cardioIntensity = k); _commit(_intLabels[k]!); });
      case 'waist':
        return _chatInput(waist, 'قياس الخصر بالسم',
            optional: true, skipLabel: 'تخطي',
            onSkip: () => _commit('سيبناها'),
            onSend: () => _commit(waist.text.trim().isEmpty ? 'سيبناها' : 'خصر ${waist.text.trim()} سم'));
      case 'neck':
        return _chatInput(neck, 'قياس الرقبة بالسم',
            optional: true, skipLabel: 'تخطي',
            onSkip: () => _commit('سيبناها'),
            onSend: () => _commit(neck.text.trim().isEmpty ? 'سيبناها' : 'رقبة ${neck.text.trim()} سم'));
      case 'hips':
        return _chatInput(hips, 'قياس الأرداف بالسم',
            optional: true, skipLabel: 'تخطي',
            onSkip: () => _commit('سيبناها'),
            onSend: () => _commit(hips.text.trim().isEmpty ? 'سيبناها' : 'أرداف ${hips.text.trim()} سم'));
      case 'exp':
        return _quickReplies(_expLabels, (k) { setState(() => experience = k); _commit(_expLabels[k]!); });
      case 'equip':
        return _quickReplies(_equipLabels, (k) { setState(() => equipment = k); _commit(_equipLabels[k]!); });
      case 'trains':
        // [TRAINS-GATE] نفس فكرة بقية الـ gates الموجودة، والـ «لأ» بينزل
        // trainingDays = 0 وهي نفس القاعدة اللي السيرفر مترمج عليها أصلا.
        return _gateComposer(
          yesLabel: 'نعم',
          noLabel: 'لا',
          onYes: () {
            setState(() {
              trains = true;
              if (trainingDays <= 0) trainingDays = 4;
              if (equipment == 'none') equipment = 'gym';
            });
            _commit('نعم');
          },
          onNo: () {
            setState(() {
              trains = false;
              trainingDays = 0;
              preferredDays.clear();
              equipment = 'gym';
            });
            _commit('لا');
          },
        );
      case 'days':
        return _numberComposer(const [2, 3, 4, 5, 6], trainingDays, (v) {
          setState(() {
            trainingDays = v;
            preferredDays.clear();
            if (equipment == 'none') equipment = 'gym';
          });
          _commit('$v أيام تمرين/أسبوع');
        });
      case 'preferredDays':
        return _preferredDaysComposer();
      case 'minutes':
        // The workout engine sizes a session by volume, not by clock time, and
        // the nutrition engine only burns kcal per training minute. So the real
        // choices people train with are the only ones offered: 45 / 60 / 90.
        return _numberComposer(const [45, 60, 90], trainingMinutes, (v) {
          setState(() => trainingMinutes = v);
          _commit('$v دقيقة للجلسة');
        });
      case 'injuriesGate':
        return _gateComposer(
          yesLabel: 'نعم',
          noLabel: 'لا',
          onYes: () { setState(() => hasInjuries = true); _commit('نعم'); },
          onNo: () { setState(() { hasInjuries = false; injuries.clear(); }); _commit('لا'); },
        );
      case 'injuries':
        return _multiComposer(injuries, _injLabels, emptyLabel: 'الحمد لله مفيش',
            onSend: () => _commit(injuries.isEmpty ? 'مفيش إصابات' : injuries.map((k) => _injLabels[k] ?? k).join('، ')));
      case 'weakGate':
        return _gateComposer(
          yesLabel: 'نعم',
          noLabel: 'لا',
          onYes: () { setState(() => hasWeak = true); _commit('نعم'); },
          onNo: () { setState(() { hasWeak = false; weakPoints.clear(); }); _commit('لا'); },
        );
      case 'weak':
        return _multiComposer(weakPoints, _weakLabels, emptyLabel: 'مفيش تحديد',
            onSend: () => _commit(weakPoints.isEmpty ? 'مفيش تحديد' : weakPoints.map((k) => _weakLabels[k] ?? k).join('، ')));
      case 'diet':
        return _quickReplies(_dietLabels, (k) { setState(() => diet = k); _commit(_dietLabels[k]!); });
      case 'meals':
        return _numberComposer(const [2, 3, 4, 5], mealCount, (v) {
          setState(() => mealCount = v);
          _commit('$v وجبات/يوم');
        });
      case 'healthGate':
        return _gateComposer(
          yesLabel: 'نعم',
          noLabel: 'لا',
          onYes: () { setState(() => hasHealth = true); _commit('نعم'); },
          onNo: () { setState(() { hasHealth = false; healthConditions.clear(); }); _commit('لا'); },
        );
      case 'health':
        return _multiComposer(healthConditions, _healthLabels, emptyLabel: 'مفيش حالات',
            onSend: () => _commit(healthConditions.isEmpty ? 'مفيش حالات صحية' : healthConditions.map((k) => _healthLabels[k] ?? k).join('، ')));
      case 'modules':
        _seedModules();
        return _multiComposer(activeModules, _moduleLabels, emptyLabel: 'من غير وحدات',
            onSend: () { modulesSeeded = true; _commit(activeModules.isEmpty ? 'من غير وحدات مساعدة' : activeModules.map((k) => _moduleLabels[k] ?? k).join('، ')); });
      case 'review':
        return _reviewComposer();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── composer building blocks ────────────────────────────
  Widget _primaryButton(String label, VoidCallback? onTap, {required Color color, required Color fg, bool busy = false}) => SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: fg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      );

  // A tidy row of numeric options replacing the old +/- stepper: one tap picks
  // the value and sends it, and every number keeps the exact same pill shape.
  // Numbers are answered on tiles, not text buttons: one tap target, one
  // obvious selected state, and a size the thumb can hit without aiming.
  List<List<T>> _balancedRows<T>(List<T> items, {int maxColumns = 4}) {
    if (items.isEmpty) return <List<T>>[];
    final columns = items.length < maxColumns ? items.length : maxColumns;
    final rowCount = (items.length / columns).ceil();
    final base = items.length ~/ rowCount;
    var extra = items.length % rowCount;
    final rows = <List<T>>[];
    var index = 0;
    for (var row = 0; row < rowCount; row++) {
      final take = base + (extra > 0 ? 1 : 0);
      if (extra > 0) extra--;
      rows.add(items.sublist(index, index + take));
      index += take;
    }
    return rows;
  }

  Widget _numberComposer(
    List<int> options,
    int current,
    ValueChanged<int> pick, {
    String? zeroLabel,
  }) => LayoutBuilder(builder: (context, box) {
        final rows = _balancedRows<int>(options,
            maxColumns: box.maxWidth < 320 ? 3 : 4);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: 10),
              Row(children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _numberTile(
                      rows[r][c],
                      rows[r][c] == current,
                      rows[r][c] == 0 && zeroLabel != null
                          ? zeroLabel
                          : '${rows[r][c]}',
                      () => pick(rows[r][c]),
                    ),
                  ),
                ],
              ]),
            ],
          ],
        );
      });

  Widget _numberTile(int value, bool active, String label, VoidCallback onTap) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 58,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      colors: [AppColors.nu, AppColors.nu2],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft)
                  : null,
              color: active ? null : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: active ? AppColors.nu2 : AppColors.line,
                  width: active ? 1.6 : 1),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: active ? const Color(0xFF04231B) : AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 17)),
          ),
        ),
      );

  // أسماء أيام الأسبوع بترتيب مصر (السبت أول الأسبوع = 0).
  static const List<String> _weekdayLabels = [
    'السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة',
  ];

  // مختار الأيام المفضلة للتمرين — اختيار متعدد بعدد أيام
  // التمرين، ولما يكتمل العدد يتأكد ويكمل.
  Widget _preferredDaysComposer() => StatefulBuilder(
        builder: (context, setSheet) {
          void toggle(int d) {
            setState(() {
              if (preferredDays.contains(d)) {
                preferredDays.remove(d);
              } else if (preferredDays.length < trainingDays) {
                preferredDays.add(d);
              }
            });
            setSheet(() {});
            // [OWNER-RULE] بمجرد اكتمال العدد المطلوب ينتقل تلقائيا بدون 'تمام'
            if (preferredDays.length >= trainingDays) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final chosen = preferredDays.toList()..sort();
                _commit(chosen.map((d) => _weekdayLabels[d]).join('، '));
              });
            }
          }

          final full = preferredDays.length >= trainingDays;
          final dayRows = _balancedRows<int>(List.generate(7, (i) => i));
          return Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var r = 0;
                    r < dayRows.length;
                    r++) ...[
                  if (r > 0) const SizedBox(height: 10),
                  Row(children: [
                    for (var c = 0;
                        c < dayRows[r].length;
                        c++) ...[
                      if (c > 0) const SizedBox(width: 10),
                      Expanded(child: Builder(builder: (_) {
                        final d = dayRows[r][c];
                        final active = preferredDays.contains(d);
                        final blocked = !active && full;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: blocked ? null : () => toggle(d),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: active
                                    ? const LinearGradient(
                                        colors: [AppColors.nu, AppColors.nu2],
                                        begin: Alignment.topRight,
                                        end: Alignment.bottomLeft)
                                    : null,
                                color: active ? null : (blocked ? AppColors.bg : AppColors.card),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: active ? AppColors.nu2 : AppColors.line,
                                    width: active ? 1.6 : 1),
                              ),
                              child: Text(_weekdayLabels[d],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: active
                                          ? const Color(0xFF04231B)
                                          : (blocked ? AppColors.muted : AppColors.text),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13)),
                            ),
                          ),
                        );
                      })),
                    ],
                  ]),
                ],
                const SizedBox(height: 12),
                Text(
                  'اخترت ${preferredDays.length} من $trainingDays',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: _choiceChip('سيبها علينا', () {
                          setState(() => preferredDays.clear());
                          _commit('وزع الأيام أوتوماتيك');
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Opacity(
                        opacity: full ? 1 : .4,
                        child: SizedBox(
                          width: double.infinity,
                          child: _choiceChip('تمام', () {
                            if (!full) return;
                            final chosen = preferredDays.toList()..sort();
                            _commit(chosen.map((d) => _weekdayLabels[d]).join('، '));
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );

  Widget _choiceChip(String label, VoidCallback onTap) => ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: AppColors.card,
        labelStyle: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );

  // Yes/No gate: two equal text cards with no decorative icons.
  Widget _gateComposer({required String yesLabel, required String noLabel, required VoidCallback onYes, required VoidCallback onNo}) => Row(
        children: [
          Expanded(child: _gateCard(yesLabel, AppColors.nu, onYes)),
          const SizedBox(width: 10),
          Expanded(child: _gateCard(noLabel, AppColors.muted, onNo)),
        ],
      );

  Widget _gateCard(String label, Color accent, VoidCallback onTap) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Center(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 14.5)),
            ),
          ),
        ),
      );

  // Review composer: a plain save in the normal flow; in edit mode it also
  // offers per-field edit chips and a full re-setup button.
  Widget _reviewComposer() {
    final save = _primaryButton(
      saving ? '...' : (_editMode && !_fromScratch ? 'احفظ التعديلات' : 'احفظ وابدأ رحلتي'),
      saving ? null : _save,
      color: AppColors.nu,
      fg: const Color(0xFF04231B),
      busy: saving,
    );
    if (!(_editMode && !_fromScratch)) return save;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Align(
        alignment: Alignment.centerRight,
        child: Text('تعدل إيه؟ اضغط على أي بند',
            style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 8),
      _optionsSurface(
        _editTargets,
        multi: false,
        isSelected: (_) => false,
        onPick: (key) { if (!saving) _editField(key); },
      ),
      const SizedBox(height: 14),
      save,
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: saving ? null : _restartFromScratch,
        child: const Text('إعادة إدخال البيانات من الأول'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.muted,
          side: const BorderSide(color: AppColors.line),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ]);
  }

  // Weekly-rate choices, worded for the user's actual direction.
  //
  // Cutting mirrors the website engine's four steps. Bulking stops at 0.5
  // because the engine caps a clean surplus at 350 kcal/day, so 0.75 and 1.0
  // produce an identical plan while promising a faster result -- the website
  // itself labels them "محدود بالسقف (يعادل 0.5 عمليا)". Offering a
  // choice that changes nothing is a lie the plan cannot keep.
  // Mirrors the website's defaultActiveModules(): everyone starts with the
  // basics, and a cutting or fitness goal adds cardio on top.
  void _seedModules() {
    if (modulesSeeded) return;
    modulesSeeded = true;
    activeModules.addAll(['warmup', 'stretch', 'core']);
    if (goal == 'lose' || goal == 'fitness') activeModules.add('cardio');
  }

  Map<String, String> _rateLabels() => goal == 'gain'
      ? const {
          '0.25': '1/4 كيلو',
          '0.5': '1/2 كيلو',
        }
      : const {
          '0.25': '1/4 كيلو',
          '0.5': '1/2 كيلو',
          '0.75': '3/4 كيلو',
          '1': '1 كيلو',
        };

  // ── One answer surface for the whole questionnaire ─────────────────────
  // Every choice — single or multiple — is the same card: an indicator, the
  // label, and a hint when the label alone would make the user guess. Chips
  // wrapped into ragged rows and hid the longer options; a stacked list keeps
  // the reading order honest and the touch targets full width.
  Widget _optionCard({
    required String label,
    required bool selected,
    required bool multi,
    required VoidCallback onTap,
    String? hint,
    Color accent = AppColors.nu,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        colors: [accent.withValues(alpha: .22), accent.withValues(alpha: .05)],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft)
                    : null,
                color: selected ? null : AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: selected ? accent : AppColors.line, width: selected ? 1.6 : 1),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: accent.withValues(alpha: .18),
                            blurRadius: 16,
                            offset: const Offset(0, 5))
                      ]
                    : null,
              ),
              child: Row(children: [
                _selectionMark(selected, multi, accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              height: 1.25)),
                      if (hint != null && hint.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(hint,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12.5, height: 1.35)),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  // Circle for "pick one", rounded square for "pick as many as you like" — the
  // shape tells the user the rule before they tap.
  Widget _selectionMark(bool selected, bool multi, Color accent) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          shape: multi ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: multi ? BorderRadius.circular(7) : null,
          border: Border.all(
              color: selected ? accent : AppColors.muted.withValues(alpha: .55), width: 1.6),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 15, color: Color(0xFF04231B))
            : null,
      );

  Widget _quickReplies(Map<String, String> opts, void Function(String key) pick) =>
      _optionsSurface(opts,
          multi: false, isSelected: (_) => false, onPick: pick);

  // [FIX-ONBOARD-GRID] Short answers are laid out as a tidy grid of boxes
  // instead of one long vertical list. Long labels keep the stacked list so
  // nothing gets clipped. Meanings and stored keys are untouched.
  static const int _gridMaxLabel = 24;

  Widget _optionsSurface(
    Map<String, String> opts, {
    required bool multi,
    required bool Function(String key) isSelected,
    required void Function(String key) onPick,
  }) {
    final entries = opts.entries.toList();
    final compact =
        entries.every((e) => e.value.length <= _gridMaxLabel);
    if (!compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: entries
            .map((e) => _optionCard(
                  label: e.value,
                  selected: isSelected(e.key),
                  multi: multi,
                  onTap: () => onPick(e.key),
                ))
            .toList(),
      );
    }
    return LayoutBuilder(builder: (context, box) {
      const gap = 10.0;
      // [FIX-ONBOARD-GRID-2] عدد الأعمدة مابقاش ثابت: بيتحسب من عدد
      // الاختيارات وطول أطول نص، وبعدين العناصر بتتوزع على الصفوف
      // بالتساوي (6 → 3+3 ، 5 → 3+2 ، 4 → 2+2 ، 3 → 3) فمفيش مربع فاضي خالص.
      final longest = entries.fold<int>(
          0, (value, e) => e.value.length > value ? e.value.length : value);
      int columns = 3;
      if (box.maxWidth < 340 || longest > 14) columns = 2;
      if (box.maxWidth < 240 || longest > 22) columns = 1;
      if (columns > entries.length) columns = entries.length;
      if (columns < 1) columns = 1;
      final rows = (entries.length / columns).ceil();
      final base = entries.length ~/ rows;
      var extra = entries.length % rows;
      final chunks = <List<MapEntry<String, String>>>[];
      var index = 0;
      for (var r = 0; r < rows; r++) {
        final take = base + (extra > 0 ? 1 : 0);
        if (extra > 0) extra--;
        chunks.add(entries.sublist(index, index + take));
        index += take;
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var r = 0; r < chunks.length; r++) ...[
            if (r > 0) const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < chunks[r].length; c++) ...[
                    if (c > 0) const SizedBox(width: gap),
                    Expanded(
                      child: _optionBox(
                        label: chunks[r][c].value,
                        selected: isSelected(chunks[r][c].key),
                        multi: multi,
                        onTap: () => onPick(chunks[r][c].key),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  // One square-ish tile: selection mark + label, clear selected state.
  Widget _optionBox({
    required String label,
    required bool selected,
    required bool multi,
    required VoidCallback onTap,
    Color accent = AppColors.nu,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        accent.withValues(alpha: .24),
                        accent.withValues(alpha: .06)
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft)
                  : null,
              color: selected ? null : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected ? accent : AppColors.line,
                  width: selected ? 1.8 : 1),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: accent.withValues(alpha: .20),
                          blurRadius: 16,
                          offset: const Offset(0, 5))
                    ]
                  : null,
            ),
            child: Row(children: [
              _selectionMark(selected, multi, accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        height: 1.2)),
              ),
            ]),
          ),
        ),
      );

  // A single numeric answer typed exactly like sending a chat message: a round
  // pill field + a circular send button. No boxed form fields.
  // نوع الكيبورد بقى لكل سؤال لوحده
  // قبل كدا كان فيه كيبورد أرقام واحد متبوت لكل الأسئلة
  // فسوال الاسم كان بيفتح لوحة أرقام والمتدرب ميقدرش يكتب اسمه
  Widget _chatInput(TextEditingController ctrl, String hint,
      {required VoidCallback onSend, bool optional = false, String? skipLabel, VoidCallback? onSkip,
      TextInputType keyboard = const TextInputType.numberWithOptions(decimal: true)}) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Semantics(
          button: true,
          label: 'إرسال',
          child: IconButton.filled(
            onPressed: onSend,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.wo,
              foregroundColor: Colors.white,
              minimumSize: const Size(46, 46),
            ),
            icon: const Icon(Icons.arrow_upward_rounded, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
              // Rebuilt per question so the keyboard opens by itself, with no tap.
              key: ValueKey('answer_$_stage'),
              controller: ctrl,
              autofocus: true,
              textAlign: TextAlign.right,
              keyboardType: keyboard,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
        ),
        // [FIX-SKIP-LEFT] The skip used to be a loud two-line block under
        // the send button. It is now one small link on the opposite side
        // of the row (left), so it never competes with the answer.
        if (optional && onSkip != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: skipLabel ?? 'تخطي',
            child: TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('تخطي',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ]),
    ]);
  }

  Widget _multiComposer(Set<String> selected, Map<String, String> options,
          {required String emptyLabel, required VoidCallback onSend}) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _optionsSurface(options,
          multi: true,
          isSelected: selected.contains,
          onPick: (key) => setState(() => selected.contains(key)
              ? selected.remove(key)
              : selected.add(key))),
      const SizedBox(height: 12),
      // The count on the button is the receipt: the user never has to recount
      // what they ticked before committing.
      _primaryButton(
          selected.isEmpty ? emptyLabel : 'تمام (${selected.length})',
          onSend,
          color: AppColors.wo,
          fg: Colors.white),
    ]);
  }
}

/// [OWNER-RULE] مؤشر كتابة بسيط: ثلاث نقط بتنبض بالتتابع (بدون مبالغة).
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_c.value + i * 0.2) % 1.0;
            final t = (phase < 0.5) ? phase * 2 : (1 - phase) * 2;
            return Container(
              margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.muted.withValues(alpha: 0.35 + t * 0.55),
              ),
            );
          }),
        );
      },
    );
  }
}
