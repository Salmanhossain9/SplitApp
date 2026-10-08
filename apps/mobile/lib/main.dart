import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'features/auth/auth_providers.dart';
import 'features/bill/draft_bill_notifier.dart';
import 'features/notifications/push_firebase.dart';
import 'features/notifications/push_service.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (Env.isConfigured) {
    // Sessions persist and refresh automatically.
    await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
    // Push is optional: it needs Firebase config and says nothing if that is missing.
    if (Env.firebaseEnabled && await initFirebase()) installFirebasePushFactory(firebasePushService);
  }
  runApp(const ProviderScope(child: SplitbitApp()));
}

/// Lets the app show a snackbar from anywhere (sync problems), whatever screen is open.
final messengerKey = GlobalKey<ScaffoldMessengerState>();

class SplitbitApp extends ConsumerWidget {
  const SplitbitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Once a profile exists, register this phone for push (a no-op unless Firebase is set up).
    ref.listen(profileProvider, (_, next) {
      final profile = next.value;
      if (profile != null) ref.read(pushServiceProvider).register(profile.id);
    });
    // Problems saving to the server show up once, on whatever screen the person is on.
    ref.listen(syncErrorProvider, (_, message) {
      if (message == null) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.coral,
          content: Text(message, style: AppType.body16.copyWith(color: AppColors.white)),
        ),
      );
      ref.read(syncErrorProvider.notifier).clear();
    });
    return MaterialApp.router(
      scaffoldMessengerKey: messengerKey,
      title: 'Splitbit',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // Big type must not break the layouts.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: AppMotion.maxTextScale),
          ),
          child: child!,
        );
      },
    );
  }
}
