import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Login step 1: enter an email, get a 6 digit code. No phone login in v1.
class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _valid => _emailPattern.hasMatch(_email.text.trim());

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      await ref.read(authRepositoryProvider).sendCode(email);
      if (mounted) context.push('/auth/verify?email=${Uri.encodeQueryComponent(email)}');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      header: AppTopBar(onBack: () => context.canPop() ? context.pop() : context.go('/welcome')),
      bottom: WideButton(
        label: 'send me a code',
        variant: WideButtonVariant.done,
        enabled: _valid,
        loading: _busy,
        onPressed: _send,
      ),
      gap: AppSpacing.s24,
      children: [
        Text('what is your email?', style: AppType.display36),
        Text(
          'We send you a 6 digit code. No password to remember.',
          style: AppType.body16.copyWith(color: AppColors.slate),
        ),
        AppTextField(
          background: AppColors.white,
          controller: _email,
          hint: 'you@example.com',
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null) ClaimedBanner(text: _error!, variant: BannerVariant.error),
      ],
    );
  }
}
