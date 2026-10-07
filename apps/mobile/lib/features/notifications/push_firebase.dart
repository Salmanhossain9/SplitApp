import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_service.dart';

/// The only file that imports Firebase. Installed from main() when FIREBASE_ENABLED is set.
PushService firebasePushService(SupabaseClient client) {
  return PushRegistrar(
    requestPermission: () async {
      try {
        final s = await FirebaseMessaging.instance.requestPermission();
        return s.authorizationStatus == AuthorizationStatus.authorized ||
            s.authorizationStatus == AuthorizationStatus.provisional;
      } catch (_) {
        return false;
      }
    },
    fetchToken: () async {
      try {
        return await FirebaseMessaging.instance.getToken();
      } catch (_) {
        return null;
      }
    },
    onTokenRefresh: () => FirebaseMessaging.instance.onTokenRefresh,
    saveToken: (userId, token) async {
      await client.from('profiles').update(pushTokenRow(token)).eq('id', userId);
    },
  );
}

/// Firebase.initializeApp with the google-services.json config. Returns false when it is missing.
Future<bool> initFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } catch (_) {
    return false;
  }
}
