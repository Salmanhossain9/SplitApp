import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../../core/env.dart';
import '../auth/auth_providers.dart';
import '../bill/draft_bill_notifier.dart';
import '../auth/profile_screen.dart' show avatarColorNames;
import '../notifications/push_service.dart';

/// Profile, bKash number and log out.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bkash;
  String _color = 'lavender';
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider).value;
    _name = TextEditingController(text: p?.name ?? '');
    _bkash = TextEditingController(text: p?.bkashNumber ?? '');
    _color = p?.avatarColor ?? 'lavender';
  }

  @override
  void dispose() {
    _name.dispose();
    _bkash.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saved = false;
    });
    try {
      await ref.read(profileProvider.notifier).save(name: _name.text, avatarColor: _color, bkash: _bkash.text);
      if (mounted) setState(() => _saved = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logOut() async {
    final auth = ref.read(authRepositoryProvider);
    final id = auth.userId;
    if (id != null) {
      try {
        await ref.read(pushServiceProvider).unregister(id);
      } catch (_) {}
    }
    // The next person to log in must not inherit this person's half-finished bill.
    await ref.read(draftBillProvider.notifier).clear();
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authRepositoryProvider).email;
    final name = _name.text.trim();
    return ScreenFrame(
      reserveBottom: true,
      gap: AppSpacing.s24,
      children: [
        Text('settings', style: AppType.display36),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s24),
          decoration: const BoxDecoration(color: AppColors.sky, borderRadius: AppRadius.rLg),
          child: Row(
            children: [
              Avatar(name: name.isEmpty ? '?' : name, color: avatarColorOf(_color), size: AppSize.avatarChip, ringColor: AppColors.lime),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'your name' : name, style: AppType.title24, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (email != null) Text(email, style: AppType.label14, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('name', style: AppType.heading20),
            const SizedBox(height: AppSpacing.s8),
            AppTextField(
              background: AppColors.white,
              controller: _name,
              hint: 'your name',
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _saved = false),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final c in avatarColorNames)
              PressableScale(
                onTap: () => setState(() {
                  _color = c;
                  _saved = false;
                }),
                child: Avatar(
                  name: name.isEmpty ? '?' : name,
                  color: avatarColorOf(c),
                  size: AppSize.avatarChip,
                  ringColor: _color == c ? AppColors.navy : null,
                ),
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('bKash number', style: AppType.heading20),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Friends see it on their bill so they know where to send money.',
              style: AppType.label14.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: AppSpacing.s8),
            AppTextField(
              background: AppColors.white,
              controller: _bkash,
              hint: '01XXXXXXXXX',
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() => _saved = false),
            ),
          ],
        ),
        WideButton(
          label: _saved ? 'saved' : 'save changes',
          variant: WideButtonVariant.done,
          enabled: name.isNotEmpty && !_saved,
          loading: _saving,
          onPressed: _save,
        ),
        WideButton(label: 'log out', variant: WideButtonVariant.another, onPressed: _logOut),
        Center(
          child: Text(
            Env.isConfigured
                ? 'connected to your Supabase project'
                : 'offline mode: bills stay on this phone until you connect Supabase',
            textAlign: TextAlign.center,
            style: AppType.micro12.copyWith(color: AppColors.slate),
          ),
        ),
      ],
    );
  }
}
