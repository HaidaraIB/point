import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/Os/Print/os_print_assets.dart';
import 'package:point/View/Os/Print/os_print_contact.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_print_a4.dart';

/// Shared Point Agency brand chrome for invoice / quotation / voucher print HTML.
class OsBrandPrint {
  OsBrandPrint._();

  static const navy = '#2B2A6B';
  static const lavender = '#EFEEF7';
  static const border = '#D8D6E8';
  static const text = '#1A1A2E';
  static const watermark = '#F4F3FA';
  static const muted = '#5B5878';

  static String get agencySiteUrl => OsPrintContact.websiteUrl;

  /// Brand CSS variables + layout helpers shared by all brand documents.
  static String brandCss() => '''
:root {
  --navy: $navy;
  --lavender: $lavender;
  --border: $border;
  --text: $text;
  --watermark: $watermark;
  --muted: $muted;
}
body {
  padding: 0;
  color: var(--text);
  font-size: 11px;
  line-height: 1.45;
}
.sheet {
  position: relative;
  min-height: 277mm;
  display: flex;
  flex-direction: column;
  box-sizing: border-box;
}
.brand-header {
  direction: ltr;
  display: flex;
  align-items: center;
  width: 100%;
  margin-bottom: 10px;
  min-width: 0;
}
.brand-primary-col {
  flex: 0 0 auto;
  min-width: 0;
}
.brand-lockup {
  min-width: 0;
  overflow: hidden;
}
.brand-lockup .brand-comp {
  display: block;
  width: auto;
  max-width: 100%;
  height: auto;
  max-height: 32mm;
  object-fit: contain;
  object-position: left center;
}
.brand-header-gap {
  flex: 1 1 0;
  display: flex;
  justify-content: center;
  align-self: stretch;
  min-width: 10px;
}
.brand-vsep {
  width: 1px;
  background: var(--navy);
  flex-shrink: 0;
}
.brand-comp {
  display: block;
  width: 100%;
  height: auto;
  max-width: 100%;
  object-fit: contain;
  object-position: center;
}
.brand-comp-info {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2px 4px;
  min-width: 0;
}
.brand-slogan-wrap {
  flex: 0 0 auto;
  min-width: 0;
  display: flex;
  justify-content: flex-end;
  align-items: center;
}
.brand-comp-slogan {
  display: block;
  width: auto;
  max-width: 100%;
  height: auto;
  max-height: 32mm;
  object-fit: contain;
  object-position: right center;
}
${OsPrintContact.css()}
.watermark-logo {
  position: absolute;
  left: 50%;
  top: 52%;
  transform: translate(-50%, -50%);
  width: 48%;
  height: auto;
  z-index: 0;
  pointer-events: none;
  user-select: none;
}
.content-layer {
  position: relative;
  z-index: 1;
  flex: 1;
  display: flex;
  flex-direction: column;
}
.panel {
  background: var(--lavender);
  border-radius: 10px;
  padding: 10px 12px;
}
.panel-bordered {
  border: 1px solid var(--border);
  background: #fff;
  border-radius: 10px;
  overflow: hidden;
}
.panel-head {
  background: var(--navy);
  color: #fff;
  padding: 7px 12px;
  font-size: 12px;
  font-weight: 800;
  text-align: right;
}
.panel-body {
  padding: 10px 12px;
}
.meta-row, .client-row {
  display: flex;
  flex-direction: row;
  justify-content: flex-start;
  gap: 8px;
  align-items: baseline;
  margin-bottom: 5px;
  font-size: 11px;
}
.meta-row:last-child, .client-row:last-child { margin-bottom: 0; }
.meta-row .lbl, .client-row .lbl {
  font-weight: 700;
  color: var(--navy);
  white-space: nowrap;
  flex-shrink: 0;
}
.meta-row .val, .client-row .val {
  font-weight: 600;
  color: var(--text);
  text-align: right;
  min-width: 0;
}
.meta-row .val.ltr, .client-row .val.ltr {
  direction: ltr;
  unicode-bidi: isolate;
  text-align: left;
}
.doc-title {
  font-size: 32px;
  font-weight: 900;
  color: var(--navy);
  line-height: 1.05;
  margin: 0;
  text-align: right;
}
.doc-title-en {
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 4px;
  color: var(--navy);
  margin-top: 2px;
  text-align: right;
}
.items-wrap {
  position: relative;
  margin: 10px 0;
}
table.items {
  width: 100%;
  border-collapse: collapse;
  font-size: 11px;
  background: rgba(255,255,255,0.72);
}
table.items th {
  background: var(--navy);
  color: #fff;
  font-weight: 800;
  padding: 7px 6px;
  text-align: center;
  border: 1px solid var(--navy);
}
table.items td {
  border: 1px solid var(--border);
  padding: 6px;
  text-align: center;
  height: 22px;
  vertical-align: middle;
  color: var(--text);
}
table.items td { background: #fff; }
table.items td.desc { text-align: right; }
table.items col.col-n { width: 8%; }
table.items col.col-desc { width: 52%; }
table.items col.col-price { width: 20%; }
table.items col.col-total { width: 20%; }
table.items.quote col.col-n { width: 10%; }
table.items.quote col.col-desc { width: 65%; }
table.items.quote col.col-total { width: 25%; }
.notes-totals {
  direction: ltr;
  display: grid;
  grid-template-columns: 1.15fr 0.85fr;
  gap: 12px;
  margin-top: 8px;
  align-items: stretch;
}
.notes-totals .notes-box {
  direction: rtl;
}
.notes-totals .totals-table {
  direction: ltr;
}
.notes-box {
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--lavender);
  min-height: 96px;
  padding: 8px 10px;
}
.notes-box h4 {
  margin: 0 0 6px;
  color: var(--navy);
  font-size: 12px;
  font-weight: 800;
}
.notes-box p, .notes-box li {
  margin: 0;
  font-size: 10px;
  color: var(--text);
  line-height: 1.55;
}
.notes-box ul {
  margin: 0;
  padding-inline-start: 16px;
}
.totals-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 11px;
  border-radius: 8px;
  overflow: hidden;
}
.totals-table td {
  border: 1px solid var(--border);
  padding: 7px 10px;
}
.totals-table .lbl {
  font-weight: 700;
  color: var(--navy);
  text-align: right;
  width: 55%;
  direction: rtl;
  unicode-bidi: isolate;
}
.totals-table .val {
  font-weight: 800;
  text-align: left;
  direction: ltr;
  unicode-bidi: isolate;
  width: 45%;
  white-space: nowrap;
}
.print-money {
  display: inline-flex;
  flex-direction: row;
  direction: ltr;
  unicode-bidi: isolate;
  gap: 4px;
  align-items: baseline;
  white-space: nowrap;
}
.print-money .curr {
  direction: rtl;
  unicode-bidi: isolate;
}
.print-money .num {
  direction: ltr;
  unicode-bidi: isolate;
}
.totals-table tr td { background: #fff; }
.totals-table tr.grand td {
  background: var(--navy) !important;
  color: #fff !important;
  font-weight: 900;
  font-size: 12px;
}
.brand-footer {
  margin-top: auto;
  padding-top: 16px;
}
.brand-footer-top {
  direction: ltr;
  display: grid;
  grid-template-columns: 0.9fr 1fr 1.2fr;
  gap: 10px;
  align-items: end;
  margin-bottom: 12px;
}
.qr-block {
  text-align: center;
}
.qr-block .qr-svg {
  width: 72px;
  height: 72px;
  margin: 0 auto 4px;
}
.qr-block .qr-svg svg { width: 72px; height: 72px; display: block; margin: 0 auto; }
.qr-caption {
  direction: rtl;
  font-size: 8px;
  color: var(--navy);
  font-weight: 600;
  line-height: 1.3;
}
.barcode-block {
  text-align: center;
  border-right: 1px solid var(--border);
  padding-right: 8px;
}
.barcode-block .bc-svg svg { width: 150px; height: 34px; display: block; margin: 0 auto; }
.barcode-ref {
  margin-top: 4px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1px;
  color: var(--navy);
  direction: ltr;
}
.sign-block {
  direction: rtl;
  text-align: center;
}
.sign-agency {
  font-size: 10px;
  font-weight: 800;
  color: var(--navy);
  margin-bottom: 18px;
}
.sign-agency-name {
  margin-bottom: 14px;
  font-weight: 700;
  font-size: 9px;
}
.sign-line {
  border-bottom: 1.5px dotted var(--navy);
  margin: 0 12px 4px;
  height: 1px;
}
.sign-label {
  font-size: 9px;
  color: var(--navy);
  font-weight: 600;
}
.seal-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
}
.seal-img {
  width: 78px;
  height: 78px;
  object-fit: contain;
  margin: 0 auto 4px;
  display: block;
}
.footer-bar {
  direction: ltr;
  background: var(--navy);
  color: #fff;
  border-radius: 0;
  padding: 9px 22px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin: 0;
  gap: 16px;
}
.footer-bar .en {
  font-size: 7.5px;
  font-weight: 400;
  letter-spacing: 2.8px;
  word-spacing: 2px;
}
.footer-bar .ar {
  direction: rtl;
  unicode-bidi: isolate;
  font-size: 11px;
  font-weight: 400;
  letter-spacing: 0.2px;
  white-space: nowrap;
}
.greeting {
  margin: 10px 0 6px;
  font-size: 11px;
  color: var(--text);
  line-height: 1.7;
  text-align: right;
}
.quote-footer-top {
  grid-template-columns: 0.7fr 1.2fr 1.4fr;
  align-items: center;
}
.quote-mark {
  direction: ltr;
  unicode-bidi: isolate;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  min-width: 0;
  width: 100%;
}
.quote-mark-img {
  display: block;
  width: 100%;
  height: auto;
  object-fit: contain;
  object-position: right center;
}
.payment-methods {
  direction: ltr;
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 10px;
  flex-wrap: nowrap;
}
.payment-methods img {
  height: 22px;
  width: auto;
  max-width: 72px;
  object-fit: contain;
  display: block;
}
.footer-bar .payment-methods {
  min-width: 0;
}
.footer-bar.invoice-bar {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  gap: 12px;
}
.footer-bar.invoice-bar .en { justify-self: start; }
.footer-bar.invoice-bar .ar { grid-column: 2; justify-self: center; }
.footer-bar.invoice-bar .payment-methods {
  grid-column: 3;
  justify-self: end;
}
''';

