/// Shared A4-portrait print stylesheet and HTML escaping for Os documents.
library;

/// Core CSS injected into every Os print HTML document.
const osPrintA4Css = '''
@import url('https://fonts.googleapis.com/css2?family=Almarai:wght@300;400;700;800&display=swap');
@page { size: A4 portrait; margin: 12mm; }
html, body {
  margin: 0;
  padding: 0;
  background: #fff;
  color: #0f172a;
  font-family: 'Almarai', sans-serif;
}
.a4 {
  width: 186mm;
  max-width: 100%;
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
@media print {
  body { padding: 0 !important; }
}
''';

String escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
