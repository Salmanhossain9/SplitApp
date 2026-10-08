import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/person.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import 'shared_bill.dart';

/// `/s/:token` when the app is installed: the same page friends see on the web.
class ShareViewScreen extends ConsumerWidget {
  const ShareViewScreen({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref.watch(sharedBillProvider(token));
    return bill.when(
      loading: () => const ScreenFrame(
        header: Align(alignment: Alignment.centerLeft, child: Logo()),
        children: [],
      ),
      error: (_, _) => _Message(
        title: 'could not load this bill.',
        sub: 'check your connection and open the link again.',
        onRetry: () => ref.invalidate(sharedBillProvider(token)),
      ),
      data: (b) => b == null
          ? const _Message(title: 'this link does not exist.', sub: 'ask your friend to send it again.')
          : _Loaded(bill: b),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.sub, this.onRetry});
  final String title;
  final String sub;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      header: const Align(alignment: Alignment.centerLeft, child: Logo()),
      gap: AppSpacing.s16,
      children: [
        const SizedBox(height: AppSpacing.s24),
        Text(title, style: AppType.display36),
        Text(sub, style: AppType.body16.copyWith(color: AppColors.slate)),
        if (onRetry != null) Align(alignment: Alignment.centerLeft, child: LinkButton(label: 'try again', onTap: onRetry)),
      ],
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.bill});
  final SharedBill bill;

  @override
  Widget build(BuildContext context) {
    final settled = bill.status == 'settled';
    return ScreenFrame(
      header: AppTopBar(onBack: () => context.canPop() ? context.pop() : context.go('/')),
      gap: AppSpacing.s16,
      children: [
        Text(bill.place, style: AppType.display36),
        Row(
          children: [
            Text('paid by ${bill.hostName}  ', style: AppType.label14.copyWith(color: AppColors.slate)),
            AppPill(settled ? 'settled' : 'open', background: settled ? AppColors.lime : AppColors.coral),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s24),
          decoration: const BoxDecoration(color: AppColors.sky, borderRadius: AppRadius.rLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('total bill', style: AppType.body16),
              Money(bill.total, style: AppType.amount56, lightDecimals: true, fit: true),
            ],
          ),
        ),
        BillCardGrid(
          cards: [
            for (var i = 0; i < bill.people.length; i++)
              BillCard(
                person: _asPerson(bill.people[i]),
                index: i,
                total: bill.people[i].total,
                itemsAmount: bill.people[i].itemsAmount,
                extrasAmount: bill.people[i].extrasAmount,
              ),
          ],
        ),
        if (bill.hostBkash != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s24),
            decoration: const BoxDecoration(color: AppColors.lime, borderRadius: AppRadius.rLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('send your share to ${bill.hostName} on bKash', style: AppType.body16),
                const SizedBox(height: AppSpacing.s4),
                Text(bill.hostBkash!, style: AppType.display36),
                const SizedBox(height: AppSpacing.s12),
                PillButton(
                  label: 'copy number',
                  background: AppColors.lavender,
                  onTap: () => Clipboard.setData(ClipboardData(text: bill.hostBkash!)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Person _asPerson(SharedPerson p) => Person(id: p.name, name: p.name, isHost: p.isHost);
