/// Admin mapping of Meta templates to Point purposes and data fields.
class OsWhatsappTemplatePurpose {
  OsWhatsappTemplatePurpose._();

  static const unused = 'UNUSED';
  static const invoice = 'INVOICE';
  static const quotation = 'QUOTATION';
  static const paymentConfirmation = 'PAYMENT_CONFIRMATION';
  static const paymentReceipt = 'PAYMENT_RECEIPT';
  static const contract = 'CONTRACT';
  static const payslip = 'PAYSLIP';
  static const custom = 'CUSTOM';

  /// Built-in uses in UI order: Invoice → Quotation → Receipt → Payment → Payroll → Contract.
  static const builtIn = [
    invoice,
    quotation,
    paymentReceipt,
    paymentConfirmation,
    payslip,
    contract,
  ];

  static const menuOrder = [
    unused,
    ...builtIn,
    custom,
  ];

  static bool isBuiltIn(String purpose) => builtIn.contains(purpose);

  static int sortIndex(String purpose) {
    final idx = menuOrder.indexOf(purpose);
    return idx < 0 ? menuOrder.length : idx;
  }
}

/// Document attachment when the template header is DOCUMENT.
class OsWhatsappTemplateDocumentAttachment {
  OsWhatsappTemplateDocumentAttachment._();

  static const none = 'NONE';
  static const invoicePdf = 'INVOICE_PDF';
  static const quotationPdf = 'QUOTATION_PDF';
  /// Receipt printable (legacy stored value `VOUCHER_PDF`).
  static const voucherPdf = 'VOUCHER_PDF';
  static const receiptPdf = 'RECEIPT_PDF';
  static const paymentPdf = 'PAYMENT_PDF';
  static const contractPdf = 'CONTRACT_PDF';
  static const payslipPdf = 'PAYSLIP_PDF';

  static const pdfTypes = [
    invoicePdf,
    quotationPdf,
    receiptPdf,
    paymentPdf,
    contractPdf,
    payslipPdf,
    voucherPdf,
  ];

  /// Printable PDFs in built-in use order.
  static List<String> documentDropdownOptions() => [
        none,
        invoicePdf,
        quotationPdf,
        receiptPdf,
        paymentPdf,
        payslipPdf,
        contractPdf,
      ];

  /// Maps legacy/custom stored values to the current printable id.
  static String normalizeAttachment(String attachment) {
    if (attachment == voucherPdf) return receiptPdf;
    return attachment;
  }

  static bool isVoucherPrintable(String? attachment) {
    final normalized = attachment == null ? null : normalizeAttachment(attachment);
    return normalized == receiptPdf || normalized == paymentPdf;
  }

  static String? defaultPdfForPurpose(String purpose) {
    switch (purpose) {
      case OsWhatsappTemplatePurpose.quotation:
        return quotationPdf;
      case OsWhatsappTemplatePurpose.invoice:
        return invoicePdf;
      case OsWhatsappTemplatePurpose.paymentConfirmation:
        return paymentPdf;
      case OsWhatsappTemplatePurpose.paymentReceipt:
        return receiptPdf;
      case OsWhatsappTemplatePurpose.contract:
        return contractPdf;
      case OsWhatsappTemplatePurpose.payslip:
        return payslipPdf;
      default:
        return null;
    }
  }

  /// Locked PDF for built-in purposes; custom keeps [documentAttachment].
  static String resolvedForPurpose(
    String purpose, {
    String documentAttachment = none,
  }) {
    if (OsWhatsappTemplatePurpose.isBuiltIn(purpose)) {
      return defaultPdfForPurpose(purpose) ?? none;
    }
    if (purpose == OsWhatsappTemplatePurpose.custom) {
      return documentDropdownOptions().contains(documentAttachment)
          ? documentAttachment
          : none;
    }
    return none;
  }

  static bool isPdfAttachment(String? attachment) {
    return attachment != null && pdfTypes.contains(attachment);
  }

  /// Built-in purposes lock the document; custom chooses from the dropdown.
  static bool isLockedForPurpose(String purpose) {
    return OsWhatsappTemplatePurpose.isBuiltIn(purpose);
  }
}

/// Point field bound to a template placeholder token.
class OsWhatsappTemplateFieldKey {
  OsWhatsappTemplateFieldKey._();

