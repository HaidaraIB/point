import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Services/EmailNotificationService.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds the mock Nogta checkout URL (point_os generatePaymentLink).
/// Uses human invoice ref (`INV-001`) like point_os, not the Firestore UUID.
String osInvoicePaymentLink(OsInvoiceModel invoice) {
  final id = OsFinanceFormat.invoiceRef(invoice);
  // nextInt max must be in (0, 2^32]. On web, `1 << 32` is 0 — use 1<<31.
  final ref = Random().nextInt(1 << 31).toRadixString(36);
  return 'https://pay.nogta.agency/checkout/$id?ref=$ref';
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
  final link = osInvoicePaymentLink(invoice);
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
                    // LTR so the URL reads left→right and copy sits after it.
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              link,
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
                                ClipboardData(text: link),
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
  final link = osInvoicePaymentLink(invoice);
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
  final body = AppLocaleKeys.osInvoicesEmailBody.trParams({
    'client': invoice.clientName,
    'ref': ref,
    'amount': OsFinanceFormat.money(invoice.total),
    'due': invoice.dueDate,
  });

  try {
    await EmailNotificationService.send(
      toEmail: email,
      subject: subject,
      body: body,
    );
    OsSnackbar.success(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osInvoicesEmailSent.trParams({'email': email}),
    );
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
