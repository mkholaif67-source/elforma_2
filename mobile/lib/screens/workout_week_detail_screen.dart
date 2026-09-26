import 'package:flutter/material.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/forma_design.dart';
import 'package:elforma/models/engine_contracts.dart';

/// Read-only drill-down over the exact completed sets already saved by the
/// training session flow. This screen never edits the plan or progression.
class WorkoutWeekDetailScreen extends StatelessWidget {
  const WorkoutWeekDetailScreen({super.key, required this.week, this.latest = false});

  final Map<String, dynamic> week;
  final bool latest;

  num _n(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;
  List<Map<String, dynamic>> _maps(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
      : const <Map<String, dynamic>>[];

  String _shortDate(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '$value';
    return '${date.day}/${date.month}';
  }

  String _volume(dynamic value) {
    final amount = _n(value).toDouble();
    return amount >= 1000 ? '${(amount / 1000).toStringAsFixed(1)} طن' : '${amount.toStringAsFixed(0)} كجم';
  }

  String _duration(dynamic value) {
    final minutes = _n(value).toInt() ~/ 60;
    if (minutes <= 0) return '—';
    return minutes >= 60 ? '${minutes ~/ 60}س ${minutes % 60}د' : '$minutes د';
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _maps(week['sessions']);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(latest ? 'الأسبوع الحالي' : 'أسبوع ${_shortDate(week['start'])}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        children: [
          _hero(),
          const SizedBox(height: 16),
          _comparison(),
          if (_maps(week['insights']).isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle('تحليل المدرب الذكي', 'الخلاصة المهمة من بيانات الأسبوع'),
            const SizedBox(height: 10),
            ..._maps(week['insights']).map(_insight),
          ],
          const SizedBox(height: 20),
          const _SectionTitle('أيام التدريب', 'تظهر الأيام اللي اكتملت واتسجلت فقط'),
          const SizedBox(height: 10),
          ...sessions.map((session) => _dayCard(context, session)),
          const SizedBox(height: 14),
          const _MethodNote(),
        ],
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: FormaDecoration(
          gradient: const LinearGradient(colors: [AppColors.nu, AppColors.wo]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: FormaDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(13)),
              child: const FormaIcon(Icons.calendar_month_rounded, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_shortDate(week['start'])} — ${_shortDate(week['end'])}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
              const SizedBox(height: 3),
              Text('${_n(week['sessionCount']).toInt()} أيام تدريب مسجلة',
                  style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 12)),
            ])),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            _heroMetric('${_n(week['setCount']).toInt()}', 'مجموعة'),
            _heroMetric(_volume(week['volume']), 'حجم العمل'),
            _heroMetric(_duration(week['durationSec']), 'وقت التدريب'),
          ]),
        ]),
      );

  Widget _heroMetric(String value, String label) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 10)),
        ]),
      );

  Widget _comparison() {
    final raw = week['comparison'];
    if (raw is! Map) {
      return _plainCard(
        icon: Icons.flag_outlined,
        title: 'أول أسبوع قابل للتحليل',
        body: 'ده خط أساسك. بعد أسبوع تدريب آخر هتظهر مقارنة دقيقة بنفس البيانات المسجلة.',
      );
    }
    final comparison = Map<String, dynamic>.from(raw);
    final volumeDelta = comparison['volumeDeltaPct'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: FormaDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          FormaIcon(Icons.compare_arrows_rounded, color: AppColors.nu, size: 20),
          SizedBox(width: 8),
          Text('مقارنة بالأسبوع السابق', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _deltaMetric('الجلسات', _n(comparison['sessionsDelta']).toDouble(), false),
          _deltaMetric('المجموعات', _n(comparison['setsDelta']).toDouble(), false),
          _deltaMetric('حجم العمل', volumeDelta == null ? null : _n(volumeDelta).toDouble(), true),
        ]),
      ]),
    );
  }

  Widget _deltaMetric(String label, double? value, bool percent) {
    final color = value == null || value == 0 ? AppColors.textSoft : value > 0 ? AppColors.nu : AppColors.warning;
    final shown = value == null ? '—' : '${value > 0 ? '+' : ''}${percent ? value.toStringAsFixed(1) : value.toInt()}${percent ? '%' : ''}';
    return Expanded(child: Column(children: [
      Text(shown, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
    ]));
  }

  Widget _insight(Map<String, dynamic> insight) {
    final type = (insight['type'] ?? 'neutral').toString();
    final color = type == 'positive' ? AppColors.nu : type == 'attention' ? AppColors.warning : AppColors.water;
    final icon = type == 'positive' ? Icons.trending_up_rounded : type == 'attention' ? Icons.priority_high_rounded : Icons.insights_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: FormaDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .22))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 34, height: 34, decoration: FormaDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: FormaIcon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((insight['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 4),
          Text((insight['body'] ?? '').toString(), style: const TextStyle(color: AppColors.textSoft, fontSize: 11.5, height: 1.55)),
        ])),
      ]),
    );
  }

  Widget _dayCard(BuildContext context, Map<String, dynamic> session) {
    final date = DateTime.tryParse('${session['finished_at'] ?? session['started_at']}')?.toLocal();
    const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final dayName = date == null ? 'يوم تدريب' : days[date.weekday - 1];
    final title = WorkoutExercise.splitDayName((session['day_name'] ?? 'جلسة تدريب').toString()).first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkoutDayDetailScreen(session: session))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: FormaDecoration(color: AppColors.wo.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
                child: const FormaIcon(Icons.fitness_center_rounded, color: AppColors.wo),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 4),
                Text('$dayName · ${date == null ? '' : '${date.day}/${date.month}/${date.year}'}', style: const TextStyle(color: AppColors.textSoft, fontSize: 11)),
                const SizedBox(height: 5),
                Text('${_n(session['exerciseCount']).toInt()} تمارين · ${_n(session['setCount']).toInt()} مجموعات · ${_duration(session['duration_sec'])}', style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
              ])),
              const FormaIcon(Icons.chevron_left_rounded, color: AppColors.muted),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _plainCard({required IconData icon, required String title, required String body}) => Container(
        padding: const EdgeInsets.all(15),
        decoration: FormaDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FormaIcon(icon, color: AppColors.nu),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: AppColors.textSoft, height: 1.55, fontSize: 11.5)),
          ])),
        ]),
      );
}

