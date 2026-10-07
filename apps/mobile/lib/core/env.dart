/// Build-time config from `--dart-define-from-file=env.json` (see env.example.json).
/// Without it the app runs in local demo mode: no login, data stays on the device.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const shareBaseUrl = String.fromEnvironment('SHARE_BASE_URL', defaultValue: 'https://splitup.app');

  /// Set with --dart-define=FIREBASE_ENABLED=true once google-services.json is in place.
  static const firebaseEnabled = bool.fromEnvironment('FIREBASE_ENABLED');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
