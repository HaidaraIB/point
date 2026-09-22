import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Quotations/os_quotation_print.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_document_action_button.dart';

/// Table / row icon: shows a spinner while the client-copy PDF is built.
class OsQuotationPdfDownloadIconButton extends StatelessWidget {
  const OsQuotationPdfDownloadIconButton({
    super.key,
    required this.quote,
    this.iconSize = 20,
    this.color,
    this.constraints = const BoxConstraints(minWidth: 36, minHeight: 36),
  });

  final OsQuotationModel quote;
  final double iconSize;
  final Color? color;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return OsDocumentActionIconButton(
      icon: Icons.picture_as_pdf_outlined,
      onPressed: () => downloadOsQuotationClientCopyPdf(quote),
      tooltip: AppLocaleKeys.osCommonDownloadClientPdf.tr,
      iconSize: iconSize,
      color: color,
      constraints: constraints,
    );
  }
}

/// Preview dialog header action with loading state.
class OsQuotationPdfDownloadFilledButton extends StatelessWidget {
  const OsQuotationPdfDownloadFilledButton({
    super.key,
    required this.quote,
    this.theme,
  });

  final OsQuotationModel quote;
  final AppThemeExtension? theme;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final resolvedTheme = theme ?? context.appTheme;

    return OsDocumentActionFilledButton(
      style: OsButtonStyles.pdfCompact(resolvedTheme),
      icon: Icons.picture_as_pdf_outlined,
      label: AppLocaleKeys.osCommonDownloadClientPdf.tr,
      onPressed: () => downloadOsQuotationClientCopyPdf(quote),
    );
  }
}
