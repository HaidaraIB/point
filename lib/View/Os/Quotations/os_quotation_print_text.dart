import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/os_quote_template_settings.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_print_a4.dart';

String buildOsQuotationPlainText(OsQuotationModel quote) {
  final ref = OsFinanceFormat.quotationRef(quote);
  final template = Get.isRegistered<OsQuoteTemplateController>()
      ? Get.find<OsQuoteTemplateController>()
      : null;
  final header = template?.headerText.value.trim().isNotEmpty == true
      ? template!.headerText.value
      : AppLocaleKeys.osQuotationsTemplateHeaderDefault.tr;
  final footer = template?.footerText.value.trim().isNotEmpty == true
      ? template!.footerText.value
      : AppLocaleKeys.osQuotationsTemplateFooterDefault.tr;

  return [
    AppLocaleKeys.osInvoicesAgencyHeader.tr,
    '',
    '${AppLocaleKeys.osQuotationsHeaderLabel.tr}: $header',
    '${AppLocaleKeys.osQuotationsClient.tr}: ${quote.clientName}',
    '${AppLocaleKeys.osQuotationsNumber.tr}: $ref',
    '${AppLocaleKeys.osQuotationsIssueDate.tr}: ${quote.date}',
    '${AppLocaleKeys.osQuotationsExpires.tr}: ${quote.expiryDate}',
    '${AppLocaleKeys.osQuotationsTotal.tr}: ${OsFinanceFormat.money(quote.total)}',
    '${AppLocaleKeys.osQuotationsApprovalStatus.tr}: '
        '${OsFinanceFormat.quotationStatusLabel(quote.status)}',
    '',
    footer,
  ].join('\n');
}

/// Darker status colors for print on white paper (UI colors are too light).
Color _printStatusColor(String status) {
  switch (status) {
    case OsQuotationStatus.approved:
      return const Color(0xFF047857);
    case OsQuotationStatus.rejected:
      return const Color(0xFFBE123C);
    default:
      return const Color(0xFF4338CA);
  }
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).substring(2)}';

String buildOsQuotationPrintHtml(OsQuotationModel quote) {
  final ref = OsFinanceFormat.quotationRef(quote);
  final agency = escapeHtml(AppLocaleKeys.osInvoicesAgencyHeader.tr);
  final template = Get.isRegistered<OsQuoteTemplateController>()
      ? Get.find<OsQuoteTemplateController>()
      : null;
  final header = escapeHtml(
    template?.headerText.value.trim().isNotEmpty == true
        ? template!.headerText.value
        : AppLocaleKeys.osQuotationsTemplateHeaderDefault.tr,
  );
  final footer = escapeHtml(
    template?.footerText.value.trim().isNotEmpty == true
        ? template!.footerText.value
        : AppLocaleKeys.osQuotationsTemplateFooterDefault.tr,
  );
  final status = escapeHtml(
    OsFinanceFormat.quotationStatusLabel(quote.status),
  );
  final statusHex = _hex(_printStatusColor(quote.status));
  final client = escapeHtml(quote.clientName);
  final money = escapeHtml(OsFinanceFormat.money(quote.total));

  return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>$agency — ${escapeHtml(ref)}</title>
<style>
$osPrintA4Css
body { padding: 0; background: #fff; }
.sheet {
  border: 1px solid #cbd5e1;
  border-radius: 12px;
  overflow: hidden;
}
.band {
  background: #514091;
  color: #fff;
  padding: 18px 20px 16px;
}
.band-row {
  display: flex;
  align-items: center;
  gap: 12px;
}
.mark {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  background: rgba(255,255,255,0.18);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 900;
  font-size: 16px;
  flex-shrink: 0;
}
.band h1 {
  margin: 0;
  font-size: 18px;
  font-weight: 800;
  color: #fff;
  flex: 1;
}
.badge {
  display: inline-block;
  padding: 5px 12px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 800;
  color: $statusHex;
  background: #fff;
  border: 1.5px solid $statusHex;
  white-space: nowrap;
}
.band-sub {
  margin-top: 12px;
  font-size: 13px;
  line-height: 1.45;
  color: rgba(255,255,255,0.92);
}
.body { padding: 20px; }
.client {
  font-size: 22px;
  font-weight: 900;
  color: #0f172a;
  margin: 0 0 4px;
}
.client-label {
  font-size: 12px;
  font-weight: 700;
  color: #334155;
  margin-bottom: 16px;
}
.meta {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px 16px;
  padding: 14px 16px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  margin-bottom: 16px;
}
.meta-label {
  display: block;
  font-size: 11px;
  font-weight: 700;
  color: #475569;
  margin-bottom: 4px;
}
.meta-value {
  font-size: 14px;
  font-weight: 800;
  color: #0f172a;
}
.meta-value.status { color: $statusHex; }
.total {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 16px 18px;
  background: #f5f3ff;
  border: 1.5px solid #7c6bb8;
  border-radius: 12px;
  margin-bottom: 16px;
}
.total-label {
  font-size: 13px;
  font-weight: 700;
  color: #334155;
}
.total-value {
  font-size: 22px;
  font-weight: 900;
  color: #4338ca;
}
.terms {
  display: flex;
  gap: 10px;
  align-items: flex-start;
  padding: 14px 16px;
  background: #f1f5f9;
  border: 1px solid #cbd5e1;
  border-radius: 12px;
}
.terms-icon {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #514091;
  color: #fff;
  font-size: 11px;
  font-weight: 900;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  margin-top: 2px;
}
.terms-text {
  font-size: 13px;
  line-height: 1.6;
  color: #1e293b;
  font-weight: 500;
}
</style>
</head>
<body>
  <div class="a4">
    <div class="sheet no-split">
      <div class="band">
        <div class="band-row">
          <div class="mark">ن</div>
          <h1>$agency</h1>
          <span class="badge">$status</span>
        </div>
        <div class="band-sub">$header</div>
      </div>
      <div class="body">
        <div class="client">$client</div>
        <div class="client-label">${escapeHtml(AppLocaleKeys.osQuotationsClient.tr)}</div>
        <div class="meta">
          <div>
            <span class="meta-label">${escapeHtml(AppLocaleKeys.osQuotationsNumber.tr)}</span>
            <div class="meta-value">${escapeHtml(ref)}</div>
          </div>
          <div>
            <span class="meta-label">${escapeHtml(AppLocaleKeys.osQuotationsApprovalStatus.tr)}</span>
            <div class="meta-value status">$status</div>
          </div>
          <div>
            <span class="meta-label">${escapeHtml(AppLocaleKeys.osQuotationsIssueDate.tr)}</span>
            <div class="meta-value">${escapeHtml(quote.date)}</div>
          </div>
          <div>
            <span class="meta-label">${escapeHtml(AppLocaleKeys.osQuotationsExpires.tr)}</span>
            <div class="meta-value">${escapeHtml(quote.expiryDate)}</div>
          </div>
        </div>
        <div class="total">
          <span class="total-label">${escapeHtml(AppLocaleKeys.osQuotationsTotal.tr)}</span>
          <span class="total-value">$money</span>
        </div>
        <div class="terms">
          <div class="terms-icon">!</div>
          <div class="terms-text">$footer</div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>
''';
}
