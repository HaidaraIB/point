import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsWhatsappLogModel.dart';
import 'package:point/Models/Os/os_whatsapp_enums.dart';

String formatWhatsappLogDate(DateTime date) {
  return DateFormat('yyyy-MM-dd HH:mm').format(date);
}

String osWhatsappLogTemplateLabel(String templateName) {
  if (templateName.trim().toUpperCase() ==
      OsWhatsappLogTemplateName.session) {
    return AppLocaleKeys.osMessagingHubLogTemplateSession.tr;
  }
  return templateName;
}

/// Display name for an attached file on a log entry (new and legacy invoice sends).
String? osWhatsappLogAttachmentFilename(OsWhatsappLogModel log) {
  final stored = log.attachmentFilename.trim();
  if (stored.isNotEmpty) return stored;
  if (log.type.trim().toUpperCase() == OsWhatsappCategory.invoice) {
    return AppLocaleKeys.osMessagingHubLogInvoiceAttachment.tr;
  }
  return null;
}

bool osWhatsappLogShowsFollowUpAttachment(
  OsWhatsappTemplateModel? template,
  OsWhatsappLogModel log,
) {
  final attach = osWhatsappLogAttachmentFilename(log);
  if (attach == null) return false;
  if (template == null) return true;
  return !template.hasDocumentHeader;
}

String osWhatsappLogCategoryLabel(String type) {
  switch (type.trim().toUpperCase()) {
    case OsWhatsappCategory.invoice:
      return AppLocaleKeys.osMessagingHubLogTypeInvoice.tr;
    case OsWhatsappCategory.crm:
      return AppLocaleKeys.osMessagingHubLogTypeCrm.tr;
    default:
      return AppLocaleKeys.osMessagingHubLogTypeCustom.tr;
  }
}

/// User-facing text for stored Graph / edge errors (logs + snackbars).
String whatsappLogErrorForUi(String? raw) {
  var msg = (raw ?? '').trim();
  while (msg.startsWith('ERR_WHATSAPP_GRAPH:')) {
    msg = msg.substring('ERR_WHATSAPP_GRAPH:'.length).trim();
  }
  if (msg.contains('#138017') ||
      msg.toLowerCase().contains('call permission request')) {
    return AppLocaleKeys.osMessagingHubErrorCallPermission.tr;
  }
  if (msg.contains('ERR_WHATSAPP_DOCUMENT_HEADER_REQUIRED') ||
      msg.contains('ERR_WHATSAPP_DOCUMENT_REQUIRED')) {
    return AppLocaleKeys.osMessagingHubInvoiceTemplateDocumentRequired.tr;
  }
  if (msg.contains('ERR_WHATSAPP_SESSION_CLOSED') ||
      msg.contains('131047') ||
      msg.contains('131026')) {
    return AppLocaleKeys.osMessagingHubErrorSessionClosed.tr;
  }
  final lower = msg.toLowerCase();
  if (lower.contains('24 hour') ||
      lower.contains('24-hour') ||
      lower.contains('customer service window') ||
      lower.contains('re-engagement')) {
    return AppLocaleKeys.osMessagingHubErrorSessionClosed.tr;
  }
  if (msg == 'ERR_WHATSAPP_SESSION_EMPTY' ||
      msg == 'ERR_WHATSAPP_TEXT_REQUIRED') {
    return AppLocaleKeys.osMessagingHubSessionMessageRequired.tr;
  }
  if (msg.startsWith('ERR_')) {
    return AppLocaleKeys.osMessagingHubSendFailed.tr;
  }
  if (msg.isEmpty) {
    return AppLocaleKeys.osMessagingHubSendFailed.tr;
  }
  return msg;
}
