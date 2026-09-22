import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_whatsapp_template_map.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_print.dart';
import 'package:point/View/Os/Finance/os_voucher_print.dart';
import 'package:point/View/Os/Invoices/os_invoice_print.dart';
import 'package:point/View/Os/Payroll/os_payslip_print.dart';
import 'package:point/View/Os/Quotations/os_quotation_print.dart';

/// Result of building a WhatsApp document PDF attachment.
class OsWhatsappPdfBuildResult {
  const OsWhatsappPdfBuildResult({
    required this.bytes,
    required this.filename,
    this.referenceId,
  });

  final Uint8List bytes;
  final String filename;
  final String? referenceId;
}

String _voucherAccountName(OsVoucherModel voucher) {
  if (!Get.isRegistered<OsFinanceController>()) return '';
  return Get.find<OsFinanceController>()
          .accountById(voucher.bankAccountId)
          ?.name ??
      '';
}

Future<OsWhatsappPdfBuildResult?> buildOsWhatsappDocumentPdf({
  required String attachment,
  OsInvoiceModel? invoice,
  OsQuotationModel? quotation,
  OsVoucherModel? voucher,
  OsLegalContractModel? contract,
  OsPayslipModel? payslip,
}) async {
  switch (attachment) {
    case OsWhatsappTemplateDocumentAttachment.invoicePdf:
      final inv = invoice;
      if (inv == null) return null;
      final bytes = await generateOsInvoiceClientCopyPdfBytes(inv);
      if (bytes == null || bytes.isEmpty) return null;
      return OsWhatsappPdfBuildResult(
        bytes: bytes,
        filename: osInvoicePdfFilename(inv),
        referenceId: inv.id,
      );
    case OsWhatsappTemplateDocumentAttachment.quotationPdf:
      final q = quotation;
      if (q == null) return null;
      final bytes = await generateOsQuotationClientCopyPdfBytes(q);
      if (bytes == null || bytes.isEmpty) return null;
      return OsWhatsappPdfBuildResult(
        bytes: bytes,
        filename: osQuotationPdfFilename(q),
        referenceId: q.id,
      );
    case OsWhatsappTemplateDocumentAttachment.voucherPdf:
    case OsWhatsappTemplateDocumentAttachment.receiptPdf:
    case OsWhatsappTemplateDocumentAttachment.paymentPdf:
      final v = voucher;
      if (v == null) return null;
      final accountName = _voucherAccountName(v);
      final bytes = await generateOsVoucherClientCopyPdfBytes(
        voucher: v,
        accountName: accountName,
      );
      if (bytes == null || bytes.isEmpty) return null;
      return OsWhatsappPdfBuildResult(
        bytes: bytes,
        filename: osVoucherPdfFilename(v),
        referenceId: v.id,
      );
    case OsWhatsappTemplateDocumentAttachment.contractPdf:
      final c = contract;
      if (c == null) return null;
      final bytes = await generateOsLegalContractPdfBytes(c);
      if (bytes == null || bytes.isEmpty) return null;
      return OsWhatsappPdfBuildResult(
        bytes: bytes,
        filename: osLegalContractPdfFilename(c),
        referenceId: c.id,
      );
    case OsWhatsappTemplateDocumentAttachment.payslipPdf:
      final p = payslip;
      if (p == null) return null;
      final bytes = await generateOsPayslipPdfBytes(p);
      if (bytes == null || bytes.isEmpty) return null;
      return OsWhatsappPdfBuildResult(
        bytes: bytes,
        filename: osPayslipPdfFilename(p),
        referenceId: p.id,
      );
    default:
      return null;
  }
}
