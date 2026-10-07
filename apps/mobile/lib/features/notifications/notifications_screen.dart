import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import 'notifications_repository.dart';

/// The bell tab: reminders and "bill shared" events. Unread ones carry a coral dot.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final items = ref.watch(notificationsProvider);
    final list = items.value ?? const <AppNotification>[];

    return ScreenFrame(
      reserveBottom: true,
      gap: AppSpacing.s12,
      children: [
        Text('notifications', style: AppType.display36),
        const SizedBox(height: AppSpacing.s4),
        if (items.isLoading && !items.hasValue)
          const Center(child: Sparkle())
        else if (list.isEmpty)
          Text(
            'Nothing yet. Reminders and bills friends share with you show up here.',
            style: AppType.body16.copyWith(color: AppColors.slate),
          )
        else
          for (final n in list) _NotificationRow(n: n, now: now),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.n, required this.now});
  final AppNotification n;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (title, body) = n.text;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lime icon on a lavender tile.
          Container(
            width: AppSize.avatarRow,
            height: AppSize.avatarRow,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
            child: const AppIcon(AppIcons.bell, size: AppSize.icon - AppSpacing.s4, color: AppColors.lime),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.heading20),
                const SizedBox(height: AppSpacing.s4),
                Text(body, style: AppType.label14.copyWith(color: AppColors.slate)),
                const SizedBox(height: AppSpacing.s4),
                Text(timeAgo(n.createdAt, now), style: AppType.micro12.copyWith(color: AppColors.slate)),
              ],
            ),
          ),
          if (n.unread)
            Container(
              width: AppDims.dot,
              height: AppDims.dot,
              margin: const EdgeInsets.only(top: AppSpacing.s8),
              decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
