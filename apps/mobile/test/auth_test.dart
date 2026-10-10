import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitbit/features/auth/auth_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitbit/features/auth/auth_providers.dart';
import 'package:splitbit/features/auth/login_screen.dart';
import 'package:splitbit/features/auth/profile.dart';
import 'package:splitbit/features/auth/profile_screen.dart';
import 'package:splitbit/features/auth/verify_screen.dart';
import 'package:splitbit/features/welcome/welcome_screen.dart';
import 'package:splitbit/router.dart';
import 'package:splitbit/theme/app_theme.dart';

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

  test('google and code problems get plain messages', () {
    expect(friendlyAuthMessage(Exception('Unsupported phone provider')), contains('phone codes are not available'));
    expect(friendlyAuthMessage(Exception('Error sending SMS message')), contains('phone codes are not available'));
    expect(friendlyAuthMessage(Exception('Unsupported provider: provider is not enabled')), contains('google sign-in is not set up'));
    expect(friendlyAuthMessage(Exception('Token has expired or is invalid')), contains('code did not work'));
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
    testWidgets('login', (t) => shot(t, const LoginScreen(), 'auth_login'));
    testWidgets('verify', (t) async {
      await shot(t, const VerifyScreen(contact: 'salman@example.com'), 'auth_verify');
      await t.pumpWidget(const SizedBox.shrink()); // Stops the resend timer.
    });
    testWidgets('profile', (t) => shot(t, const ProfileScreen(), 'auth_profile'));

  });

  testWidgets('the link Google sends the browser back with never lands on an error page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.listen(routerProvider, (_, _) {});
    final router = c.read(routerProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildAppTheme(), routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    for (final link in ['/login-callback?code=abc', '/login-callback']) {
      router.go(link);
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.state.uri.path, isNot('/login-callback'), reason: '$link was left as it is');
      expect(find.textContaining('page not found'), findsNothing);
    }
    await tester.pump(const Duration(milliseconds: 600));
  });

  group('login screen', () {
    Future<FakeAuth> open(WidgetTester tester, {FakeAuth? auth, double width = 390, double height = 844}) async {
      final fake = auth ?? FakeAuth();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, height);
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/auth/login', routes: [
        GoRoute(path: '/auth/login', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/auth/verify',
          builder: (_, state) => VerifyScreen(
            contact: state.uri.queryParameters['contact'] ?? '',
          ),
        ),
        GoRoute(path: '/welcome', builder: (_, _) => const SizedBox()),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildAppTheme(), routerConfig: router),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      return fake;
    }

    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink()); // Stops timers and animations.
    }

    bool sendEnabled(WidgetTester tester) {
      // A disabled WideButton is drawn slate; enabled it is lavender.
      final box = tester.widget<Container>(find.ancestor(of: find.text('send me a code'), matching: find.byType(Container)).first);
      return (box.decoration as BoxDecoration).color != const Color(0xFF6F8393);
    }

    testWidgets('everything on the screen: tabs, Apple, Google, email, the code button', (tester) async {
      await open(tester);
      expect(find.text('hop in.'), findsOneWidget);
      expect(find.text('log in'), findsOneWidget);
      expect(find.text('sign up'), findsOneWidget);
      expect(find.text('continue with Apple'), findsOneWidget);
      expect(find.text('continue with Google'), findsOneWidget);
      expect(find.text('or use your email'), findsOneWidget);
      expect(find.text('phone'), findsNothing);
      expect(find.text('send me a code'), findsOneWidget);
      expect(find.textContaining('terms and privacy policy'), findsOneWidget);
      await done(tester);
    });

    testWidgets('email is the only code login: no phone option', (tester) async {
      await open(tester);
      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.textContaining('+880'), findsNothing);
      expect(find.text('We will email you a 6 digit code.'), findsOneWidget);
      await done(tester);
    });

    testWidgets('an email code: only a real address enables the button, then the code screen', (tester) async {
      final auth = await open(tester);
      expect(sendEnabled(tester), isFalse);
      await tester.enterText(find.byType(TextField), 'nope');
      await tester.pump();
      expect(sendEnabled(tester), isFalse);
      await tester.enterText(find.byType(TextField), 'salman@example.com');
      await tester.pump();
      expect(sendEnabled(tester), isTrue);
      await tester.tap(find.text('send me a code'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['sendCode salman@example.com']);
      expect(find.text('check your email.'), findsOneWidget);
      expect(find.textContaining('salman@example.com'), findsOneWidget);
      await done(tester);
    });

    testWidgets('an email code is checked as an email code', (tester) async {
      final auth = await open(tester);
      await tester.enterText(find.byType(TextField), 'salman@example.com');
      await tester.pump();
      await tester.tap(find.text('send me a code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '654321');
      await tester.pumpAndSettle();
      expect(auth.calls.last, 'verifyCode salman@example.com 654321');
      await done(tester);
    });

    testWidgets('Google sign-in is really started', (tester) async {
      final auth = await open(tester);
      await tester.tap(find.text('continue with Google'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(auth.calls, ['signInWithGoogle']);
      await done(tester);
    });

    testWidgets('a Google problem is shown', (tester) async {
      await open(tester, auth: FakeAuth(googleFails: true));
      await tester.tap(find.text('continue with Google'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('google sign-in is not set up'), findsOneWidget);
      await done(tester);
    });

    testWidgets('Apple is only a placeholder: it says so and starts nothing', (tester) async {
      final auth = await open(tester);
      await tester.tap(find.text('continue with Apple'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('coming soon'), findsOneWidget);
      expect(auth.calls, isEmpty);
      await done(tester);
    });

    testWidgets('the log in and sign up tabs change the wording', (tester) async {
      await open(tester);
      expect(find.text('Log in or sign up in a few seconds.'), findsOneWidget);
      await tester.tap(find.text('sign up'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Make your account in a few seconds.'), findsOneWidget);
      await done(tester);
    });

    for (final (w, h, scale) in [(320.0, 640.0, 1.0), (360.0, 740.0, 1.15)]) {
      testWidgets('nothing overflows on a $w x $h phone, font x$scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(w, h);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(FakeAuth())],
          child: MaterialApp(
            theme: buildAppTheme(),
            builder: (c, app) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: app!),
            home: const LoginScreen(),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        await done(tester);
      });
    }
  });
}

/// A login backend that records what the screens ask of it.
class FakeAuth implements AuthRepository {
  FakeAuth({this.googleFails = false, this.deleteFails = false});
  final bool deleteFails;
  final bool googleFails;
  final calls = <String>[];

  @override
  Stream<String?> get userIdChanges => const Stream.empty();
  @override
  String? get userId => null;
  @override
  String? get email => null;
  @override
  String? get phone => null;
  @override
  String? get suggestedName => null;

  @override
  Future<void> sendCode(String email) async => calls.add('sendCode $email');
  @override
  Future<void> verifyCode(String email, String code) async => calls.add('verifyCode $email $code');
  @override
  Future<void> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    if (googleFails) throw AuthFailure(friendlyAuthMessage(Exception('provider is not enabled')));
  }

  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
    if (deleteFails) throw const AuthFailure('could not delete your account. check your connection and try again.');
  }
  @override
  Future<Profile?> loadProfile() async => null;
  @override
  Future<Profile> saveProfile(Profile profile) async => profile;
}
