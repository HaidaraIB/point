import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Waits for Firebase Auth to restore the session from IndexedDB after a web
/// refresh (async); without this, [FirebaseAuth.instance.currentUser] is often
/// null on the first frames.
Future<void> waitForFirebaseAuthHydrationOnWeb() async {
  if (!kIsWeb) return;
  if (FirebaseAuth.instance.currentUser != null) return;
  try {
    await FirebaseAuth.instance.authStateChanges().first.timeout(
          const Duration(seconds: 1),
        );
  } catch (_) {}
  for (var i = 0; i < 80; i++) {
    if (FirebaseAuth.instance.currentUser != null) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
