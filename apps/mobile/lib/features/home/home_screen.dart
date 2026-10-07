import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../auth/auth_providers.dart';
import '../bill/draft_bill_notifier.dart';

/// Placeholder home until milestone 6 (dashboard, bill list, open tabs).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenFrame(
      header: const Align(alignment: Alignment.centerLeft, child: Logo()),
      gap: AppSpacing.s24,
      children: [
        Row(
          children: [
            Expanded(child: Text('good evening.', style: AppType.display36)),
            NewBillPill(onTap: () async {
              await ref.read(draftBillProvider.notifier).clear();
              if (context.mounted) context.push('/bill/new');
            }),
          ],
        ),
        Wrap(
          spacing: AppSpacing.s8,
          children: [
            if (kDebugMode) PillButton(label: 'gallery', onTap: () => context.push('/gallery')),
            PillButton(
              label: 'log out',
              background: AppColors.cream,
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ),
      ],
    );
  }
}
