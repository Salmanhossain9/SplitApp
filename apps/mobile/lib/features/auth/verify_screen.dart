import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

/// Login step 2: type the 6 digit code. Signing in makes the router redirect on its own.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.contact, this.isPhone = false});

  /// The email address, or the phone number as "+8801XXXXXXXXX".
  final String contact;
  final bool isPhone;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  static const _resendSeconds = 30;
  final _codeKey = GlobalKey<State<CodeField>>();
  String _code = '';
  bool _busy = false;
  String? _error;
  int _cooldown = _resendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown = (_cooldown - 1).clamp(0, _resendSeconds));
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _verify([String? code]) async {
    final value = code ?? _code;
    if (value.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      await (widget.isPhone ? auth.verifyPhoneCode(widget.contact, value) : auth.verifyCode(widget.contact, value));
      // The session stream fires and the router redirects to the profile or home.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      final auth = ref.read(authRepositoryProvider);
      await (widget.isPhone ? auth.sendPhoneCode(widget.contact) : auth.sendCode(widget.contact));
      _startCooldown();
      if (mounted) setState(() => _error = null);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      header: AppTopBar(onBack: () => context.pop()),
      bottom: WideButton(
        label: 'log in',
        variant: WideButtonVariant.done,
        enabled: _code.length == 6,
        loading: _busy,
        onPressed: _verify,
      ),
      gap: AppSpacing.s24,
      children: [
        Text(widget.isPhone ? 'check your texts.' : 'check your email.', style: AppType.display36),
        Text(
          'We sent a 6 digit code to ${widget.contact}.',
          style: AppType.body16.copyWith(color: AppColors.slate),
        ),
        CodeField(
          key: _codeKey,
          enabled: !_busy,
          onChanged: (v) => setState(() {
            _code = v;
            _error = null;
          }),
          onCompleted: _verify,
        ),
        if (_error != null) ClaimedBanner(text: _error!, variant: BannerVariant.error),
        Align(
          alignment: Alignment.centerLeft,
          child: LinkButton(
            label: _cooldown > 0 ? 'send a new code in ${_cooldown}s' : 'send a new code',
            onTap: _cooldown > 0 ? null : _resend,
          ),
        ),
      ],
    );
  }
}
