import 'dart:async';
import 'package:point/Utils/app_log.dart';

import 'package:firebase_auth/firebase_auth.dart';

/// يمنع تسرب أخطاء `permission-denied` إلى [Rx.bindStream] / الـ zone بعد تسجيل الخروج.
Stream<List<T>> safeFirestoreListStream<T>(
  Stream<List<T>> source,
  String label,
) {
  return source.transform(
    StreamTransformer<List<T>, List<T>>.fromHandlers(
      handleError: (Object error, StackTrace stackTrace, EventSink<List<T>> sink) {
        if (FirebaseAuth.instance.currentUser == null) {
          sink.add(<T>[]);
          return;
        }
        final msg = error.toString();
        if (msg.contains('permission-denied')) {
          appLog(
            '⚠️ Firestore stream [$label]: permission-denied '
            '(often authRoles missing/stale — expect empty until streams rebind)',
          );
          sink.add(<T>[]);
          return;
        }
        appLog('⚠️ Firestore stream [$label]: $error');
        sink.add(<T>[]);
      },
    ),
  );
}
