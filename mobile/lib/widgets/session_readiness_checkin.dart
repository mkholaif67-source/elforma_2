import 'package:flutter/material.dart';
import 'package:elforma/theme.dart';

/// The check-in step inside the existing training session, before exercise one.
class SessionReadinessCheckin extends StatefulWidget {
  const SessionReadinessCheckin({super.key, required this.onSubmit});
  final Future<bool> Function(Map<String, dynamic>) onSubmit;
  @override
  State<SessionReadinessCheckin> createState() => _SessionReadinessCheckinState();
}

class _SessionReadinessCheckinState extends State<SessionReadinessCheckin> {
  final Map<String, dynamic> _answers = {};
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_saving || _answers.length != 4) return;
    setState(() { _saving = true; _error = null; });
    var ok = false;
    try { ok = await widget.onSubmit(Map.of(_answers)); } catch (_) { /* Show retry below. */ }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _error = 'تعذر حفظ إجاباتك. جرب تاني قبل ما تبدأ';
    });
  }

  Widget _question(String key, String title, Map<int, String> choices) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final choice in choices.entries) ChoiceChip(
          label: Text(choice.value), selected: _answers[key] == choice.key,
          onSelected: _saving ? null : (_) => setState(() => _answers[key] = choice.key),
        ),
      ]),
    ]),
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('جاهز لتمرين النهارده؟')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('طمني على حالك عشان نضبط مجهود الجلسة دي بس', style: TextStyle(height: 1.5)),
        const SizedBox(height: 24),
        _question('sleepHours', 'نمت كام ساعة؟', {5: 'أقل من 6 ساعات', 7: 'من 6 إلى 8 ساعات', 8: '8 ساعات أو أكثر'}),
        _question('fatigue', 'حاسس بتعب قد إيه؟', {0: 'مش تعبان', 1: 'تعب متوسط', 2: 'تعب شديد'}),
        _question('pain', 'في ألم أو إجهاد مش معتاد؟', {0: 'مفيش', 1: 'بسيط', 2: 'واضح أو مزعج'}),
        _question('readiness', 'جاهز للجلسة قد إيه؟', {0: 'جاهز', 1: 'أفضل أخفف شوية', 2: 'جاهزيتي قليلة'}),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!)),
        FilledButton(onPressed: _saving || _answers.length != 4 ? null : _submit,
          child: Padding(padding: const EdgeInsets.all(14), child: Text(_saving ? 'بنحفظ إجاباتك...' : 'ابدأ الجلسة المناسبة لي'))),
      ])),
    ),
  );
}
