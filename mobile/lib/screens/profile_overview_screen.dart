// ── ElForma · screens/profile_overview_screen.dart ──
// The chic, read-first view of a COMPLETED training & nutrition profile.
// Opened from the account tab («بيانات التدريب والتغذية») ONLY when onboarding is
// already done. It lays every saved answer out in neat, grouped cards, and gives
// three actions:
//   • تعديل (top-right) → opens the setup chat in edit mode; on save the store
//     refreshes and this view updates instantly.
//   • عرض التحليل → the same wow analysis dashboard, in view-only mode
//     (no re-save, no auto-countdown).
//   • حذف وإعادة الإدخال → resets onboarding so the user re-enters from scratch.
// شاشة عرض البيانات المكتملة بشكل مرتب مع تعديل / عرض تحليل / حذف.

import 'package:flutter/material.dart';
import 'package:elforma/api.dart';
import 'package:elforma/models/profile_store.dart';
import 'package:elforma/models/plan_store.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/error_view.dart';
import 'package:elforma/screens/analysis_screen.dart';
import 'package:elforma/screens/profile_setup_screen.dart';

class ProfileOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> initial;
  const ProfileOverviewScreen({super.key, required this.initial});

  @override
  State<ProfileOverviewScreen> createState() => _ProfileOverviewScreenState();
}

class _ProfileOverviewScreenState extends State<ProfileOverviewScreen> {
  late Map<String, dynamic> _p;
  bool _busy = false;
  bool _changed = false; // did anything change while we were here?

  @override
  void initState() {
    super.initState();
    _p = Map<String, dynamic>.from(widget.initial);
  }

  // ── label dictionaries (mirror the setup screen) ─────────────────
  static const Map<String, String> _gender = {'male': 'ذكر', 'female': 'أنثى'};
  static const Map<String, String> _goal = {'lose': 'خسارة دهون', 'maintain': 'ثبات', 'gain': 'بناء عضلات', 'strength': 'قوة', 'fitness': 'لياقة'};
  static const Map<String, String> _activity = {'sedentary': 'محدودة', 'light': 'خفيفة', 'moderate': 'متوسطة', 'active': 'عالية', 'athlete':'عالية جدا'};
  static const Map<String, String> _sleep = {'poor': 'ضعيف', 'ok': 'جيد', 'good': 'ممتاز'};
  static const Map<String, String> _stress = {'low': 'قليل', 'mid': 'متوسط', 'high': 'عال'};
  static const Map<String, String> _intensity = {'light': 'خفيف', 'moderate': 'متوسط', 'vigorous': 'عالي'};
  static const Map<String, String> _exp = {'beginner': 'مبتدئ', 'intermediate': 'متوسط', 'advanced': 'متقدم'};
  static const Map<String, String> _equip = {'gym': 'الجيم', 'home': 'البيت'};
  static const Map<String, String> _diet = {'balanced': 'متوازن', 'lowcarb': 'قليل الكارب', 'keto': 'كيتو', 'carbcycle': 'تدوير الكارب', 'mediterranean': 'البحر المتوسط', 'carnivore': 'كارنيفور'};
  static const Map<String, String> _fasting = {'normal': 'أكل عادي', 'ramadan': 'صيام رمضان', 'if16': 'صيام متقطع 16:8'};
  static const Map<String, String> _inj = {'shoulder': 'كتف', 'back': 'ظهر', 'knee': 'ركبة', 'elbow': 'كوع', 'wrist': 'رسغ', 'neck': 'رقبة'};
  static const Map<String, String> _weak = {'chest': 'صدر', 'back': 'ظهر', 'shoulders': 'أكتاف', 'arms': 'ذراع', 'quads': 'رجل أمامية', 'hamstrings': 'رجل خلفية', 'glutes': 'جلوتس', 'calves': 'سمانة', 'core': 'بطن/كور'};
  static const Map<String, String> _health = {'diabetes': 'سكري', 'insulin': 'مقاومة إنسولين', 'bp': 'ضغط', 'cholesterol': 'كوليسترول', 'kidney': 'كلى', 'gerd': 'ارتجاع', 'gout': 'نقرس', 'ibs': 'قولون عصبي'};

  // ── tiny readers ──────────────────────────────────────
  String _s(String k) {
    final v = _p[k];
    return v == null ? '' : '$v';
  }