class WorkoutDayDetailScreen extends StatelessWidget {
  const WorkoutDayDetailScreen({super.key, required this.session});
  final Map<String, dynamic> session;

  num _n(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;
  List<Map<String, dynamic>> _maps(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
      : const <Map<String, dynamic>>[];

  String _weight(dynamic value) {
    final amount = _n(value).toDouble();
    return amount > 0 ? '${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)} كجم' : 'وزن الجسم';
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _maps(session['exercises']);
    final title = WorkoutExercise.splitDayName((session['day_name'] ?? 'جلسة تدريب').toString()).first;
    final date = DateTime.tryParse('${session['finished_at'] ?? session['started_at']}')?.toLocal();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: FormaDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(date == null ? 'جلسة مكتملة' : '${date.day}/${date.month}/${date.year}', style: const TextStyle(color: AppColors.nu, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),
              Row(children: [
                _metric('${_n(session['exerciseCount']).toInt()}', 'تمارين'),
                _metric('${_n(session['setCount']).toInt()}', 'مجموعات'),
                _metric('${(_n(session['volume']) / 1000).toStringAsFixed(1)} طن', 'حجم العمل'),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('تفاصيل التمارين', 'الوزن والتكرارات وRIR لكل مجموعة'),
          const SizedBox(height: 10),
          ...exercises.map(_exerciseCard),
          const SizedBox(height: 8),
          const _MethodNote(),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
      ]));

  Widget _exerciseCard(Map<String, dynamic> exercise) {
    final sets = _maps(exercise['sets']);
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: FormaDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 34, height: 34, decoration: FormaDecoration(color: AppColors.wo.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: const FormaIcon(Icons.fitness_center_rounded, color: AppColors.wo, size: 17)),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((exercise['name'] ?? 'تمرين').toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
            const SizedBox(height: 3),
            Text((exercise['muscleName'] ?? 'عضلات متعددة').toString(), style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
          ])),
          if (exercise['bestE1rm'] != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_n(exercise['bestE1rm']).toStringAsFixed(1)} كجم', style: const TextStyle(color: AppColors.nu, fontWeight: FontWeight.w900, fontSize: 12)),
              const Text('قوة تقديرية', style: TextStyle(color: AppColors.muted, fontSize: 8.5)),
            ]),
        ]),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: FormaDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Expanded(child: Text('المجموعة', style: TextStyle(color: AppColors.muted, fontSize: 9.5))),
            Expanded(child: Text('الوزن', style: TextStyle(color: AppColors.muted, fontSize: 9.5))),
            Expanded(child: Text('التكرار', style: TextStyle(color: AppColors.muted, fontSize: 9.5))),
            Expanded(child: Text('RIR', style: TextStyle(color: AppColors.muted, fontSize: 9.5))),
          ]),
        ),
        ...sets.map((set) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(children: [
            Expanded(child: Text('${_n(set['set_number']).toInt()}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
            Expanded(child: Text(_weight(set['weight']), style: const TextStyle(fontSize: 11.5))),
            Expanded(child: Text('${_n(set['reps']).toInt()}', style: const TextStyle(fontSize: 11.5))),
            Expanded(child: Text(set['rir'] == null ? '—' : _n(set['rir']).toStringAsFixed(1), style: const TextStyle(fontSize: 11.5))),
          ]),
        )),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: AppColors.textSoft, fontSize: 11.5)),
      ]);
}

class _MethodNote extends StatelessWidget {
  const _MethodNote();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: FormaDecoration(color: AppColors.water.withValues(alpha: .06), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.water.withValues(alpha: .18))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FormaIcon(Icons.info_outline_rounded, color: AppColors.water, size: 17),
          SizedBox(width: 8),
          Expanded(child: Text('التحليل مبني على المجموعات المكتملة المسجلة. حجم العمل = الوزن × التكرارات، والقوة التقديرية تتحسب للمجموعات من 1 إلى 12 تكرار فقط؛ المؤشرات تساعدك على المتابعة وليست تشخيص طبي.', style: TextStyle(color: AppColors.textSoft, fontSize: 10.5, height: 1.55))),
        ]),
      );
}
