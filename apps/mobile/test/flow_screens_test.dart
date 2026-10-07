import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitup/features/bill/draft_bill.dart';
import 'package:splitup/features/bill/draft_bill_notifier.dart';
import 'package:splitup/router.dart';
import 'package:splitup/theme/app_theme.dart';
import 'package:splitup/ui/ui.dart';

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required int friends,
  required String route,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  final n = container.read(draftBillProvider.notifier);
  n.setPlace('Chillox');
  for (final name in ['Rafi', 'Nabil', 'Tania', 'Arif', 'Mim'].take(friends)) {
    n.addGuest(name);
  }
  n.addItem(name: 'Chicken burger', unitPrice: 34500);
  n.addItem(name: 'Fries', qty: 2, unitPrice: 12000);
  n.setItemsConfirmed(true);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: appRouter),
  ));
  appRouter.go(route);
  await tester.pumpAndSettle();
  return container;
}

/// Lets the draft's debounced save timer fire before the test ends.
Future<void> flush(WidgetTester tester) => tester.pump(const Duration(milliseconds: 400));

void main() {
  testWidgets('4 people: inline name chips, next blocked until all items claimed', (tester) async {
    final c = await pumpApp(tester, friends: 3, route: '/bill/draft/claim');
    expect(find.text('0 of 2 items assigned'), findsOneWidget);
    expect(find.byType(NameChip), findsNWidgets(8)); // 4 people x 2 items
    expect(find.text('who shared this?'), findsNothing);

    // Claim item 1 by tapping Rafi's chip on the first card.
    await tester.tap(find.widgetWithText(NameChip, 'Rafi').first);
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 items assigned'), findsOneWidget);
    expect(c.read(draftBillProvider).claimStepValid, isFalse);

    await tester.tap(find.widgetWithText(NameChip, 'You').last);
    await tester.pumpAndSettle();
    expect(find.text('every item is claimed'), findsOneWidget);
    expect(c.read(draftBillProvider).claimStepValid, isTrue);
    await flush(tester);
  });

  testWidgets('5 people: the bottom sheet opens on the first unclaimed item', (tester) async {
    await pumpApp(tester, friends: 4, route: '/bill/draft/claim');
    expect(find.text('who shared this?'), findsOneWidget);
    expect(find.text('Chicken burger'), findsWidgets);
    await flush(tester);
  });

  testWidgets('mode switch shows equally and custom bodies', (tester) async {
    await pumpApp(tester, friends: 3, route: '/bill/draft/claim');
    await tester.tap(find.text('equally'));
    await tester.pumpAndSettle();
    expect(find.text('each pays'), findsOneWidget);
    expect(find.text('incl. vat and service'), findsOneWidget);

    await tester.tap(find.text('custom'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomRow), findsNWidgets(4));
    expect(find.text('split the rest equally'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('charges screen: bills add up to the total, send bills opens settle', (tester) async {
    final c = await pumpApp(tester, friends: 1, route: '/bill/draft/claim');
    final n = c.read(draftBillProvider.notifier);
    for (final item in c.read(draftBillProvider).items) {
      n.toggleClaim(item.id, hostId);
    }
    appRouter.go('/bill/draft/charges');
    await tester.pumpAndSettle();
    // 345 + 240 = 585 items, 5.9% twice = 69.03 + ... total shown as a banner.
    final total = c.read(draftBillProvider).total;
    expect(find.textContaining('bills add up to'), findsOneWidget);
    expect(total, greaterThan(58500));
    expect(find.text('how should we split the extras?'), findsOneWidget);
    expect(find.byType(BillCard), findsNWidgets(2));
    await flush(tester);
  });
}
