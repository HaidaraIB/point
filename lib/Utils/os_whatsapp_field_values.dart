import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Models/Os/os_whatsapp_template_map.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/os_finance_format.dart';

class OsWhatsappSendContext {
  const OsWhatsappSendContext({
    this.client,
    this.invoice,
    this.quotation,
    this.voucher,
    this.contract,
    this.payslip,
    this.paymentLink = '',
    this.voucherRef = '',
    this.manualOverrides = const {},
  });

  final ClientModel? client;
  final OsInvoiceModel? invoice;
  final OsQuotationModel? quotation;
  final OsVoucherModel? voucher;
  final OsLegalContractModel? contract;
  final OsPayslipModel? payslip;
  final String paymentLink;
  final String voucherRef;
  final Map<String, String> manualOverrides;
}

Future<OsWhatsappSendContext> osWhatsappContextForInvoice(
  OsInvoiceModel invoice, {
  bool resolvePaymentLink = true,
}) async {
  var link = '';
  if (resolvePaymentLink && !invoice.isPaid) {
    final resolved = await resolveOsInvoicePaymentLink(invoice);
    if (resolved != null && resolved.isNotEmpty) link = resolved;
  }
  final client = osInvoiceClient(invoice);
  return OsWhatsappSendContext(
    client: client,
    invoice: invoice,
    paymentLink: link,
  );
}

OsWhatsappSendContext osWhatsappContextForQuotation(
  OsQuotationModel quote,
  ClientModel? client,
) {
  return OsWhatsappSendContext(client: client, quotation: quote);
}

OsWhatsappSendContext osWhatsappContextForPaidInvoice(
  OsInvoiceModel invoice, {
  String voucherRef = '',
}) {
  final client = osInvoiceClient(invoice);
  return OsWhatsappSendContext(
    client: client,
    invoice: invoice,
    voucherRef: voucherRef,
  );
}

OsWhatsappSendContext osWhatsappContextForVoucher(
  OsVoucherModel voucher, {
  OsInvoiceModel? linkedInvoice,
  ClientModel? client,
}) {
  return OsWhatsappSendContext(
    client: client,
    invoice: linkedInvoice,
    voucher: voucher,
    voucherRef: OsFinanceFormat.voucherRef(voucher),
  );
}

OsWhatsappSendContext osWhatsappContextForContract(
  OsLegalContractModel contract,
) {
  return OsWhatsappSendContext(contract: contract);
}

OsWhatsappSendContext osWhatsappContextForPayslip(
  OsPayslipModel payslip,
) {
  return OsWhatsappSendContext(payslip: payslip);
}

String? osWhatsappResolveField(
  String fieldKey,
  OsWhatsappSendContext ctx,
) {
  switch (fieldKey) {
    case OsWhatsappTemplateFieldKey.clientName:
      return ctx.client?.name?.trim() ??
          ctx.invoice?.clientName.trim() ??
          ctx.quotation?.clientName.trim();
    case OsWhatsappTemplateFieldKey.company:
      return ctx.client?.company?.trim();
    case OsWhatsappTemplateFieldKey.phone:
      return ctx.client?.phone?.trim() ??
          ctx.invoice?.clientPhone?.trim() ??
          ctx.quotation?.clientPhone?.trim();
    case OsWhatsappTemplateFieldKey.invoiceRef:
      if (ctx.invoice == null) return null;
      return OsFinanceFormat.invoiceRef(ctx.invoice!);
    case OsWhatsappTemplateFieldKey.quoteRef:
      if (ctx.quotation == null) return null;
      return OsFinanceFormat.quotationRef(ctx.quotation!);
    case OsWhatsappTemplateFieldKey.amount:
      if (ctx.voucher != null) {
        return OsFinanceFormat.money(ctx.voucher!.amount);
      }
      if (ctx.invoice != null) {
        return OsFinanceFormat.money(ctx.invoice!.amount);
      }
      if (ctx.quotation != null) {
        return OsFinanceFormat.money(ctx.quotation!.amount);
      }
      return null;
    case OsWhatsappTemplateFieldKey.total:
      if (ctx.invoice != null) {
        return OsFinanceFormat.money(ctx.invoice!.total);
      }
      if (ctx.quotation != null) {
        return OsFinanceFormat.money(ctx.quotation!.total);
      }
      return null;
    case OsWhatsappTemplateFieldKey.issueDate:
      return ctx.invoice?.date.trim() ?? ctx.quotation?.date.trim();
    case OsWhatsappTemplateFieldKey.dueDate:
      return ctx.invoice?.dueDate.trim();
    case OsWhatsappTemplateFieldKey.expiryDate:
      return ctx.quotation?.expiryDate.trim();
    case OsWhatsappTemplateFieldKey.paymentLink:
      return ctx.paymentLink.trim().isNotEmpty ? ctx.paymentLink.trim() : null;
    case OsWhatsappTemplateFieldKey.invoiceStatus:
      if (ctx.invoice == null) return null;
      return OsFinanceFormat.invoiceStatusLabel(ctx.invoice!.status);
    case OsWhatsappTemplateFieldKey.voucherRef:
      if (ctx.voucher != null) {
        return OsFinanceFormat.voucherRef(ctx.voucher!);
      }
      return ctx.voucherRef.trim().isNotEmpty ? ctx.voucherRef.trim() : null;
    case OsWhatsappTemplateFieldKey.voucherPayee:
      return ctx.voucher?.payeeOrPayer.trim();
    case OsWhatsappTemplateFieldKey.voucherDate:
      return ctx.voucher?.date.trim();
    case OsWhatsappTemplateFieldKey.contractNumber:
      return ctx.contract?.contractNumber.trim();
    case OsWhatsappTemplateFieldKey.contractTitle:
      return ctx.contract?.title.trim();
    case OsWhatsappTemplateFieldKey.contractPartyName:
      final c = ctx.contract;
      if (c == null) return null;
      final target = c.targetName.trim();
      if (target.isNotEmpty) return target;
      return c.partyTwoCompany.trim().isNotEmpty
          ? c.partyTwoCompany.trim()
          : null;
    case OsWhatsappTemplateFieldKey.contractStartDate:
      final c = ctx.contract;
      if (c == null) return null;
      return FirestoreOsFinanceApi.formatDate(c.startDate);
    case OsWhatsappTemplateFieldKey.contractEndDate:
      final end = ctx.contract?.endDate;
      if (end == null) return null;
      return FirestoreOsFinanceApi.formatDate(end);
    case OsWhatsappTemplateFieldKey.contractTotalValue:
      final c = ctx.contract;
      if (c == null) return null;
      final money = OsFinanceFormat.money(c.totalValue);
      final currency = c.currency.trim();
      if (currency.isEmpty) return money;
      return '$money $currency';
    case OsWhatsappTemplateFieldKey.payslipEmployeeName:
      return ctx.payslip?.employeeName.trim();
    case OsWhatsappTemplateFieldKey.payslipPeriod:
      return ctx.payslip?.period.trim();
    case OsWhatsappTemplateFieldKey.payslipRef:
      final slip = ctx.payslip;
      if (slip == null) return null;
      final num = slip.displayNumber?.trim() ?? '';
      if (num.isNotEmpty) return num;
      return slip.id?.trim();
    case OsWhatsappTemplateFieldKey.payslipNetPay:
      if (ctx.payslip == null) return null;
      return OsFinanceFormat.money(ctx.payslip!.netPay);
    case OsWhatsappTemplateFieldKey.manual:
      return null;
    default:
      return null;
  }
}

