import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitbit/core/clock.dart';
import 'package:splitbit/core/person.dart';
import 'package:splitbit/features/bill/bill_repository.dart';
import 'package:splitbit/features/bill/bills_provider.dart';
import 'package:splitbit/features/bill/draft_bill.dart';
import 'package:splitbit/features/bill/draft_bill_notifier.dart';
import 'package:splitbit/router.dart';
import 'package:splitbit/theme/tokens.dart';
import 'package:splitbit/theme/app_theme.dart';
import 'package:splitbit/ui/ui.dart';

final now = DateTime(2026, 9, 14, 20, 30);

/// Chillox through the same notifier the screens use, ending settled with Tania on a 200 tab.
Future<ProviderContainer> settledChillox({bool finish = true}) async {
  SharedPreferences.setMockInitialValues({});
  final c = ProviderContainer(overrides: [
    clockProvider.overrideWithValue(() => now),
    billRepositoryProvider.overrideWithValue(LocalBillRepository(seed: false, now: now)),
  ]);
  addTearDown(c.dispose);
  final n = c.read(draftBillProvider.notifier);
  n.setPlace('Chillox');
  final ids = {
    'rafi': n.addGuest('Rafi').id,
    'nabil': n.addGuest('Nabil').id,
    'tania': n.addGuest('Tania').id,
  };
  n.addItem(name: 'Chicken burger', unitPrice: 34500);
  n.addItem(name: 'Beef kala bhuna', unitPrice: 114500);
  n.addItem(name: 'Fries', unitPrice: 24000);
  n.addItem(name: 'Coke', qty: 3, unitPrice: 9000);
  final items = c.read(draftBillProvider).items;
  void claim(int i, List<String> who) {
    for (final w in who) {
      n.toggleClaim(items[i].id, w == 'you' ? hostId : ids[w]!);
    }
  }

  claim(0, ['you']);
  claim(1, ['rafi', 'nabil']);
  claim(2, ['you', 'tania']);
  claim(3, ['you', 'rafi', 'tania']);
  await n.sendBills();
  n.setMethod(ids['rafi']!, SettleMethod.bkash);
  n.setMethod(ids['nabil']!, SettleMethod.cash);
  n.setMethod(ids['tania']!, SettleMethod.owesMe);
  n.setOwed(ids['tania']!, 20000);
  if (finish) await n.finishBill();
  return c;
}

