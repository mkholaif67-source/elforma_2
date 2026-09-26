import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/ui/widgets/cue_banner.dart';
import '../tool/form_coach_regression.dart' as regression;

void main() {
  test('shared movement and engine stabilization regressions', regression.main);
  testWidgets('first correction is visible and its timer is disposed on exit', (tester) async {
    const cue = FormCue(id:'test', textAr:'ثبّت الجسم', kind:FormCueKind.formError,
      severity:RuleSeverity.major, priority:1, tMs:100);
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:CueBanner(cue:cue))));
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds:3));
    expect(tester.takeException(), isNull);
  });
}
