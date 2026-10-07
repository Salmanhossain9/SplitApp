import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../notifications/notifications_repository.dart';

/// The four tabs (home, money, notifications, settings) with the floating navy nav.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          shell,
          Positioned(
            left: AppSpacing.s24,
            right: AppSpacing.s24,
            bottom: AppSpacing.s24 + bottomInset,
            child: BottomNav(
              index: shell.currentIndex,
              unreadNotifications: ref.watch(hasUnreadProvider),
              onTap: (i) {
                shell.goBranch(i, initialLocation: i == shell.currentIndex);
                // Opening the bell clears the dot (after a beat so the person sees what was new).
                if (i == 2) {
                  Future<void>.delayed(const Duration(milliseconds: 900), () {
                    ref.read(notificationsRepositoryProvider).markAllRead();
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
