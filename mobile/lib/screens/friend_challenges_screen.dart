import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:elforma/api.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/forma_design.dart';
import 'package:elforma/widgets/forma_input_dialog.dart';

List<Map<String, dynamic>> _rows(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

const _kindLabels = <String, String>{
  'workout': 'التمرين',
  'nutrition': 'التغذية',
  'water': 'المياه',
  'steps': 'الخطوات',
  'sleep': 'النوم',
  'mood': 'المزاج',
  'habit': 'عادة يومية',
  'custom': 'تحدي مخصص',
};
const _metricLabels = <String, String>{
  'manual_daily': 'انجاز يومي',
  'manual_value': 'قيمة تسجلها كل يوم',
  'workout_days': 'ايام التمرين المكتملة',
  'workout_max': 'اعلى وزن مسجل',
  'nutrition_days': 'ايام الالتزام بالسعرات',
  'water_days': 'ايام الوصول لهدف المياه',
};
const _scoreLabels = <String, String>{
  'daily': 'نقطة عن كل يوم',
  'sum': 'مجموع القيم',
  'highest': 'اعلى قيمة',
};

class FriendChallengesScreen extends StatefulWidget {
  const FriendChallengesScreen({super.key});
  @override
  State<FriendChallengesScreen> createState() => _FriendChallengesScreenState();
}

class _FriendChallengesScreenState extends State<FriendChallengesScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final owner = Api.I.accountId;
    final result = await Api.I.friendChallenges();
    if (!mounted || owner != Api.I.accountId) return;
    setState(() {
      loading = false;
      error = result.ok ? null : 'تعذر تحميل تحديات الاصحاب';
      if (result.ok) items = _rows(result.data['items']);
    });
  }

  Future<void> create() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FriendChallengeEditor()),
    );
    if (changed == true && mounted) await load();
  }

  Future<void> joinByCode() async {
    final code = await showFormaTextPrompt(
      context,
      title: 'انضم بكود',
      label: 'كود التحدي',
      action: 'عرض التحدي',
      maxLength: 20,
      description: 'اكتب الكود الذي ارسله لك صاحبك',
      validator: (value) => value == null || value.trim().length < 6
          ? 'راجع الكود وحاول مرة اخرى'
          : null,
    );
    if (code == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendChallengePreviewScreen(code: code.trim()),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تحديات الاصحاب')),
        body: loading
            ? const Center(child: FormaLoader())
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                  children: [
                    const Text(
                      'اعمل تحدي خاص وشارك الكود مع اصحابك',
                      style: TextStyle(color: AppColors.muted, height: 1.7),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: create,
                            icon: const FormaIcon(Icons.add_rounded),
                            label: const Text('تحدي جديد'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: joinByCode,
                            icon: const FormaIcon(Icons.key_rounded),
                            label: const Text('انضم بكود'),
                          ),
                        ),
                      ],
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Card(
                          child: ListTile(
                            title: Text(error!),
                            trailing: TextButton(
                              onPressed: load,
                              child: const Text('حاول تاني'),
                            ),
                          ),
                        ),
                      ),
                    if (items.isEmpty && error == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Column(
                              children: [
                                FormaIcon(Icons.groups_rounded,
                                    size: 52, color: AppColors.nu),
                                SizedBox(height: 12),
                                Text('لسه مفيش تحديات مع اصحابك'),
                                SizedBox(height: 6),
                                Text(
                                  'ابدأ تحدي جديد او انضم بكود',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ...items.map(_card),
                  ],
                ),
              ),
      );

  Widget _card(Map<String, dynamic> item) {
    final mine = item['mine'] as Map? ?? {};
    final closed = item['status'] != 'active';
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FriendChallengeDetailScreen(id: '${item['id']}'),
              ),
            );
            if (mounted) await load();
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FormaIcon(Icons.groups_rounded, color: AppColors.nu),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${item['title']}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    if ((item['pendingCount'] as num? ?? 0) > 0)
                      Badge(label: Text('${item['pendingCount']}')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${item['participantCount']} مشارك · ${closed ? 'انتهى' : 'مستمر'}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: ((mine['progress'] as num? ?? 0) / 100)
                      .clamp(0, 1)
                      .toDouble(),
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 7),
                Text('${mine['score'] ?? 0} نقطة · ${mine['progress'] ?? 0}٪'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FriendChallengePreviewScreen extends StatefulWidget {
  const FriendChallengePreviewScreen({super.key, required this.code});
  final String code;
  @override
  State<FriendChallengePreviewScreen> createState() =>
      _FriendChallengePreviewScreenState();
}

class _FriendChallengePreviewScreenState
    extends State<FriendChallengePreviewScreen> {
  bool loading = true, sending = false;
  String? error;
  Map<String, dynamic>? item;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final result = await Api.I.friendChallengePreview(widget.code);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (result.ok) {
        item = Map<String, dynamic>.from(result.data['item'] as Map);
        error = null;
      } else {
        error = result.friendlyError('الدعوة غير متاحة');
      }
    });
  }

  Future<void> requestJoin() async {
    final name = await showFormaTextPrompt(
      context,
      title: 'طلب الانضمام',
      label: 'الاسم الذي سيظهر لاصحابك',
      action: 'ارسال الطلب',
      maxLength: 40,
      description: '${item?['privacyText'] ?? ''}',
      validator: (value) => value == null || value.trim().isEmpty
          ? 'اكتب الاسم الذي سيظهر لاصحابك'
          : null,
    );
    if (name == null || !mounted) return;
    setState(() => sending = true);
    final result = await Api.I.friendChallengeAction('request', {
      'code': widget.code,
      'displayName': name.trim(),
    });
    if (!mounted) return;
    setState(() => sending = false);
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم ارسال طلبك لصاحب التحدي')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.friendlyError('تعذر ارسال الطلب'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = item;
    return Scaffold(
      appBar: AppBar(title: const Text('دعوة لتحدي')),
      body: loading
          ? const Center(child: FormaLoader())
          : data == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error ?? 'الدعوة غير متاحة'),
                      TextButton(onPressed: load, child: const Text('حاول تاني')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const FormaIcon(Icons.flag_rounded,
                        size: 58, color: AppColors.nu),
                    const SizedBox(height: 18),
                    Text('${data['title']}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 25, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('${data['description'] ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.muted, height: 1.7)),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('من ${data['start']} الى ${data['end']}'),
                            const SizedBox(height: 8),
                            Text('${data['participantCount']} مشارك'),
                            const SizedBox(height: 8),
                            Text('${data['privacyText']}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (data['membershipStatus'] == 'active')
                      FilledButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => FriendChallengeDetailScreen(
                              id: '${data['id']}',
                            ),
                          ),
                        ),
                        child: const Text('فتح التحدي'),
                      )
                    else if (data['membershipStatus'] == 'pending')
                      const FilledButton(
                        onPressed: null,
                        child: Text('طلبك في انتظار الموافقة'),
                      )
                    else
                      FilledButton(
                        onPressed: sending ? null : requestJoin,
                        child: Text(sending ? 'جاري الارسال...' : 'اطلب الانضمام'),
                      ),
                  ],
                ),
    );
  }
}

