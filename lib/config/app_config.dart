import 'package:point/firebase_options.dart';

class AppConfig {
  /// Public (safe to ship in client builds)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const String supabaseStorageBaseUrl = String.fromEnvironment(
    'SUPABASE_STORAGE_BASE_URL',
    defaultValue: '',
  );

  /// Dev-only convenience. Do NOT pass this in production builds.
  static const String testAdminPassword = String.fromEnvironment(
    'TEST_ADMIN_PASSWORD',
    defaultValue: '',
  );

  /// Firebase project for this build. The Supabase secret for Edge Function
  /// `send-fcm` must be a service account whose `project_id` equals this value
  /// (FCM `messages:send` URL uses that project).
  static String get firebaseProjectId =>
      DefaultFirebaseOptions.currentPlatform.projectId;
}
