import 'env.dart';

/// The public pages Google Play asks for. They are hosted with the share page (web/share).
String get privacyPolicyUrl => '${Env.shareBaseUrl}/privacy.html';
String get termsUrl => '${Env.shareBaseUrl}/terms.html';
String get deleteAccountUrl => '${Env.shareBaseUrl}/delete-account.html';
