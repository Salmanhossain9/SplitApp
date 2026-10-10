import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_core/split_core.dart';
import 'package:splitbit/features/bill/draft_bill.dart' show hostId;
import 'package:splitbit/features/bill/draft_bill_notifier.dart';
import 'package:splitbit/features/groups/groups_provider.dart';
import 'package:splitbit/features/groups/groups_repository.dart';
import 'package:splitbit/router.dart';
import 'package:splitbit/theme/app_theme.dart';

/// The vat and service screen in each way of splitting: what is offered, and what each person pays.
Future<(ProviderContainer, DraftBillNotifier, Map<String, String>)> openCharges(
  WidgetTester tester, {
  SplitMode mode = SplitMode.items,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(tester.view.reset);
  final c = ProviderContainer(overrides: [
    groupsRepositoryProvider.overrideWithValue(LocalGroupsRepository(initial: const [])),
  ]);
  addTearDown(c.dispose);
  final n = c.read(draftBillProvider.notifier);
  n.setPlace('Chillox');
  final ids = <String, String>{'you': hostId};
  for (final name in ['Rafi', 'Nabil', 'Tania']) {
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
  n.setVatRate(590);
  n.setServiceRate(590);
  n.setSplitMode(mode);
  if (mode == SplitMode.custom) {
    n.setCustomAmount(ids['you']!, 61400);
    n.setCustomAmount(ids['rafi']!, 72150);
    n.setCustomAmount(ids['nabil']!, 63150);
    n.setCustomAmount(ids['tania']!, 26900);
  }
  c.listen(routerProvider, (_, _) {});
  final router = c.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildAppTheme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
  router.go('/bill/draft/charges');
  await tester.pumpAndSettle();
  return (c, n, ids);
}

Map<String, int> shares(ProviderContainer c, Map<String, String> ids) {
  final d = c.read(draftBillProvider);
  return {for (final e in ids.entries) e.key: d.shareOf(e.value)};
}

void main() {
  testWidgets('by items: equally or separate, and separate puts vat on each own food', (t) async {
    final (c, _, ids) = await openCharges(t);
    expect(find.text('equally'), findsOneWidget);
    expect(find.text('separate'), findsOneWidget);
    expect(find.text('by what they ate'), findsNothing);

    // Equally: the total vat and service split evenly across everyone.
    expect(shares(c, ids), {'you': 61400, 'rafi': 72150, 'nabil': 63150, 'tania': 26900});

    await t.tap(find.text('separate'));
    await t.pumpAndSettle();
    final d = c.read(draftBillProvider);
    expect(d.extrasMode, ExtrasMode.byItems);
    // Tania only had half the fries and a third of the cokes, so she pays far less vat.
    expect(shares(c, ids), {'you': 62049, 'rafi': 74067, 'nabil': 64006, 'tania': 23478});
    expect(find.text('on their own food'), findsOneWidget);
    expect(c.read(draftBillProvider).result!.sharesSum, c.read(draftBillProvider).total);
    await t.pump(const Duration(milliseconds: 400));
  });

  testWidgets('everyone eating the same: equally and separate agree', (t) async {
    final (c, n, ids) = await openCharges(t);
    final items = c.read(draftBillProvider).items;
    for (final i in items) {
      for (final p in ids.values) {
        if (!(c.read(draftBillProvider).claims[i.id] ?? {}).contains(p)) n.toggleClaim(i.id, p);
      }
    }
    final equally = shares(c, ids);
    n.setExtrasMode(ExtrasMode.byItems);
    expect(shares(c, ids), equally);
    await t.pump(const Duration(milliseconds: 400)); // the draft's debounced save
  });

  testWidgets('split the whole bill equally: extras are shared equally, no choice offered', (t) async {
    final (c, _, ids) = await openCharges(t, mode: SplitMode.equally);
    expect(find.text('separate'), findsNothing);
    expect(shares(c, ids).values.toSet(), {55900});
    expect(find.textContaining('shared equally too'), findsOneWidget);
  });

  testWidgets('typed shares: the rates are locked so the bills cannot stop adding up', (t) async {
    final (c, _, _) = await openCharges(t, mode: SplitMode.custom);
    expect(find.text('separate'), findsNothing);
    final fields = t.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, isNotEmpty);
    expect(fields.every((f) => f.enabled == false), isTrue);
    expect(c.read(draftBillProvider).result, isNotNull);
  });
}