  String _mapv(Map<String, String> m, String k) => m[_s(k)] ?? '—';

  String _numv(String k, {String suffix = ''}) {
    final v = _p[k];
    if (v == null) return '—';
    final s = '$v'.replaceFirst(RegExp(r'\.0$'), '');
    if (s.isEmpty) return '—';
    return suffix.isEmpty ? s : '$s $suffix';
  }

  bool _has(String k) {
    final v = _p[k];
    if (v == null) return false;
    if (v is num) return v > 0;
    return '$v'.trim().isNotEmpty;
  }

  List<String> _listv(String k) {
    final v = _p[k];
    if (v is List) return v.whereType<String>().toList();
    return const [];
  }

  // ── actions ─────────────────────────────────────────
  static const _fields = <String, String>{
    'الاسم':'name','الجنس':'gender','السن':'age','الطول':'height','الوزن':'weight',
    'الوزن المستهدف':'targetWeight','الهدف':'goal','النشاط اليومي':'dailyActivity',
    'النوم':'sleep','التوتر':'stress','الخطوات':'steps','الكارديو':'cardioSessions',
    'شدة الكارديو':'cardioIntensity','الخبرة':'experience','مكان التمرين':'equipment',
    'أيام التمرين':'trainingDays','الأيام المحددة':'preferredDays','مدة الجلسة':'trainingMinutes',
    'نظام الأكل':'diet','عدد الوجبات':'mealCount','نمط الأكل':'fastingMode',
    'الخصر':'waist','الرقبة':'neck','الأرداف':'hips','نسبة الدهون':'bodyFat',
    'إصابات':'injuries','عضلات متأخرة':'weakPoints','حالات صحية':'healthConditions',
    'معدل تغير الوزن أسبوعيا':'weeklyRate',
  };
  Map<String,String>? _options(String key) => <String,Map<String,String>>{
    'gender':_gender,'goal':_goal,'dailyActivity':_activity,'sleep':_sleep,'stress':_stress,
    'cardioIntensity':_intensity,'experience':_exp,'equipment':_equip,'diet':_diet,
    'fastingMode':_fasting,'injuries':_inj,'weakPoints':_weak,'healthConditions':_health,
    'trainingDays':{'0':'لا أتدرب حاليا',for(final n in [2,3,4,5,6]) '$n':'$n أيام'},
    'trainingMinutes':{for(final n in [30,45,60,75,90,120]) '$n':'$n دقيقة'},
    'mealCount':{for(final n in [2,3,4,5]) '$n':'$n وجبات'},
    'preferredDays':{'0':'السبت','1':'الأحد','2':'الاثنين','3':'الثلاثاء','4':'الأربعاء','5':'الخميس','6':'الجمعة'},
  }[key];
  static const _bounds = <String,List<double>>{
    'age':[7,80],'height':[100,250],'weight':[30,350],'targetWeight':[30,350],
    'steps':[0,40000],'cardioSessions':[0,14],'waist':[40,250],'neck':[20,80],
    'hips':[50,250],'bodyFat':[3,65],'weeklyRate':[0.25,1],
  };

  Future<void> _edit() async {
    final label = await showModalBottomSheet<String>(context:context, isScrollControlled:true,
      builder:(ctx)=>SafeArea(child:SizedBox(height:MediaQuery.sizeOf(ctx).height*.75,
        child:ListView(children:[
          const ListTile(title:Text('اختر البيان الذي تريد تعديله')),
          for(final label in _fields.keys) ListTile(title:Text(label),
            trailing:const Icon(Icons.edit_outlined),onTap:()=>Navigator.pop(ctx,label)),
        ]))));
    if(label!=null&&mounted) await _editField(label);
  }