Map<String, String> osWhatsappValuesFromMap(
  Map<String, String> placeholderFields,
  OsWhatsappSendContext ctx, {
  Map<String, String> manualByToken = const {},
}) {
  final out = <String, String>{};
  for (final e in placeholderFields.entries) {
    final token = e.key;
    final field = e.value;
    if (field == OsWhatsappTemplateFieldKey.manual) {
      out[token] = manualByToken[token]?.trim() ?? '';
    } else {
      out[token] = osWhatsappResolveField(field, ctx)?.trim() ?? '';
    }
  }
  return out;
}

/// Receipt voucher linked to an invoice, if any.
String osWhatsappVoucherRefForInvoice(
  OsInvoiceModel invoice,
  List<OsVoucherModel> vouchers,
) {
  final id = invoice.id?.trim() ?? '';
  if (id.isEmpty) return '';
  for (final v in vouchers) {
    if (v.invoiceId?.trim() == id &&
        v.type == OsVoucherType.receipt) {
      final num = v.displayNumber?.trim() ?? '';
      if (num.isNotEmpty) return num;
      return v.id?.trim() ?? '';
    }
  }
  return '';
}

/// Phone to show on voucher forms: stored payeePhone, then client, then invoice snapshot.
String osVoucherResolvedPayeePhone(
  OsVoucherModel voucher, {
  OsInvoiceModel? linkedInvoice,
  ClientModel? client,
}) {
  final fromVoucher = voucher.payeePhone?.trim();
  if (fromVoucher != null && fromVoucher.isNotEmpty) return fromVoucher;
  final fromClient = client?.phone?.trim();
  if (fromClient != null && fromClient.isNotEmpty) return fromClient;
  final fromInvoice = linkedInvoice?.clientPhone?.trim();
  if (fromInvoice != null && fromInvoice.isNotEmpty) return fromInvoice;
  return '';
}

/// Recipient phone when sending a voucher (client and invoice before voucher cache).
String osWhatsappRecipientPhoneForVoucher(
  OsVoucherModel voucher, {
  OsInvoiceModel? linkedInvoice,
  ClientModel? client,
}) {
  final fromClient = client?.phone?.trim();
  if (fromClient != null && fromClient.isNotEmpty) return fromClient;
  final fromInvoice = linkedInvoice?.clientPhone?.trim();
  if (fromInvoice != null && fromInvoice.isNotEmpty) return fromInvoice;
  final fromVoucher = voucher.payeePhone?.trim();
  if (fromVoucher != null && fromVoucher.isNotEmpty) return fromVoucher;
  return '';
}

OsInvoiceModel? osWhatsappInvoiceForVoucher(
  OsVoucherModel voucher,
  List<OsInvoiceModel> invoices,
) {
  final invoiceId = voucher.invoiceId?.trim() ?? '';
  if (invoiceId.isEmpty) return null;
  for (final inv in invoices) {
    if (inv.id?.trim() == invoiceId) return inv;
  }
  return null;
}
