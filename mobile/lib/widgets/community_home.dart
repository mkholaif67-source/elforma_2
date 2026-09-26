import 'package:elforma/widgets/home_dashboard_widgets.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elforma/api.dart';
import 'package:elforma/screens/community_screen.dart';
import 'package:elforma/screens/steps_screen.dart';
import 'package:elforma/widgets/forma_design.dart';

class CommunityHome extends StatefulWidget {
  const CommunityHome({super.key});
  @override
  State<CommunityHome> createState() => _CommunityHomeState();
}

class _CommunityHomeState extends State<CommunityHome>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> recipes = [], challenges = [];
  Timer? contentTimer, stepTimer;
  bool contentLoading = false, stepsLoading = false;
  int? stepCount;
  int stepGoal = 6000;
  String stepLabel = 'تابع حركتك وهدفك';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshSteps());
    unawaited(refreshContent(Api.I.accountId));
    // المحتوى الشبكي لا يحتاج polling كل 10 ثوان؛ ده كان يبطئ الرئيسية ويستهلك البيانات.
    contentTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted &&
          TickerMode.of(context) &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(refreshContent(Api.I.accountId));
      }
    });
    // الخطوات محلية بالكامل ولا تنتظر الشبكة.
    // كل 10 ثوان كان بيعمل setState على الرئيسية 6 مرات في الدقيقة بدون داعي.
    stepTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          TickerMode.of(context) &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(refreshSteps());
      }
    });
  }

  @override
  void dispose() {
    contentTimer?.cancel();
    stepTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      unawaited(refreshSteps());
      unawaited(refreshContent(Api.I.accountId));
    }
  }

  Future<void> load() async {
    final owner = Api.I.accountId;
    await refreshSteps();
    await refreshContent(owner);
  }

  Future<void> refreshContent(String? owner) async {
    if (contentLoading) return;
    contentLoading = true;
    try {
      final r = await Api.I.community();
      if (mounted && r.ok && owner == Api.I.accountId) {
        setState(() {
          recipes = communityRows(r.data['recipes']);
          challenges = communityRows(r.data['challenges']);
        });
      }
    } finally {
      contentLoading = false;
    }
  }

  Future<void> refreshSteps() async {
    if (!Platform.isAndroid || stepsLoading) return;
    stepsLoading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final r = await const MethodChannel(
            'elforma/steps',
          ).invokeMapMethod<String, dynamic>('readLocal') ??
          {};
      final days = (r['days'] as List? ?? []).whereType<Map>().toList();
      final count = days.isEmpty ? null : days.last['count'];
      if (mounted) {
        setState(() {
          stepGoal = prefs.getInt('steps_goal:${Api.I.accountId}') ?? 6000;
          stepCount =
              r['status'] == 'ready' && count is num ? count.round() : null;
          stepLabel = stepCount == null
              ? 'اضغط لتفعيل عداد الحركة'
              : stepCount == 0
                  ? 'ابدأ أول خطواتك النهاردة'
                  : 'من هدفك اليومي $stepGoal خطوة';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          stepCount = null;
          stepLabel = 'افتح لتحديث خطواتك';
        });
      }
    } finally {
      stepsLoading = false;
    }
  }

  Future<void> open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final activeChallenges = challenges
        .where((e) => e['joined'] == true && e['ended'] != true)
        .toList();
    return FormaReveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          const Text(
            'يومك أحسن بخطوة',
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w800,
                color: HomeDesign.forest),
          ),
          const SizedBox(height: 12),
          _stepsCard(),
          const SizedBox(height: 12),
          _challengeCard(activeChallenges),
          const SizedBox(height: 12),
          _kitchenCard(),
        ],
      ),
    );
  }

  Widget _stepsCard() => HomeStepsCard(
        count: stepCount,
        goal: stepGoal,
        label: stepLabel,
        onTap: () => open(const StepsScreen()),
      );

  Widget _challengeCard(List<Map<String, dynamic>> active) {
    final current = active.isEmpty ? null : active.first;
    final mine = current?['mine'] as Map? ?? {};
    final progress = (mine['progress'] as num? ?? 0).round().clamp(0, 100);
    final count = active.length;
    final subtitle = count == 0
        ? 'ابدأ تحديا جديدا'
        : count == 1
            ? '${current?['title'] ?? 'تحديك الحالي'}'
            : 'لديك $count تحديات نشطة اضغط لعرضها وإضافة المزيد';
    return HomeChallengeCard(
      title: count == 0
          ? 'تحدياتي'
          : count == 1
              ? 'تحدي نشط'
              : '$count تحديات نشطة',
      subtitle: subtitle,
      progress: count == 1 ? progress : null,
      onTap: () => open(const CommunityScreen()),
    );
  }

  Widget _kitchenCard() {
    final hasRecipe = recipes.isNotEmpty;
    final title = hasRecipe
        ? '${recipes.first['title'] ?? 'وصفة اليوم'}'
        : 'وصفات صحية بطعم تحبه';
    final destination = hasRecipe
        ? RecipeScreen(item: recipes.first)
        : const CommunityScreen(recipes: true);
    return HomeKitchenCard(title: title, onTap: () => open(destination));
  }
}
