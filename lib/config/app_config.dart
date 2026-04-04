import 'package:point/firebase_app_options.dart';

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
      FirebaseAppOptions.currentPlatform.projectId;

  /// Public VAPID keys for Web Push Notifications (safe to be public)
  static const String fcmVapidKeyTest = 'BE5qo7OjlOYrCm57Bhw3eIOGB10llXhD1kJ8jCWQqBHfdYvfOYl7Wck6ugC1cj4BLPccwAU7AGTp35yCpiSddss';
  static const String fcmVapidKeyProd = 'BBR3nvqnyEKzmgmV5jj8-S-nuoMiJk9osiBt5Mv4ExNfZIa5aD-T6wklMXGBRmv2jGguAmhmJ1K13r0UVgm2OQc';
}
