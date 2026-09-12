import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/View/Os/Finance/os_voucher_print_text.dart';
import 'package:web/web.dart';

/// Web: open a print-friendly HTML slip and call window.print() (point_os).
Future<void> printOsVoucher({
  required OsVoucherModel voucher,
  required String accountName,
}) async {
  final html = buildOsVoucherPrintHtml(
    voucher: voucher,
    accountName: accountName,
  );
  final bytes = Uint8List.fromList(utf8.encode(html));
  final blob = Blob(
    <BlobPart>[bytes.toJS].toJS,
    BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = URL.createObjectURL(blob);
  final win = window.open(url, '_blank');
  if (win == null) {
    URL.revokeObjectURL(url);
    return;
  }
  Future<void>.delayed(const Duration(milliseconds: 400), () {
    win.focus();
    win.print();
    URL.revokeObjectURL(url);
  });
}
