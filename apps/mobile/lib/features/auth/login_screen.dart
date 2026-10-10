import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

enum LoginTab { logIn, signUp }

/// The one login screen: Google, Apple (not yet), or a 6 digit code to an email. Logging in and
/// signing up are the same passwordless thing, so the two tabs only change the wording.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  LoginTab _tab = LoginTab.logIn;
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;
  String? _notice;

  late final _termsTap = TapGestureRecognizer()..onTap = () => _open(termsUrl);
  late final _privacyTap = TapGestureRecognizer()..onTap = () => _open(privacyPolicyUrl);

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _valid => _emailPattern.hasMatch(_email.text.trim());

  void _edited() => setState(() {
        _error = null;
        _notice = null;
      });

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      final email = _email.text.trim();
      await auth.sendCode(email);
      if (mounted) context.push('/auth/verify?contact=${Uri.encodeQueryComponent(email)}');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      header: AppTopBar(
        trailing: const Logo(),
        onBack: () => context.canPop() ? context.pop() : context.go('/welcome'),
      ),
      gap: AppSpacing.s16,
      children: [
        Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('hop in.', style: AppType.hero50),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    _tab == LoginTab.logIn
                        ? 'Log in or sign up in a few seconds.'
                        : 'Make your account in a few seconds.',
                    style: AppType.label14.copyWith(color: AppColors.slate),
                  ),
                ],
              ),
            ),
            // Still stars: a login screen should not twinkle while someone types.
            const Positioned(right: 40, top: 0, child: AppIcon(AppIcons.sparkle, size: AppSize.icon + AppSpacing.s12, color: AppColors.lavender)),
            const Positioned(right: 8, top: 28, child: AppIcon(AppIcons.sparkle, size: AppSize.icon - AppSpacing.s4, color: AppColors.lavender)),
          ],
        ),
        PillSwitch<LoginTab>(
          options: const [(LoginTab.logIn, 'log in'), (LoginTab.signUp, 'sign up')],
          selected: _tab,
          onChanged: (t) => setState(() => _tab = t),
          activeColor: AppColors.navy,
        ),
        WideButton(
          label: 'continue with Apple',
          variant: WideButtonVariant.apple,
          // Not built yet: it says so instead of doing nothing.
          onPressed: () => setState(() {
            _error = null;
            _notice = 'sign in with Apple is coming soon. use google or an email code for now.';
          }),
        ),
        WideButton(
          label: 'continue with Google',
          variant: WideButtonVariant.google,
          loading: _googleBusy,
          onPressed: _google,
        ),
        Row(
          children: [
            const Expanded(child: _Rule()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              child: Text('or use your email', style: AppType.micro12.copyWith(color: AppColors.slate)),
            ),
            const Expanded(child: _Rule()),
          ],
        ),
        if (_notice != null) ClaimedBanner(text: _notice!),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                  background: AppColors.cream,
                  controller: _email,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  onChanged: (_) => _edited(),
                ),
              const SizedBox(height: AppSpacing.s8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                child: Text(
                  'We will email you a 6 digit code.',
                  style: AppType.micro12.copyWith(color: AppColors.slate),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ClaimedBanner(text: _error!, variant: BannerVariant.error),
        WideButton(
          label: 'send me a code',
          variant: WideButtonVariant.send,
          enabled: _valid,
          loading: _busy,
          onPressed: _send,
        ),
        Center(
          child: Text.rich(
            TextSpan(
              style: AppType.micro11.copyWith(color: AppColors.slate),
              children: [
                const TextSpan(text: 'By continuing you agree to our '),
                TextSpan(text: 'terms', recognizer: _termsTap, style: const TextStyle(decoration: TextDecoration.underline)),
                const TextSpan(text: ' and '),
                TextSpan(text: 'privacy policy', recognizer: _privacyTap, style: const TextStyle(decoration: TextDecoration.underline)),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// A thin flat line either side of "or use your email".
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: AppDims.divider,
        child: ColoredBox(color: AppColors.slate.withValues(alpha: AppOpacity.addFriend)),
      );
}
