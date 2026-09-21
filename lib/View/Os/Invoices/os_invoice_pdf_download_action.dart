import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/os_invoice_print.dart';

/// Table / row icon: shows a spinner while the WhatsApp client-copy PDF is built.
class OsInvoicePdfDownloadIconButton extends StatefulWidget {
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
  State<OsInvoicePdfDownloadIconButton> createState() =>
      _OsInvoicePdfDownloadIconButtonState();
}

class _OsInvoicePdfDownloadIconButtonState
    extends State<OsInvoicePdfDownloadIconButton> {
  var _loading = false;

  Future<void> _download() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await downloadOsInvoiceClientCopyPdf(widget.invoice);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final theme = context.appTheme;
    final spinnerColor = widget.color ?? theme.accentText;

    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: widget.constraints,
      padding: EdgeInsets.zero,
      tooltip: AppLocaleKeys.osInvoicesDownloadWhatsappPdf.tr,
      onPressed: _loading ? null : _download,
      icon: _loading
          ? SizedBox(
              width: widget.iconSize,
              height: widget.iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: spinnerColor,
              ),
            )
          : Icon(
              Icons.picture_as_pdf_outlined,
              size: widget.iconSize,
              color: widget.color,
            ),
    );
  }
}

/// Preview dialog action chip with loading state.
class OsInvoicePdfDownloadFilledButton extends StatefulWidget {
  const OsInvoicePdfDownloadFilledButton({
    super.key,
    required this.invoice,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final OsInvoiceModel invoice;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  State<OsInvoicePdfDownloadFilledButton> createState() =>
      _OsInvoicePdfDownloadFilledButtonState();
}

class _OsInvoicePdfDownloadFilledButtonState
    extends State<OsInvoicePdfDownloadFilledButton> {
  var _loading = false;

  Future<void> _download() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await downloadOsInvoiceClientCopyPdf(widget.invoice);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final label = AppLocaleKeys.osInvoicesDownloadWhatsappPdf.tr;

    return FilledButton.icon(
      onPressed: _loading ? null : _download,
      style: FilledButton.styleFrom(
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      icon: _loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.foregroundColor,
              ),
            )
          : const Icon(Icons.picture_as_pdf_outlined, size: 16),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
