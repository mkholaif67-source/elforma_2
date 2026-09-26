// Form Coach - the ONLY seam between the feature and the workout app.
//
// It reads an existing WorkoutExercise (the same object the training session
// screen already holds) and produces a read-only request. Nothing is written
// back: no session mutation, no API call, no database, no progress update.
//
// The plan stores reps/tempo as free-form strings ("8-12", "30 ثانية",
// "AMRAP", "3-1-1"), so parsing lives here and is unit-tested.

import 'package:elforma/features/form_coach/domain/form_coach_engine.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/profiles/fallback_form_engine.dart';
import 'package:elforma/features/form_coach/profiles/form_profile_registry.dart';
import 'package:elforma/models/engine_contracts.dart';

enum FormCoachResolutionKind { verified, fallback }

class FormCoachRequest {
  const FormCoachRequest({
    required this.profile,
    required this.session,
    this.resolutionKind = FormCoachResolutionKind.verified,
    this.resolutionNoteAr = '',
    this.fallbackMechanics,
  });

  final FormProfile profile;
  final FormCoachSession session;
  final FormCoachResolutionKind resolutionKind;
  final String resolutionNoteAr;
  final FallbackMechanics? fallbackMechanics;

  bool get isFallback => resolutionKind == FormCoachResolutionKind.fallback;

  /// Returns null when the exercise has no Form Profile (unsupported).
  static FormCoachRequest? fromWorkoutExercise(
    WorkoutExercise exercise, {
    int? setNumber,
    int? totalSets,
  }) {
    final FormProfile? verifiedProfile = FormProfileRegistry.lookup(
      exerciseKey: exercise.key,
      exerciseName: exercise.name,
      muscle: exercise.muscle,
    );
    FormProfile? profile = verifiedProfile;
    FormCoachResolutionKind resolutionKind = FormCoachResolutionKind.verified;
    String resolutionNoteAr = '';
    FallbackMechanics? fallbackMechanics;

    // The verified registry always wins. The fallback is consulted only when
    // no trusted mapping exists; it cannot overwrite or promote a profile.
    if (profile == null) {
      final FallbackResolution fallback = FormFallbackEngine.resolve(
        exerciseKey: exercise.key,
        exerciseName: exercise.name,
        muscle: exercise.muscle,
      );
      if (!fallback.isUsable || fallback.profile == null) return null;
      profile = fallback.profile;
      resolutionKind = FormCoachResolutionKind.fallback;
      resolutionNoteAr = fallback.reasonAr;
      fallbackMechanics = fallback.mechanics;
    }

    final String reps = exercise.reps;
    final bool openEnded = isOpenEnded(reps);
    final int? seconds = parseTargetSeconds(reps);
    final int? targetReps = seconds != null ? null : parseTargetReps(reps);

    return FormCoachRequest(
      profile: profile!,
      resolutionKind: resolutionKind,
      resolutionNoteAr: resolutionNoteAr,
      fallbackMechanics: fallbackMechanics,
      session: FormCoachSession(
        exerciseKey: exercise.key,
        exerciseName: exercise.name,
        muscle: exercise.muscle,
        targetReps: openEnded ? null : targetReps,
        targetSeconds: openEnded ? null : seconds,
        openEnded: openEnded,
        tempo: exercise.tempo,
        prescribedRepMs: parseTempoRepMs(exercise.tempo),
        setLabelAr: _setLabel(setNumber, totalSets),
      ),
    );
  }

  static String _setLabel(int? setNumber, int? totalSets) {
    if (setNumber == null) return '';
    if (totalSets == null) return 'المجموعة $setNumber';
    return 'المجموعة $setNumber من $totalSets';
  }

  /// "AMRAP", "للفشل", "max" -> no target, the user decides when to stop.
  static bool isOpenEnded(String reps) {
    final String value = reps.toLowerCase();
    return value.contains('amrap') ||
        value.contains('failure') ||
        value.contains('max') ||
        value.contains('فشل') ||
        value.contains('مفتوح');
  }

  /// "30 ثانية", "45s", "1 دقيقة" -> duration-based set.
  static int? parseTargetSeconds(String reps) {
    final String value = reps.toLowerCase();
    final bool minutes = value.contains('دقيق') || value.contains('min');
    final bool secondsUnit = value.contains('ثان') ||
        value.contains('sec') ||
        RegExp(r'\d\s*s\b').hasMatch(value);
    if (!minutes && !secondsUnit) return null;

    final int? number = _lastNumber(value);
    if (number == null || number <= 0) return null;
    final int seconds = minutes ? number * 60 : number;
    return seconds.clamp(5, 600);
  }

  /// "8-12" -> 12 (the set ends at the top of the prescribed range).
  static int? parseTargetReps(String reps) {
    final Iterable<RegExpMatch> matches = RegExp(r'\d+').allMatches(reps);
    if (matches.isEmpty) return null;
    int best = 0;
    for (final RegExpMatch match in matches) {
      final int? value = int.tryParse(match.group(0)!);
      if (value != null && value > best) best = value;
    }
    if (best <= 0 || best > 100) return null;
    return best;
  }

  /// Tempo "3-1-1" -> 5000 ms per rep. Letters such as "X" count as ~0.3 s.
  static int? parseTempoRepMs(String tempo) {
    if (tempo.trim().isEmpty) return null;
    final List<String> parts = tempo
        .split(RegExp(r'[-:/\s]+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) return null;
    double total = 0;
    for (final String part in parts) {
      final double? value = double.tryParse(part);
      if (value != null) {
        total += value;
      } else if (part.length == 1) {
        total += 0.3; // explosive marker
      } else {
        return null;
      }
    }
    if (total <= 0) return null;
    return (total * 1000).round();
  }

  static int? _lastNumber(String value) {
    final Iterable<RegExpMatch> matches = RegExp(r'\d+').allMatches(value);
    if (matches.isEmpty) return null;
    return int.tryParse(matches.last.group(0)!);
  }
}
