import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elforma/api.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/forma_input_dialog.dart';
import 'package:elforma/widgets/forma_design.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});
  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> with WidgetsBindingObserver {
  static const channel = MethodChannel('elforma/steps');
  List<Map> days = [];
  String status = 'loading';
  int goal = 6000;
  bool busy = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadGoal();
    read();
    // 5s was a local (network-free) read, but it still woke the isolate 12
    // times a minute and rebuilt the whole screen each time. 20s is
    // imperceptible for a step counter and cuts those wakeups by 4x.
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)
        read();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) read();
  }

  Future<void> loadGoal() async {
    final p = await SharedPreferences.getInstance();
    if (mounted)
      setState(() => goal = p.getInt('steps_goal:${Api.I.accountId}') ?? 6000);
  }

  Future<void> read({bool request = false, bool includeHealth = false}) async {
    if (busy) return;
    if (!Platform.isAndroid) {
      setState(() => status = 'unsupported');
      return;
    }
    setState(() => busy = true);
    try {
      final r =
          await channel.invokeMapMethod<String, dynamic>(
            request ? 'request' : includeHealth ? 'read' : 'readLocal',
          ) ??
          {};
      if (!mounted) return;
      setState(() {
        status = '${r['status'] ?? 'error'}';
        days = (r['days'] as List? ?? []).whereType<Map>().toList();
      });
      if (request && status == 'ready') {
        setState(() => busy = false);
        await read(includeHealth: true);
      }
    } catch (_) {
      if (mounted)
        setState(() {
          status = 'error';
          days = [];
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeGoal() async {
    final owner = Api.I.accountId;
    final value = await showFormaTextPrompt(
      context,
      title: 'هدف خطواتك اليومي',
      label: 'من 500 إلى 50000 خطوة',
      action: 'حفظ',
      initialValue: '$goal',
      keyboardType: TextInputType.number,
      validator: (v) {
        final n = int.tryParse(v ?? '');
        return n == null || n < 500 || n > 50000
            ? 'اختار هدفا بين 500 و50000'
            : null;
      },
    );
    if (value != null && mounted && owner == Api.I.accountId) {
      final p = await SharedPreferences.getInstance();
      await p.setInt('steps_goal:$owner', int.parse(value));
      if (mounted && owner == Api.I.accountId)
        setState(() => goal = int.parse(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = days.isEmpty ? null : days.last['count'] as num?;
    final recorded = days.where((d) => d['count'] is num).toList();
    final best = recorded.isEmpty
        ? null
        : recorded.reduce(
            (a, b) => (a['count'] as num) >= (b['count'] as num) ? a : b,
          );
    return Scaffold(
      appBar: AppBar(title: const Text('خطوات اليوم')),
      body: RefreshIndicator(
        onRefresh: () => read(includeHealth: true),
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Text(
              'كل خطوة محسوبة',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'تابع حركتك بهدف تختاره على قد يومك',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: count == null
                                  ? 0
                                  : (count / goal).clamp(0, 1).toDouble(),
                              strokeWidth: 12,
                              backgroundColor: AppColors.bg2,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const FormaIcon(
                                Icons.directions_walk_rounded,
                                color: AppColors.nu,
                                size: 32,
                              ),
                              Text(
                                count == null ? '—' : '${count.round()}',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text('خطوة اليوم'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('هدفك: $goal خطوة'),
                    TextButton(
                      onPressed: changeGoal,
                      child: const Text('تعديل الهدف'),
                    ),
                    if (count != null)
                      Text(
                        count >= goal
                            ? 'وصلت لهدفك اليوم 👏'
                            : 'فاضلك ${goal - count.round()} خطوة لهدفك',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (status == 'loading') const Center(child: FormaLoader()),
            if (status != 'ready' && status != 'loading')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status == 'unsupported'
                            ? 'قراءة الخطوات غير متاحة على هذا الجهاز'
                            : status == 'install'
                            ? 'جهز مصدر الخطوات'
                            : status == 'sensor_permission'
                            ? 'اسمح بقراءة حركة الهاتف'
                            : 'اربط خطواتك',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'بإذنك، نقرأ الخطوات من عداد الحركة داخل الهاتف مباشرة، ومع Health Connect إن كان متاحا. لا تحتاج تطبيقا مساعدا، وتظل البيانات على جهازك',
                        style: TextStyle(height: 1.8),
                      ),
                      if (status == 'error')
                        const Text('تعذر تحديث الخطوات، حاول مرة أخرى'),
                      if (status != 'unsupported') ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: busy ? null : () => read(request: true),
                          child: const Text('السماح بقراءة الخطوات'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (status == 'ready' && count == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'لا توجد خطوات مسجلة بعد. تحرك قليلا ثم اسحب الصفحة للتحديث؛ ويمكن استخدام Health Connect كمصدر إضافي',
                    style: TextStyle(height: 1.8),
                  ),
                ),
              ),
            if (days.length > 1) ...[
              const Text(
                'منذ بدء التتبع',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...days.map(
                (d) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${d['day']}'),
                  trailing: Text(
                    d['count'] == null ? 'لا بيانات' : '${d['count']} خطوة',
                  ),
                ),
              ),
              if (best != null)
                Card(
                  child: ListTile(
                    leading: const FormaIcon(
                      Icons.emoji_events_rounded,
                      color: AppColors.warning,
                    ),
                    title: const Text('أفضل يوم مسجل'),
                    subtitle: Text('${best['day']}'),
                    trailing: Text('${best['count']} خطوة'),
                  ),
                ),
            ],
            if (Platform.isAndroid)
              TextButton(
                onPressed: () async {
                  try {
                    await channel.invokeMethod<void>('settings');
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تعذر فتح إعدادات Health Connect'),
                        ),
                      );
                  }
                },
                child: const Text('إعدادات Health Connect والأذونات'),
              ),
            const Text(
              'عداد الهاتف يعمل في الخلفية بدون إنترنت بعد منح إذن الحركة ويبدأ السجل من يوم تفعيل التتبع فقط وقد توقفه إعدادات توفير البطارية أو الإيقاف الإجباري حتى تفتح التطبيق مرة أخرى',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