  static const clientName = 'CLIENT_NAME';
  static const company = 'COMPANY';
  static const phone = 'PHONE';
  static const invoiceRef = 'INVOICE_REF';
  static const quoteRef = 'QUOTE_REF';
  static const amount = 'AMOUNT';
  static const total = 'TOTAL';
  static const issueDate = 'ISSUE_DATE';
  static const dueDate = 'DUE_DATE';
  static const expiryDate = 'EXPIRY_DATE';
  static const paymentLink = 'PAYMENT_LINK';
  static const invoiceStatus = 'INVOICE_STATUS';
  static const voucherRef = 'VOUCHER_REF';
  static const voucherPayee = 'VOUCHER_PAYEE';
  static const voucherDate = 'VOUCHER_DATE';
  static const contractNumber = 'CONTRACT_NUMBER';
  static const contractTitle = 'CONTRACT_TITLE';
  static const contractPartyName = 'CONTRACT_PARTY_NAME';
  static const contractStartDate = 'CONTRACT_START_DATE';
  static const contractEndDate = 'CONTRACT_END_DATE';
  static const contractTotalValue = 'CONTRACT_TOTAL_VALUE';
  static const payslipEmployeeName = 'PAYSLIP_EMPLOYEE_NAME';
  static const payslipPeriod = 'PAYSLIP_PERIOD';
  static const payslipRef = 'PAYSLIP_REF';
  static const payslipNetPay = 'PAYSLIP_NET_PAY';
  static const manual = 'MANUAL';

  static const _invoiceFields = [
    clientName,
    company,
    phone,
    invoiceRef,
    amount,
    total,
    issueDate,
    dueDate,
    paymentLink,
    invoiceStatus,
    manual,
  ];

  static const _quotationFields = [
    clientName,
    company,
    phone,
    quoteRef,
    amount,
    total,
    issueDate,
    expiryDate,
    manual,
  ];

  static const _voucherFields = [
    voucherPayee,
    voucherRef,
    amount,
    voucherDate,
    invoiceRef,
    manual,
  ];

  static const _contractFields = [
    contractNumber,
    contractTitle,
    contractPartyName,
    contractStartDate,
    contractEndDate,
    contractTotalValue,
    manual,
  ];

  static const _payslipFields = [
    payslipEmployeeName,
    payslipPeriod,
    payslipRef,
    payslipNetPay,
    manual,
  ];

  static const _customNoDocumentFields = [
    clientName,
    company,
    phone,
    manual,
  ];

  static List<String> forPurpose(String purpose) {
    return allowedFor(
      purpose: purpose,
      documentAttachment: OsWhatsappTemplateDocumentAttachment.resolvedForPurpose(
        purpose,
      ),
    );
  }

  /// Allowed placeholder bindings for a purpose and optional custom PDF choice.
  static List<String> allowedFor({
    required String purpose,
    required String documentAttachment,
  }) {
    switch (purpose) {
      case OsWhatsappTemplatePurpose.invoice:
        return _invoiceFields;
      case OsWhatsappTemplatePurpose.quotation:
        return _quotationFields;
      case OsWhatsappTemplatePurpose.paymentConfirmation:
      case OsWhatsappTemplatePurpose.paymentReceipt:
        return _voucherFields;
      case OsWhatsappTemplatePurpose.contract:
        return _contractFields;
      case OsWhatsappTemplatePurpose.payslip:
        return _payslipFields;
      case OsWhatsappTemplatePurpose.custom:
        return forDocumentAttachment(documentAttachment);
      default:
        return const [];
    }
  }

  /// Custom templates: placeholder list follows the chosen PDF (or none).
  static List<String> forDocumentAttachment(String attachment) {
    switch (attachment) {
      case OsWhatsappTemplateDocumentAttachment.invoicePdf:
        return _invoiceFields;
      case OsWhatsappTemplateDocumentAttachment.quotationPdf:
        return _quotationFields;
      case OsWhatsappTemplateDocumentAttachment.voucherPdf:
      case OsWhatsappTemplateDocumentAttachment.receiptPdf:
      case OsWhatsappTemplateDocumentAttachment.paymentPdf:
        return _voucherFields;
      case OsWhatsappTemplateDocumentAttachment.contractPdf:
        return _contractFields;
      case OsWhatsappTemplateDocumentAttachment.payslipPdf:
        return _payslipFields;
      default:
        return _customNoDocumentFields;
    }
  }

  /// Drop placeholder mappings that are not allowed for the current purpose/PDF.
  static Map<String, String> prunePlaceholders({
    required Map<String, String> current,
    required Iterable<String> placeholderTokens,
    required List<String> allowedFields,
  }) {
    final out = <String, String>{};
    for (final token in placeholderTokens) {
      final field = current[token];
      if (field != null &&
          field.isNotEmpty &&
          allowedFields.contains(field)) {
        out[token] = field;
      }
    }
    return out;
  }
}

