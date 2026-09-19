import 'package:elforma/widgets/forma_design.dart';
// ── ElForma · screens/progress_screen.dart ──
// Progress charts (weight / measurements) computed from logged history.
// مخططات التقدم من السجل.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:elforma/api.dart';
import 'package:elforma/theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool loading = true;
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> weights = [];
  List<Map<String, dynamic>> measurements = [];
  Map<String, dynamic> profile = {};
  Map<String, dynamic> story = {};

  num _number(dynamic value) {
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    final responses = await Future.wait<ApiResult>([
      Api.I.mobileBootstrap(),
      Api.I.progressStory(),
    ]);
    if (!mounted) return;
    final response = responses[0];
    final storyResponse = responses[1];
    setState(() {
      loading = false;
      if (response.ok) {
        weights = response.data['weights'] is List
            ? (response.data['weights'] as List).whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item)).toList()
            : [];
        measurements = response.data['measurements'] is List
            ? (response.data['measurements'] as List).whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item)).toList()
            : [];
        profile = response.data['profile'] is Map
            ? Map<String, dynamic>.from(response.data['profile']) : {};
      } else {
        error = response.friendlyError('تعذر تحميل تقدمك');
      }
      if (storyResponse.ok && storyResponse.data['summary'] is Map) {
        story = Map<String, dynamic>.from(storyResponse.data);
      }
    });
    final moments = storyResponse.ok && storyResponse.data['moments'] is List
        ? storyResponse.data['moments'] as List
        : const [];
    if (moments.isNotEmpty) {
      unawaited(Api.I.acknowledgeProgressMoments(
          moments.map((item) => item is Map ? item['id'] : null).where((id) => id != null).toList()));
    }
  }

  Future<void> _logProgress() async {
    final fields = <String, TextEditingController>{
      'weight': TextEditingController(), 'waist': TextEditingController(),
      'chest': TextEditingController(), 'hips': TextEditingController(),
      'arm': TextEditingController(), 'thigh': TextEditingController(),
      'bodyFat': TextEditingController(),
    };
    if (weights.isNotEmpty) fields['weight']!.text = '${weights.first['weight'] ?? ''}';
    if (measurements.isNotEmpty) {
      final latest = measurements.first;
      for (final key in ['waist','chest','hips','arm','thigh','bodyFat']) {
        final sourceKey = key == 'bodyFat' ? 'body_fat' : key;
        if (latest[sourceKey] != null) fields[key]!.text = '${latest[sourceKey]}';
      }
    }
    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).viewInsets.bottom + 22),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('تسجيل تقدم اليوم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            IconButton(tooltip: 'إقفال', onPressed: () => Navigator.pop(context), icon: const FormaIcon(Icons.close)),
          ]),
          const Text('سجل ما قسته فقط؛ باقي الخانات اختيارية', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          _field(fields['weight']!, 'الوزن', 'كجم'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(fields['waist']!, 'محيط الخصر', 'سم')),
            const SizedBox(width: 9),
            Expanded(child: _field(fields['chest']!, 'محيط الصدر', 'سم')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(fields['hips']!, 'محيط الحوض', 'سم')),
            const SizedBox(width: 9),
            Expanded(child: _field(fields['arm']!, 'محيط الذراع', 'سم')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(fields['thigh']!, 'محيط الفخذ', 'سم')),
            const SizedBox(width: 9),
            Expanded(child: _field(fields['bodyFat']!, 'نسبة الدهون', '%')),
          ]),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.nu,
                foregroundColor: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ قياسات اليوم', style: TextStyle(fontWeight: FontWeight.w900)),
          )),
        ])),
      ),
    );
    if (shouldSave != true || !mounted) {
      for (final controller in fields.values) controller.dispose();
      return;
    }
    double? value(String key) => double.tryParse(fields[key]!.text.trim());
    final weight = value('weight');
    final measurement = <String, dynamic>{
      if (value('waist') != null) 'waist': value('waist'),
      if (value('chest') != null) 'chest': value('chest'),
      if (value('hips') != null) 'hips': value('hips'),
      if (value('arm') != null) 'arm': value('arm'),
      if (value('thigh') != null) 'thigh': value('thigh'),
      if (value('bodyFat') != null) 'bodyFat': value('bodyFat'),
    };
    for (final controller in fields.values) controller.dispose();
    if (weight == null && measurement.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اكتب الوزن أو قياسا واحدا على الأقل')));
      return;
    }
    setState(() => saving = true);
    final futures = <Future<ApiResult>>[];
    if (weight != null) futures.add(Api.I.saveWeight(weight));
    if (measurement.isNotEmpty) futures.add(Api.I.saveMeasurement(measurement));
    final results = await Future.wait(futures);
    if (!mounted) return;
    setState(() => saving = false);
    if (results.every((result) => result.ok)) {
      await _load();
    } else {
      final failed = results.firstWhere((result) => !result.ok);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(failed.friendlyError('تعذر حفظ القياسات'))));
    }
  }

  Widget _field(TextEditingController controller, String label, String unit) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: unit),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('تقدمك', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saving ? null : _logProgress,
        backgroundColor: AppColors.nu,
        foregroundColor: const Color(0xFFFFFFFF),
        icon: saving ? const SizedBox(width: 18, height: 18, child: FormaLoader(strokeWidth: 2)) : const FormaIcon(Icons.add_chart_rounded),
        label: const Text('سجل تقدمك', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: loading
          ? const Center(child: FormaLoader(color: AppColors.nu))
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: AppColors.wo2)))
              : RefreshIndicator(color: AppColors.nu, onRefresh: _load, child: _content()),
    );
  }

  Widget _content() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          if (story.isNotEmpty) ...[
            _storyCard(),
            const SizedBox(height: 14),
          ],
          _weightSummary(),
          const SizedBox(height: 14),
          _weightChart(),
          const SizedBox(height: 18),
          const Text('آخر القياسات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _measurementCards(),
          if (weights.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('سجل الوزن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            ...weights.take(10).map(_weightRow),
          ],
        ],
      );

  Widget _storyCard() {
    final summary = story['summary'] is Map ? Map<String, dynamic>.from(story['summary']) : <String, dynamic>{};
    final events = story['events'] is List ? story['events'] as List : const [];
    final moments = story['moments'] is List ? story['moments'] as List : const [];
    final firstMoment = moments.isNotEmpty && moments.first is Map ? Map<String, dynamic>.from(moments.first as Map) : null;
    final title = firstMoment == null ? 'قصة تقدمك' : _eventTitle(firstMoment);
    final subtitle = firstMoment == null ? 'ملخص موثق من سجلك الحقيقي' : _eventSubtitle(firstMoment);
    final sessionCount = _number(summary['sessions']).round();
    final eventCount = _number(summary['eventCount']).round();
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: FormaDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          FormaIcon(firstMoment == null ? Icons.auto_graph_rounded : Icons.celebration_rounded, color: AppColors.nu, size: 24),
          const SizedBox(width: 9),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
        ]),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: AppColors.muted, height: 1.35)),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: _storyStat('جلسات', '$sessionCount')),
          Expanded(child: _storyStat('إنجازات', '$eventCount')),
          Expanded(child: _storyStat('الشهر', '${story['month'] ?? '—'}')),
        ]),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...events.take(4).map((item) => _storyEvent(item)),
        ],
        if (events.isEmpty && summary['weightStart'] == null && sessionCount == 0)
          const Padding(padding: EdgeInsets.only(top: 10), child: Text('سجل وزنك أو أكمل تمرينا لنبني قصة حقيقية لتقدمك.', style: TextStyle(color: AppColors.muted))),
      ]),
    );
  }

  Widget _storyStat(String label, String value) => Column(children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.nu)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
      ]);

  Map<String, dynamic> _payload(dynamic item) => item is Map && item['payload'] is Map
      ? Map<String, dynamic>.from(item['payload'] as Map) : <String, dynamic>{};

  String _eventTitle(Map<String, dynamic> item) {
    switch ('${item['type']}') {
      case 'new_pr': return 'رقم جديد 🔥';
      case 'training_consistency': return 'ثبات ممتاز 💪';
      case 'weight_milestone': return 'محطة وزن جديدة ⚖️';
      case 'adherence_milestone': return 'التزام غذائي ممتاز ✅';
      default: return 'لحظة تقدم';
    }
  }

  String _eventSubtitle(Map<String, dynamic> item) {
    final p = _payload(item);
    switch ('${item['type']}') {
      case 'new_pr': return 'وصلت ${p['exerciseName'] ?? 'في تمرينك'} إلى ${_number(p['e1rm']).toStringAsFixed(1)} كجم e1RM.';
      case 'training_consistency': return 'أكملت ${_number(p['completedSessions']).round()} جلسات موثقة.';
      case 'weight_milestone': return p['targetReached'] == true ? 'وصلت إلى وزنك المستهدف المسجل.' : 'حققت تغيرا قدره ${_number(p['changeKg']).toStringAsFixed(1)} كجم من خط الأساس.';
      case 'adherence_milestone': return 'تسجيلك الغذائي وتطابق السعرات مع الهدف كانا داخل النطاق الموثوق.';
      default: return 'إنجاز مبني على بياناتك المسجلة فقط.';
    }
  }

  Widget _storyEvent(dynamic raw) {
    final item = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 3), child: FormaIcon(Icons.check_circle_outline_rounded, color: AppColors.nu, size: 17)),
        const SizedBox(width: 8),
        Expanded(child: Text(_eventSubtitle(item), style: const TextStyle(fontSize: 12.5, height: 1.3))),
      ]),
    );
  }

  Widget _weightSummary() {
    final current = weights.isNotEmpty ? _number(weights.first['weight']) : _number(profile['weight']);
    final target = _number(profile['targetWeight']);
    final oldest = weights.length > 1 ? _number(weights.last['weight']) : current;
    final change = current - oldest;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: FormaDecoration(
        gradient: const LinearGradient(colors: [AppColors.nu, AppColors.nu2]),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(children: [
        Expanded(child: _summaryValue('الوزن الحالي', current > 0 ? '${current.toStringAsFixed(1)} كجم' : '—')),
        Expanded(child: _summaryValue('التغيير', weights.length > 1 ? '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} كجم' : '—')),
        Expanded(child: _summaryValue('الهدف', target > 0 ? '${target.toStringAsFixed(1)} كجم' : '—')),
      ]),
    );
  }

  Widget _summaryValue(String label, String value) => Column(children: [
        Text(value, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFFEAF2E4), fontSize: 10.5)),
      ]);

  Widget _weightChart() {
    final points = weights.reversed.take(30).map((item) => _number(item['weight']).toDouble()).where((value) => value > 0).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: FormaDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('اتجاه الوزن', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        SizedBox(height: 150, width: double.infinity,
          child: points.length < 2
              ? const Center(child: Text('سجل وزنك مرتين لظهور الاتجاه', style: TextStyle(color: AppColors.muted)))
              : CustomPaint(painter: _WeightChartPainter(points))),
      ]),
    );
  }

  Widget _measurementCards() {
    if (measurements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: FormaDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.line)),
        child: const Text('لم تسجل قياسات جسم بعد', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      );
    }
    final latest = measurements.first;
    final items = <MapEntry<String, dynamic>>[
      MapEntry('الخصر', latest['waist']), MapEntry('الصدر', latest['chest']),
      MapEntry('الحوض', latest['hips']), MapEntry('الذراع', latest['arm']),
      MapEntry('الفخذ', latest['thigh']), MapEntry('الدهون', latest['body_fat']),
    ].where((item) => item.value != null).toList();
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: items.map((item) => Container(
        width: (MediaQuery.of(context).size.width - 54) / 2,
        padding: const EdgeInsets.all(14),
        decoration: FormaDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.key, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 5),
          Text('${_number(item.value).toStringAsFixed(1)} ${item.key == 'الدهون' ? '%' : 'سم'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.nu)),
        ]),
      )).toList(),
    );
  }

  Widget _weightRow(Map<String, dynamic> item) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: FormaDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line)),
        child: Row(children: [
          const FormaIcon(Icons.monitor_weight_outlined, color: AppColors.nu, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text((item['day'] ?? '').toString(), style: const TextStyle(color: AppColors.muted))),
          Text('${_number(item['weight']).toStringAsFixed(1)} كجم', style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      );
}

class _WeightChartPainter extends CustomPainter {
  final List<double> values;
  _WeightChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1.0, maxValue - minValue);
    final line = Paint()..color = AppColors.nu..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final grid = Paint()..color = AppColors.line..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minValue) / range * (size.height - 16)) - 8;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, line);
    final point = Paint()..color = AppColors.nu2;
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minValue) / range * (size.height - 16)) - 8;
      canvas.drawCircle(Offset(x, y), 4, point);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) => oldDelegate.values != values;
}
