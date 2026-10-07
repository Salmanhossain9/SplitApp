import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile.dart';

/// Everything the screens need from login. Keeping it behind this interface means Google
/// sign-in or phone OTP can be added later without touching a screen.
abstract class AuthRepository {
  /// Emits the signed-in user id (or null) now and on every change.
  Stream<String?> get userIdChanges;
  String? get userId;
  String? get email;

  /// Sends a 6 digit code to the email.
  Future<void> sendCode(String email);

  /// Verifies the code and signs in. Throws [AuthFailure] with a friendly message.
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();

  Future<Profile?> loadProfile();
  Future<Profile> saveProfile(Profile profile);
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String friendlyAuthMessage(Object error) {
  final text = error.toString().toLowerCase();
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
  Future<void> sendCode(String email) async {}

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