class OsWhatsappTemplateMapEntry {
  const OsWhatsappTemplateMapEntry({
    required this.templateName,
    required this.languageCode,
    this.purpose = OsWhatsappTemplatePurpose.unused,
    this.customLabel = '',
    this.enabled = false,
    this.documentAttachment = OsWhatsappTemplateDocumentAttachment.none,
    this.placeholderFields = const {},
  });

  final String templateName;
  final String languageCode;
  final String purpose;
  final String customLabel;
  final bool enabled;
  final String documentAttachment;

  /// Placeholder token (e.g. `customer_name` or `1`) → [OsWhatsappTemplateFieldKey].
  final Map<String, String> placeholderFields;

  String mapKey() => '${templateName.trim()}|${languageCode.trim()}';

  /// PDF implied by purpose (built-in) or stored choice (custom).
  String effectiveDocumentAttachment() {
    return OsWhatsappTemplateDocumentAttachment.resolvedForPurpose(
      purpose,
      documentAttachment: documentAttachment,
    );
  }

  List<String> allowedFieldKeys() {
    return OsWhatsappTemplateFieldKey.allowedFor(
      purpose: purpose,
      documentAttachment: effectiveDocumentAttachment(),
    );
  }

  /// Normalize PDF + prune invalid placeholder mappings after load or edits.
  OsWhatsappTemplateMapEntry coerced({Iterable<String>? placeholderTokens}) {
    final resolved = effectiveDocumentAttachment();
    final attachment = purpose == OsWhatsappTemplatePurpose.custom
        ? resolved
        : (OsWhatsappTemplatePurpose.isBuiltIn(purpose)
            ? OsWhatsappTemplateDocumentAttachment.defaultPdfForPurpose(
                  purpose,
                ) ??
                OsWhatsappTemplateDocumentAttachment.none
            : OsWhatsappTemplateDocumentAttachment.none);

    if (placeholderTokens == null) {
      return copyWith(documentAttachment: attachment);
    }

    final pruned = OsWhatsappTemplateFieldKey.prunePlaceholders(
      current: placeholderFields,
      placeholderTokens: placeholderTokens,
      allowedFields: OsWhatsappTemplateFieldKey.allowedFor(
        purpose: purpose,
        documentAttachment: attachment,
      ),
    );
    return copyWith(
      documentAttachment: attachment,
      placeholderFields: pruned,
    );
  }

  OsWhatsappTemplateMapEntry withPurposeChange(
    String newPurpose, {
    required Iterable<String> placeholderTokens,
  }) {
    final attachment = OsWhatsappTemplateDocumentAttachment.resolvedForPurpose(
      newPurpose,
      documentAttachment: newPurpose == OsWhatsappTemplatePurpose.custom
          ? documentAttachment
          : OsWhatsappTemplateDocumentAttachment.none,
    );
    final allowed = OsWhatsappTemplateFieldKey.allowedFor(
      purpose: newPurpose,
      documentAttachment: attachment,
    );
    final pruned = OsWhatsappTemplateFieldKey.prunePlaceholders(
      current: placeholderFields,
      placeholderTokens: placeholderTokens,
      allowedFields: allowed,
    );
    return copyWith(
      purpose: newPurpose,
      documentAttachment: attachment,
      placeholderFields: pruned,
    );
  }

  OsWhatsappTemplateMapEntry withDocumentAttachmentChange(
    String newAttachment, {
    required Iterable<String> placeholderTokens,
  }) {
    if (purpose != OsWhatsappTemplatePurpose.custom) {
      return this;
    }
    final allowed = OsWhatsappTemplateFieldKey.allowedFor(
      purpose: purpose,
      documentAttachment: newAttachment,
    );
    final pruned = OsWhatsappTemplateFieldKey.prunePlaceholders(
      current: placeholderFields,
      placeholderTokens: placeholderTokens,
      allowedFields: allowed,
    );
    return copyWith(
      documentAttachment: newAttachment,
      placeholderFields: pruned,
    );
  }

  bool hasUnmappedPlaceholders(Iterable<String> placeholderTokens) {
    if (purpose == OsWhatsappTemplatePurpose.unused || !enabled) return false;
    for (final token in placeholderTokens) {
      final field = placeholderFields[token];
      if (field == null || field.isEmpty) return true;
    }
    return false;
  }

