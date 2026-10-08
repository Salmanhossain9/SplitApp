import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile.dart';

/// Everything the screens need from login: email code, phone code, Google. Keeping it behind this
/// interface keeps the screens free of Supabase.
abstract class AuthRepository {
  /// Emits the signed-in user id (or null) now and on every change.
  Stream<String?> get userIdChanges;
  String? get userId;
  String? get email;

  /// The signed-in user's phone number, when they logged in by phone.
  String? get phone;

  /// A name to start the profile screen with (Google gives one).
  String? get suggestedName;

  /// Sends a 6 digit code to the email.
  Future<void> sendCode(String email);

  /// Verifies the code and signs in. Throws [AuthFailure] with a friendly message.
  Future<void> verifyCode(String email, String code);

  /// Texts a 6 digit code to a phone number in the "+8801XXXXXXXXX" form.
  Future<void> sendPhoneCode(String phone);
  Future<void> verifyPhoneCode(String phone, String code);

  /// Opens Google's sign-in in the browser. The app is signed in when the browser hands back to it.
  Future<void> signInWithGoogle();
  Future<void> signOut();

  Future<Profile?> loadProfile();
  Future<Profile> saveProfile(Profile profile);
}

/// Where the browser sends the person back after Google. Must also be listed under Supabase,
/// Authentication, URL Configuration, Redirect URLs (docs/LOGIN_SETUP.md).
const authRedirectUrl = 'splitbit://login-callback';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String friendlyAuthMessage(Object error) {
  final text = error.toString().toLowerCase();
  // Supabase answers like this when no SMS service (Twilio and so on) is connected to the project.
  if (text.contains('sms') || text.contains('phone provider') || text.contains('unsupported phone')) {
    return 'phone codes are not available yet. use email or google instead.';
  }
  if (text.contains('provider is not enabled') || text.contains('unsupported provider')) {
    return 'google sign-in is not set up yet. use email for now.';
  }
  if (text.contains('expired') || text.contains('invalid')) {
    return 'that code did not work. check it or ask for a new one.';
  }
  if (text.contains('rate') || text.contains('too many') || text.contains('seconds')) {
    return 'too many tries. wait a minute and try again.';
  }
  if (text.contains('socket') || text.contains('network') || text.contains('failed host')) {
    return 'no connection. check your internet and try again.';
  }
  return 'something went wrong. please try again.';
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  @override
  Stream<String?> get userIdChanges async* {
    yield _client.auth.currentUser?.id;
    yield* _client.auth.onAuthStateChange.map((s) => s.session?.user.id).distinct();
  }

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  String? get phone {
    final p = _client.auth.currentUser?.phone;
    return (p == null || p.isEmpty) ? null : (p.startsWith('+') ? p : '+$p');
  }

  @override
  String? get suggestedName {
    final meta = _client.auth.currentUser?.userMetadata;
    final name = (meta?['full_name'] ?? meta?['name']) as String?;
    return (name == null || name.trim().isEmpty) ? null : name.trim();
  }

  @override
  Future<void> sendPhoneCode(String phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone.trim(), shouldCreateUser: true);
    } catch (e) {
      throw AuthFailure(friendlyAuthMessage(e));
    }
  }

  @override
  Future<void> verifyPhoneCode(String phone, String code) async {
    try {
      final res = await _client.auth.verifyOTP(phone: phone.trim(), token: code.trim(), type: OtpType.sms);
      if (res.session == null) throw const AuthFailure('that code did not work. check it or ask for a new one.');
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure(friendlyAuthMessage(e));
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      // Google's page opens in the browser. When it is done the browser opens splitbit://login-callback,
      // which brings the person back here already signed in (supabase_flutter picks the link up).
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: authRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      throw AuthFailure(friendlyAuthMessage(e));
    }
  }

  @override
  Future<void> sendCode(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true);
    } catch (e) {
      throw AuthFailure(friendlyAuthMessage(e));
    }
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    try {
      final res = await _client.auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.email);
      if (res.session == null) throw const AuthFailure('that code did not work. check it or ask for a new one.');
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure(friendlyAuthMessage(e));
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<Profile?> loadProfile() async {
    final id = userId;
    if (id == null) return null;
    final row = await _client.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : Profile.fromRow(row);
  }

  @override
  Future<Profile> saveProfile(Profile profile) async {
    final row = await _client.from('profiles').upsert(profile.toRow()).select().single();
    return Profile.fromRow(row);
  }
}

/// Demo mode (no Supabase configured): always "signed in" as a local user with a local profile.
class LocalAuthRepository implements AuthRepository {
  static const localId = 'local-user';
  Profile? _profile = const Profile(id: localId, name: 'You');
  final _controller = StreamController<String?>.broadcast();

  @override
  Stream<String?> get userIdChanges async* {
    yield userId;
    yield* _controller.stream;
  }

  String? _id = localId;

  @override
  String? get userId => _id;

  @override
  String? get email => 'demo@splitup.app';

  @override
  String? get phone => null;

  @override
  String? get suggestedName => null;

  @override
  Future<void> sendCode(String email) async {}

  @override
  Future<void> sendPhoneCode(String phone) async {}

  @override
  Future<void> verifyPhoneCode(String phone, String code) => verifyCode(phone, code);

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> verifyCode(String email, String code) async {
    _id = localId;
    _controller.add(_id);
  }

  @override
  Future<void> signOut() async {
    _id = null;
    _controller.add(null);
  }

  @override
  Future<Profile?> loadProfile() async => _id == null ? null : _profile;

  @override
  Future<Profile> saveProfile(Profile profile) async => _profile = profile;
}