  Future<void> _editField(String label) async {
    final key=_fields[label];
    if(key==null||_busy)return;
    final options=_options(key);
    final multiple=['injuries','weakPoints','healthConditions','preferredDays'].contains(key);
    final selected=<String>{if(_p[key] is List) ...(_p[key] as List).map((v)=>'$v')};
    String? choice=_p[key]?.toString();
    final controller=TextEditingController(text:options==null?(_p[key]?.toString()??''):'');
    String? validation;
    final value=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,setDialog)=>AlertDialog(
        title:Text('تعديل $label'),
        content:SizedBox(width:double.maxFinite,child:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          if(key=='preferredDays') const Text('اترك الخيارات فارغة للتوزيع التلقائي، أو اختر عدد أيام التدريب نفسه.'),
          if(options!=null) ...options.entries.map((e)=>multiple
            ? CheckboxListTile(title:Text(e.value),value:selected.contains(e.key),onChanged:(v)=>setDialog((){if(v==true){selected.add(e.key);}else{selected.remove(e.key);}}))
            : RadioListTile<String>(title:Text(e.value),value:e.key,groupValue:choice,onChanged:(v)=>setDialog(()=>choice=v)))
          else TextField(controller:controller,autofocus:true,
            keyboardType:key=='name'?TextInputType.text:const TextInputType.numberWithOptions(decimal:true),
            decoration:InputDecoration(labelText:label)),
          if(validation!=null) Text(validation!,style:const TextStyle(color:Colors.redAccent)),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
          FilledButton(onPressed:(){
            dynamic next;
            if(options!=null){
              if(multiple){next=key=='preferredDays'?selected.map(int.parse).toList():selected.toList();}
              else {if(choice==null){setDialog(()=>validation='اختر قيمة أولا.');return;}
                next=['trainingDays','trainingMinutes','mealCount'].contains(key)?int.parse(choice!):choice;}
            }else if(key=='name'){
              next=controller.text.trim();
              if(next.isEmpty||next.length>80){setDialog(()=>validation='اكتب اسما من 1 إلى 80 حرفا.');return;}
            }else{
              final normalized=controller.text.trim().replaceAll('٫','.').replaceAllMapped(RegExp('[٠-٩]'),(m)=>'${m[0]!.codeUnitAt(0)-0x660}');
              next=num.tryParse(normalized);
              final limits=_bounds[key];
              final cleared=normalized.isEmpty && ['waist','neck','hips','bodyFat','steps','weeklyRate'].contains(key);
              if(!cleared && (next==null||!next.isFinite||(limits!=null&&(next<limits[0]||next>limits[1])))){
                setDialog(()=>validation=limits==null?'اكتب رقما صحيحا.':'القيمة المطلوبة من ${limits[0]} إلى ${limits[1]}.');return;}
              if(next!=null&&['age','steps','cardioSessions'].contains(key)&&next!=next.round()){
                setDialog(()=>validation='اكتب عددا صحيحا بدون كسور.');return;}
            }
            final patch=<String,dynamic>{key:next};
            if(key=='trainingDays') patch['trains']=next>0;
            final days=key=='trainingDays'?next:(_p['trainingDays']??0);
            final fixed=key=='preferredDays'?next:(_p['preferredDays']??[]);
            if(fixed is List&&fixed.isNotEmpty&&fixed.length!=days){
              setDialog(()=>validation='عدد الأيام المحددة لا يطابق أيام التدريب. عدل الأيام المحددة أو اختر التوزيع التلقائي أولا.');return;}
            Navigator.pop(ctx,patch);
          },child:const Text('حفظ'))],
      )));
    controller.dispose();
    if(value==null||!mounted)return;
    setState(()=>_busy=true);
    final result=await Api.I.saveMobileProfile(value,patch:true,preparePlans:true);
    if(!mounted)return;
    setState(()=>_busy=false);
    if((result.ok||result.data['profileSaved']==true)&&result.data['profile'] is Map){
      final fresh=Map<String,dynamic>.from(result.data['profile'] as Map);
      setState((){_p=fresh;_changed=true;});
      await ProfileStore.I.apply(fresh);
      PlanStore.I.markChanged();
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result.ok?'تم التعديل':'تم حفظ البيانات تعذر تحديث الخطة حاول مرة أخرى')));
    }else{
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result.friendlyError('تعذر تأكيد الحفظ حاول مرة أخرى'))));
    }
  }

  Future<void> _redo() async {
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('إعادة إدخال البيانات'),
      content:const Text('ستدخل بيانات التدريب والتغذية مرة أخرى. لن نحذف سجل التمرين أو نعيد تاريخ بداية رحلتك. تبقى البيانات الحالية محفوظة حتى تؤكد البيانات الجديدة.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('متابعة'))]));
    if(confirmed!=true||!mounted)return;
    await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const ProfileSetupScreen()));
    if(mounted&&ProfileStore.I.profile!=null)setState((){_p=Map<String,dynamic>.from(ProfileStore.I.profile!);_changed=true;});
  }

  void _viewAnalysis() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AnalysisScreen(payload: _p, viewOnly: true),
    ));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('حذف البيانات؟',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
        content: const Text(
            'سنحذف إعدادات التدريب والتغذية لإدخالها مرة أخرى. سجل الجلسات والأوزان وتاريخ بداية رحلتك سيظل محفوظا. هل تريد المتابعة؟',
            style: TextStyle(color: AppColors.muted, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.wo, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الإعدادات'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    // The server insists on age/height/weight, so we keep the trio but drop
    // everything else and flip onboardingComplete off → the app treats the user
    // as not-yet-onboarded and walks them through a fresh setup that overwrites
    // the old plan entirely.
    final reset = <String, dynamic>{
      'age': _p['age'],
      'height': _p['height'],
      'weight': _p['weight'],
      'onboardingComplete': false,
    };
    final res = await Api.I.saveMobileProfile(reset);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      await ProfileStore.I.clear();
      if (!mounted) return;
      Navigator.pop(context, true); // account reloads → tile flips to «أكمل بياناتك»
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.friendlyError('تعذر حذف البيانات'))),
      );
    }
  }

  // ── build ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cardio = ProfileStore.num0(_p['cardioSessions']).round();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          title: const Text('بيانات التدريب والتغذية',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          centerTitle: true,
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, _changed),
          ),
        ),
        body: SafeArea(
          child: _p.isEmpty
              // Reaching this screen with no profile is not an error: it means
              // onboarding was never finished. Saying "something went wrong"
              // would send the trainee hunting for a bug that isn't there.
              ? EmptyView(
                  message: 'مفيش بيانات لسة. اكمل بياناتك عشان نبني لك الخطة',
                  icon: Icons.assignment_ind_rounded,
                  actionLabel: 'ابدأ دلوقتي',
                  onAction: _busy ? null : _edit,
                )
              : ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _hero(),
              const SizedBox(height: 16),
              _section('البيانات الأساسية', Icons.badge_rounded, AppColors.nu, [
                _row('الجنس', _mapv(_gender, 'gender')),
                _row('السن', _numv('age', suffix: 'سنة')),
                _row('الطول', _numv('height', suffix: 'سم')),
                _row('الوزن', _numv('weight', suffix: 'كجم')),
                if (_has('targetWeight')) _row('الوزن المستهدف', _numv('targetWeight', suffix: 'كجم')),
              ]),
              _section('الهدف والنشاط', Icons.flag_rounded, AppColors.wo, [
                _row('الهدف', _mapv(_goal, 'goal')),
                _row('النشاط اليومي', _mapv(_activity, 'dailyActivity')),
                _row('النوم', _mapv(_sleep, 'sleep')),
                _row('التوتر', _mapv(_stress, 'stress')),
                if (_has('steps')) _row('الخطوات', _numv('steps', suffix: 'خطوة/يوم')),
                _row('الكارديو',
                    cardio == 0 ? 'مفيش' : '$cardio جلسة/أسبوع · ${_mapv(_intensity, 'cardioIntensity')}'),
              ]),
              _section('التمرين', Icons.fitness_center_rounded, AppColors.wo, [
                _row('الخبرة', _mapv(_exp, 'experience')),
                _row('مكان التمرين', _mapv(_equip, 'equipment')),
                _row('أيام التمرين', _numv('trainingDays', suffix: 'أيام/أسبوع')),
                _row('الأيام المحددة', ((_p['preferredDays'] as List?) ?? []).isEmpty ? 'توزيع تلقائي' : ((_p['preferredDays'] as List).map((d)=>_options('preferredDays')!['$d']??'').join('، '))),
                _row('مدة الجلسة', _numv('trainingMinutes', suffix: 'دقيقة')),
              ]),
              _section('التغذية', Icons.restaurant_rounded, AppColors.nu, [
                _row('نظام الأكل', _mapv(_diet, 'diet')),
                _row('عدد الوجبات', _numv('mealCount', suffix: 'وجبات')),
                _row('نمط الأكل', _mapv(_fasting, 'fastingMode')),
              ]),
              if (_p.isNotEmpty)
                _section('القياسات', Icons.straighten_rounded, AppColors.nu2, [
                  _row('الخصر', _numv('waist', suffix: 'سم')),
                  _row('الرقبة', _numv('neck', suffix: 'سم')),
                  _row('الأرداف', _numv('hips', suffix: 'سم')),
                  _row('نسبة الدهون', _numv('bodyFat', suffix: '%')),
                ]),
              _section('الإصابات والتركيز', Icons.health_and_safety_rounded, AppColors.wo2, [
                _chips('إصابات', _listv('injuries'), _inj),
                _chips('عضلات متأخرة', _listv('weakPoints'), _weak),
                _chips('حالات صحية', _listv('healthConditions'), _health),
              ]),
              const SizedBox(height: 6),
              _primary('عرض التحليل', Icons.insights_rounded, _busy ? null : _viewAnalysis),
              const SizedBox(height: 12),
              _primary('إعادة إدخال البيانات', Icons.restart_alt, _busy ? null : _redo),
              const SizedBox(height:12),
              _danger('حذف إعدادات البيانات', Icons.delete_outline_rounded, _busy ? null : _delete),
            ],
          ),
        ),
      ),
    );
  }

  // ── pieces ────────────────────────────────────────
  Widget _hero() {
    final h = ProfileStore.num0(_p['height']);
    final w = ProfileStore.num0(_p['weight']);
    final bmi = (h > 0 && w > 0) ? w / ((h / 100) * (h / 100)) : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [
          AppColors.nu.withValues(alpha: .18),
          AppColors.wo.withValues(alpha: .12),
        ]),
        border: Border.all(color: AppColors.nu.withValues(alpha: .3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.nu, AppColors.nu2])),
            child: const Icon(Icons.verified_rounded, color: Color(0xFF04231B), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ملفك مكتمل', softWrap: true,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.5)),
            const SizedBox(height: 4),
            Text('${_mapv(_goal, 'goal')} · نشاط ${_mapv(_activity, 'dailyActivity')}',
              softWrap: true, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.muted)),
          ])),
        ]),
        if (bmi != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
            child: Row(children: [
              const Expanded(child: Text('مؤشر كتلة الجسم · BMI',
                softWrap: true, style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.muted))),
              const SizedBox(width: 12),
              Flexible(child: Text(bmi.toStringAsFixed(1), textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.nu2))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _section(String title, IconData icon, Color color, List<Widget> rows) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, softWrap: true,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, height: 1.5, color: AppColors.text))),
            ]),
            const SizedBox(height: 6),
            ...rows,
          ],
        ),
      );

  Widget _row(String label, String value) => Semantics(
        button: true,
        label: '$label: $value. تعديل',
        child: InkWell(
          onTap: _busy ? null : () => _editField(label),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            decoration: BoxDecoration(border: Border(
              bottom: BorderSide(color: AppColors.line.withValues(alpha: .5)),
            )),
            child: Row(children: [
              Expanded(flex: 4, child: Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5))),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: Row(children: [
                Expanded(child: Text(value, textAlign: TextAlign.end,
                  style: const TextStyle(color: AppColors.text,
                    fontWeight: FontWeight.w800, fontSize: 15, height: 1.5))),
                const SizedBox(width: 10),
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_outlined, size: 17, color: AppColors.nu2)),
              ])),
            ]),
          ),
        ),
      );

  Widget _chips(String label, List<String> keys, Map<String, String> m) =>
      _row(label, keys.isEmpty ? 'لا يوجد' : keys.map((k) => m[k] ?? k).join('، '));

  Widget _primary(String label, IconData icon, VoidCallback? onTap) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 54),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.nu,
            foregroundColor: const Color(0xFF04231B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(label, textAlign: TextAlign.center, softWrap: true, style: const TextStyle(fontSize: 15.5, height: 1.5, fontWeight: FontWeight.w900))),
        ),
      );

  Widget _danger(String label, IconData icon, VoidCallback? onTap) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 52),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.wo2,
            side: BorderSide(color: AppColors.wo.withValues(alpha: .5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(label, textAlign: TextAlign.center, softWrap: true, style: const TextStyle(fontSize: 14.5, height: 1.5, fontWeight: FontWeight.w800))),
        ),
      );
}
