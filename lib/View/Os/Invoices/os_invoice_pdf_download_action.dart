import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/os_invoice_print.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_document_action_button.dart';

/// Table / row icon: shows a spinner while the WhatsApp client-copy PDF is built.
class OsInvoicePdfDownloadIconButton extends StatelessWidget {
  const OsInvoicePdfDownloadIconButton({
    super.key,
    required this.invoice,
    this.iconSize = 20,
    this.color,
    this.constraints = const BoxConstraints(minWidth: 36, minHeight: 36),
  });

  final OsInvoiceModel invoice;
  final double iconSize;
  final Color? color;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return OsDocumentActionIconButton(
      icon: Icons.picture_as_pdf_outlined,
      onPressed: () => downloadOsInvoiceClientCopyPdf(invoice),
      tooltip: AppLocaleKeys.osInvoicesDownloadWhatsappPdf.tr,
      iconSize: iconSize,
      color: color,
      constraints: constraints,
    );
  }
}

/// Preview dialog action chip with loading state.
class OsInvoicePdfDownloadFilledButton extends StatelessWidget {
  const OsInvoicePdfDownloadFilledButton({
    super.key,
    required this.invoice,
    this.theme,
    this.expand = false,
  });

  final OsInvoiceModel invoice;
  final AppThemeExtension? theme;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final resolvedTheme = theme ?? context.appTheme;

    return OsDocumentActionFilledButton(
      style: OsButtonStyles.pdfCompact(resolvedTheme),
      icon: Icons.picture_as_pdf_outlined,
      label: AppLocaleKeys.osInvoicesDownloadWhatsappPdf.tr,
      onPressed: () => downloadOsInvoiceClientCopyPdf(invoice),
      expand: expand,
    );
  }
}