  bool hasWrongDocumentForPurpose({required bool templateHasDocumentHeader}) {
    if (!enabled || purpose == OsWhatsappTemplatePurpose.unused) return false;
    if (!templateHasDocumentHeader) return false;
    if (purpose == OsWhatsappTemplatePurpose.custom) {
      return !OsWhatsappTemplateDocumentAttachment.isPdfAttachment(
        effectiveDocumentAttachment(),
      );
    }
    if (!OsWhatsappTemplatePurpose.isBuiltIn(purpose)) return false;
    final expected = OsWhatsappTemplateDocumentAttachment.defaultPdfForPurpose(
      purpose,
    );
    return documentAttachment != expected;
  }

  factory OsWhatsappTemplateMapEntry.fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['placeholderFields'];
    final fields = <String, String>{};
    if (fieldsRaw is Map) {
      for (final e in fieldsRaw.entries) {
        final k = e.key.toString().trim();
        final v = e.value?.toString().trim() ?? '';
        if (k.isNotEmpty && v.isNotEmpty) fields[k] = v;
      }
    }
    return OsWhatsappTemplateMapEntry(
      templateName: (json['templateName'] as String?)?.trim() ?? '',
      languageCode: (json['languageCode'] as String?)?.trim() ?? '',
      purpose: (json['purpose'] as String?)?.trim().toUpperCase() ??
          OsWhatsappTemplatePurpose.unused,
      customLabel: (json['customLabel'] as String?)?.trim() ?? '',
      enabled: json['enabled'] == true,
      documentAttachment: OsWhatsappTemplateDocumentAttachment.normalizeAttachment(
        (json['documentAttachment'] as String?)?.trim().toUpperCase() ??
            OsWhatsappTemplateDocumentAttachment.none,
      ),
      placeholderFields: fields,
    );
  }

  Map<String, dynamic> toJson() => {
        'templateName': templateName,
        'languageCode': languageCode,
        'purpose': purpose,
        'customLabel': customLabel,
        'enabled': enabled,
        'documentAttachment': documentAttachment,
        'placeholderFields': placeholderFields,
      };

  OsWhatsappTemplateMapEntry copyWith({
    String? purpose,
    String? customLabel,
    bool? enabled,
    String? documentAttachment,
    Map<String, String>? placeholderFields,
  }) {
    return OsWhatsappTemplateMapEntry(
      templateName: templateName,
      languageCode: languageCode,
      purpose: purpose ?? this.purpose,
      customLabel: customLabel ?? this.customLabel,
      enabled: enabled ?? this.enabled,
      documentAttachment: documentAttachment ?? this.documentAttachment,
      placeholderFields: placeholderFields ?? this.placeholderFields,
    );
  }
}

class OsWhatsappTemplateMapConfig {
  const OsWhatsappTemplateMapConfig({this.entries = const []});

  final List<OsWhatsappTemplateMapEntry> entries;

  factory OsWhatsappTemplateMapConfig.fromJson(dynamic raw) {
    if (raw is! Map) return const OsWhatsappTemplateMapConfig();
    final list = raw['templates'];
    if (list is! List) return const OsWhatsappTemplateMapConfig();
    return OsWhatsappTemplateMapConfig(
      entries: list
          .whereType<Map>()
          .map((e) => OsWhatsappTemplateMapEntry.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .where((e) => e.templateName.isNotEmpty)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'templates': entries.map((e) => e.toJson()).toList(),
      };

  OsWhatsappTemplateMapEntry? entryFor(String templateName, String languageCode) {
    final name = templateName.trim().toLowerCase();
    final lang = languageCode.trim().toLowerCase();
    for (final e in entries) {
      if (e.templateName.trim().toLowerCase() == name &&
          e.languageCode.trim().toLowerCase() == lang) {
        return e;
      }
    }
    return null;
  }

  List<OsWhatsappTemplateMapEntry> enabledForPurpose(String purpose) {
    return entries
        .where((e) =>
            e.enabled &&
            e.purpose == purpose &&
            e.purpose != OsWhatsappTemplatePurpose.unused)
        .toList(growable: false);
  }

  OsWhatsappTemplateMapEntry? primaryForPurpose(String purpose) {
    final list = enabledForPurpose(purpose);
    return list.isEmpty ? null : list.first;
  }

  /// Returns a copy with [entry] replacing any existing row for the same template.
  OsWhatsappTemplateMapConfig withReplacedEntry(
    OsWhatsappTemplateMapEntry entry,
  ) {
    final key = entry.mapKey();
    final others = entries.where((e) => e.mapKey() != key).toList();
    return OsWhatsappTemplateMapConfig(entries: [...others, entry]);
  }
}