  /// Three-column brand header from the print comps in `assets/print/`.
  static String headerHtml() {
    String img(String src, String alt, [String extra = '']) => src.isEmpty
        ? ''
        : '<img class="brand-comp $extra" src="$src" alt="$alt"/>';

    return '''
<div class="brand-header no-split">
  <div class="brand-primary-col">
    <div class="brand-lockup">
      ${img(OsPrintAssets.headerBrandDataUri, 'POINT AGENCY')}
    </div>
  </div>
  <div class="brand-header-gap" aria-hidden="true"><span class="brand-vsep"></span></div>
  <div class="brand-comp-info">
    ${OsPrintContact.headerHtml()}
  </div>
  <div class="brand-header-gap" aria-hidden="true"><span class="brand-vsep"></span></div>
  <div class="brand-slogan-wrap">
    ${img(OsPrintAssets.headerSloganDataUri, '', 'brand-comp-slogan')}
  </div>
</div>''';
  }

  static String watermarkHtml() {
    final src = OsPrintAssets.watermarkLogoDataUri;
    if (src.isEmpty) return '';
    return '<img class="watermark-logo" src="$src" alt="" aria-hidden="true"/>';
  }

  /// Currency on the visual left of the number (`د.ع 1,500,000`).
  /// Uses flex so the Unicode bidi algorithm cannot swap the two parts.
  static String moneyHtml(num value) {
    final n = escapeHtml(OsFinanceFormat.moneyNumber(value));
    final c = escapeHtml(AppLocaleKeys.osInvoicesCurrency.tr);
    return '<span class="print-money"><span class="curr">$c</span><span class="num">$n</span></span>';
  }

