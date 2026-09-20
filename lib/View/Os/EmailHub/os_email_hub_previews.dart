import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/OsEmailHubController.dart';
import 'package:point/View/Os/EmailHub/html_email_preview.dart';

class OsEmailHubInvoicePreview extends StatelessWidget {
  const OsEmailHubInvoicePreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (hub.selectedInvoice == null) return const SizedBox.shrink();
      return FutureBuilder<String>(
        future: hub.invoiceEmailHtml(),
        builder: (context, snapshot) {
          final html = snapshot.data ?? '';
          if (html.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return osEmailHubHtmlPreviewWidget(context, html);
        },
      );
    });
  }
}

class OsEmailHubQuotationPreview extends StatelessWidget {
  const OsEmailHubQuotationPreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (hub.selectedQuote == null) return const SizedBox.shrink();
      final html = hub.quotationEmailHtml();
      return osEmailHubHtmlPreviewWidget(context, html);
    });
  }
}

class OsEmailHubPayslipPreview extends StatelessWidget {
  const OsEmailHubPayslipPreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final emp = hub.selectedPayslipEmployee;
      if (emp == null) return const SizedBox.shrink();
      final html = hub.payslipEmailHtml(emp);
      return osEmailHubHtmlPreviewWidget(context, html);
    });
  }
}

class OsEmailHubAppreciationPreview extends StatelessWidget {
  const OsEmailHubAppreciationPreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (hub.selectedAppreciationEmployee == null) {
        return const SizedBox.shrink();
      }
      final html = hub.appreciationEmailHtml();
      return osEmailHubHtmlPreviewWidget(context, html);
    });
  }
}

class OsEmailHubContractPreview extends StatelessWidget {
  const OsEmailHubContractPreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (hub.selectedContract == null) return const SizedBox.shrink();
      return FutureBuilder<String>(
        future: hub.contractEmailHtml(),
        builder: (context, snapshot) {
          final html = snapshot.data ?? '';
          if (html.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return osEmailHubHtmlPreviewWidget(context, html);
        },
      );
    });
  }
}

class OsEmailHubPenaltyPreview extends StatelessWidget {
  const OsEmailHubPenaltyPreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (hub.selectedPenaltyEmployee == null) return const SizedBox.shrink();
      final html = hub.penaltyEmailHtml();
      return osEmailHubHtmlPreviewWidget(context, html);
    });
  }
}

String formatEmailLogDate(DateTime date) {
  return DateFormat('yyyy-MM-dd HH:mm').format(date);
}
