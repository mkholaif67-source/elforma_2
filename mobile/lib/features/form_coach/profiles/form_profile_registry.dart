// Form Coach - profile registry and exercise matching.
//
// This is the ONLY place that decides whether Form Coach is offered for an
// exercise. An exercise existing in the workout database is not enough: if no
// profile matches, the entry point is simply not shown.
//
// Matching is done on the exercise key + name coming from the plan, normalized
// for Arabic/English spelling noise. The longest matched keyword wins, so
// "Machine Lateral Raise" resolves to the lateral raise profile and never to a
// generic one, and exclude keywords protect against traps such as
// "Lying Leg Curl Machine" matching the biceps curl family.

import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/profiles/biceps_curl_profile.dart';
import 'package:elforma/features/form_coach/profiles/catalog_form_profiles.dart';
import 'package:elforma/features/form_coach/profiles/incline_barbell_press_profile.dart';
import 'package:elforma/features/form_coach/profiles/bodyweight_squat_profile.dart';
import 'package:elforma/features/form_coach/profiles/lat_pulldown_profile.dart';
import 'package:elforma/features/form_coach/profiles/lateral_raise_profile.dart';
import 'package:elforma/features/form_coach/profiles/machine_leg_extension_profile.dart';

class FormProfileRegistry {
  const FormProfileRegistry._();

  /// Every profile the feature currently supports. Adding an exercise family
  /// means adding a profile here - no engine or UI change.
  static final List<FormProfile> profiles = List<FormProfile>.unmodifiable(
    <FormProfile>[
      bicepsCurlProfile,
      bodyweightSquatProfile,
      lateralRaiseProfile,
      inclineBarbellPressProfile,
      legExtensionMachineProfile,
      latPulldownProfile,
      ...catalogFormProfiles,
    ],
  );

  /// Returns the profile for an exercise, or null when it is unsupported.
  static FormProfile? lookup({
    required String exerciseKey,
    required String exerciseName,
    String muscle = '',
  }) {
    final String haystack = normalize('$exerciseKey $exerciseName');
    if (haystack.trim().isEmpty) return null;

    FormProfile? best;
    int bestScore = 0;

    for (final FormProfile profile in profiles) {
      if (!profile.isSupported) continue;

      bool excluded = false;
      for (final String keyword in profile.excludeKeywords) {
        if (haystack.contains(normalize(keyword))) {
          excluded = true;
          break;
        }
      }
      if (excluded) continue;

      for (final String keyword in profile.matchKeywords) {
        final String needle = normalize(keyword);
        if (needle.isEmpty || !haystack.contains(needle)) continue;
        if (needle.length > bestScore) {
          bestScore = needle.length;
          best = profile;
        }
      }
    }
    return best;
  }

  static FormProfile? byId(String id) {
    for (final FormProfile profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// Quick check used by the workout screen to decide whether to show the entry.
  static bool isSupported({
    required String exerciseKey,
    required String exerciseName,
    String muscle = '',
  }) =>
      lookup(
        exerciseKey: exerciseKey,
        exerciseName: exerciseName,
        muscle: muscle,
      ) !=
      null;

  /// Lowercase, strip punctuation, unify Arabic letter variants and diacritics.
  static String normalize(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.toLowerCase().runes) {
      final String char = String.fromCharCode(rune);
      if (rune >= 0x064B && rune <= 0x0652) continue; // Arabic diacritics
      if (rune == 0x0640) continue; // tatweel
      switch (char) {
        case 'أ':
        case 'إ':
        case 'آ':
        case 'ٱ':
          buffer.write('ا');
          break;
        case 'ى':
          buffer.write('ي');
          break;
        case 'ة':
          buffer.write('ه');
          break;
        case 'ؤ':
          buffer.write('و');
          break;
        case 'ئ':
          buffer.write('ي');
          break;
        case '_':
        case '-':
        case '/':
        case '(':
        case ')':
        case ',':
        case '.':
        case '+':
          buffer.write(' ');
          break;
        default:
          buffer.write(char);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
