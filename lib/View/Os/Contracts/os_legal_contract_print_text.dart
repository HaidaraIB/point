import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsContractSettings.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/Print/os_brand_print.dart';
import 'package:point/View/Os/os_print_a4.dart';

String buildOsLegalContractPlainText(
  OsLegalContractModel contract,
  OsContractSettings settings,
) {
  final start = FirestoreOsFinanceApi.formatDate(contract.startDate);
  final end = contract.endDate == null
      ? AppLocaleKeys.osCommonNa.tr
      : FirestoreOsFinanceApi.formatDate(contract.endDate!);

  final buf = StringBuffer()
    ..writeln(AppLocaleKeys.osPrintContractTitle.tr)
    ..writeln('${AppLocaleKeys.osLegalContractNumber.tr}: ${contract.contractNumber}')
    ..writeln('${AppLocaleKeys.osLegalContractFieldTitle.tr}: ${contract.title}')
    ..writeln(
      '${AppLocaleKeys.osLegalContractStatus.tr}: '
      '${osLegalContractStatusLabel(contract.status)}',
    )
    ..writeln('---')
    ..writeln('${AppLocaleKeys.osLegalContractPreviewPartyOne.tr}:')
    ..writeln(settings.agencyLegalName)
    ..writeln(
      '${settings.agencyAuthorizedSignatory} — ${settings.agencySignatoryTitle}',
    )
    ..writeln('---')
    ..writeln('${AppLocaleKeys.osLegalContractPreviewPartyTwo.tr}:')
    ..writeln(contract.targetName)
    ..writeln('---')
    ..writeln('${AppLocaleKeys.osLegalContractStart.tr}: $start')
    ..writeln('${AppLocaleKeys.osLegalContractEnd.tr}: $end')
    ..writeln(
      '${AppLocaleKeys.osLegalContractValue.tr}: '
      '${osLegalContractMoneyLabel(contract.totalValue, contract.currency)}',
    )
    ..writeln(
      '${AppLocaleKeys.osLegalContractGoverningLaw.tr}: ${contract.governingLaw}',
    )
    ..writeln(
      '${AppLocaleKeys.osLegalContractJurisdiction.tr}: ${contract.jurisdiction}',
    )
    ..writeln('---');

  for (final clause in contract.clauses) {
    buf
      ..writeln(clause.title)
      ..writeln(clause.content)
      ..writeln('');
  }

  final notes = contract.notes?.trim() ?? '';
  if (notes.isNotEmpty) {
    buf
      ..writeln('---')
      ..writeln('${AppLocaleKeys.osPrintNotes.tr}: $notes');
  }

  return buf.toString();
}

