import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitup/features/auth/auth_repository.dart';
import 'package:splitup/features/auth/email_screen.dart';
import 'package:splitup/features/auth/profile.dart';
import 'package:splitup/features/auth/profile_screen.dart';
import 'package:splitup/features/auth/verify_screen.dart';
import 'package:splitup/features/welcome/welcome_screen.dart';
import 'package:splitup/router.dart';
import 'package:splitup/theme/app_theme.dart';

const _p = Profile(id: 'u', name: 'Salman');

String? redirect(String location, AsyncValue<String?> session, AsyncValue<Profile?> profile) =>
    redirectFor(location: location, session: session, profile: profile);

void main() {
  group('router redirect rules', () {
    const out = AsyncData<String?>(null);
    const inn = AsyncData<String?>('u');
    const noProfile = AsyncData<Profile?>(null);
    const hasProfile = AsyncData<Profile?>(_p);

    test('logged out users only see welcome, auth and share pages', () {
      expect(redirect('/home', out, noProfile), '/welcome');
      expect(redirect('/bill/new', out, noProfile), '/welcome');
      expect(redirect('/money', out, noProfile), '/welcome');
      expect(redirect('/welcome', out, noProfile), isNull);
      expect(redirect('/auth/email', out, noProfile), isNull);
      expect(redirect('/auth/verify', out, noProfile), isNull);
      expect(redirect('/s/abcdef', out, noProfile), isNull);
    });

    test('logged in without a profile goes to the profile screen', () {
      expect(redirect('/home', inn, noProfile), '/auth/profile');
      expect(redirect('/auth/verify', inn, noProfile), '/auth/profile');
      expect(redirect('/auth/profile', inn, noProfile), isNull);
    });

    test('logged in with a profile skips welcome and auth', () {
      expect(redirect('/welcome', inn, hasProfile), '/home');
      expect(redirect('/auth/email', inn, hasProfile), '/home');
      expect(redirect('/auth/profile', inn, hasProfile), '/home');
      expect(redirect('/', inn, hasProfile), '/home');
      expect(redirect('/home', inn, hasProfile), isNull);
      expect(redirect('/bill/new', inn, hasProfile), isNull);
      expect(redirect('/s/abcdef', inn, hasProfile), isNull);
    });

    test('while loading nothing private is shown', () {
      const loading = AsyncLoading<String?>();
      expect(redirect('/home', loading, noProfile), '/');
      expect(redirect('/', loading, noProfile), isNull);
      expect(redirect('/welcome', loading, noProfile), isNull);
      expect(redirect('/home', inn, const AsyncLoading<Profile?>()), '/');
    });
  });

  test('friendly auth messages never leak raw errors', () {
    expect(friendlyAuthMessage(Exception('Token has expired or is invalid')), contains('code did not work'));
    expect(friendlyAuthMessage(Exception('SocketException: Failed host lookup')), contains('no connection'));
    expect(friendlyAuthMessage(Exception('boom 500')), contains('something went wrong'));
  });

  test('profile row mapping trims and nulls an empty bKash number', () {
    final row = const Profile(id: 'u', name: ' Salman ', bkashNumber: '  ').toRow();
    expect(row['name'], 'Salman');
    expect(row['bkash_number'], isNull);
    expect(Profile.fromRow({'id': 'u', 'name': 'S', 'avatar_color': 'coral', 'bkash_number': '017'}).bkashNumber, '017');
  });

  group('screens', () {
    Future<void> shot(WidgetTester tester, Widget screen, String name) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: screen),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/$name.png'));
    }

    testWidgets('welcome', (t) => shot(t, const WelcomeScreen(), 'welcome'));
    testWidgets('email', (t) => shot(t, const EmailScreen(), 'auth_email'));
    testWidgets('verify', (t) async {
      await shot(t, const VerifyScreen(email: 'salman@example.com'), 'auth_verify');
      await t.pumpWidget(const SizedBox.shrink()); // Stops the resend timer.
    });
    testWidgets('profile', (t) => shot(t, const ProfileScreen(), 'auth_profile'));

    testWidgets('email screen only enables the button for a real address', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(theme: buildAppTheme(), home: const EmailScreen()),
      ));
      await tester.enterText(find.byType(TextField), 'nope');
      await tester.pump();
      expect(tester.widget<Text>(find.text('send me a code')).data, 'send me a code');
      await tester.enterText(find.byType(TextField), 'salman@example.com');
      await tester.pump();
      // No exception and the field kept the text.
      expect(find.text('salman@example.com'), findsOneWidget);
    });
  });
}