  /// Totals stack: subtotal / discount / tax / grand total.
  static String totalsHtml({
    required String subtotal,
    required String discount,
    required String tax,
    required String grandTotal,
    String? taxLabel,
  }) {
    final taxLbl = taxLabel ?? AppLocaleKeys.osPrintTax.tr;
    return '''
<table class="totals-table" dir="ltr">
  <tr><td class="val">$subtotal</td><td class="lbl">${escapeHtml(AppLocaleKeys.osPrintSubtotal.tr)}</td></tr>
  <tr><td class="val">$discount</td><td class="lbl">${escapeHtml(AppLocaleKeys.osPrintDiscount.tr)}</td></tr>
  <tr><td class="val">$tax</td><td class="lbl">${escapeHtml(taxLbl)}</td></tr>
  <tr class="grand"><td class="val">$grandTotal</td><td class="lbl">${escapeHtml(AppLocaleKeys.osPrintGrandTotal.tr)}</td></tr>
</table>''';
  }

  /// Shared navy footer bar: English tagline (left), Arabic slogan (center), payment logos.
  static String brandFooterBarHtml() => '''
  <div class="footer-bar invoice-bar">
    <span class="en">TOGETHER WE CREATE IMPACT</span>
    <span class="ar">${escapeHtml(AppLocaleKeys.osPrintTogetherAr.tr)}</span>
    ${paymentMethodsHtml()}
  </div>''';

  /// Accepted payment method logos (Visa/Mastercard, Qi Card, Zain Cash, FIB).
  static String paymentMethodsHtml() {
    final imgs = OsPrintAssets.paymentMethodDataUris
        .map(
          (src) => src.isEmpty ? '' : '<img src="$src" alt=""/>',
        )
        .where((img) => img.isNotEmpty)
        .join('');
    if (imgs.isEmpty) return '';
    return '<div class="payment-methods no-split">$imgs</div>';
  }