String buildOsLegalContractPrintHtml(
  OsLegalContractModel contract,
  OsContractSettings settings,
) {
  final start = FirestoreOsFinanceApi.formatDate(contract.startDate);
  final end = contract.endDate == null
      ? AppLocaleKeys.osCommonNa.tr
      : FirestoreOsFinanceApi.formatDate(contract.endDate!);
  final value = escapeHtml(
    osLegalContractMoneyLabel(contract.totalValue, contract.currency),
  );
  final status = escapeHtml(osLegalContractStatusLabel(contract.status));

  final clausesHtml = contract.clauses
      .map(
        (c) => '''
<div class="clause no-split">
  <h3>${escapeHtml(c.title)}</h3>
  <p>${escapeHtml(c.content)}</p>
</div>''',
      )
      .join('\n');

  var stampBlock = '';
  if (settings.enableDigitalStamp &&
      Get.isRegistered<OsStampSettingsController>()) {
    final stamp = Get.find<OsStampSettingsController>();
    if (stamp.stampEnabled.value) {
      final hex =
          '#${stamp.stampColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      stampBlock = '''
<div class="stamp no-split" style="border-color:$hex;color:$hex">
  ${escapeHtml(stamp.stampText.value)}
</div>''';
    }
  }

  final notes = contract.notes?.trim() ?? '';
  final notesBlock = notes.isEmpty
      ? ''
      : '''
<div class="notes no-split">
  <strong>${escapeHtml(AppLocaleKeys.osPrintNotes.tr)}</strong>
  <p>${escapeHtml(notes)}</p>
</div>''';

  final inner = '''
${OsBrandPrint.headerHtml()}
${OsBrandPrint.watermarkHtml()}
<div class="content-layer">
<div class="contract-head no-split">
  <h1>${escapeHtml(AppLocaleKeys.osPrintContractTitle.tr)}</h1>
  <p class="contract-title">${escapeHtml(contract.title)}</p>
  <p class="contract-ref">${escapeHtml(AppLocaleKeys.osLegalContractNumber.tr)}: <strong>${escapeHtml(contract.contractNumber)}</strong></p>
  <span class="status-pill">$status</span>
</div>
<div class="parties no-split">
  <div class="party">
    <div class="party-label">${escapeHtml(AppLocaleKeys.osLegalContractPreviewPartyOne.tr)}</div>
    <div class="party-name">${escapeHtml(settings.agencyLegalName)}</div>
    <div class="party-meta">${escapeHtml(settings.agencyAuthorizedSignatory)}</div>
    <div class="party-meta">${escapeHtml(settings.agencySignatoryTitle)}</div>
    <div class="party-meta">${escapeHtml(settings.agencyHeadquarters)}</div>
  </div>
  <div class="party">
    <div class="party-label">${escapeHtml(AppLocaleKeys.osLegalContractPreviewPartyTwo.tr)}</div>
    <div class="party-name">${escapeHtml(contract.targetName)}</div>
  </div>
</div>
<table class="meta no-split">
  <tr><td>${escapeHtml(AppLocaleKeys.osLegalContractStart.tr)}</td><td>${escapeHtml(start)}</td></tr>
  <tr><td>${escapeHtml(AppLocaleKeys.osLegalContractEnd.tr)}</td><td>${escapeHtml(end)}</td></tr>
  <tr><td>${escapeHtml(AppLocaleKeys.osLegalContractValue.tr)}</td><td><strong>$value</strong></td></tr>
  <tr><td>${escapeHtml(AppLocaleKeys.osLegalContractGoverningLaw.tr)}</td><td>${escapeHtml(contract.governingLaw)}</td></tr>
  <tr><td>${escapeHtml(AppLocaleKeys.osLegalContractJurisdiction.tr)}</td><td>${escapeHtml(contract.jurisdiction)}</td></tr>
</table>
<div class="clauses">$clausesHtml</div>
$notesBlock
<div class="signatures no-split">
  <div class="sig">
    <div class="sig-line"></div>
    <div>${escapeHtml(settings.agencyAuthorizedSignatory)}</div>
    <div class="sig-caption">${escapeHtml(AppLocaleKeys.osLegalContractPreviewPartyOne.tr)}</div>
  </div>
  <div class="sig">
    <div class="sig-line"></div>
    <div>${escapeHtml(contract.targetName)}</div>
    <div class="sig-caption">${escapeHtml(AppLocaleKeys.osLegalContractPreviewPartyTwo.tr)}</div>
  </div>
  $stampBlock
</div>
</div>''';

  return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>${escapeHtml(AppLocaleKeys.osPrintContractTitle.tr)} — ${escapeHtml(contract.contractNumber)}</title>
<style>
$osPrintA4Css
${OsBrandPrint.brandCss()}
.contract-print.sheet { min-height: 273mm; }
.contract-head { text-align: center; margin: 10px 0 16px; }
.contract-head h1 { font-size: 18px; margin: 0 0 6px; color: var(--navy); }
.contract-title { font-size: 14px; font-weight: 800; margin: 0 0 4px; }
.contract-ref { font-size: 11px; color: var(--muted); margin: 0 0 8px; }
.status-pill {
  display: inline-block;
  padding: 4px 12px;
  border-radius: 999px;
  background: var(--lavender);
  font-size: 10px;
  font-weight: 800;
}
.parties {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  margin-bottom: 12px;
}
.party {
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px 12px;
  background: #faf9fe;
}
.party-label { font-size: 9px; font-weight: 800; color: var(--muted); margin-bottom: 4px; }
.party-name { font-size: 12px; font-weight: 800; margin-bottom: 4px; }
.party-meta { font-size: 10px; color: var(--muted); line-height: 1.45; }
table.meta {
  font-size: 10px;
  margin-bottom: 14px;
}
table.meta td {
  border: 1px solid var(--border);
  padding: 6px 8px;
  vertical-align: top;
}
table.meta td:first-child {
  width: 28%;
  font-weight: 700;
  background: var(--lavender);
}
.clause { margin-bottom: 12px; }
.clause h3 { font-size: 11px; margin: 0 0 4px; color: var(--navy); }
.clause p { font-size: 10px; margin: 0; line-height: 1.55; text-align: justify; }
.notes { margin-top: 10px; font-size: 10px; }
.signatures {
  display: grid;
  grid-template-columns: 1fr 1fr auto;
  gap: 16px;
  align-items: end;
  margin-top: 20px;
}
.sig { text-align: center; font-size: 10px; }
.sig-line { border-top: 1px solid var(--text); margin-bottom: 8px; height: 40px; }
.sig-caption { font-size: 9px; color: var(--muted); margin-top: 4px; }
.stamp {
  border: 2px solid;
  border-radius: 50%;
  width: 72px;
  height: 72px;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  font-size: 9px;
  font-weight: 800;
  padding: 6px;
}
</style>
</head>
<body>
${osPrintTwoCopies(sheetClass: 'contract-print', innerHtml: inner)}
</body>
</html>''';
}
