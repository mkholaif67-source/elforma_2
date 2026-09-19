// Form Coach - entry card shown inside the existing training session screen.
//
// It renders NOTHING when the exercise has no Form Profile, so the feature never
// appears just because an exercise exists in the plan. It reads the exercise it
// is given and opens the camera; it never writes to the session.

import 'package:elforma/features/form_coach/integration/form_coach_launcher.dart';
import 'package:elforma/features/form_coach/integration/form_coach_request.dart';
import 'package:elforma/models/engine_contracts.dart';
import 'package:elforma/theme.dart';
import 'package:flutter/material.dart';

class FormCoachEntryCard extends StatelessWidget {
  const FormCoachEntryCard({
    super.key,
    required this.exercise,
    this.setNumber,
    this.totalSets,
  });

  final WorkoutExercise exercise;
  final int? setNumber;
  final int? totalSets;

  @override
  Widget build(BuildContext context) {
    final FormCoachRequest? request = FormCoachRequest.fromWorkoutExercise(
      exercise,
      setNumber: setNumber,
      totalSets: totalSets,
    );
    if (request == null) return const SizedBox.shrink();

    final bool coaching = request.profile.canCorrectForm;
    final String subtitle = request.isFallback
        ? 'متابعة احتياطية للعدات والمدى فقط — بدون حكم فني'
        : (coaching
            ? 'ملاحظات فورية تساعدك تحسن أداءك'
            : 'شوف حركتك ومدى أدائك أثناء التمرين');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => FormCoachLauncher.open(
          context,
          exercise: exercise,
          setNumber: setNumber,
          totalSets: totalSets,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.wo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  coaching ? Icons.center_focus_strong : Icons.videocam_outlined,
                  color: AppColors.wo,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'تابع أداءك',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

