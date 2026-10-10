import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';

/// "delete my account" confirmation. Returns true once the person has typed `delete` and tapped
/// the button; the caller does the deleting. Deleting cannot be undone, so it is never one tap.
class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({super.key, required this.onDelete});

  /// Runs the deletion. Throws an exception whose toString is a plain message to show the problem in the sheet.
  final Future<void> Function() onDelete;

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _typed = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _ready => _typed.text.trim().toLowerCase() == 'delete';

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // AuthFailure prints as its plain message.
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('delete your account?', style: AppType.display36),
        const SizedBox(height: AppSpacing.s12),
        Text(
          'This cannot be undone. We delete your profile, your groups and friends, your notifications '
          'and every bill you made, including the shares your friends can see.',
          style: AppType.body16.copyWith(color: AppColors.slate),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'On bills other people made, your name stays as a plain name so their totals still add up.',
          style: AppType.label14.copyWith(color: AppColors.slate),
        ),
        const SizedBox(height: AppSpacing.s16),
        Text('type delete to confirm', style: AppType.heading20),
        const SizedBox(height: AppSpacing.s8),
        AppTextField(
          background: AppColors.white,
          controller: _typed,
          hint: 'delete',
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s12),
          ClaimedBanner(text: _error!, variant: BannerVariant.error),
        ],
        const SizedBox(height: AppSpacing.s16),
        DangerButton(label: 'delete forever', enabled: _ready, loading: _busy, onPressed: _delete),
        const SizedBox(height: AppSpacing.s12),
        WideButton(
          label: 'keep my account',
          variant: WideButtonVariant.another,
          enabled: !_busy,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

/// A flat coral pill for things that cannot be undone.
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.label, required this.onPressed, this.enabled = true, this.loading = false});
  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final live = enabled && !loading;
    return PressableScale(
      onTap: live ? onPressed : null,
      child: Container(
        height: AppSize.tabSwitch,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: live || loading ? AppColors.coral : AppColors.coral.withValues(alpha: AppOpacity.awayChip),
          borderRadius: AppRadius.rFull,
        ),
        child: loading
            ? const SizedBox(
                width: AppSize.icon,
                height: AppSize.icon,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.white),
              )
            : Text(label, style: AppType.body16.copyWith(color: AppColors.white, fontWeight: AppFonts.bold)),
      ),
    );
  }
}
