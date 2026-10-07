import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../groups/groups_provider.dart';
import 'draft_bill_notifier.dart';

/// Screen 3: where are we eating, who is here, which group.
class NewBillScreen extends ConsumerStatefulWidget {
  const NewBillScreen({super.key});

  @override
  ConsumerState<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends ConsumerState<NewBillScreen> {
  late final TextEditingController _place =
      TextEditingController(text: ref.read(draftBillProvider).place);

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _addGuest() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('add a friend', style: AppType.display36),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'They do not need the app. They get a link to see their share.',
            style: AppType.label14.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: AppSpacing.s16),
          AppTextField(
            controller: name,
            hint: 'name',
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.s8),
          AppTextField(
            controller: phone,
            hint: 'phone (optional, for WhatsApp reminders)',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.s16),
          WideButton(
            label: 'add friend',
            variant: WideButtonVariant.done,
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              ref.read(draftBillProvider.notifier).addGuest(name.text, phone: phone.text);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
    name.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftBillProvider);
    final notifier = ref.read(draftBillProvider.notifier);
    final groups = ref.watch(groupsProvider);
    final groupName = groups.where((g) => g.id == draft.groupId).map((g) => g.name).firstOrNull;
    final here = draft.participants.length;
    final canContinue = draft.place.trim().isNotEmpty && here >= 2;

    return ScreenFrame(
      header: AppTopBar(
        trailing: const StepPill('step 1 of 3'),
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      bottom: WideButton(
        label: 'scan receipt',
        variant: WideButtonVariant.primary,
        enabled: canContinue,
        onPressed: () => context.push('/bill/${draft.id}/items'),
      ),
      gap: AppSpacing.s24,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('where are we eating?', style: AppType.title24),
            const SizedBox(height: AppSpacing.s8),
            HeadlineField(controller: _place, hint: 'Chillox', onChanged: notifier.setPlace),
            const SizedBox(height: AppSpacing.s8),
            Text(
              '${groupName == null ? '' : 'with $groupName . '}$here of ${draft.people.length} here',
              style: AppType.label14.copyWith(color: AppColors.slate),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('who is here', style: AppType.heading20),
            const SizedBox(height: AppSpacing.s12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in draft.people) ...[
                    AvatarChip(
                      person: p,
                      selected: draft.presentIds.contains(p.id),
                      onTap: () => notifier.toggleHere(p.id),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s24 + AppSpacing.s16),
                    child: AddFriendButton(onTap: _addGuest),
                  ),
                ],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('your groups', style: AppType.heading20),
            const SizedBox(height: AppSpacing.s12),
            GroupStack(
              groups: groups,
              frontId: draft.groupId,
              onTap: notifier.loadGroup,
            ),
          ],
        ),
      ],
    );
  }
}
