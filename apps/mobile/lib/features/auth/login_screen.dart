import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/phone.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

enum LoginTab { logIn, signUp }

enum Contact { email, phone }

/// The one login screen: Google, Apple (not yet), or a 6 digit code to an email (the default) or a
/// phone. Logging in and signing up are the same passwordless thing, so the two tabs only change
/// the wording.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  LoginTab _tab = LoginTab.logIn;
  Contact _contact = Contact.email;
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? get _phoneE164 => bdMobileE164(_phone.text);
  bool get _valid => _contact == Contact.email ? _emailPattern.hasMatch(_email.text.trim()) : _phoneE164 != null;

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
      if (_contact == Contact.email) {
        final email = _email.text.trim();
        await auth.sendCode(email);
        if (mounted) context.push('/auth/verify?kind=email&contact=${Uri.encodeQueryComponent(email)}');
      } else {
        final phone = _phoneE164!;
        await auth.sendPhoneCode(phone);
        if (mounted) context.push('/auth/verify?kind=phone&contact=${Uri.encodeQueryComponent(phone)}');
      }
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
    final phone = _contact == Contact.phone;
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
            _notice = 'sign in with Apple is coming soon. use google or a code for now.';
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
              child: Text('or use your phone or email', style: AppType.micro12.copyWith(color: AppColors.slate)),
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
              _ContactSwitch(
                selected: _contact,
                onChanged: (c) => setState(() {
                  _contact = c;
                  _error = null;
                }),
              ),
              const SizedBox(height: AppSpacing.s12),
              if (phone)
                _PhoneField(controller: _phone, onChanged: (_) => _edited())
              else
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
                  phone ? 'We will text you a 6 digit code.' : 'We will email you a 6 digit code.',
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
          child: Text(
            'By continuing you agree to our terms and privacy policy.',
            textAlign: TextAlign.center,
            style: AppType.micro11.copyWith(color: AppColors.slate),
          ),
        ),
      ],
    );
  }
}

/// A thin flat line either side of "or use your phone or email".
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: AppDims.divider,
        child: ColoredBox(color: AppColors.slate.withValues(alpha: AppOpacity.addFriend)),
      );
}

/// "phone | email" inside the card: cream pill, the chosen side lavender with its icon.
class _ContactSwitch extends StatelessWidget {
  const _ContactSwitch({required this.selected, required this.onChanged});
  final Contact selected;
  final ValueChanged<Contact> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget side(Contact c, AppIcons icon, String label) {
      final on = selected == c;
      return Expanded(
        child: PressableScale(
          onTap: () => onChanged(c),
          child: AnimatedContainer(
            duration: AppMotion.chip,
            height: AppSize.tabSwitch - AppSpacing.s8,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? AppColors.lavender : AppColors.clear, borderRadius: AppRadius.rFull),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(icon, size: AppSize.icon - AppSpacing.s8, color: on ? AppColors.white : AppColors.slate, stroke: 2.6),
                  const SizedBox(width: AppSpacing.s8),
                  Text(label, style: AppType.body16.copyWith(color: on ? AppColors.white : AppColors.slate)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: const BoxDecoration(color: AppColors.cream, borderRadius: AppRadius.rFull),
      child: Row(children: [side(Contact.phone, AppIcons.phone, 'phone'), side(Contact.email, AppIcons.mail, 'email')]),
    );
  }
}

/// "BD +880" and the 10 digits that follow. Typing a leading 0 (01712...) works too.
class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: const BoxDecoration(color: AppColors.cream, borderRadius: AppRadius.rFull),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
            decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rFull),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'BD ', style: AppType.label14.copyWith(fontWeight: AppFonts.bold)),
                TextSpan(text: '+880', style: AppType.label14.copyWith(fontWeight: AppFonts.bold)),
              ]),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(13)],
              style: AppType.body16,
              cursorColor: AppColors.lavender,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '1XXX XXXXXX',
                hintStyle: AppType.body16.copyWith(color: AppColors.slate.withValues(alpha: AppOpacity.awayChip)),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
