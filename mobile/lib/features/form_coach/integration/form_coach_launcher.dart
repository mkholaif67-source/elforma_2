// Form Coach - navigation entry point.
//
// Opens the camera screen as a normal pushed route, so the training session
// screen below stays alive and untouched: no session state is rebuilt, nothing
// is saved, and popping returns the user exactly where they were.

import 'package:elforma/features/form_coach/integration/form_coach_request.dart';
import 'package:elforma/features/form_coach/ui/form_coach_screen.dart';
import 'package:elforma/models/engine_contracts.dart';
import 'package:flutter/material.dart';

class FormCoachLauncher {
  const FormCoachLauncher._();

  /// Whether the entry card should be shown for this exercise at all.
  static bool isAvailableFor(WorkoutExercise exercise) =>
      FormCoachRequest.fromWorkoutExercise(exercise) != null;

  static Future<void> open(
    BuildContext context, {
    required WorkoutExercise exercise,
    int? setNumber,
    int? totalSets,
  }) async {
    final FormCoachRequest? request = FormCoachRequest.fromWorkoutExercise(
      exercise,
      setNumber: setNumber,
      totalSets: totalSets,
    );
    if (request == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('التمرين ده مش مدعوم في تابع أداءك دلوقتي'),
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext _) => FormCoachScreen(request: request),
      ),
    );
  }
}
