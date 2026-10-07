/// Build-time config from `--dart-define-from-file=env.json` (see env.example.json).
/// Without it the app runs in local demo mode: no login, data stays on the device.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const shareBaseUrl = String.fromEnvironment('SHARE_BASE_URL', defaultValue: 'https://splitup.app');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