class FriendChallengeEditor extends StatefulWidget {
  const FriendChallengeEditor({super.key, this.personal});
  final Map<String, dynamic>? personal;
  @override
  State<FriendChallengeEditor> createState() => _FriendChallengeEditorState();
}

class _FriendChallengeEditorState extends State<FriendChallengeEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, description, target, unit, maxMembers, exerciseName;
  String kind = 'habit', metric = 'manual_daily', scoring = 'daily';
  late DateTime start, end;
  Set<int> weekdays = {0, 1, 2, 3, 4, 5, 6};
  bool workoutSummary = false, nutritionSummary = false, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final source = widget.personal ?? {};
    final now = DateTime.now();
    start = DateTime(now.year, now.month, now.day);
    title = TextEditingController(text: '${source['title'] ?? ''}');
    description = TextEditingController(text: '${source['description'] ?? ''}');
    target = TextEditingController();
    unit = TextEditingController();
    maxMembers = TextEditingController(text: '10');
    exerciseName = TextEditingController();
    final sourceStart = DateTime.tryParse('${source['start'] ?? ''}');
    if (sourceStart != null && sourceStart.isAfter(start)) start = sourceStart;
    end = start.add(Duration(days: ((source['duration'] as num?)?.toInt() ?? 30) - 1));
    if (source['weekdays'] is List) {
      weekdays = Set<int>.from(source['weekdays'] as List);
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    target.dispose();
    unit.dispose();
    maxMembers.dispose();
    exerciseName.dispose();
    super.dispose();
  }

  bool get needsTarget =>
      ['manual_value', 'workout_max', 'nutrition_days', 'water_days']
          .contains(metric);

  List<String> get availableMetrics {
    switch (kind) {
      case 'workout': return ['workout_days', 'workout_max', 'manual_daily', 'manual_value'];
      case 'nutrition': return ['nutrition_days', 'manual_daily', 'manual_value'];
      case 'water': return ['water_days', 'manual_daily', 'manual_value'];
      default: return ['manual_daily', 'manual_value'];
    }
  }

  List<String> get availableScores => metric == 'manual_value'
      ? ['sum', 'highest']
      : metric == 'workout_max'
          ? ['highest']
          : ['daily'];

  void chooseMetric(String value) {
    setState(() {
      metric = value;
      scoring = metric == 'workout_max'
          ? 'highest'
          : metric == 'manual_value'
              ? 'sum'
              : 'daily';
      if (metric == 'water_days' && unit.text.isEmpty) unit.text = 'مل';
      if (metric == 'workout_max' && unit.text.isEmpty) unit.text = 'كجم';
      if (metric == 'nutrition_days' && unit.text.isEmpty) unit.text = 'سعر';
    });
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    if (weekdays.isEmpty) {
      setState(() => error = 'اختار يوم واحد على الاقل');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    String day(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final result = await Api.I.createFriendChallenge({
      if (widget.personal != null) 'sourcePersonalId': widget.personal!['id'],
      'title': title.text.trim(),
      'description': description.text.trim(),
      'kind': kind,
      'metric': metric,
      'scoring': scoring,
      'target': needsTarget ? double.tryParse(target.text) : null,
      'unit': unit.text.trim(),
      'exerciseKey': metric == 'workout_max' ? exerciseName.text.trim() : null,
      'start': day(start),
      'end': day(end),
      'weekdays': weekdays.toList(),
      'maxMembers': int.tryParse(maxMembers.text),
      'sharing': {
        'workoutSummary': workoutSummary,
        'nutritionSummary': nutritionSummary,
      },
    });
    if (!mounted) return;
    if (result.ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        saving = false;
        error = result.friendlyError('راجع البيانات وحاول مرة اخرى');
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.personal == null
              ? 'تحدي جديد مع اصحابك'
              : 'تحدي اصحابك بنفس الفكرة'),
        ),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            children: [
              const Text(
                'حدد الهدف والقواعد وبعدها شارك الكود مع اصحابك',
                style: TextStyle(color: AppColors.muted, height: 1.7),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'اسم التحدي'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'اكتب اسم التحدي'
                    : null,
              ),
              TextFormField(
                controller: description,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'وصف بسيط'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'نوع التحدي'),
                items: _kindLabels.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  kind = value!;
                  if (!availableMetrics.contains(metric)) {
                    metric = availableMetrics.first;
                    scoring = metric == 'workout_max' ? 'highest' : 'daily';
                  }
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: metric,
                decoration: const InputDecoration(labelText: 'طريقة متابعة التحدي'),
                items: availableMetrics
                    .map((key) => DropdownMenuItem(
                          value: key,
                          child: Text(_metricLabels[key]!),
                        ))
                    .toList(),
                onChanged: (value) => chooseMetric(value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: scoring,
                decoration: const InputDecoration(labelText: 'طريقة حساب النتيجة'),
                items: availableScores
                    .map((key) => DropdownMenuItem(
                          value: key,
                          child: Text(_scoreLabels[key]!),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => scoring = value!),
              ),
              if (metric == 'workout_max') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: exerciseName,
                  decoration: const InputDecoration(
                    labelText: 'اسم التمرين كما يظهر في جدولك',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'اكتب اسم التمرين'
                      : null,
                ),
              ],
              if (needsTarget) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: target,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'الهدف'),
                        validator: (value) => double.tryParse(value ?? '') == null
                            ? 'اكتب الهدف'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: unit,
                        decoration: const InputDecoration(labelText: 'الوحدة'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: maxMembers,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'اقصى عدد للمشاركين'),
                validator: (value) {
                  final count = int.tryParse(value ?? '');
                  return count == null || count < 2 || count > 100
                      ? 'اختار عددا من 2 الى 100'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تاريخ البداية'),
                subtitle: Text('${start.year}/${start.month}/${start.day}'),
                trailing: const FormaIcon(Icons.calendar_month_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: start,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) setState(() {
                    start = picked;
                    if (end.isBefore(start)) end = start;
                  });
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تاريخ النهاية'),
                subtitle: Text('${end.year}/${end.month}/${end.day}'),
                trailing: const FormaIcon(Icons.event_available_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: end.isBefore(start) ? start : end,
                    firstDate: start,
                    lastDate: start.add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => end = picked);
                },
              ),
              const Text('ايام التحدي'),
              Wrap(
                spacing: 6,
                children: const {
                  6: 'السبت',
                  0: 'الاحد',
                  1: 'الاثنين',
                  2: 'الثلاثاء',
                  3: 'الاربعاء',
                  4: 'الخميس',
                  5: 'الجمعة',
                }.entries.map((e) => FilterChip(
                      label: Text(e.value),
                      selected: weekdays.contains(e.key),
                      onSelected: (selected) => setState(() => selected
                          ? weekdays.add(e.key)
                          : weekdays.remove(e.key)),
                    )).toList(),
              ),
              const SizedBox(height: 18),
              const Text('الذي سيظهر للمشاركين',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const CheckboxListTile(
                value: true,
                onChanged: null,
                title: Text('السكور ونسبة التقدم'),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: workoutSummary,
                onChanged: (value) =>
                    setState(() => workoutSummary = value == true),
                title: const Text('ملخص الالتزام بالتمرين'),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: nutritionSummary,
                onChanged: (value) =>
                    setState(() => nutritionSummary = value == true),
                title: const Text('ملخص الالتزام بالتغذية'),
                contentPadding: EdgeInsets.zero,
              ),
              const Text(
                'تفاصيل الوجبات والقياسات والملاحظات الخاصة لا تظهر للمشاركين',
                style: TextStyle(color: AppColors.muted, height: 1.6),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'جاري الحفظ...' : 'انشاء التحدي'),
              ),
            ],
          ),
        ),
      );
}

