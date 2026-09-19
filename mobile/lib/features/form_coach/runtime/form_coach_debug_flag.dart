// Form Coach - developer calibration switch.
//
// Off by default and not advertised in the normal UI: it is opened by a long
// press on the header inside the Form Coach screen. It is persisted so a tester
// can keep it on across sets while tuning Form Profiles and thresholds.

import 'package:shared_preferences/shared_preferences.dart';

class FormCoachDebugFlag {
  const FormCoachDebugFlag._();

  static const String prefsKey = 'form_coach_debug';

  static Future<bool> isEnabled() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> toggle() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool next = !(prefs.getBool(prefsKey) ?? false);
      await prefs.setBool(prefsKey, next);
      return next;
    } catch (_) {
      return false;
    }
  }
}