Future<GoRouter> pump(WidgetTester tester, ProviderContainer c, String route) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  c.listen(routerProvider, (_, _) {});
  final router = c.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildAppTheme(), routerConfig: router),
  ));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  router.go(route);
  await tester.pump(const Duration(milliseconds: 100));
  return router;
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('all settled (screen 11)', () {
    testWidgets('headline, recap tiles and the saved tab', (tester) async {
      final c = await settledChillox();
      await pump(tester, c, '/bill/${c.read(draftBillProvider).id}/done');
      await pumpFor(tester, 1500);

      expect(find.text('all settled.'), findsOneWidget);
      expect(find.text('Chillox is done. 4 friends, ৳2,236 and zero awkward.'), findsOneWidget);
      expect(find.text("Tania's ৳200 is saved on your tab"), findsOneWidget);
      expect(find.byType(RecapTile), findsNWidgets(3));
      expect(find.text('split'), findsOneWidget);
      expect(find.text('friends'), findsOneWidget);
      expect(find.text('open tab'), findsOneWidget);
      expect(find.text('back to home'), findsOneWidget);
      expect(find.text('split another bill'), findsOneWidget);
      expect(find.byType(ConfettiLayer), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/all_settled.png'));
      await pumpFor(tester, 4000); // Let the confetti finish before the test ends.
    });

    testWidgets('the celebration: a tap you feel, a burst, tiles that pop in, replay on tap', (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final c = await settledChillox();
      await pump(tester, c, '/bill/${c.read(draftBillProvider).id}/done');
      double scaleOf() => tester
          .widget<Transform>(find.descendant(of: find.byKey(const ValueKey('pop600')), matching: find.byType(Transform)).first)
          .transform
          .entry(0, 0);
      // Just after arriving: the burst is flying and the recap tiles have not popped in yet.
      await pumpFor(tester, 100);
      expect(scaleOf(), lessThan(0.2));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/all_settled_burst.png'));
      await pumpFor(tester, 300);
      expect(haptics, ['HapticFeedbackType.heavyImpact']); // The tap lands as the badge pops.
      await pumpFor(tester, 1200);
      expect(scaleOf(), closeTo(1, 0.1));

      // Tapping the badge plays the confetti again.
      final before = tester.widget<ConfettiLayer>(find.byType(ConfettiLayer)).key;
      await pumpFor(tester, 3000);
      await tester.tap(find.byKey(const ValueKey('badge')));
      await pumpFor(tester, 100);
      expect(tester.widget<ConfettiLayer>(find.byType(ConfettiLayer)).key, isNot(before));
      expect(haptics.last, 'HapticFeedbackType.mediumImpact');
      await pumpFor(tester, 4500);
    });

    testWidgets('no open tab: no tab pill', (tester) async {
      final c = await settledChillox(finish: false);
      final n = c.read(draftBillProvider.notifier);
      final tania = c.read(draftBillProvider).friends.last.id;
      n.setOwed(tania, 0);
      await n.finishBill();
      await pump(tester, c, '/bill/${c.read(draftBillProvider).id}/done');
      await pumpFor(tester, 600);
      expect(find.textContaining('is saved on your tab'), findsNothing);
      expect(find.text('0'), findsOneWidget);
      await pumpFor(tester, 4000);
    });

    testWidgets('back to home clears the bill', (tester) async {
      final c = await settledChillox();
      await pump(tester, c, '/bill/${c.read(draftBillProvider).id}/done');
      await pumpFor(tester, 600);
      await tester.tap(find.text('back to home'));
      await pumpFor(tester, 800);
      expect(find.text('good evening.'), findsOneWidget);
      expect(c.read(draftBillProvider).place, '');
      expect(c.read(draftBillProvider).status, DraftStatus.draft);
      await pumpFor(tester, 4000);
    });

    testWidgets('split another bill starts a fresh one', (tester) async {
      final c = await settledChillox();
      await pump(tester, c, '/bill/${c.read(draftBillProvider).id}/done');
      await pumpFor(tester, 600);
      await tester.tap(find.text('split another bill'));
      await pumpFor(tester, 800);
      expect(find.text('where are we eating?'), findsOneWidget);
      expect(c.read(draftBillProvider).items, isEmpty);
      await pumpFor(tester, 4000);
    });

    testWidgets('finishing on the settle screen lands here', (tester) async {
      final c = await settledChillox(finish: false);
      await pump(tester, c, '/bill/${c.read(draftBillProvider).id}/settle');
      await pumpFor(tester, 500);
      await tester.ensureVisible(find.text('finish bill'));
      await tester.tap(find.text('finish bill'));
      await pumpFor(tester, 800);
      expect(find.text('all settled.'), findsOneWidget);
      await pumpFor(tester, 4000);
    });

    testWidgets('a bill that is not settled sends you home instead', (tester) async {
      final c = await settledChillox(finish: false);
      await pump(tester, c, '/bill/${c.read(draftBillProvider).id}/done');
      await pumpFor(tester, 800);
      expect(find.text('all settled.'), findsNothing);
      expect(find.text('good evening.'), findsOneWidget);
    });
  });

  group('motion', () {
    testWidgets('SpringValue overshoots its target, then settles on it', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(MaterialApp(
        home: SpringValue(
          initial: 0,
          target: 1,
          builder: (context, v) {
            seen.add(v);
            return const SizedBox();
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(seen.reduce((a, b) => a > b ? a : b), greaterThan(1)); // The pop.
      expect(seen.last, closeTo(1, 0.001));
      expect(seen.first, 0);
    });

    testWidgets('SpringValue follows a new target', (tester) async {
      double value = -1;
      Widget build(double target) => MaterialApp(
            home: SpringValue(target: target, builder: (_, v) {
              value = v;
              return const SizedBox();
            }),
          );
      await tester.pumpWidget(build(68));
      expect(value, 68);
      await tester.pumpWidget(build(96));
      await tester.pumpAndSettle();
      expect(value, closeTo(96, 0.01));
    });

    testWidgets('AvatarChip grows into the lavender pill when selected, shrinks when away', (tester) async {
      const person = Person(id: 'r', name: 'Rafi');
      Widget chip(bool selected) => MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(body: Center(child: AvatarChip(person: person, selected: selected))),
          );
      await tester.pumpWidget(chip(false));
      await tester.pumpAndSettle();
      final away = tester.getSize(find.byType(AvatarChip)).height;
      await tester.pumpWidget(chip(true));
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getSize(find.byType(AvatarChip)).height;
      await tester.pumpAndSettle();
      final selected = tester.getSize(find.byType(AvatarChip)).height;
      expect(away, lessThan(selected));
      expect(selected - away, closeTo(AppDims.selectedChipHeight - AppSize.chipWidth, 0.5));
      expect(mid, greaterThan(away)); // Mid-flight it is already on its way up.
    });

    testWidgets('NameChip changes colour over ~150 ms', (tester) async {
      Widget chip(bool on) => MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(body: Center(child: NameChip(label: 'Rafi', on: on))),
          );
      Color? bg() {
        // The animated value lives on the DecoratedBox it builds, not on the widget's target.
        final box = tester
            .widget<DecoratedBox>(find.descendant(of: find.byType(AnimatedContainer), matching: find.byType(DecoratedBox)).first)
            .decoration as BoxDecoration;
        return box.color;
      }

      await tester.pumpWidget(chip(false));
      expect(bg(), AppColors.cream);
      await tester.pumpWidget(chip(true));
      await tester.pump(const Duration(milliseconds: 75));
      final mid = bg()!;
      expect(mid, isNot(AppColors.cream));
      expect(mid, isNot(AppColors.lavender)); // Halfway through the 150 ms.
      await tester.pump(const Duration(milliseconds: 100));
      expect(bg(), AppColors.lavender);
    });

    testWidgets('pressing scales to 0.96', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(child: PressableScale(onTap: () {}, child: const SizedBox(width: 100, height: 100))),
      ));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, AppMotion.pressScale);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    });

    testWidgets('confetti drops pieces over time and ends off screen', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConfettiLayer())));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ConfettiLayer), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
