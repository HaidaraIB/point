/// Shared A4-portrait print stylesheet and HTML escaping for Os documents.
library;

import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';

/// Core CSS injected into every Os print HTML document.
const osPrintA4Css = '''
@import url('https://fonts.googleapis.com/css2?family=Almarai:wght@300;400;700;800&display=swap');
@page { size: A4 portrait; margin: 10mm 12mm; }
html, body {
  margin: 0;
  padding: 0;
  background: #fff;
  color: #0f172a;
  font-family: 'Almarai';
}
.a4 {
  width: 186mm;
  margin: 0 auto;
  box-sizing: border-box;
}
table {
  width: 100%;
  table-layout: fixed;
  border-collapse: collapse;
}
thead { display: table-header-group; }
tr, .no-split {
  page-break-inside: avoid;
  break-inside: avoid;
}
td, th { overflow-wrap: break-word; }
* {
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}
.copy-watermark {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
  z-index: 3;
  overflow: hidden;
}
.copy-watermark span {
  font-size: 42px;
  font-weight: 900;
  color: rgba(43, 42, 107, 0.10);
  transform: rotate(-18deg);
  white-space: nowrap;
  letter-spacing: 1px;
}
@media screen {
  body { background: #d8dce3; padding: 12px 0 !important; }
  .a4 {
    width: 210mm;
    max-width: none;
    min-height: 297mm;
    padding: 10mm 12mm;
    background: #fff;
    box-shadow: 0 1px 8px rgba(15, 23, 42, 0.12);
  }
  .a4 + .a4 { margin-top: 10mm; }
}
@media print {
  body { padding: 0 !important; background: #fff !important; }
  .a4 {
    box-shadow: none;
    page-break-after: always;
    break-after: page;
  }
  .a4:last-child {
    page-break-after: auto;
    break-after: auto;
  }
}
''';

/// Two A4 sheets for one print job: agency copy, then client copy.
String osPrintTwoCopies({
  String sheetClass = '',
  required String innerHtml,
}) {
  String page(String label) {
    final safe = escapeHtml(label);
    final classes = [
      'sheet',
      if (sheetClass.isNotEmpty) sheetClass,
    ].join(' ');
    return '''
<div class="a4">
  <div class="$classes">
    <div class="copy-watermark" aria-hidden="true"><span>$safe</span></div>
    $innerHtml
  </div>
</div>''';
  }

  return '${page(AppLocaleKeys.osPrintCopyAgency.tr)}\n'
      '${page(AppLocaleKeys.osPrintCopyClient.tr)}';
}

String escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
