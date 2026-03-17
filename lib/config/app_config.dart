class AppConfig {
  /// Public (safe to ship in client builds)
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String supabaseStorageBaseUrl =
      String.fromEnvironment('SUPABASE_STORAGE_BASE_URL', defaultValue: '');

  /// Dev-only convenience. Do NOT pass this in production builds.
  static const String testAccountholderPassword =
      String.fromEnvironment('TEST_ACCOUNTHOLDER_PASSWORD', defaultValue: '');
}

