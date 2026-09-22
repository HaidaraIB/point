import 'package:get/get.dart';
import 'package:point/Controller/OsGeneralSettingsController.dart';
import 'package:point/Models/Os/OsGeneralSettings.dart';
import 'package:point/Utils/whatsapp_phone.dart';
import 'package:point/View/Os/os_print_a4.dart';

/// HTML/CSS for the agency contact block on print headers.
///
/// Used on invoices, quotations, contracts, and vouchers. The lines are
/// edited from OS settings.
class OsPrintContact {
  OsPrintContact._();

  static const color = '#2B2A6B';

  static OsGeneralSettings current() {
    if (Get.isRegistered<OsGeneralSettingsController>()) {
      return Get.find<OsGeneralSettingsController>().settings.value;
    }
    return OsGeneralSettings.defaults();
  }

  static String get websiteUrl => current().printWebsiteUrl;

  static String css() => '''
.print-contact {
  direction: ltr;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 5px;
  width: 100%;
  color: $color;
  min-width: 0;
}
.print-contact .pc-row {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.print-contact .pc-ico {
  width: 15px;
  height: 15px;
  flex-shrink: 0;
}
.print-contact .pc-ico svg {
  width: 15px;
  height: 15px;
  display: block;
}
.print-contact .pc-txt {
  min-width: 0;
  line-height: 1.18;
}
.print-contact .pc-ar {
  font-size: 11px;
  font-weight: 800;
  direction: ltr;
  text-align: left;
  unicode-bidi: isolate;
}
.print-contact .pc-en {
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.15px;
  direction: ltr;
  text-align: left;
  unicode-bidi: isolate;
}
.print-contact .pc-line {
  font-size: 10px;
  font-weight: 700;
  direction: ltr;
  unicode-bidi: isolate;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
''';

  static String headerHtml() => previewHtml(current());

  static String previewHtml(OsGeneralSettings settings) {
    final rows = <String>[];

    final addressAr = settings.printAddressAr.trim();
    final addressEn = settings.printAddressEn.trim();
    if (addressAr.isNotEmpty || addressEn.isNotEmpty) {
      final lines = StringBuffer();
      if (addressAr.isNotEmpty) {
        lines.write(
          '<div class="pc-ar">${escapeHtml(addressAr)}</div>',
        );
      }
      if (addressEn.isNotEmpty) {
        lines.write(
          '<div class="pc-en">${escapeHtml(addressEn)}</div>',
        );
      }
      rows.add(_row(_pinSvg(), lines.toString()));
    }

    final phone = formatWhatsappPhoneDisplay(settings.printPhone);
    if (phone.isNotEmpty) {
      rows.add(_row(_phoneSvg(), _line(phone)));
    }
    final email = settings.printEmail.trim();
    if (email.isNotEmpty) {
      rows.add(_row(_mailSvg(), _line(email)));
    }
    final website = settings.printWebsite.trim();
    if (website.isNotEmpty) {
      rows.add(_row(_badgeGlobeSvg(), _line(website)));
    }

    if (rows.isEmpty) return '';

    return '''
<div class="print-contact">
  ${rows.join('\n')}
</div>''';
  }

  static String _row(String icon, String text) => '''
<div class="pc-row">
  <span class="pc-ico">$icon</span>
  <div class="pc-txt">$text</div>
</div>''';

  static String _line(String value) =>
      '<div class="pc-line">${escapeHtml(value)}</div>';

  static String _pinSvg() => '''
<svg viewBox="0 0 24 24" fill="$color" aria-hidden="true"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z"/></svg>''';

  static String _phoneSvg() => '''
<svg viewBox="0 0 24 24" fill="$color" aria-hidden="true"><path d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/></svg>''';

  static String _mailSvg() => '''
<svg viewBox="0 0 24 24" fill="$color" aria-hidden="true"><path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4-8 5-8-5V6l8 5 8-5v2z"/></svg>''';

  static String _badgeGlobeSvg() => '''
<svg viewBox="0 0 24 24" fill="none" stroke="$color" stroke-width="1.7" aria-hidden="true"><circle cx="12" cy="12" r="9.2"/><circle cx="12" cy="12" r="6.2"/><path d="M12 5.8v12.4M5.8 12h12.4"/><path d="M8.2 8.2c2.4 1.4 5.2 1.4 7.6 0M8.2 15.8c2.4-1.4 5.2-1.4 7.6 0"/></svg>''';
}
