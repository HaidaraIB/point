/// Spells out an IQD amount in Arabic (tafqeet), matching Point OS Finance.
class OsArabicCurrency {
  OsArabicCurrency._();

  static const _ones = [
    '',
    'واحد',
    'اثنان',
    'ثلاثة',
    'أربعة',
    'خمسة',
    'ستة',
    'سبعة',
    'ثمانية',
    'تسعة',
    'عشرة',
    'أحد عشر',
    'اثنا عشر',
    'ثلاثة عشر',
    'أربعة عشر',
    'خمسة عشر',
    'ستة عشر',
    'سبعة عشر',
    'ثمانية عشر',
    'تسعة عشر',
  ];

  static const _tens = [
    '',
    '',
    'عشرون',
    'ثلاثون',
    'أربعون',
    'خمسون',
    'ستون',
    'سبعون',
    'ثمانون',
    'تسعون',
  ];

  static const _hundreds = [
    '',
    'مائة',
    'مائتان',
    'ثلاثمائة',
    'أربعمائة',
    'خمسمائة',
    'ستمائة',
    'سبعمائة',
    'ثمانمائة',
    'تسعمائة',
  ];

  static String formatIqd(num value) {
    final numInt = value.round();
    if (numInt == 0) return 'صفر دينار عراقي';
    if (numInt < 0) return formatIqd(-numInt);

    final parts = <String>[];
    var temp = numInt;

    final billions = temp ~/ 1000000000;
    temp %= 1000000000;
    final millions = temp ~/ 1000000;
    temp %= 1000000;
    final thousands = temp ~/ 1000;
    final remaining = temp % 1000;

    if (billions > 0) {
      if (billions == 1) {
        parts.add('مليار');
      } else if (billions == 2) {
        parts.add('ملياران');
      } else {
        parts.add('${_threeDigits(billions)} مليار');
      }
    }

    if (millions > 0) {
      if (millions == 1) {
        parts.add('مليون');
      } else if (millions == 2) {
        parts.add('مليونان');
      } else if (millions >= 3 && millions <= 10) {
        parts.add('${_threeDigits(millions)} ملايين');
      } else {
        parts.add('${_threeDigits(millions)} مليون');
      }
    }

    if (thousands > 0) {
      if (thousands == 1) {
        parts.add('ألف');
      } else if (thousands == 2) {
        parts.add('ألفان');
      } else if (thousands >= 3 && thousands <= 10) {
        parts.add('${_threeDigits(thousands)} آلاف');
      } else {
        parts.add('${_threeDigits(thousands)} ألف');
      }
    }

    if (remaining > 0) {
      parts.add(_threeDigits(remaining));
    }

    return '${parts.join(' و ')} دينار عراقي لا غير';
  }

  static String _threeDigits(int val) {
    final parts = <String>[];
    final h = val ~/ 100;
    final remainder = val % 100;
    if (h > 0) parts.add(_hundreds[h]);
    if (remainder > 0) {
      if (remainder < 20) {
        parts.add(_ones[remainder]);
      } else {
        final o = remainder % 10;
        final t = remainder ~/ 10;
        if (o > 0) {
          parts.add('${_ones[o]} و ${_tens[t]}');
        } else {
          parts.add(_tens[t]);
        }
      }
    }
    return parts.join(' و ');
  }
}
