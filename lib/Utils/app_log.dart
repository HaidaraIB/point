import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// يسجّل في وضع التصحيح فقط ([kDebugMode]).
void appLog(
  String message, {
  DateTime? time,
  int? sequenceNumber,
  int level = 0,
  String name = '',
  Object? error,
  StackTrace? stackTrace,
}) {
  if (!kDebugMode) return;
  developer.log(
    message,
    time: time,
    sequenceNumber: sequenceNumber,
    level: level,
    name: name,
    error: error,
    stackTrace: stackTrace,
  );
}

/// مثل [debugPrint] لكن لا يُنفَّذ في الإصدار النهائي.
void appDebugPrint(String? message, {int? wrapWidth}) {
  if (!kDebugMode) return;
  debugPrint(message, wrapWidth: wrapWidth);
}
