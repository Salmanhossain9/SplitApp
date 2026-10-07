import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_providers.dart';
import 'features/auth/email_screen.dart';
import 'features/auth/profile_screen.dart';
import 'features/auth/verify_screen.dart';
import 'features/bill/charges_screen.dart';
import 'features/bill/claim_screen.dart';
import 'features/bill/items_screen.dart';
import 'features/bill/new_bill_screen.dart';
import 'features/bill/settle_screen.dart';
import 'features/gallery/gallery_screen.dart';
import 'features/home/home_screen.dart';
import 'features/money/money_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/share/share_view_screen.dart';
import 'features/welcome/welcome_screen.dart';
import 'theme/tokens.dart';
import 'ui/ui.dart';

bool _isPublic(String path) =>
    path == '/welcome' || path.startsWith('/auth/') || path.startsWith('/s/') || path == '/gallery';

/// Logged out users only see /welcome, /auth/* and /s/:token. Logged in users skip /welcome.
/// Users without a profile row are sent to /auth/profile.
String? redirectFor({
  required String location,
  required AsyncValue<String?> session,
  required AsyncValue<dynamic> profile,
}) {
  if (session.isLoading || (session.value != null && profile.isLoading)) {
    return location == '/' || _isPublic(location) ? null : '/';
  }
  final signedIn = session.value != null;
  if (!signedIn) {
    if (_isPublic(location)) return null;
    return '/welcome';
  }
  final hasProfile = profile.value != null;
  if (!hasProfile) return location == '/auth/profile' ? null : '/auth/profile';
  if (location == '/' || location == '/welcome' || location.startsWith('/auth/')) return '/home';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.listen(profileProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      location: state.uri.path,
      session: ref.read(sessionProvider),
      profile: ref.read(profileProvider),
    ),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Splash()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/auth/email', builder: (_, _) => const EmailScreen()),
      GoRoute(
        path: '/auth/verify',
        builder: (_, state) => VerifyScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(path: '/auth/profile', builder: (_, _) => const ProfileScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/money', builder: (_, _) => const MoneyScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())]),
        ],
      ),
      GoRoute(path: '/bill/new', builder: (_, _) => const NewBillScreen()),
      GoRoute(path: '/bill/:id/items', builder: (_, _) => const ItemsScreen()),
      GoRoute(path: '/bill/:id/claim', builder: (_, _) => const ClaimScreen()),
      GoRoute(path: '/bill/:id/charges', builder: (_, _) => const ChargesScreen()),
      GoRoute(path: '/bill/:id/settle', builder: (_, _) => const SettleScreen()),
      GoRoute(
        path: '/s/:token',
        builder: (_, state) => ShareViewScreen(token: state.pathParameters['token']!),
      ),
      if (kDebugMode) GoRoute(path: '/gallery', builder: (_, _) => const GalleryScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: AppColors.cream, body: Center(child: Logo()));
}
