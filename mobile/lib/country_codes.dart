// ElForma - country_codes.dart
// [OWNER-RULE] Country dial-code registry + expected national phone length per country.
// The user types the number without the country code; validation checks the digit
// count matches the selected country (not just any digits).

class Country {
  final String iso;
  final String name;
  final String dial; // country code without +
  final String flag;
  final int minLen;
  final int maxLen;
  final String example;
  // [FIX-PHONE] Allowed national mobile prefixes (without the trunk 0). Empty
  // means length-only. Egypt = 10/11/12/15, so a number like 2532542225 is
  // rejected even though it is 10 digits long.
  final List<String> prefixes;
  final String prefixHint;
  const Country(this.iso, this.name, this.dial, this.flag, this.minLen,
      this.maxLen, this.example,
      [this.prefixes = const [], this.prefixHint = '']);

  String get hint =>
      minLen == maxLen ? '$minLen \u0623\u0631\u0642\u0627\u0645' : '\u0645\u0646 $minLen \u0644\u0640 $maxLen \u0623\u0631\u0642\u0627\u0645';
}

const List<Country> kCountries = [
  Country('EG', '\u0645\u0635\u0631', '20', '\u{1F1EA}\u{1F1EC}', 10, 10, '1012345678', const ['10', '11', '12', '15'], '010 / 011 / 012 / 015'),
  Country('SA', '\u0627\u0644\u0633\u0639\u0648\u062f\u064a\u0629', '966', '\u{1F1F8}\u{1F1E6}', 9, 9, '512345678', const ['5'], '05xxxxxxxx'),
  Country('AE', '\u0627\u0644\u0625\u0645\u0627\u0631\u0627\u062a', '971', '\u{1F1E6}\u{1F1EA}', 9, 9, '501234567'),
  Country('KW', '\u0627\u0644\u0643\u0648\u064a\u062a', '965', '\u{1F1F0}\u{1F1FC}', 8, 8, '50123456'),
  Country('QA', '\u0642\u0637\u0631', '974', '\u{1F1F6}\u{1F1E6}', 8, 8, '33123456'),
  Country('BH', '\u0627\u0644\u0628\u062d\u0631\u064a\u0646', '973', '\u{1F1E7}\u{1F1ED}', 8, 8, '36123456'),
  Country('OM', '\u0639\u0645\u0627\u0646', '968', '\u{1F1F4}\u{1F1F2}', 8, 8, '92123456'),
  Country('JO', '\u0627\u0644\u0623\u0631\u062f\u0646', '962', '\u{1F1EF}\u{1F1F4}', 9, 9, '791234567'),
  Country('LB', '\u0644\u0628\u0646\u0627\u0646', '961', '\u{1F1F1}\u{1F1E7}', 7, 8, '71123456'),
  Country('IQ', '\u0627\u0644\u0639\u0631\u0627\u0642', '964', '\u{1F1EE}\u{1F1F6}', 10, 10, '7912345678'),
  Country('DZ', '\u0627\u0644\u062c\u0632\u0627\u0626\u0631', '213', '\u{1F1E9}\u{1F1FF}', 9, 9, '551234567'),
  Country('MA', '\u0627\u0644\u0645\u063a\u0631\u0628', '212', '\u{1F1F2}\u{1F1E6}', 9, 9, '612345678'),
  Country('TN', '\u062a\u0648\u0646\u0633', '216', '\u{1F1F9}\u{1F1F3}', 8, 8, '20123456'),
  Country('LY', '\u0644\u064a\u0628\u064a\u0627', '218', '\u{1F1F1}\u{1F1FE}', 9, 9, '912345678'),
  Country('SD', '\u0627\u0644\u0633\u0648\u062f\u0627\u0646', '249', '\u{1F1F8}\u{1F1E9}', 9, 9, '912345678'),
  Country('SY', '\u0633\u0648\u0631\u064a\u0627', '963', '\u{1F1F8}\u{1F1FE}', 9, 9, '944123456'),
  Country('PS', '\u0641\u0644\u0633\u0637\u064a\u0646', '970', '\u{1F1F5}\u{1F1F8}', 9, 9, '599123456'),
  Country('YE', '\u0627\u0644\u064a\u0645\u0646', '967', '\u{1F1FE}\u{1F1EA}', 9, 9, '712345678'),
  Country('MR', '\u0645\u0648\u0631\u064a\u062a\u0627\u0646\u064a\u0627', '222', '\u{1F1F2}\u{1F1F7}', 8, 8, '22123456'),
  Country('SO', '\u0627\u0644\u0635\u0648\u0645\u0627\u0644', '252', '\u{1F1F8}\u{1F1F4}', 8, 8, '61234567'),
  Country('US', '\u0623\u0645\u0631\u064a\u0643\u0627', '1', '\u{1F1FA}\u{1F1F8}', 10, 10, '2015550123'),
  Country('GB', '\u0628\u0631\u064a\u0637\u0627\u0646\u064a\u0627', '44', '\u{1F1EC}\u{1F1E7}', 10, 10, '7400123456'),
  Country('FR', '\u0641\u0631\u0646\u0633\u0627', '33', '\u{1F1EB}\u{1F1F7}', 9, 9, '612345678'),
  Country('DE', '\u0623\u0644\u0645\u0627\u0646\u064a\u0627', '49', '\u{1F1E9}\u{1F1EA}', 10, 11, '15123456789'),
  Country('TR', '\u062a\u0631\u0643\u064a\u0627', '90', '\u{1F1F9}\u{1F1F7}', 10, 10, '5312345678'),
  Country('IT', '\u0625\u064a\u0637\u0627\u0644\u064a\u0627', '39', '\u{1F1EE}\u{1F1F9}', 9, 10, '3123456789'),
  Country('ES', '\u0625\u0633\u0628\u0627\u0646\u064a\u0627', '34', '\u{1F1EA}\u{1F1F8}', 9, 9, '612345678'),
  Country('CA', '\u0643\u0646\u062f\u0627', '1', '\u{1F1E8}\u{1F1E6}', 10, 10, '4165550123'),
];

