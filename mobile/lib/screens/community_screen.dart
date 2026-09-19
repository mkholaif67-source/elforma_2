import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elforma/api.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/forma_input_dialog.dart';
import 'package:elforma/widgets/forma_design.dart';

List<Map<String, dynamic>> communityRows(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];

class CommunityImage extends StatelessWidget {
  const CommunityImage({super.key, required this.data, this.height = 180});
  final Map<String, dynamic> data;
  final double height;
  @override
  Widget build(BuildContext context) {
    final raw = '${data['image'] ?? ''}';
    final fallback = Container(
      height: height,
      color: AppColors.bg2,
      alignment: Alignment.center,
      child: FormaIcon(
        data['team'] == true
            ? Icons.emoji_events_rounded
            : data.containsKey('duration')
            ? Icons.flag_rounded
            : Icons.restaurant_menu_rounded,
        size: 54,
        color: AppColors.nu,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: raw.isEmpty
          ? fallback
          : Image.network(
              Uri.parse(Api.baseUrl).resolve(raw).toString(),
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.recipes = false});
  final bool recipes;
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> items = [];
  bool busy = true;
  String? error;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    // كان كل 30 ثانية = طلب شبكة كامل مرتين في الدقيقة طول ما الصفحة مفتوحة.
    timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        load(quiet: true);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load(quiet: true);
  }

  Future<void> load({bool quiet = false}) async {
    final account = Api.I.accountId;
    final r = await Api.I.community();
    if (!mounted || account != Api.I.accountId) return;
    setState(() {
      busy = false;
      error = r.ok ? null : 'تعذر تحديث المحتوى. حاول مرة أخرى';
      if (r.ok)
        items = communityRows(
          r.data[widget.recipes ? 'recipes' : 'challenges'],
        );
    });
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChallengeEditor(item: item)));
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.recipes ? 'من مطبخ الفورمة' : 'تحدياتي'),
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: load,
          icon: const FormaIcon(Icons.refresh_rounded),
        ),
      ],
    ),
    floatingActionButton: widget.recipes
        ? null
        : FloatingActionButton.extended(
            onPressed: edit,
            backgroundColor: AppColors.nu,
            foregroundColor: Colors.white,
            label: const Text('إضافة تحد جديد'),
            icon: const FormaIcon(Icons.add_rounded),
          ),
    body: busy
        ? const Center(child: FormaLoader())
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (error != null)
                  ListTile(
                    title: Text(error!),
                    trailing: TextButton(
                      onPressed: load,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ),
                Text(
                  widget.recipes
                      ? 'أفكار من فريقك، تختار منها اللي يناسبك'
                      : 'خطوة صغيرة كل يوم تصنع فرقا',
                  style: const TextStyle(color: AppColors.muted, height: 1.7),
                ),
                const SizedBox(height: 18),
                if (items.isEmpty && error == null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          FormaIcon(
                            widget.recipes
                                ? Icons.restaurant_menu_rounded
                                : Icons.flag_rounded,
                            size: 52,
                            color: AppColors.nu,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.recipes
                                ? 'الوصفات الجديدة هتظهر هنا'
                                : 'ابدأ أول تحد لنفسك',
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.recipes)
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecipeScreen(item: item),
                          ),
                        ),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CommunityImage(data: item),
                                const SizedBox(height: 12),
                                Text(
                                  '${item['title']}',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (item['calories'] != null)
                                  Text(
                                    '${item['calories']} سعرة / حصة',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                const Text(
                                  'اكتشف الوصفة ←',
                                  style: TextStyle(
                                    color: AppColors.nu,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!widget.recipes) ...[
                  const Text(
                    'تحدياتك الشخصية',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
                  ),
                  ...items.where((e) => e['team'] != true).map(challengeCard),
                  const SizedBox(height: 18),
                  const Text(
                    'تحديات فريق الفورمة',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
                  ),
                  ...items.where((e) => e['team'] == true).map(challengeCard),
                ],
              ],
            ),
          ),
  );
  Widget challengeCard(Map<String, dynamic> item) {
    final mine = item['mine'] as Map? ?? {};
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChallengeScreen(id: '${item['id']}'),
              ),
            );
            if (mounted) load();
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ('${item['image'] ?? ''}'.isNotEmpty) ...[
                  CommunityImage(data: item, height: 145),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    const FormaIcon(Icons.flag_rounded, color: AppColors.nu),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${item['title']}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item['checkedToday'] == true)
                      const FormaIcon(
                        Icons.check_circle_rounded,
                        color: AppColors.nu,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${item['duration']} يوم${item['team'] == true ? ' · ${item['participantCount']} مشارك' : ''}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                if (item['joined'] == true) ...[
                  LinearProgressIndicator(
                    value: ((mine['progress'] as num? ?? 0) / 100)
                        .clamp(0, 1)
                        .toDouble(),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${mine['completed']} / ${mine['total']} يوم · ${mine['progress']}٪',
                  ),
                ] else
                  Text(
                    item['ended'] == true
                        ? 'انتهى التحدي'
                        : 'اعرف القواعد وانضم ←',
                    style: const TextStyle(color: AppColors.nu),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecipeScreen extends StatelessWidget {
  const RecipeScreen({super.key, required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('من مطبخ الفورمة')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        CommunityImage(data: item, height: 240),
        const SizedBox(height: 18),
        Text(
          '${item['title']}',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('${item['servings']} حصة')),
            if (item['calories'] != null)
              Chip(label: Text('${item['calories']} سعرة / حصة')),
            if (item['cost'] != null)
              Chip(
                label: Text(
                  'تكلفة تقريبية: ${item['cost']} ${item['currency'] == 'USD' ? 'دولار' : 'ج.م'}',
                ),
              ),
            if ((item['points'] as num? ?? 0) > 0)
              Chip(label: Text('${item['points']} نقطة')),
          ],
        ),
        Wrap(
          spacing: 12,
          children: [
            for (final f in {
              'protein': 'بروتين',
              'carbs': 'كارب',
              'fat': 'دهون',
            }.entries)
              if (item[f.key] != null)
                Text('${f.value}: ${item[f.key]} جم / حصة'),
          ],
        ),
        for (final section in {
          'ingredients': 'المكونات',
          'preparation': 'طريقة التحضير',
          'highlights': 'نقاط تهمك',
        }.entries)
          if ((item[section.key] as List? ?? []).isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 18),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(item[section.key] as List).asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${section.key == 'preparation' ? '${e.key + 1}. ' : '• '}${e.value}',
                          style: const TextStyle(height: 1.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Text(
            'وصفة مقترحة من الفريق. القيم تخص الحصة الموضحة، ولا تضاف إلى خطتك تلقائيا',
            style: TextStyle(color: AppColors.muted, height: 1.7),
          ),
        ),
      ],
    ),
  );
}

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, required this.id});
  final String id;
  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? item;
  String? error;
  bool saving = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        load();
      }
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
    if (s == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    final owner = Api.I.accountId;
    final r = await Api.I.challengeDetail(widget.id);
    if (!mounted || owner != Api.I.accountId) return;
    setState(() {
      if (r.ok) {
        item = Map<String, dynamic>.from(r.data['item'] as Map);
        error = null;
      } else {
        error = 'تعذر عرض التحدي. قد يكون الفريق أخفاه أو الاتصال غير متاح';
      }
    });
  }

  Future<void> action(String action, Map<String, dynamic> body) async {
    if (saving) return;
    setState(() => saving = true);
    final owner = Api.I.accountId;
    final r = await Api.I.communityAction(action, {'id': widget.id, ...body});
    if (!mounted || owner != Api.I.accountId) return;
    setState(() => saving = false);
    if (r.ok) {
      if (action == 'delete') {
        Navigator.pop(context);
        return;
      }
      await load();
    } else
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${r.data['error'] ?? 'تعذر الحفظ، حاول مرة أخرى'}'),
        ),
      );
  }

  Future<void> join() async {
    final name = await showFormaTextPrompt(
      context,
      title: 'انضم للتحدي',
      label: 'اسم العرض',
      action: 'موافق، انضم',
      maxLength: 40,
      description:
          'اسم العرض ودرجة التزامك هيظهروا للمشاركين. التسجيل ذاتي، مرة واحدة كل يوم بتوقيت القاهرة',
      validator: (v) => v == null || v.trim().isEmpty ? 'اكتب اسم العرض' : null,
    );
    if (name != null && mounted) await action('join', {'displayName': name});
  }

  @override
  Widget build(BuildContext context) {
    final p = item;
    final mine = p?['mine'] as Map? ?? {};
    return Scaffold(
      appBar: AppBar(
        title: Text('${p?['title'] ?? 'التحدي'}'),
        actions: [
          if (p != null && p['team'] != true)
            IconButton(
              tooltip: 'تعديل التحدي',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChallengeEditor(item: p)),
                );
                if (mounted) load();
              },
              icon: const FormaIcon(Icons.edit_outlined),
            ),
        ],
      ),
      body: p == null
          ? Center(
              child: error == null
                  ? const FormaLoader()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!),
                        TextButton(
                          onPressed: load,
                          child: const Text('حاول تاني'),
                        ),
                      ],
                    ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  CommunityImage(data: p, height: 180),
                  const SizedBox(height: 18),
                  Text(
                    '${p['title']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${p['description'] ?? ''}',
                    style: const TextStyle(height: 1.8, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  Text('البداية ${p['start']} · ${p['duration']} يوم'),
                  if ('${p['reminderTime'] ?? ''}'.isNotEmpty)
                    Text('وقت التنفيذ: ${p['reminderTime']}'),
                  if (p['team'] == true)
                    Text(
                      '${p['participantCount']} مشارك · اليوم بتوقيت القاهرة',
                    ),
                  if (p['joined'] == true) ...[
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 18),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            Text(
                              '${mine['progress']}٪',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: AppColors.nu,
                              ),
                            ),
                            Text(
                              '${mine['completed']} من ${mine['total']} يوم مكتمل',
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: ((mine['progress'] as num? ?? 0) / 100)
                                  .clamp(0, 1)
                                  .toDouble(),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            const SizedBox(height: 12),
                            Text('الالتزام حتى اليوم: ${mine['consistency']}٪'),
                          ],
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: !saving && p['canCheck'] == true
                          ? () => action('check', {
                              'done': p['checkedToday'] != true,
                            })
                          : null,
                      child: Text(
                        saving
                            ? 'جار الحفظ…'
                            : p['checkedToday'] == true
                            ? '✓ تم اليوم — تراجع'
                            : p['ended'] == true
                            ? 'التحدي انتهى'
                            : p['canCheck'] == true
                            ? 'أكملت تحدي النهارده'
                            : 'اليوم خارج أيام التحدي',
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'سجل التزامك',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: List.generate((p['duration'] as num).toInt(), (
                        i,
                      ) {
                        final start = DateTime.parse('${p['start']}');
                        final d = start.add(Duration(days: i));
                        final day =
                            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        final done = (p['checkedDays'] as List).contains(day);
                        final scheduled = (p['weekdays'] as List).contains(
                          d.weekday % 7,
                        );
                        return Semantics(
                          label:
                              '$day: ${done
                                  ? 'مكتمل'
                                  : scheduled
                                  ? 'غير مكتمل'
                                  : 'راحة'}',
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: done
                                  ? AppColors.nu
                                  : scheduled
                                  ? AppColors.card
                                  : AppColors.bg2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: done ? Colors.white : AppColors.muted,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: p['ended'] == true || saving ? null : join,
                      child: Text(
                        p['ended'] == true ? 'انتهى التحدي' : 'انضم للتحدي',
                      ),
                    ),
                  ],
                  if (p['team'] == true) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'أكثر 3 مشاركين التزاما',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'حسب تسجيل المشاركين اليومي. التعادل يرتب بالأسبق انضماما، والأيام السابقة للانضمام لا تسجل',
                      style: TextStyle(color: AppColors.muted, height: 1.7),
                    ),
                    ...communityRows(p['leaders']).map(
                      (l) => Card(
                        child: ListTile(
                          leading: const FormaIcon(
                            Icons.emoji_events_rounded,
                            color: AppColors.warning,
                          ),
                          title: Text(
                            '${l['rank']}. ${l['displayName']}${l['isMe'] == true ? ' · أنت' : ''}',
                          ),
                          subtitle: Text('${l['completed']} يوم مكتمل'),
                          trailing: Text('${l['consistency']}٪'),
                        ),
                      ),
                    ),
                  ],
                  if (p['team'] != true)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: TextButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('حذف التحدي؟'),
                                    content: const Text(
                                      'هيتم حذف التحدي وسجل أيامه نهائيا',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('إلغاء'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('حذف'),
                                      ),
                                    ],
                                  ),
                                );
                                if (yes == true && mounted)
                                  action('delete', {});
                              },
                        child: const Text(
                          'حذف التحدي',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class ChallengeEditor extends StatefulWidget {
  const ChallengeEditor({super.key, this.item});
  final Map<String, dynamic>? item;
  @override
  State<ChallengeEditor> createState() => _ChallengeEditorState();
}

class _ChallengeEditorState extends State<ChallengeEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, description, duration;
  String type = 'custom';
  late DateTime start;
  TimeOfDay? time;
  Set<int> weekdays = {0, 1, 2, 3, 4, 5, 6};
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = widget.item ?? {};
    title = TextEditingController(text: '${p['title'] ?? ''}');
    description = TextEditingController(text: '${p['description'] ?? ''}');
    duration = TextEditingController(text: '${p['duration'] ?? 30}');
    type = '${p['type'] ?? 'custom'}';
    start = DateTime.tryParse('${p['start']}') ?? DateTime.now();
    weekdays = Set<int>.from(p['weekdays'] as List? ?? [0, 1, 2, 3, 4, 5, 6]);
    final parts = '${p['reminderTime'] ?? ''}'.split(':');
    if (parts.length == 2)
      time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    duration.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    if (weekdays.isEmpty) {
      setState(() => error = 'اختار يوما واحدا على الأقل');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final p = widget.item ?? {};
    final owner = Api.I.accountId;
    final r = await Api.I.communityAction('challenge', {
      'id': p['id'],
      'title': title.text.trim(),
      'description': description.text.trim(),
      'duration': int.parse(duration.text),
      'type': type,
      'start':
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      'weekdays': weekdays.toList(),
      'offsetMinutes':
          p['offsetMinutes'] ?? DateTime.now().timeZoneOffset.inMinutes,
      'reminderTime': time == null
          ? ''
          : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
    });
    if (!mounted || owner != Api.I.accountId) return;
    if (r.ok) {
      Navigator.pop(context, true);
    } else
      setState(() {
        saving = false;
        error = '${r.data['error'] ?? 'تعذر الحفظ'}';
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.item == null ? 'ابدأ تحديك' : 'تعديل التحدي'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text(
            'اختار عادة صغيرة وهدف واضح تقدر تسجله كل يوم',
            style: TextStyle(color: AppColors.muted, height: 1.8),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'اسم التحدي'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'اكتب اسم التحدي' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'هدفك اليومي وقواعد التحدي',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'نوع التحدي'),
            items:
                const {
                      'custom': 'مخصص',
                      'movement': 'حركة',
                      'nutrition': 'تغذية',
                      'water': 'مياه',
                      'sleep': 'نوم',
                    }.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
            onChanged: (v) => setState(() => type = v!),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'المدة بالأيام (1–365)',
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 365
                  ? 'اكتب عددا من 1 إلى 365'
                  : null;
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('تاريخ البداية'),
            subtitle: Text('${start.year}/${start.month}/${start.day}'),
            trailing: const FormaIcon(Icons.calendar_month_outlined),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: start,
                firstDate: start.isBefore(now)
                    ? start
                    : DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 730)),
              );
              if (d != null) setState(() => start = d);
            },
          ),
          const Text('أيام الالتزام'),
          Wrap(
            spacing: 6,
            children:
                const {
                      6: 'السبت',
                      0: 'الأحد',
                      1: 'الاثنين',
                      2: 'الثلاثاء',
                      3: 'الأربعاء',
                      4: 'الخميس',
                      5: 'الجمعة',
                    }.entries
                    .map(
                      (e) => FilterChip(
                        label: Text(e.value),
                        selected: weekdays.contains(e.key),
                        onSelected: (v) => setState(
                          () =>
                              v ? weekdays.add(e.key) : weekdays.remove(e.key),
                        ),
                      ),
                    )
                    .toList(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('وقت تنفيذ التحدي'),
            subtitle: Text(time?.format(context) ?? 'اختياري'),
            trailing: const FormaIcon(Icons.schedule_rounded),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: time ?? const TimeOfDay(hour: 18, minute: 0),
              );
              if (t != null) setState(() => time = t);
            },
          ),
          if (time != null)
            TextButton(
              onPressed: () => setState(() => time = null),
              child: const Text('إزالة الوقت'),
            ),
          const Text(
            'وقت التنفيذ لتنظيم يومك. التسجيل متاح خلال يوم التحدي، ولن يتغير سجل الأيام عند تعديل الاسم أو الوصف',
            style: TextStyle(color: AppColors.muted, height: 1.7, fontSize: 12),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'جار الحفظ…' : 'حفظ التحدي'),
          ),
        ],
      ),
    ),
  );
}
