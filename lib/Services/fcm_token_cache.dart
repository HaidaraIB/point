import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تخزين آخر توكن مُزامَن ومقارنته عند استئناف التطبيق.
class FcmTokenCache {
  FcmTokenCache._();

  static Future<void> rememberSuccess({
    required String token,
    required String role,
    required String userId,
  }) async {
    final cleaned = userId.trim();
    if (cleaned.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(StorageKeys.prefsFcmTokenLastSynced, token);
    await p.setString(StorageKeys.prefsFcmTokenRole, role);
    await p.setString(StorageKeys.prefsFcmTokenUserId, cleaned);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(StorageKeys.prefsFcmTokenLastSynced);
    await p.remove(StorageKeys.prefsFcmTokenRole);
    await p.remove(StorageKeys.prefsFcmTokenUserId);
  }

  /// إن تغيّر التوكن أثناء إغلاق التطبيق، ارفع النسخة الجديدة.
  static Future<void> resyncIfChanged() async {
    if (kIsWeb) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final cached = p.getString(StorageKeys.prefsFcmTokenLastSynced);
    if (cached == token) return;
    final role = p.getString(StorageKeys.prefsFcmTokenRole);
    final userId = p.getString(StorageKeys.prefsFcmTokenUserId);
    if (role == null || userId == null || userId.isEmpty) return;
    if (role == 'employee') {
      await FirestoreServices.addEmployeeFcmToken(
        employeeId: userId,
        token: token,
      );
    } else if (role == 'client') {
      await FirestoreServices.addClientFcmToken(
        clientId: userId,
        token: token,
      );
    }
    await rememberSuccess(token: token, role: role, userId: userId);
  }
}
