import 'package:flutter_test/flutter_test.dart';
import 'package:elforma/features/form_coach/domain/tempo_coach.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';
import 'package:elforma/features/form_coach/domain/form_coach_engine.dart';
import 'package:elforma/features/form_coach/profiles/biceps_curl_profile.dart';
import '../../../../tool/form_coach_regression.dart' as fixture;

RepEvent rep(int ms, {bool assessable = true}) => RepEvent(
    kind: RepEventKind.repCompleted,
    amplitude: 100,
    durationMs: ms,
    assessable: assessable);
void main() {
  test('no prescribed timing never labels speed as an error', () {
    final c = TempoCoach();
    for (var i = 0; i < 10; i++) {
      c.observe(rep(700), null);
    }
    expect(c.warningReady, false);
    expect(c.fastReps, 0);
  });
  test(
      'two fast repetitions warn; two later assessable clean repetitions verify improvement',
      () {
    final c = TempoCoach();
    c.observe(rep(1000), 4000);
    c.observe(rep(1000), 4000);
    expect(c.warningReady, true);
    c.markWarningSpoken();
    c.observe(rep(3500), 4000);
    expect(c.improved, false);
    c.observe(rep(3500), 4000);
    expect(c.improvementPending, true);
    c.markImprovementSpoken();
    expect(c.improvementPending, false);
    c.observe(rep(1000), 4000);
    expect(c.improved, false);
  });
  test('unassessable movement breaks the evidence streak', () {
    final c = TempoCoach();
    c.observe(rep(1000), 4000);
    c.observe(rep(1000, assessable: false), 4000);
    c.observe(rep(1000), 4000);
    expect(c.warningReady, false);
  });
  test(
      'production tracking engine speaks prescribed tempo without claiming correct form',
      () {
    final e = FormCoachEngine(
        profile: bicepsCurlProfile,
        session: const FormCoachSession(
            exerciseKey: 'curl',
            exerciseName: 'curl',
            openEnded: true,
            prescribedRepMs: 5000));
    fixture.warm(e);
    fixture.move(e, 3000);
    final s = fixture.move(e, 5200);
    expect(s.lastCue?.id, 'tempo_fast');
    expect(s.valid, 0);
    expect(s.incorrect, 0);
  });
}
