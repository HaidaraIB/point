import 'package:point/Models/Os/OsEmailLogModel.dart';
import 'package:point/Models/Os/OsEmailSettings.dart';
import 'package:point/Models/Os/os_email_enums.dart';
import 'package:point/Services/EmailNotificationService.dart';
import 'package:point/Services/firestore/firestore_os_email_api.dart';

/// Central dispatch + audit logging for the Point OS email hub.
class OsEmailHubService {
  OsEmailHubService._();

  static String composeBody({
    required String message,
    required OsEmailSettings settings,
    bool includeSignature = true,
  }) {
    final trimmed = message.trim();
    if (!includeSignature || settings.signatureText.trim().isEmpty) {
      return trimmed;
    }
    if (trimmed.isEmpty) return settings.signatureText.trim();
    return '$trimmed\n\n${settings.signatureText.trim()}';
  }

  static Future<bool> sendAndLog({
    required String type,
    required String toEmail,
    required String recipientName,
    required String subject,
    required String content,
    required OsEmailSettings settings,
    String? referenceId,
    int attachmentsCount = 0,
    bool includeSignature = true,
    bool logToFirestore = true,
    bool isHtml = true,
    String? languageCode,
  }) async {
    final email = toEmail.trim();
    if (email.isEmpty) return false;

    final body = isHtml
        ? content
        : composeBody(
            message: content,
            settings: settings,
            includeSignature: includeSignature,
          );

    final ok = await EmailNotificationService.sendWithResult(
      toEmail: email,
      subject: subject,
      body: body,
      isHtml: isHtml,
      languageCode: languageCode,
    );

    final log = OsEmailLogModel(
      type: type,
      recipientName: recipientName.trim(),
      recipientEmail: email,
      subject: subject.trim(),
      content: body,
      status: ok ? OsEmailLogStatus.sent : OsEmailLogStatus.failed,
      referenceId: referenceId,
      senderEmail: settings.senderEmail.trim(),
      attachmentsCount: attachmentsCount,
      sentAt: DateTime.now(),
    );
    if (logToFirestore) {
      await FirestoreOsEmailApi.addLog(log);
    }
    return ok;
  }
}
