import 'package:flutter_test/flutter_test.dart';
import 'package:point/Models/Os/os_whatsapp_template_map.dart';

void main() {
  group('OsWhatsappTemplateDocumentAttachment', () {
    test('locks PDF per built-in purpose', () {
      expect(
        OsWhatsappTemplateDocumentAttachment.defaultPdfForPurpose(
          OsWhatsappTemplatePurpose.invoice,
        ),
        OsWhatsappTemplateDocumentAttachment.invoicePdf,
      );
      expect(
        OsWhatsappTemplateDocumentAttachment.defaultPdfForPurpose(
          OsWhatsappTemplatePurpose.quotation,
        ),
        OsWhatsappTemplateDocumentAttachment.quotationPdf,
      );
      expect(
        OsWhatsappTemplateDocumentAttachment.defaultPdfForPurpose(
          OsWhatsappTemplatePurpose.paymentConfirmation,
        ),
        OsWhatsappTemplateDocumentAttachment.paymentPdf,
      );
      expect(
        OsWhatsappTemplateDocumentAttachment.defaultPdfForPurpose(
          OsWhatsappTemplatePurpose.paymentReceipt,
        ),
        OsWhatsappTemplateDocumentAttachment.receiptPdf,
      );
      expect(
        OsWhatsappTemplateDocumentAttachment.defaultPdfForPurpose(
          OsWhatsappTemplatePurpose.contract,
        ),
        OsWhatsappTemplateDocumentAttachment.contractPdf,
      );
      expect(
        OsWhatsappTemplateDocumentAttachment.defaultPdfForPurpose(
          OsWhatsappTemplatePurpose.payslip,
        ),
        OsWhatsappTemplateDocumentAttachment.payslipPdf,
      );
    });

    test('normalizes legacy voucher pdf to receipt pdf', () {
      expect(
        OsWhatsappTemplateDocumentAttachment.normalizeAttachment(
          OsWhatsappTemplateDocumentAttachment.voucherPdf,
        ),
        OsWhatsappTemplateDocumentAttachment.receiptPdf,
      );
    });
  });

  group('OsWhatsappTemplateFieldKey', () {
    test('invoice fields exclude voucher-only keys', () {
      final fields = OsWhatsappTemplateFieldKey.allowedFor(
        purpose: OsWhatsappTemplatePurpose.invoice,
        documentAttachment: OsWhatsappTemplateDocumentAttachment.invoicePdf,
      );
      expect(fields, contains(OsWhatsappTemplateFieldKey.paymentLink));
      expect(fields, isNot(contains(OsWhatsappTemplateFieldKey.voucherRef)));
      expect(fields, isNot(contains(OsWhatsappTemplateFieldKey.voucherPayee)));
    });

    test('payment and receipt share voucher fields', () {
      final paymentFields = OsWhatsappTemplateFieldKey.allowedFor(
        purpose: OsWhatsappTemplatePurpose.paymentConfirmation,
        documentAttachment: OsWhatsappTemplateDocumentAttachment.paymentPdf,
      );
      final receiptFields = OsWhatsappTemplateFieldKey.allowedFor(
        purpose: OsWhatsappTemplatePurpose.paymentReceipt,
        documentAttachment: OsWhatsappTemplateDocumentAttachment.receiptPdf,
      );
      expect(paymentFields, contains(OsWhatsappTemplateFieldKey.voucherPayee));
      expect(paymentFields, isNot(contains(OsWhatsappTemplateFieldKey.paymentLink)));
      expect(receiptFields, contains(OsWhatsappTemplateFieldKey.invoiceRef));
    });

    test('custom none keeps only client fields and manual', () {
      final fields = OsWhatsappTemplateFieldKey.forDocumentAttachment(
        OsWhatsappTemplateDocumentAttachment.none,
      );
      expect(fields, containsAll([
        OsWhatsappTemplateFieldKey.clientName,
        OsWhatsappTemplateFieldKey.company,
        OsWhatsappTemplateFieldKey.phone,
        OsWhatsappTemplateFieldKey.manual,
      ]));
      expect(fields.length, 4);
    });
  });

  group('OsWhatsappTemplateMapEntry', () {
    const tokens = ['customer_name', 'amount'];

    test('prunes invalid mappings when purpose changes', () {
      const entry = OsWhatsappTemplateMapEntry(
        templateName: 'tpl',
        languageCode: 'ar',
        purpose: OsWhatsappTemplatePurpose.invoice,
        placeholderFields: {
          'customer_name': OsWhatsappTemplateFieldKey.clientName,
          'amount': OsWhatsappTemplateFieldKey.paymentLink,
        },
      );

      final next = entry.withPurposeChange(
        OsWhatsappTemplatePurpose.quotation,
        placeholderTokens: tokens,
      );

      expect(next.purpose, OsWhatsappTemplatePurpose.quotation);
      expect(
        next.documentAttachment,
        OsWhatsappTemplateDocumentAttachment.quotationPdf,
      );
      expect(next.placeholderFields['customer_name'],
          OsWhatsappTemplateFieldKey.clientName);
      expect(next.placeholderFields.containsKey('amount'), isFalse);
    });

    test('detects unmapped placeholders for enabled templates', () {
      const entry = OsWhatsappTemplateMapEntry(
        templateName: 'tpl',
        languageCode: 'ar',
        enabled: true,
        purpose: OsWhatsappTemplatePurpose.invoice,
        placeholderFields: {
          'customer_name': OsWhatsappTemplateFieldKey.clientName,
        },
      );

      expect(entry.hasUnmappedPlaceholders(tokens), isTrue);
    });

    test('flags wrong document for built-in purpose with document header', () {
      const entry = OsWhatsappTemplateMapEntry(
        templateName: 'tpl',
        languageCode: 'ar',
        enabled: true,
        purpose: OsWhatsappTemplatePurpose.invoice,
        documentAttachment: OsWhatsappTemplateDocumentAttachment.quotationPdf,
      );

      expect(
        entry.hasWrongDocumentForPurpose(templateHasDocumentHeader: true),
        isTrue,
      );
    });
  });
}
