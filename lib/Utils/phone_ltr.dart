/// Left-to-right display and embedding for phone numbers in RTL UI.
const _lri = '\u2066';
const _pdi = '\u2069';

/// Wraps [value] in Unicode LRI/PDI so it stays LTR inside RTL strings (e.g. snackbars).
String isolatePhoneLtr(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return value;
  return '$_lri$trimmed$_pdi';
}

/// Same bidi isolation for access tokens and other LTR-only strings in RTL UI.
String isolateLtrString(String value) => isolatePhoneLtr(value);
