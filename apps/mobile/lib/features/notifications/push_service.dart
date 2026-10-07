import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';

/// Registers this phone for push and keeps `profiles.push_token` current.
///
/// Push needs a Firebase project: add `android/app/google-services.json` and build with
/// `--dart-define=FIREBASE_ENABLED=true`. Without both, this does nothing and reminders still
/// arrive as in-app notifications.
abstract class PushService {
  /// Ask permission, fetch the token, store it for [userId]. Returns false when push is off.
  Future<bool> register(String userId);
  Future<void> unregister(String userId);
}

class NoPushService implements PushService {
  @override
  Future<bool> register(String userId) async => false;

  @override
  Future<void> unregister(String userId) async {}
}

/// Where a tapped push goes.
const pushTapLocation = '/notifications';

/// Pure: the token as the profile column wants it.
Map<String, dynamic> pushTokenRow(String? token) => {'push_token': token};

typedef TokenFetcher = Future<String?> Function();

/// Firebase-free core of push registration, so it can be tested: ask for a token, write it,
/// and write it again whenever it rotates.
class PushRegistrar implements PushService {
  PushRegistrar({
    required this.requestPermission,
    required this.fetchToken,
    required this.onTokenRefresh,
    required this.saveToken,
  });

  final Future<bool> Function() requestPermission;
  final TokenFetcher fetchToken;
  final Stream<String> Function() onTokenRefresh;
  final Future<void> Function(String userId, String? token) saveToken;
  StreamSubscription<String>? _sub;

  @override
  Future<bool> register(String userId) async {
    if (!await requestPermission()) return false;
    final token = await fetchToken();
    if (token == null) return false;
    await saveToken(userId, token);
    await _sub?.cancel();
    _sub = onTokenRefresh().listen((t) => saveToken(userId, t));
    return true;
  }

  @override
  Future<void> unregister(String userId) async {
    await _sub?.cancel();
    _sub = null;
    await saveToken(userId, null);
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  if (!Env.isConfigured || !Env.firebaseEnabled) return NoPushService();
  return createFirebasePushService(Supabase.instance.client);
});

/// Defined in push_firebase.dart so tests and demo builds never touch Firebase.
PushService createFirebasePushService(SupabaseClient client) {
  debugPrint('push: Firebase service requested');
  return _firebaseFactory(client);
}

PushService Function(SupabaseClient) _firebaseFactory = (_) => NoPushService();

/// Called once from main() when Firebase is enabled, with the real implementation.
void installFirebasePushFactory(PushService Function(SupabaseClient) factory) => _firebaseFactory = factory;
