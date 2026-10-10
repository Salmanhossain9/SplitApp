import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitbit/features/auth/auth_providers.dart';
import 'package:splitbit/features/settings/settings_screen.dart';
import 'package:splitbit/theme/app_theme.dart';

import 'auth_test.dart' show FakeAuth;

/// Google Play wants account deletion inside the app: reachable from settings, confirmed on
/// purpose, and really calling the server.
void main() {
  Future<void> open(WidgetTester tester, FakeAuth auth, {double width = 390, double height = 1100}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: MaterialApp(theme: buildAppTheme(), home: const Scaffold(body: SettingsScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('delete my account'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('delete my account'));
    await tester.pumpAndSettle();
  }

  testWidgets('settings shows the privacy policy, terms and delete account', (tester) async {
    await open(tester, FakeAuth());
    await tester.ensureVisible(find.text('delete my account'));
    expect(find.text('privacy policy'), findsOneWidget);
    expect(find.text('terms'), findsOneWidget);
    expect(find.text('delete my account'), findsOneWidget);
  });

  testWidgets('nothing is deleted until the person types delete', (tester) async {
    final auth = FakeAuth();
    await open(tester, auth);
    await openSheet(tester);
    expect(find.text('delete your account?'), findsOneWidget);
    await tester.tap(find.text('delete forever'));
    await tester.pump();
    expect(auth.calls, isEmpty, reason: 'the button is off while the box is empty');
    await tester.enterText(find.widgetWithText(TextField, 'delete'), 'del');
    await tester.pump();
    await tester.tap(find.text('delete forever'));
    await tester.pump();
    expect(auth.calls, isEmpty);
  });

  testWidgets('typing delete and confirming deletes the account', (tester) async {
    final auth = FakeAuth();
    await open(tester, auth);
    await openSheet(tester);
    await tester.enterText(find.byType(TextField).last, 'Delete');
    await tester.pump();
    await tester.tap(find.text('delete forever'));
    await tester.pumpAndSettle();
    expect(auth.calls, ['deleteAccount']);
    expect(find.text('delete your account?'), findsNothing, reason: 'the sheet closes');
  });

  testWidgets('keep my account closes the sheet and deletes nothing', (tester) async {
    final auth = FakeAuth();
    await open(tester, auth);
    await openSheet(tester);
    await tester.tap(find.text('keep my account'));
    await tester.pumpAndSettle();
    expect(auth.calls, isEmpty);
    expect(find.text('delete your account?'), findsNothing);
  });

  testWidgets('a failed delete says so and the sheet stays open', (tester) async {
    final auth = FakeAuth(deleteFails: true);
    await open(tester, auth);
    await openSheet(tester);
    await tester.enterText(find.byType(TextField).last, 'delete');
    await tester.pump();
    await tester.tap(find.text('delete forever'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('could not delete your account'), findsOneWidget);
    expect(find.text('delete your account?'), findsOneWidget);
  });

  for (final (w, h, scale) in [(320.0, 640.0, 1.0), (320.0, 640.0, 1.3)]) {
    testWidgets('the confirm sheet fits a $w x $h phone, font x$scale', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(w, h);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(FakeAuth(deleteFails: true))],
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (c, app) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: app!),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await openSheet(tester);
      await tester.enterText(find.byType(TextField).last, 'delete');
      await tester.pump();
      await tester.tap(find.text('delete forever'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  }
}
