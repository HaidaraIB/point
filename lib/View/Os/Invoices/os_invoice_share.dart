import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Services/email/os_email_html_composer.dart';
import 'package:point/Services/firestore/firestore_os_email_api.dart';
import 'package:point/Services/os_email_hub_service.dart';
import 'package:point/Services/os_paytabs_service.dart';
import 'package:point/Models/Os/os_email_enums.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

final Map<String, Future<String?>> _paymentLinkFutures = {};
final Set<String> _paymentLinkDialogInFlight = {};

/// Resolves a hosted PayTabs payment URL for [invoice].
Future<String?> resolveOsInvoicePaymentLink(OsInvoiceModel invoice) async {
  if (invoice.isPaid) return null;

  final invoiceId = invoice.id?.trim() ?? '';
  if (invoiceId.isEmpty) return null;

  final existing = _paymentLinkFutures[invoiceId];
  if (existing != null) return existing;

  final future = OsPaytabsService.instance.resolveInvoicePaymentLink(invoice);
  _paymentLinkFutures[invoiceId] = future;
  try {
    return await future;
  } finally {
    _paymentLinkFutures.remove(invoiceId);
  }
}

Future<T?> _withPaymentLinkLoading<T>(
  BuildContext context,
  Future<T?> action,
) async {
  if (!context.mounted) return null;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) {
      final theme = ctx.appTheme;
      return PopScope(
        canPop: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Material(
              color: theme.cardSurface,
              borderRadius: BorderRadius.circular(16),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.accentText,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        AppLocaleKeys.osInvoicesPaymentLinkPreparing.tr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  try {
    return await action;
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

ClientModel? osInvoiceClient(OsInvoiceModel invoice) {
  if (!Get.isRegistered<HomeController>()) return null;
  final clients = Get.find<HomeController>().clients;
  for (final c in clients) {
    if (c.id == invoice.clientId) return c;
  }
  for (final c in clients) {
    final name = c.name?.trim() ?? '';
    if (name.isNotEmpty && name == invoice.clientName.trim()) return c;
  }
  return null;
}

String osInvoiceItemsCountLabel(int count) {
  if (count <= 1) return AppLocaleKeys.osInvoicesItemsCountOne.tr;
  return AppLocaleKeys.osInvoicesItemsCountOther.trParams({
    'count': '$count',
  });
}

Future<void> showOsInvoicePaymentLinkDialog(
  BuildContext context,
  OsInvoiceModel invoice,
) async {
  if (invoice.isPaid) {
    OsSnackbar.error(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osInvoicesErrorAlreadyPaid.tr,
    );
    return;
  }

  final invoiceId = invoice.id?.trim() ?? '';
  if (invoiceId.isEmpty) return;
  if (!_paymentLinkDialogInFlight.add(invoiceId)) return;

  String? link;
  try {
    link = await _withPaymentLinkLoading(
      context,
      resolveOsInvoicePaymentLink(invoice),
    );
  } finally {
    _paymentLinkDialogInFlight.remove(invoiceId);
  }

  if (!context.mounted) return;
  if (link == null || link.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osInvoicesPaymentLinkUnavailable.tr,
    );
    return;
  }

  final paymentLink = link;
  final theme = context.appTheme;
  final narrow = MediaQuery.sizeOf(context).width < 600;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: narrow ? 16 : 28,
          vertical: narrow ? 24 : 28,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.link, color: theme.accentText, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocaleKeys.osInvoicesPaymentLinkTitle.tr,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close, color: theme.secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Text(
                    AppLocaleKeys.osInvoicesPaymentLinkHint.tr,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.secondaryText,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: theme.panelTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.border),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              paymentLink,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip:
                                AppLocaleKeys.osInvoicesPaymentLinkCopied.tr,
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: paymentLink),
                              );
                              OsSnackbar.success(
                                AppLocaleKeys.osInvoicesTitle.tr,
                                AppLocaleKeys.osInvoicesPaymentLinkCopied.tr,
                              );
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(AppLocaleKeys.osInvoicesOk.tr),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> shareOsInvoiceWhatsApp(OsInvoiceModel invoice) async {
  if (invoice.isPaid) {
    OsSnackbar.error(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osInvoicesErrorAlreadyPaid.tr,
    );
    return;
  }

  final link = await resolveOsInvoicePaymentLink(invoice);
  if (link == null || link.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osInvoicesPaymentLinkUnavailable.tr,
    );
    return;
  }

  final ref = OsFinanceFormat.invoiceRef(invoice);
  final body = AppLocaleKeys.osInvoicesWhatsappBody.trParams({
    'ref': ref,
    'amount': OsFinanceFormat.money(invoice.total),
    'link': link,
  });
  final client = osInvoiceClient(invoice);
  final phone = _digitsOnly(client?.phone);
  final uri = phone != null && phone.length >= 8
      ? Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(body)}')
      : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(body)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    OsSnackbar.error(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osInvoicesErrorLaunchFailed.tr,
    );
  }
}

Future<void> sendOsInvoiceEmail(OsInvoiceModel invoice) async {
  final client = osInvoiceClient(invoice);
  final email = client?.email?.trim() ?? '';
  if (email.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osInvoicesErrorNoEmail.tr,
    );
    return;
  }

  final ref = OsFinanceFormat.invoiceRef(invoice);
  final subject = AppLocaleKeys.osInvoicesEmailSubject.trParams({'ref': ref});
  var paymentLink = '';
  if (!invoice.isPaid) {
    final link = await resolveOsInvoicePaymentLink(invoice);
    if (link != null && link.isNotEmpty) paymentLink = link;
  }

  try {
    final settings = await FirestoreOsEmailApi.loadSettings();
    final html = OsEmailHtmlComposer.invoice(
      invoice: invoice,
      settings: settings,
      paymentLink: paymentLink,
    );
    final ok = await OsEmailHubService.sendAndLog(
      type: OsEmailCategory.invoice,
      toEmail: email,
      recipientName: invoice.clientName,
      subject: subject,
      content: html,
      settings: settings,
      referenceId: ref,
      attachmentsCount: 1,
    );
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesEmailSent.trParams({'email': email}),
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesErrorEmailFailed.tr,
      );
    }
  } catch (_) {
    OsSnackbar.error(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osInvoicesErrorEmailFailed.tr,
    );
  }
}

String? _digitsOnly(String? phone) {
  if (phone == null) return null;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  return digits;
}
