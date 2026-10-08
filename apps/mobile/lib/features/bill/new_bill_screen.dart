import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/person.dart';
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

  Future<void> _addGuest() {
    return showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => _AddGuestSheet(
        onAdd: (name, phone) => ref.read(draftBillProvider.notifier).addGuest(name, phone: phone),
      ),
    );
  }

  /// The arrow on the active group: tick who is away tonight. They stay in the group but are
  /// left out of this bill.
  Future<void> _whoIsAway(GroupCardData group) {
    if (ref.read(draftBillProvider).groupId != group.id) {
      ref.read(draftBillProvider.notifier).loadGroup(group);
    }
    return showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => _AwaySheet(groupId: group.id),
    );
  }

  Future<void> _saveGroup() {
    final taken = [for (final g in ref.read(groupsProvider).value ?? const <GroupCardData>[]) g.name.trim().toLowerCase()];
    return showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => _SaveGroupSheet(
        taken: taken,
        onSave: (name) async {
          final friends = ref.read(draftBillProvider).participants.where((p) => !p.isHost).toList();
          final created = await ref.read(groupsProvider.notifier).create(name, friends);
          ref.read(draftBillProvider.notifier).setGroup(created.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftBillProvider);
    final notifier = ref.read(draftBillProvider.notifier);
    final groups = ref.watch(groupsProvider).value ?? const <GroupCardData>[];
    final groupName = groups.where((g) => g.id == draft.groupId).map((g) => g.name).firstOrNull;
    final here = draft.participants.length;
    final canContinue = draft.place.trim().isNotEmpty && here >= 2;

    return ScreenFrame(
      header: AppTopBar(
        trailing: const StepPill('step 1 of 3'),
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      // Same navy as the tab bar. It stays navy; tapping it too early says what is missing.
      bottom: WideButton(
        label: 'scan receipt',
        variant: WideButtonVariant.primary,
        onPressed: () {
          if (!canContinue) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.navy,
                content: Text(
                  draft.place.trim().isEmpty ? 'add where you are eating first.' : 'pick at least two people.',
                  style: AppType.body16.copyWith(color: AppColors.white),
                ),
              ),
            );
            return;
          }
          context.push('/bill/${draft.id}/items');
        },
      ),
      gap: AppSpacing.s24,
      children: [
        // Question, restaurant name and who is here, all centered like the design.
        Column(
          children: [
            Text('where are we eating?', style: AppType.heading20, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s8),
            HeadlineField(
              controller: _place,
              hint: 'Chillox',
              textAlign: TextAlign.center,
              onChanged: notifier.setPlace,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text.rich(
              TextSpan(
                style: AppType.label14.copyWith(color: AppColors.slate),
                children: [
                  if (groupName != null) ...[
                    const TextSpan(text: 'with '),
                    TextSpan(
                      text: groupName,
                      style: AppType.label14.copyWith(color: AppColors.lavender, fontWeight: AppFonts.bold),
                    ),
                    const TextSpan(text: ' · '),
                  ],
                  TextSpan(text: '$here of ${draft.people.length} here'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, box) {
            final row = Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
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
            );
            // Up to five friends shrink to fit the screen so none is cut in half; a bigger table
            // scrolls sideways.
            if (draft.people.length <= 5) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(constraints: BoxConstraints(minWidth: box.maxWidth), child: row),
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(constraints: BoxConstraints(minWidth: box.maxWidth), child: row),
            );
          },
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('your groups', style: AppType.heading20)),
                if (draft.participants.length >= 2)
                  PillButton(
                    label: 'new group',
                    onTap: _saveGroup,
                    background: AppColors.lime,
                    icon: AppIcons.plus,
                    iconColor: AppColors.lavender,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            if (groups.isEmpty)
              Text(
                'Add friends above, then save them as a group to start the next bill in one tap.',
                style: AppType.label14.copyWith(color: AppColors.slate),
              )
            else
              GroupStack(
                groups: [
                  for (final g in groups)
                    // The active group shows who is here and who is away tonight.
                    GroupCardData(
                      id: g.id,
                      name: g.name,
                      members: g.members,
                      absentIds: g.id == draft.groupId
                          ? {for (final m in g.members) if (!draft.presentIds.contains(m.id)) m.id}
                          : const {},
                    ),
                ],
                frontId: draft.groupId,
                onTap: notifier.loadGroup,
                onAway: _whoIsAway,
              ),
          ],
        ),
      ],
    );
  }
}

// The sheets own their text controllers. Disposing them right after showModalBottomSheet returns
// is too early: the route future completes while the close animation still draws the fields.
class _AddGuestSheet extends StatefulWidget {
  const _AddGuestSheet({required this.onAdd});
  final void Function(String name, String phone) onAdd;

  @override
  State<_AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends State<_AddGuestSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
          background: AppColors.white,
          controller: _name,
          hint: 'name',
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSpacing.s8),
        AppTextField(
          background: AppColors.white,
          controller: _phone,
          hint: 'phone (optional, for WhatsApp reminders)',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.s16),
        WideButton(
          label: 'add friend',
          variant: WideButtonVariant.done,
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            widget.onAdd(_name.text, _phone.text);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _SaveGroupSheet extends StatefulWidget {
  const _SaveGroupSheet({required this.onSave, this.taken = const []});
  final Future<void> Function(String name) onSave;

  /// Names (lower case) the person already has a group for.
  final List<String> taken;

  @override
  State<_SaveGroupSheet> createState() => _SaveGroupSheetState();
}

class _SaveGroupSheetState extends State<_SaveGroupSheet> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    // A second tap while saving must not make a second group.
    if (name.isEmpty || _busy) {
      return;
    }
    if (widget.taken.contains(name.toLowerCase())) {
      setState(() => _error = 'you already have a group called $name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      await widget.onSave(name);
      nav.pop();
    } catch (e) {
      debugPrint('group save failed: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'could not save the group. check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('name this group', style: AppType.display36),
        const SizedBox(height: AppSpacing.s16),
        AppTextField(
          background: AppColors.white,
          controller: _name,
          hint: 'NSU boys',
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s12),
          ClaimedBanner(text: _error!, variant: BannerVariant.error),
        ],
        const SizedBox(height: AppSpacing.s16),
        WideButton(
          label: 'save group',
          variant: WideButtonVariant.done,
          loading: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

/// "Who is here?" for the active group. Someone away stays in the group but is left out of this
/// bill: no share, no claims.
class _AwaySheet extends ConsumerWidget {
  const _AwaySheet({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftBillProvider);
    final notifier = ref.read(draftBillProvider.notifier);
    final group = (ref.watch(groupsProvider).value ?? const <GroupCardData>[]).where((g) => g.id == groupId).firstOrNull;
    final members = group?.members ?? const <Person>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('who is here?', style: AppType.display36),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'Tap anyone who is away. They stay in the group but are left out of this bill.',
          style: AppType.label14.copyWith(color: AppColors.slate),
        ),
        const SizedBox(height: AppSpacing.s16),
        for (final m in members) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
            child: Row(
              children: [
                Avatar(
                  name: m.name,
                  color: avatarColorOf(m.avatarColor) == AppColors.lime ? AppColors.lavender : avatarColorOf(m.avatarColor),
                  size: AppSize.avatarRow,
                  ringColor: AppColors.lime,
                  ringWidth: AppSize.avatarRingGroup,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body16)),
                NameChip(
                  key: ValueKey('away-${m.id}'),
                  label: draft.presentIds.contains(m.id) ? 'here' : 'away',
                  on: draft.presentIds.contains(m.id),
                  onTap: () => notifier.toggleHere(m.id),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        const SizedBox(height: AppSpacing.s8),
        WideButton(
          label: 'done',
          variant: WideButtonVariant.done,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
