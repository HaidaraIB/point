import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_document_action_button.dart';

/// Web-only action that runs [onDownload] with a loading state.
class OsPrintPdfOutlinedButton extends StatefulWidget {
  const OsPrintPdfOutlinedButton({
    super.key,
    required this.onDownload,
    this.iconSize = 18,
  });

  final Future<void> Function() onDownload;
  final double iconSize;

  @override
  State<OsPrintPdfOutlinedButton> createState() => _OsPrintPdfOutlinedButtonState();
}

class _OsPrintPdfOutlinedButtonState extends State<OsPrintPdfOutlinedButton> {
  var _loading = false;

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onDownload();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final theme = context.appTheme;

    return OutlinedButton.icon(
      onPressed: _loading ? null : _run,
      style: OsButtonStyles.outlinedCompact(theme),
      icon: osDocumentActionIcon(
        loading: _loading,
        icon: Icons.picture_as_pdf_outlined,
        size: widget.iconSize,
      ),
      label: Text(AppLocaleKeys.osCommonDownloadClientPdf.tr),
    );
  }
}

/// Web-only compact filled button for toolbars (voucher detail, etc.).
class OsPrintPdfFilledCompactButton extends StatelessWidget {
  const OsPrintPdfFilledCompactButton({
    super.key,
    required this.theme,
    required this.onDownload,
    this.iconSize = 18,
    this.expand = false,
  });

  final AppThemeExtension theme;
  final Future<void> Function() onDownload;
  final double iconSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return OsDocumentActionFilledButton(
      style: OsButtonStyles.pdfCompact(theme),
      icon: Icons.picture_as_pdf_outlined,
      iconSize: iconSize,
      label: AppLocaleKeys.osCommonDownloadClientPdf.tr,
      onPressed: onDownload,
      expand: expand,
    );
  }
}

/// Web-only icon button for narrow toolbars.
class OsPrintPdfIconButton extends StatelessWidget {
  const OsPrintPdfIconButton({
    super.key,
    required this.onDownload,
    this.tooltip,
    this.iconSize = 18,
    this.color,
    this.constraints = const BoxConstraints(minWidth: 36, minHeight: 36),
  });

  final Future<void> Function() onDownload;
  final String? tooltip;
  final double iconSize;
  final Color? color;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return OsDocumentActionIconButton(
      icon: Icons.picture_as_pdf_outlined,
      onPressed: onDownload,
      tooltip: tooltip ?? AppLocaleKeys.osCommonDownloadClientPdf.tr,
      iconSize: iconSize,
      color: color,
      constraints: constraints,
    );
  }
}
