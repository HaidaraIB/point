/// أخطاء إرسال FCM عبر Edge Function [send-fcm].
class FcmSendException implements Exception {
  final int? status;
  final String? errorCode;
  final Object? details;
  final String? fcmErrorStatus;
  final String? fcmErrorMessage;

  const FcmSendException({
    this.status,
    this.errorCode,
    this.details,
    this.fcmErrorStatus,
    this.fcmErrorMessage,
  });

  @override
  String toString() =>
      'FcmSendException(status: $status, code: $errorCode, fcmStatus: $fcmErrorStatus, details: $details)';
}
