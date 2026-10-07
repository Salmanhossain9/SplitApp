import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_core/split_core.dart';
import 'package:splitup/features/bill/draft_bill.dart';
import 'package:splitup/core/person.dart';
import 'package:splitup/features/bill/draft_bill_notifier.dart';
import 'package:splitup/features/groups/groups_provider.dart';
import 'package:splitup/features/groups/groups_repository.dart';
import 'package:splitup/router.dart';
import 'package:splitup/theme/app_theme.dart';
import 'package:splitup/ui/settle_row.dart' show SettleMethod;

/// Whole-screen goldens at the 390 x 844 design frame, driven by the Chillox sample.
Future<void> shot(
  WidgetTester tester,
  String route,
  String name, {
  FutureOr<void> Function(DraftBillNotifier n, Map<String, String> ids)? setup,
  int people = 4,
  List<GroupCardData> groups = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final c = ProviderContainer(overrides: [
    groupsRepositoryProvider.overrideWithValue(LocalGroupsRepository(initial: groups)),
  ]);
  addTearDown(c.dispose);
  final n = c.read(draftBillProvider.notifier);
  n.setPlace('Chillox');
  final ids = <String, String>{'you': hostId};
  for (final name in ['Rafi', 'Nabil', 'Tania', 'Arif'].take(people - 1)) {
    ids[name.toLowerCase()] = n.addGuest(name).id;
  }
  n.addItem(name: 'Chicken burger', unitPrice: 34500);
  n.addItem(name: 'Beef kala bhuna', unitPrice: 114500);
  n.addItem(name: 'Fries', unitPrice: 24000);
  n.addItem(name: 'Coke', qty: 3, unitPrice: 9000);
  n.setItemsConfirmed(true);
  final items = c.read(draftBillProvider).items;
  void claim(int i, List<String> who) {
    for (final w in who) {
      n.toggleClaim(items[i].id, ids[w]!);
    }
  }

  claim(0, ['you']);
  claim(1, ['rafi', 'nabil']);
  claim(2, ['you', 'tania']);
  claim(3, ['you', 'rafi', 'tania']);
  await setup?.call(n, ids);

  c.listen(routerProvider, (_, _) {}); // The app watches it, so do the tests.
  final router = c.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  router.go(route);
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/$name.png'));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('new bill', (t) => shot(t, '/bill/new', 'new_bill', groups: const [
        GroupCardData(id: 'g1', name: 'NSU boys', members: [
          Person(id: 'f1', name: 'Rafi', avatarColor: 'coral'),
          Person(id: 'f2', name: 'Nabil', avatarColor: 'sky'),
          Person(id: 'f3', name: 'Tania', avatarColor: 'lime'),
        ]),
        GroupCardData(id: 'g2', name: 'Roommates', members: [Person(id: 'f4', name: 'Arif'), Person(id: 'f2', name: 'Nabil', avatarColor: 'sky')]),
        GroupCardData(id: 'g3', name: 'Office lunch', members: [
          Person(id: 'f5', name: 'Mim', avatarColor: 'coral'), Person(id: 'f4', name: 'Arif'), Person(id: 'f1', name: 'Rafi', avatarColor: 'coral'),
          Person(id: 'f3', name: 'Tania', avatarColor: 'lime'), Person(id: 'f2', name: 'Nabil', avatarColor: 'sky'),
        ]),
      ]));
  testWidgets('items', (t) => shot(t, '/bill/draft/items', 'items'));
  testWidgets('claim by items', (t) => shot(t, '/bill/draft/claim', 'claim_items'));
  testWidgets('claim sheet (5 people)', (t) => shot(t, '/bill/draft/claim', 'claim_sheet', people: 5, setup: (n, ids) {
        n.toggleClaim(n.state.items[3].id, ids['arif']!);
        // Fries has nobody yet, so the sheet opens on it.
        n.toggleClaim(n.state.items[2].id, ids['you']!);
        n.toggleClaim(n.state.items[2].id, ids['tania']!);
      }));
  testWidgets('claim equally', (t) => shot(t, '/bill/draft/claim', 'claim_equally', setup: (n, _) => n.setSplitMode(SplitMode.equally)));
  testWidgets('claim custom', (t) => shot(t, '/bill/draft/claim', 'claim_custom', setup: (n, ids) {
        n.setSplitMode(SplitMode.custom);
        n.setCustomAmount(ids['you']!, 61400);
        n.setCustomAmount(ids['rafi']!, 72150);
      }));
  testWidgets('charges', (t) => shot(t, '/bill/draft/charges', 'charges'));
  testWidgets('settle', (t) => shot(t, '/bill/draft/settle', 'settle', setup: (n, ids) async {
        await n.sendBills();
        n.setMethod(ids['rafi']!, SettleMethod.bkash);
        n.setMethod(ids['nabil']!, SettleMethod.cash);
        n.setMethod(ids['tania']!, SettleMethod.owesMe);
        n.setOwed(ids['tania']!, 20000);
      }));
}
