// Form Coach - public surface of the feature.
//
// The rest of the app only needs this file: an availability check, the entry
// card, and the launcher. Everything else (engine, profiles, camera runtime)
// stays internal to the feature folder.

export 'package:elforma/features/form_coach/domain/form_profile.dart'
    show FormProfile, FormSupportLevel, formSupportLevelAr;
export 'package:elforma/features/form_coach/integration/form_coach_launcher.dart';
export 'package:elforma/features/form_coach/integration/form_coach_request.dart';
export 'package:elforma/features/form_coach/profiles/form_profile_registry.dart';
export 'package:elforma/features/form_coach/profiles/fallback_form_engine.dart';
export 'package:elforma/features/form_coach/ui/form_coach_entry_card.dart';
