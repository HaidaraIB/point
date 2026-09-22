/// WhatsApp phone normalization (aligned with Edge Function `normalizeWhatsappPhone`).
library;

class WhatsappCountryDialCode {
  const WhatsappCountryDialCode({
    required this.iso,
    required this.dialCode,
    required this.labelEn,
    required this.labelAr,
  });

  final String iso;
  final String dialCode;
  final String labelEn;
  final String labelAr;

  String displayLabel(String localeCode) {
    final name = localeCode == 'ar' ? labelAr : labelEn;
    return '+$dialCode $name';
  }
}

/// Common dial codes for OS phone inputs (Iraq first).
const List<WhatsappCountryDialCode> kWhatsappCountryDialCodes = [
  WhatsappCountryDialCode(
    iso: 'IQ',
    dialCode: '964',
    labelEn: 'Iraq',
    labelAr: 'العراق',
  ),
  WhatsappCountryDialCode(
    iso: 'SA',
    dialCode: '966',
    labelEn: 'Saudi Arabia',
    labelAr: 'السعودية',
  ),
  WhatsappCountryDialCode(
    iso: 'AE',
    dialCode: '971',
    labelEn: 'UAE',
    labelAr: 'الإمارات',
  ),
  WhatsappCountryDialCode(
    iso: 'KW',
    dialCode: '965',
    labelEn: 'Kuwait',
    labelAr: 'الكويت',
  ),
  WhatsappCountryDialCode(
    iso: 'QA',
    dialCode: '974',
    labelEn: 'Qatar',
    labelAr: 'قطر',
  ),
  WhatsappCountryDialCode(
    iso: 'BH',
    dialCode: '973',
    labelEn: 'Bahrain',
    labelAr: 'البحرين',
  ),
  WhatsappCountryDialCode(
    iso: 'OM',
    dialCode: '968',
    labelEn: 'Oman',
    labelAr: 'عُمان',
  ),
  WhatsappCountryDialCode(
    iso: 'JO',
    dialCode: '962',
    labelEn: 'Jordan',
    labelAr: 'الأردن',
  ),
  WhatsappCountryDialCode(
    iso: 'LB',
    dialCode: '961',
    labelEn: 'Lebanon',
    labelAr: 'لبنان',
  ),
  WhatsappCountryDialCode(
    iso: 'EG',
    dialCode: '20',
    labelEn: 'Egypt',
    labelAr: 'مصر',
  ),
  WhatsappCountryDialCode(
    iso: 'TR',
    dialCode: '90',
    labelEn: 'Turkey',
    labelAr: 'تركيا',
  ),
  WhatsappCountryDialCode(
    iso: 'US',
    dialCode: '1',
    labelEn: 'United States',
    labelAr: 'الولايات المتحدة',
  ),
  WhatsappCountryDialCode(
    iso: 'GB',
    dialCode: '44',
    labelEn: 'United Kingdom',
    labelAr: 'المملكة المتحدة',
  ),
];

const String kDefaultWhatsappDialCode = '964';

WhatsappCountryDialCode whatsappDialCodeByCode(String dialCode) {
  for (final c in kWhatsappCountryDialCodes) {
    if (c.dialCode == dialCode) return c;
  }
  return kWhatsappCountryDialCodes.first;
}

/// Normalize to digits-only international WhatsApp `to` value.
String? normalizeWhatsappPhone(
  String raw, {
  String defaultCountryCode = kDefaultWhatsappDialCode,
}) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8) return null;
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) {
    digits = '$defaultCountryCode${digits.substring(1)}';
  }
  if (digits.startsWith('7') &&
      digits.length == 10 &&
      defaultCountryCode == kDefaultWhatsappDialCode) {
    digits = '${kDefaultWhatsappDialCode}$digits';
  }
  if (digits.length < 10) return null;
  return digits;
}

/// Strip pasted/typed input to national digits only (no country code).
String sanitizeNationalPhoneInput(String raw, {required String dialCode}) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }

  final sorted = List<WhatsappCountryDialCode>.from(kWhatsappCountryDialCodes)
    ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
  for (final c in sorted) {
    if (digits.startsWith(c.dialCode) &&
        digits.length > c.dialCode.length + 5) {
      digits = digits.substring(c.dialCode.length);
      break;
    }
  }

  if (digits.startsWith(dialCode) && digits.length > dialCode.length + 5) {
    digits = digits.substring(dialCode.length);
  }

  while (digits.startsWith('0') && digits.length > 1) {
    digits = digits.substring(1);
  }

  return digits;
}

/// Build normalized phone from dial code + national number.
String? normalizeWhatsappPhoneParts({
  required String dialCode,
  required String nationalNumber,
}) {
  final national = sanitizeNationalPhoneInput(
    nationalNumber,
    dialCode: dialCode,
  );
  if (national.isEmpty) return null;
  return normalizeWhatsappPhone('$dialCode$national', defaultCountryCode: dialCode);
}

/// Split stored digits into dial code + national part for editing.
({String dialCode, String national}) splitWhatsappPhone(String? stored) {
  final digits = (stored ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return (dialCode: kDefaultWhatsappDialCode, national: '');
  }
  final sorted = List<WhatsappCountryDialCode>.from(kWhatsappCountryDialCodes)
    ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
  for (final c in sorted) {
    if (digits.startsWith(c.dialCode) && digits.length > c.dialCode.length + 6) {
      return (dialCode: c.dialCode, national: digits.substring(c.dialCode.length));
    }
  }
  return (dialCode: kDefaultWhatsappDialCode, national: digits);
}

/// Display format for UI: visible `+`, country code, space, national digits.
String formatWhatsappPhoneDisplay(String? normalized) {
  final raw = (normalized ?? '').trim();
  if (raw.isEmpty) return '';

  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  final split = splitWhatsappPhone(digits);
  final national = split.national.trim();
  if (national.isNotEmpty) {
    return '+${split.dialCode} $national';
  }

  // Unknown / national-only storage: keep leading + without forcing Iraq.
  if (raw.startsWith('+')) return '+$digits';
  return '+$digits';
}
