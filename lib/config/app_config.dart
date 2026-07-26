import 'package:point/Utils/AppConstants.dart';
import 'package:point/firebase_app_options.dart';

class AppConfig {
  /// Compile-time app version / build from `--dart-define` (CI parses pubspec).
  /// Used on web to detect a newer deployed `version.json` than this bundle.
  /// Defaults are placeholders only — never bump them; bump `pubspec.yaml`.
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: kAppVersionFallback,
  );
  static const String appBuildNumber = String.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: kAppBuildFallback,
  );

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

  /// Cloudflare Worker base URL (no trailing slash), e.g. `https://r2-presign.xxx.workers.dev`
  static const String r2SignerUrl = String.fromEnvironment(
    'R2_SIGNER_URL',
    defaultValue: '',
  );

  /// Same value as the Worker secret `R2_PUBLIC_BASE_URL` (optional `dart-define` for tooling/docs).
  /// Uploads do not require this in the client: the Worker returns the full `publicUrl`.
  static const String r2PublicBaseUrl = String.fromEnvironment(
    'R2_PUBLIC_BASE_URL',
    defaultValue: '',
  );

  /// Play / App Store listing URLs when Firestore `appVersionGate/mobile` omits them.
  static const String androidStoreUrlFallback = String.fromEnvironment(
    'ANDROID_STORE_URL',
    defaultValue: '',
  );
  static const String iosStoreUrlFallback = String.fromEnvironment(
    'IOS_STORE_URL',
    defaultValue: '',
  );

  /// Dev-only convenience. Do NOT pass this in production builds.
  static const String testAdminPassword = String.fromEnvironment(
    'TEST_ADMIN_PASSWORD',
    defaultValue: '',
  );
  static const String testClientPassword = String.fromEnvironment(
    'TEST_CLIENT_PASSWORD',
    defaultValue: '',
  );

  /// Controls app-triggered email delivery.
  ///
  /// `EMAIL_DELIVERY_MODE=mock` logs emails locally and skips the Supabase
  /// Edge Function. `EMAIL_DELIVERY_MODE=send` invokes the Edge Function as
  /// usual. Without an explicit value, test Firebase builds mock email while
  /// production Firebase builds send real email.
  static const String emailDeliveryMode = String.fromEnvironment(
    'EMAIL_DELIVERY_MODE',
    defaultValue: '',
  );

  static bool get isMockEmailMode {
    final mode = emailDeliveryMode.trim().toLowerCase();
    if (mode == 'mock') return true;
    if (mode == 'send') return false;
    if (mode.isNotEmpty) {
      throw StateError('EMAIL_DELIVERY_MODE must be either "mock" or "send".');
    }
    return FirebaseAppOptions.isUsingTestFirebaseProject;
  }

  static bool get shouldSendRealEmails => !isMockEmailMode;

  /// Firebase project for this build (from [FirebaseAppOptions]: debug/legacy vs
  /// prod per `USE_FIREBASE_PROD` / `USE_FIREBASE_TEST` / `kDebugMode`).
  ///
  /// The Cloudflare **r2-presign** Worker expects secret `FIREBASE_PROJECT_IDS`
  /// (comma-separated allowlist matching every project you ship against). Tokens
  /// carry the correct `aud` automatically.
  ///
  /// The Supabase Edge Function `send-fcm` service account must still match the
  /// project used for FCM when sending pushes.
  static String get firebaseProjectId =>
      FirebaseAppOptions.currentPlatform.projectId;

  /// Public VAPID keys for Web Push Notifications (safe to be public)
  static const String fcmVapidKeyTest =
      'BE5qo7OjlOYrCm57Bhw3eIOGB10llXhD1kJ8jCWQqBHfdYvfOYl7Wck6ugC1cj4BLPccwAU7AGTp35yCpiSddss';
  static const String fcmVapidKeyProd =
      'BBR3nvqnyEKzmgmV5jj8-S-nuoMiJk9osiBt5Mv4ExNfZIa5aD-T6wklMXGBRmv2jGguAmhmJ1K13r0UVgm2OQc';
}