  /// Invoice-style footer: QR + barcode + signature/seal + navy bar.
  static String invoiceFooterHtml({
    required String qrSvg,
    required String barcodeSvg,
    required String documentRef,
  }) {
    final seal = OsPrintAssets.sealDataUri;
    final sealImg = seal.isEmpty
        ? ''
        : '<img class="invoice-seal" src="$seal" alt=""/>';

    return '''
<div class="brand-footer no-split">
  <div class="invoice-footer-top">
    <div class="qr-block">
      <div class="qr-svg">$qrSvg</div>
      <div class="qr-caption">${escapeHtml(AppLocaleKeys.osPrintQrVerify.tr)}</div>
    </div>
    <div class="invoice-barcode">
      <div class="bc-svg">$barcodeSvg</div>
      <div class="barcode-ref">${escapeHtml(documentRef)}</div>
    </div>
    <div class="invoice-sign">
      <div class="sign-block">
        <div class="sign-agency">${escapeHtml(AppLocaleKeys.osPrintThanks.tr)}</div>
        <div class="sign-agency sign-agency-name">${escapeHtml(AppLocaleKeys.osPrintAgencyAr.tr)}</div>
        <div class="sign-line"></div>
        <div class="sign-label">${escapeHtml(AppLocaleKeys.osPrintSignature.tr)}</div>
      </div>
      $sealImg
    </div>
  </div>
  ${brandFooterBarHtml()}
</div>''';
  }

  /// Quotation-style footer: QR (website) + thank-you/sign + keywords + navy bar.
  static String quotationFooterHtml({
    required String qrSvg,
  }) {
    final mark = OsPrintAssets.watermarkLogoDataUri;
    final markImg = mark.isEmpty
        ? ''
        : '<img class="quote-mark-img" src="$mark" alt=""/>';

    return '''
<div class="brand-footer no-split">
  <div class="brand-footer-top quote-footer-top">
    <div class="qr-block">
      <div class="qr-svg">$qrSvg</div>
      <div class="qr-caption">${escapeHtml(AppLocaleKeys.osPrintQrVisit.tr)}</div>
    </div>
    <div class="sign-block">
      <div class="sign-agency">${escapeHtml(AppLocaleKeys.osPrintThanks.tr)}</div>
      <div class="sign-agency" style="margin-bottom:14px;font-weight:700;font-size:9px">${escapeHtml(AppLocaleKeys.osPrintAgencyAr.tr)}</div>
      <div class="sign-line"></div>
      <div class="sign-label">${escapeHtml(AppLocaleKeys.osPrintSignature.tr)}</div>
    </div>
    <div class="quote-mark" dir="ltr">
      $markImg
    </div>
  </div>
  ${brandFooterBarHtml()}
</div>''';
  }

  /// Receipt/payment voucher footer: signature + seal + barcode + QR + navy bar.
  static String voucherFooterHtml({
    required String qrSvg,
    required String barcodeSvg,
    required String documentRef,
  }) {
    final seal = OsPrintAssets.sealDataUri;
    final sealImg = seal.isEmpty
        ? ''
        : '<img class="seal-img" src="$seal" alt=""/>';

    return '''
<div class="brand-footer no-split">
  <div class="voucher-footer-top">
    <div class="voucher-sign">
      <div class="voucher-sign-line"></div>
      <div class="voucher-sign-lbl">${escapeHtml(AppLocaleKeys.osPrintEmployeeSign.tr)}</div>
    </div>
    <div class="seal-wrap">
      $sealImg
    </div>
    <div class="voucher-barcode">
      <div class="bc-svg">$barcodeSvg</div>
      <div class="barcode-ref">${escapeHtml(documentRef)}</div>
    </div>
    <div class="qr-block">
      <div class="qr-svg">$qrSvg</div>
    </div>
  </div>
  <div class="footer-bar voucher-bar">
    <span class="en-wrap">
      <span class="en">POINT AGENCY</span>
      <span class="rule"></span>
    </span>
    <span class="ar">${escapeHtml(AppLocaleKeys.osPrintSloganAr.tr)}</span>
  </div>
</div>''';
  }

  /// Pad item rows so the table keeps a consistent visual height.
  /// Empty padded rows still show the row index in column 1 (template style).
  static List<String> padItemRows(
    List<String> rows, {
    int minRows = 10,
    required int columnCount,
  }) {
    final out = List<String>.from(rows);
    while (out.length < minRows) {
      final n = out.length + 1;
      final rest = List.filled(columnCount - 1, '<td>&nbsp;</td>').join();
      out.add('<tr><td>$n</td>$rest</tr>');
    }
    return out;
  }
}
