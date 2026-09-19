import 'package:elforma/features/form_coach/domain/rep_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

RepCounter counter() => RepCounter(
      const RepCycleSpec(
        driverMetricId: 'movement_angle',
        topValue: 160,
        bottomValue: 100,
        enterMargin: 5,
        minAmplitude: 40,
        partialAmplitude: 20,
        minPhaseMs: 70,
        noiseFloorMs: 300,
        maxRepMs: 15000,
      ),
    );

List<RepEvent> update(
  RepCounter c,
  int t,
  double? value, {
  bool usable = true,
}) => c.update(tMs: t, driver: value, usable: usable);

void main() {
  test('a valid rep commits once and jitter at the top cannot double count', () {
    final c = counter();
    update(c, 0, 160);
    update(c, 100, 130);
    update(c, 180, 130);
    update(c, 260, 100);
    update(c, 340, 100);
    update(c, 480, 130);
    update(c, 560, 160); // movement itself clears the hard duration floor
    final events = update(c, 640, 160); // second top frame confirms persistence

    expect(events.single.kind, RepEventKind.repCompleted);
    expect(c.reps, 1);
    var t = 700;
    for (final point in <double>[156, 154, 156, 164, 155, 165]) {
      update(c, t, point);
      t += 80;
    }
    expect(c.reps, 1);
  });

  test('a rapid valid rep is not lost when it crosses the endpoint briefly', () {
    final c = counter();
    update(c, 0, 160);
    update(c, 80, 100); // candidate bottom; full excursion is remembered immediately
    update(c, 160, 100);
    update(c, 580, 160); // actual excursion clears the safety floor
    final events = update(c, 660, 160);

    expect(events.single.kind, RepEventKind.repCompleted);
    expect(c.reps, 1);
  });

  test('partial range is reported as incomplete and never as a full rep', () {
    final c = counter();
    update(c, 0, 160);
    update(c, 100, 130);
    update(c, 180, 125);
    update(c, 400, 160);
    final events = update(c, 500, 160);

    expect(events.single.kind, RepEventKind.partialRep);
    expect(c.reps, 0);
    expect(c.partials, 1);
  });

  test('direction reversal before full range does not jump the counter', () {
    final c = counter();
    update(c, 0, 160);
    update(c, 100, 130);
    update(c, 180, 145);
    update(c, 260, 160);
    update(c, 360, 160);

    expect(c.reps, 0);
    expect(c.partials, 0);
  });

  test('a long confidence gap aborts the in-flight cycle', () {
    final c = counter();
    update(c, 0, 160);
    update(c, 100, 130);
    update(c, 180, 100);
    final events = update(c, 1000, null, usable: false);
    update(c, 1100, 160);

    expect(events.any((e) => e.kind == RepEventKind.cycleAborted), isTrue);
    expect(c.reps, 0);
    expect(c.inCycle, isFalse);
  });

  test('a short confidence gap blocks an unsafe commit without a jump', () {
    final c = counter();
    update(c, 0, 160);
    update(c, 100, 130);
    update(c, 180, 100);
    update(c, 500, null, usable: false);
    final events = update(c, 600, 160);

    expect(events.where((e) => e.kind == RepEventKind.repCompleted), isEmpty);
    expect(c.reps, 0);
  });

  test('reset makes a new set independent of the previous set', () {
    final c = counter();
    update(c, 0, 160);
    update(c, 100, 130);
    update(c, 180, 100);
    update(c, 580, 160);
    update(c, 660, 160);
    expect(c.reps, 1);

    c.reset();
    expect(c.reps, 0);
    expect(c.partials, 0);
    expect(c.inCycle, isFalse);
    expect(c.phase, RepPhase.unknown);
  });
}
