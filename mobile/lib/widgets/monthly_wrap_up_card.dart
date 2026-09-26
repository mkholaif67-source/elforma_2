import 'package:flutter/material.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/forma_design.dart';

/// A friendly, read-only recap built only from the member's recorded data.
/// Dismissing it never deletes the recap; the same month remains available
/// from the Progress screen.
class MonthlyWrapUpCard extends StatefulWidget {
  const MonthlyWrapUpCard({super.key, required this.story});

  final Map<String, dynamic> story;

  @override
  State<MonthlyWrapUpCard> createState() => _MonthlyWrapUpCardState();
}

class _MonthlyWrapUpCardState extends State<MonthlyWrapUpCard> {
  final PageController _controller = PageController();
  int _page = 0;

  num _n(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;

  Map<String, dynamic> get _summary => widget.story['summary'] is Map
      ? Map<String, dynamic>.from(widget.story['summary'] as Map)
      : <String, dynamic>{};

  List<dynamic> get _events => widget.story['events'] is List
      ? widget.story['events'] as List
      : const [];

  String get _monthLabel {
    final raw = '${widget.story['month'] ?? ''}';
    final parts = raw.split('-');
    if (parts.length != 2) return 'الشهر اللي فات';
    const names = ['يناير', 'فبراير', 'مارس', 'ابريل', 'مايو', 'يونيو',
      'يوليو', 'اغسطس', 'سبتمبر', 'اكتوبر', 'نوفمبر', 'ديسمبر'];
    final month = int.tryParse(parts[1]);
    return month != null && month >= 1 && month <= 12
        ? '${names[month - 1]} ${parts[0]}'
        : raw;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _cover(),
      _training(),
      _bodyProgress(),
      _nutrition(),
      if (_events.isNotEmpty) _achievements(),
    ];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 650),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 14))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Expanded(child: PageView(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (value) => setState(() => _page = value),
            children: pages,
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(pages.length, (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: index == _page ? 22 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: index == _page ? AppColors.nu : AppColors.line, borderRadius: BorderRadius.circular(8)),
              ))),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, height: 48, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.nu, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () {
                  if (_page < pages.length - 1) {
                    _controller.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(_page < pages.length - 1 ? 'كمل الحصاد' : 'جاهز للشهر الجديد',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              )),
              const SizedBox(height: 7),
              Text('اسحب يمين وشمال لمشاهدة كل النتائج', style: TextStyle(fontSize: 11, color: AppColors.muted.withValues(alpha: .9))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pageShell(IconData icon, String title, String subtitle, List<Widget> children,
      {Color color = AppColors.nu}) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(18)),
          child: Center(child: FormaIcon(icon, color: color, size: 28))),
      const SizedBox(height: 18),
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.25)),
      const SizedBox(height: 7),
      Text(subtitle, style: const TextStyle(color: AppColors.muted, height: 1.45)),
      const SizedBox(height: 22),
      ...children,
    ]),
  );

  Widget _cover() {
    final sessions = _n(_summary['sessions']).round();
    final logged = _n(_summary['nutritionLoggedDays']).round();
    final wins = _n(_summary['eventCount']).round();
    return _pageShell(Icons.celebration_rounded, 'حصاد $_monthLabel',
      'كل خطوة سجلتها اتجمعت هنا. شوف وصلت لفين وخد دفعة جديدة للشهر الجاي.', [
        _heroNumber('${sessions + logged}', 'يوم وجلسة مسجلين'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _miniStat('$sessions', 'جلسة تمرين')),
          const SizedBox(width: 9),
          Expanded(child: _miniStat('$logged', 'يوم تغذية')),
          const SizedBox(width: 9),
          Expanded(child: _miniStat('$wins', 'انجاز')),
        ]),
      ], color: const Color(0xFFE29A24));
  }

  Widget _training() {
    final sessions = _n(_summary['sessions']).round();
    final sets = _n(_summary['sets']).round();
    final volume = _n(_summary['totalVolume']);
    return _pageShell(Icons.fitness_center_rounded, 'مجهودك في التمرين',
      sessions > 0 ? 'كل جلسة كملتها اتحسبت في حصاد الشهر.' : 'مفيش جلسات مكتملة مسجلة في الشهر ده.', [
        Row(children: [Expanded(child: _bigStat('$sessions', 'جلسة مكتملة')), const SizedBox(width: 10), Expanded(child: _bigStat('$sets', 'مجموعة'))]),
        const SizedBox(height: 10),
        _wideStat(volume > 0 ? volume.toStringAsFixed(0) : '0', 'كجم حجم تمرين مسجل'),
      ], color: const Color(0xFF267A4A));
  }

  Widget _bodyProgress() {
    final start = _summary['weightStart'];
    final end = _summary['weightEnd'];
    final change = _n(_summary['weightChange']);
    final measurementDays = _n(_summary['measurementDays']).round();
    String value(dynamic v) => v == null ? '—' : '${_n(v).toStringAsFixed(1)} كجم';
    final changeText = start == null || end == null ? '—' : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} كجم';
    return _pageShell(Icons.monitor_weight_rounded, 'تغير جسمك',
      start != null || measurementDays > 0 ? 'دي مقارنة بين أول وآخر تسجيل موجودين في الشهر.' : 'سجل وزنك وقياساتك الشهر الجاي علشان تشوف الفرق بوضوح.', [
        Row(children: [Expanded(child: _bigStat(value(start), 'بداية الشهر')), const SizedBox(width: 10), Expanded(child: _bigStat(value(end), 'آخر تسجيل'))]),
        const SizedBox(height: 10),
        _wideStat(changeText, 'التغير خلال الشهر'),
        const SizedBox(height: 10),
        _wideStat('$measurementDays', 'ايام سجلت فيها قياسات جسم'),
      ], color: const Color(0xFF6A4FB3));
  }

  Widget _nutrition() {
    final days = _n(_summary['nutritionLoggedDays']).round();
    final accuracy = _summary['calorieAccuracy'];
    final targetDays = _n(_summary['calorieTargetDays']).round();
    final waterDays = _n(_summary['waterGoalDays']).round();
    return _pageShell(Icons.restaurant_rounded, 'التزامك اليومي',
      days > 0 ? 'النتائج مبنية على الايام اللي سجلتها فعلا.' : 'مفيش ايام تغذية مسجلة في الشهر ده.', [
        Row(children: [
          Expanded(child: _bigStat('$days', 'يوم تغذية')),
          const SizedBox(width: 10),
          Expanded(child: _bigStat(accuracy == null ? '—' : '${_n(accuracy).round()}%', 'دقة السعرات')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _bigStat('$targetDays', 'يوم قريب من الهدف')),
          const SizedBox(width: 10),
          Expanded(child: _bigStat('$waterDays', 'يوم هدف المياه')),
        ]),
      ], color: AppColors.water);
  }

  Widget _achievements() => _pageShell(Icons.emoji_events_rounded, 'انجازات تستاهل تفتخر بيها',
    'دي اهم المحطات اللي حققتها من تسجيلاتك الحقيقية.', [
      ..._events.take(6).map((raw) {
        final item = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        return Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
          child: Row(children: [const FormaIcon(Icons.check_circle_rounded, color: AppColors.nu, size: 20), const SizedBox(width: 9), Expanded(child: Text(_eventText(item), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)))]));
      }),
    ], color: const Color(0xFFE29A24));

  String _eventText(Map<String, dynamic> item) {
    final payload = item['payload'] is Map ? Map<String, dynamic>.from(item['payload'] as Map) : <String, dynamic>{};
    switch ('${item['type']}') {
      case 'new_pr': return 'رقم جديد في ${payload['exerciseName'] ?? 'تمرينك'}';
      case 'training_consistency': return 'كملت ${_n(payload['completedSessions']).round()} جلسات';
      case 'weight_milestone': return payload['targetReached'] == true ? 'وصلت لوزنك المستهدف' : 'وصلت لمحطة وزن جديدة';
      case 'adherence_milestone': return 'التزام ممتاز بالسعرات والتسجيل';
      default: return 'خطوة جديدة في تقدمك';
    }
  }

  Widget _heroNumber(String value, String label) => Container(width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.nu, AppColors.nu2]), borderRadius: BorderRadius.circular(20)),
    child: Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Color(0xFFEAF2E4), fontWeight: FontWeight.w700))]));

  Widget _miniStat(String value, String label) => Container(padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
    child: Column(children: [Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.nu)), const SizedBox(height: 3), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.muted))]));

  Widget _bigStat(String value, String label) => Container(padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted))]));

  Widget _wideStat(String value, String label) => Container(width: double.infinity, padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
    child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.nu))]));
}

Future<void> showMonthlyWrapUp(BuildContext context, Map<String, dynamic> story) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => MonthlyWrapUpCard(story: story),
);