// ── [FIX-PHONE] Shared phone helpers ─────────────────────────────────────────
// One place that understands BOTH ways numbers are typed in the app:
//   1) registration: user picks a country code, then types the number WITHOUT
//      the leading 0  (e.g. 1012345678 for Egypt).
//   2) wallet transfer: no country picker, the full local number WITH the
//      leading 0 is typed (e.g. 01012345678).
// Everything is reduced to the national significant number, then validated
// against length + the country's allowed mobile prefixes.

/// Keep digits only.
String phoneDigits(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

/// Reduce any accepted input style to the national significant number
/// (no country code, no trunk 0).
String phoneNational(Country c, String raw) {
  var d = phoneDigits(raw);
  if (d.isEmpty) return '';
  // 00 international prefix.
  if (d.startsWith('00')) d = d.substring(2);
  // Leading country code — only strip when the remainder can still be national.
  if (d.length > c.maxLen && d.startsWith(c.dial)) {
    final rest = d.substring(c.dial.length);
    if (rest.length >= c.minLen) d = rest;
  }
  // A single trunk 0 (wallet style writes the local number with it).
  if (d.startsWith('0') && d.length > c.maxLen) d = d.substring(1);
  return d;
}

/// Validation message, or null when acceptable.
/// Pass required:true where a number must be entered (e.g. wallet transfer).
String? phoneError(Country c, String raw, {bool required = false}) {
  final entered = phoneDigits(raw);
  if (entered.isEmpty) return required ? '\u0627\u0643\u062a\u0628 \u0631\u0642\u0645 \u0647\u0627\u062a\u0641\u0643' : null;
  final n = phoneNational(c, raw);
  if (n.length < c.minLen || n.length > c.maxLen) {
    return '\u0631\u0642\u0645 ${c.name} \u0644\u0627\u0632\u0645 \u064a\u0643\u0648\u0646 ${c.hint}';
  }
  if (c.prefixes.isNotEmpty && !c.prefixes.any((p) => n.startsWith(p))) {
    final hint = c.prefixHint.isNotEmpty ? c.prefixHint : c.prefixes.join(' / ');
    return '\u0631\u0642\u0645 ${c.name} \u0644\u0627\u0632\u0645 \u064a\u0628\u062f\u0623 \u0628\u0640 $hint';
  }
  return null;
}

/// E.164 form for tel: links, e.g. +201012345678. Empty when blank.
String phoneE164(Country c, String raw) {
  final n = phoneNational(c, raw);
  return n.isEmpty ? '' : '+${c.dial}$n';
}

/// Digits-only international form (no +) for wa.me links, e.g. 201012345678.
String phoneWaDigits(Country c, String raw) {
  final n = phoneNational(c, raw);
  return n.isEmpty ? '' : '${c.dial}$n';
}