class FriendChallengeDetailScreen extends StatefulWidget {
  const FriendChallengeDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<FriendChallengeDetailScreen> createState() =>
      _FriendChallengeDetailScreenState();
}

class _FriendChallengeDetailScreenState
    extends State<FriendChallengeDetailScreen> {
  Map<String, dynamic>? item;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final result = await Api.I.friendChallengeDetail(widget.id);
    if (!mounted) return;
    setState(() {
      if (result.ok) {
        item = Map<String, dynamic>.from(result.data['item'] as Map);
        error = null;
      } else {
        error = result.friendlyError('تعذر فتح التحدي');
      }
    });
  }

  Future<ApiResult> action(String name, Map<String, dynamic> body,
      {bool queue = false}) async {
    setState(() => busy = true);
    final result = await Api.I.friendChallengeAction(
      name,
      {'id': widget.id, ...body},
      queueOnFailure: queue,
    );
    if (!mounted) return result;
    setState(() => busy = false);
    if (result.ok) {
      if (name == 'leave') {
        Navigator.pop(context, true);
      } else {
        await load();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.friendlyError('تعذر تنفيذ الطلب'))),
      );
    }
    return result;
  }

  Future<void> invite() async {
    final result = await action('invite', {'maxUses': 10});
    if (!result.ok || !mounted) return;
    final invite = Map<String, dynamic>.from(result.data['invite'] as Map);
    final text = 'انضم لتحدي ${item?['title']} في الفورمة\n'
        '${invite['link']}\n'
        'او استخدم الكود: ${invite['code']}';
    await Share.share(text, subject: 'دعوة لتحدي ${item?['title']}');
  }

  Future<void> log() async {
    final data = item;
    if (data == null) return;
    final metric = '${data['metric']}';
    dynamic value = true;
    if (metric == 'manual_value') {
      final raw = await showFormaTextPrompt(
        context,
        title: 'سجل نتيجتك',
        label: '${data['unit'] ?? 'القيمة'}',
        action: 'حفظ',
        maxLength: 12,
        validator: (text) => double.tryParse(text ?? '') == null
            ? 'اكتب رقما صحيحا'
            : null,
      );
      if (raw == null) return;
      value = double.parse(raw);
    }
    await action('log', {
      'value': value,
      'clientAt': DateTime.now().toUtc().toIso8601String(),
    }, queue: true);
  }

  Future<void> confirmClose() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انهاء التحدي؟'),
        content: const Text('سيتم تثبيت النتيجة النهائية وايقاف الدعوات'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('انهاء')),
        ],
      ),
    );
    if (yes == true) await action('close', {});
  }

  Future<void> confirmLeave() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مغادرة التحدي؟'),
        content: const Text('لن تظهر في الترتيب بعد المغادرة'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('مغادرة')),
        ],
      ),
    );
    if (yes == true) await action('leave', {});
  }

  @override
  Widget build(BuildContext context) {
    final data = item;
    final mine = data?['mine'] as Map? ?? {};
    final owner = data?['role'] == 'owner';
    final active = data?['status'] == 'active';
    final automatic = ['workout_days', 'workout_max', 'nutrition_days', 'water_days']
        .contains('${data?['metric']}');
    return Scaffold(
      appBar: AppBar(
        title: Text('${data?['title'] ?? 'التحدي'}'),
        actions: [
          if (data != null && active)
            IconButton(
              tooltip: 'دعوة صاحب',
              onPressed: busy ? null : invite,
              icon: const FormaIcon(Icons.person_add_alt_1_rounded),
            ),
        ],
      ),
      body: data == null
          ? Center(
              child: error == null
                  ? const FormaLoader()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!),
                        TextButton(onPressed: load, child: const Text('حاول تاني')),
                      ],
                    ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 50),
                children: [
                  Text('${data['description'] ?? ''}',
                      style: const TextStyle(color: AppColors.muted, height: 1.7)),
                  const SizedBox(height: 8),
                  Text('من ${data['start']} الى ${data['end']}'),
                  Text('${data['participantCount']} مشارك'),
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 18),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Text('${mine['score'] ?? 0}',
                              style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.nu)),
                          const Text('نقطتك الحالية'),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: ((mine['progress'] as num? ?? 0) / 100)
                                .clamp(0, 1)
                                .toDouble(),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(height: 10),
                          Text('${mine['completedDays'] ?? 0} يوم مكتمل · ${mine['missedDays'] ?? 0} يوم فات'),
                        ],
                      ),
                    ),
                  ),
                  if (active && data['canLog'] == true && !automatic)
                    FilledButton.icon(
                      onPressed: busy ? null : log,
                      icon: const FormaIcon(Icons.check_rounded),
                      label: Text(busy ? 'جاري الحفظ...' : 'سجل نتيجة اليوم'),
                    )
                  else if (active && automatic)
                    const Card(
                      child: ListTile(
                        leading: FormaIcon(Icons.sync_rounded, color: AppColors.nu),
                        title: Text('نتيجتك تتحدث من بياناتك في التطبيق'),
                      ),
                    ),
                  if (owner && _rows(data['requests']).isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('طلبات الانضمام',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ..._rows(data['requests']).map((request) => Card(
                          child: ListTile(
                            title: Text('${request['displayName']}'),
                            subtitle: Text('وصل عن طريق ${request['invitedBy']}'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'رفض',
                                  onPressed: busy
                                      ? null
                                      : () => action('decide', {
                                            'userId': request['userId'],
                                            'approve': false,
                                          }),
                                  icon: const FormaIcon(Icons.close_rounded),
                                ),
                                IconButton(
                                  tooltip: 'قبول',
                                  onPressed: busy
                                      ? null
                                      : () => action('decide', {
                                            'userId': request['userId'],
                                            'approve': true,
                                          }),
                                  icon: const FormaIcon(Icons.check_rounded,
                                      color: AppColors.nu),
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                  const SizedBox(height: 24),
                  Text(active ? 'الترتيب' : 'النتيجة النهائية',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ..._rows(active ? data['leaderboard'] : data['finalResults']).map(
                    (entry) => Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${entry['rank']}')),
                        title: Text('${entry['displayName']}${entry['isMe'] == true ? ' · انت' : ''}'),
                        subtitle: Text(active
                            ? '${entry['completedDays']} يوم مكتمل · ${entry['progress']}٪'
                            : 'النتيجة النهائية'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${entry['score']}'),
                            if (owner && active && entry['isMe'] != true)
                              IconButton(
                                tooltip: 'ازالة من التحدي',
                                onPressed: busy
                                    ? null
                                    : () => action('remove', {
                                          'userId': entry['memberId'],
                                        }),
                                icon: const FormaIcon(Icons.person_remove_outlined,
                                    color: Colors.red),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (owner && active)
                    OutlinedButton(
                      onPressed: busy ? null : confirmClose,
                      child: const Text('انهاء التحدي'),
                    )
                  else if (!owner && active)
                    TextButton(
                      onPressed: busy ? null : confirmLeave,
                      child: const Text('مغادرة التحدي',
                          style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
    );
  }
}
