import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import 'auth_providers.dart';

const avatarColorNames = ['lavender', 'lime', 'sky', 'coral'];

/// First login: name, avatar colour and an optional bKash number. The router sends everyone
/// without a profile row here.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _bkash = TextEditingController();
  String _color = 'lavender';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Google tells us the person's name: start from it instead of an empty field.
    _name.text = ref.read(authRepositoryProvider).suggestedName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _bkash.dispose();
    super.dispose();
  }

  /// Network problems get the friendly line; anything else shows the server's own reason so a
  /// wrong setup (missing table, policy) is visible instead of blamed on the connection.
  String _saveMessage(Object e) {
    final text = e.toString();
    final lower = text.toLowerCase();
    if (lower.contains('socket') || lower.contains('failed host') || lower.contains('network')) {
      return 'no connection. check your internet and try again.';
    }
    return 'could not save your profile: ${text.replaceAll('PostgrestException', '').trim()}';
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).save(
            name: _name.text,
            avatarColor: _color,
            bkash: _bkash.text,
          );
      // profileProvider now has a value, so the router moves on to home.
    } catch (e) {
      debugPrint('profile save failed: $e');
      if (mounted) setState(() => _error = _saveMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    return ScreenFrame(
      header: const Align(alignment: Alignment.centerLeft, child: Logo()),
      bottom: WideButton(
        label: 'let us go',
        variant: WideButtonVariant.done,
        enabled: name.isNotEmpty,
        loading: _busy,
        onPressed: _save,
      ),
      gap: AppSpacing.s24,
      children: [
        Text('what should friends call you?', style: AppType.display36),
        AppTextField(
          background: AppColors.white,
          controller: _name,
          hint: 'your name',
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _error = null),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final c in avatarColorNames)
              PressableScale(
                onTap: () => setState(() => _color = c),
                child: Avatar(
                  name: name.isEmpty ? '?' : name,
                  color: avatarColorOf(c),
                  size: AppSize.avatarChip,
                  // The chunky ring marks the picked colour.
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
              'Optional. Friends see it on their bill so they know where to send money.',
              style: AppType.label14.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: AppSpacing.s12),
            AppTextField(
              background: AppColors.white,
              controller: _bkash,
              hint: '01XXXXXXXXX',
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        if (_error != null) ClaimedBanner(text: _error!, variant: BannerVariant.error),
      ],
    );
  }
}
