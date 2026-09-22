import 'package:point/View/Os/Print/os_print_assets.dart';
import 'package:point/View/Os/os_print_a4.dart';

/// Same document as [openOsPrintDocument], with fonts and CSS tuned for iframe PDF capture.
String osPrintHtmlForPdfCapture(String printHtml) {
  var html = printHtml;
  if (!html.contains('os-pdf-capture')) {
    html = html.replaceFirstMapped(
      RegExp(r'<html(\s+[^>]*)?>'),
      (match) {
        final attrs = match.group(1) ?? '';
        if (attrs.contains('os-pdf-capture')) {
          return match.group(0)!;
        }
        return '<html$attrs class="os-pdf-capture">';
      },
    );
  }

  final googleImport = RegExp(
    r"@import url\('https://fonts\.googleapis\.com/css2\?family=Almarai[^']*'\)[^;]*;\s*",
  );
  html = html.replaceFirst(googleImport, '');

  final embedded = OsPrintAssets.embeddedAlmaraiFontFaceCss;
  if (embedded.isNotEmpty && !html.contains('@font-face')) {
    html = html.replaceFirst('<style>', '<style>\n$embedded\n');
  }

  if (!OsPrintAssets.hasEmbeddedAlmarai &&
      !html.contains('fonts.googleapis.com')) {
    html = html.replaceFirst('</head>', '${osPrintGoogleFontsLink}\n</head>');
  }

  return html;
}
