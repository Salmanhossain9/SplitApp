import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_core/split_core.dart';
import 'package:splitup/features/bill/draft_bill.dart' show hostId;
import 'package:splitup/features/scan/scan_models.dart';
import 'package:splitup/ui/cards.dart' show TabCard;
import 'package:splitup/ui/code_field.dart';
import 'package:splitup/ui/ui.dart' show RecapTile, SettleRow, Logo;
import 'package:splitup/features/bill/draft_bill_notifier.dart';
import 'package:splitup/features/groups/groups_provider.dart';
import 'package:splitup/features/groups/groups_repository.dart';
import 'package:splitup/router.dart';
import 'package:splitup/theme/app_theme.dart';
import 'package:splitup/ui/settle_row.dart' show SettleMethod;

/// Every screen of the bill flow on small phones: 320 dp is a Galaxy with a larger display size.
/// Nothing may overflow, whatever the font size.
const sizes = [(320.0, 640.0, 1.0), (320.0, 640.0, 1.3), (360.0, 740.0, 1.15)];

Future<ProviderContainer> flow(WidgetTester tester, double w, double h, double scale, {required String route, void Function(DraftBillNotifier n, Map<String, String> ids)? setup}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.reset);
  final c = ProviderContainer(overrides: [
    groupsRepositoryProvider.overrideWithValue(LocalGroupsRepository(initial: const [])),
  ]);
  addTearDown(c.dispose);
  final n = c.read(draftBillProvider.notifier);
  n.setPlace('Chocolate Brownie Rustic Cafe');
  final ids = <String, String>{'you': hostId};
  for (final name in ['Adnan', 'Siwom', 'Hasanuzzaman', 'Karim']) {
    ids[name.toLowerCase()] = n.addGuest(name).id;
  }
  n.addItem(name: 'Sakura Water 330 ml', qty: 2, unitPrice: 1500);
  n.addItem(name: 'Chocolate Brownie Cream Regular', unitPrice: 49900);
  n.addItem(name: 'Caramel Banana French Toast', unitPrice: 59900);
  n.addItem(name: 'Tiramisu', unitPrice: 36900);
  n.setItemsConfirmed(true);
  final items = c.read(draftBillProvider).items;
  void claim(int i, List<String> who) {
    for (final p in who) {
      n.toggleClaim(items[i].id, ids[p]!);
    }
  }

  claim(0, ['you', 'adnan']);
  claim(1, ['siwom']);
  claim(2, ['hasanuzzaman', 'karim']);
  claim(3, ['you', 'adnan', 'siwom', 'hasanuzzaman', 'karim']);
  n.setVatRate(500);
  n.setServiceRate(500);
  setup?.call(n, ids);
  c.listen(routerProvider, (_, _) {});
  final router = c.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: app!,
      ),
      routerConfig: router,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 200));
  router.go(route);
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return c;
}

Future<void> finish(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 5000)); // Let confetti and timers end.
}

void main() {
  for (final (w, h, scale) in sizes) {
    final tag = '$w x $h, font x$scale';
    for (final entry in {
      'home': '/home',
      'money': '/money',
      'notifications': '/notifications',
      'settings': '/settings',
      'new bill': '/bill/new',
      'items (manual)': '/bill/draft/items',
      'claim by items': '/bill/draft/claim',
      'charges': '/bill/draft/charges',
    }.entries) {
      testWidgets('${entry.key}, $tag', (tester) async {
        await flow(tester, w, h, scale, route: entry.value);
        await finish(tester);
      });
    }
    testWidgets('claim equally, $tag', (tester) async {
      await flow(tester, w, h, scale, route: '/bill/draft/claim', setup: (n, _) => n.setSplitMode(SplitMode.equally));
      // "total bill" is on one line, with its pill beside it, and the amount is on one line too.
      expect(tester.getSize(find.text('total bill')).height, lessThan(40), reason: '"total bill" wrapped');
      final label = tester.getRect(find.text('total bill'));
      final pill = tester.getRect(find.text('incl. vat and service'));
      expect(label.right, lessThanOrEqualTo(pill.left));
      expect((label.center.dy - pill.center.dy).abs(), lessThan(24), reason: 'the pill dropped below the label');
      expect(pill.right, lessThanOrEqualTo(w - 24 + 1));
      await finish(tester);
    });
    testWidgets('claim custom, $tag', (tester) async {
      await flow(tester, w, h, scale, route: '/bill/draft/claim', setup: (n, ids) {
        n.setSplitMode(SplitMode.custom);
        n.setCustomAmount(ids['you']!, 61400);
      });
      await finish(tester);
    });
    testWidgets('charges separate, $tag', (tester) async {
      await flow(tester, w, h, scale, route: '/bill/draft/charges', setup: (n, _) => n.setExtrasMode(ExtrasMode.byItems));
      await finish(tester);
    });
    testWidgets('claim sheet with 6 people, $tag', (tester) async {
      await flow(tester, w, h, scale, route: '/bill/draft/claim', setup: (n, _) {
        n.addGuest('Rafi');
        n.addGuest('Nabil');
      });
      await finish(tester);
    });
    testWidgets('settle, $tag', (tester) async {
      await flow(tester, w, h, scale, route: '/bill/draft/settle', setup: (n, ids) async {
        await n.sendBills();
        n.setMethod(ids['adnan']!, SettleMethod.bkash);
        n.setMethod(ids['siwom']!, SettleMethod.cash);
        n.setMethod(ids['hasanuzzaman']!, SettleMethod.owesMe);
        n.setOwed(ids['hasanuzzaman']!, 20000);
      });
      // "collected" and the big amount each sit on one line.
      expect(tester.getSize(find.text('collected')).height, lessThan(30));
      final big = tester.getSize(find.textContaining('1,').first).height;
      expect(big, lessThan(80), reason: 'the collected amount wrapped');
      // The method chips stay inside their card.
      final rows = tester.widgetList(find.byType(SettleRow)).length;
      expect(rows, greaterThan(0));
      for (var i = 0; i < rows; i++) {
        final card = tester.getRect(find.byType(SettleRow).at(i));
        for (final m in ['cash', 'bKash', 'bank', 'owes me']) {
          final chip = tester.getRect(find.descendant(of: find.byType(SettleRow).at(i), matching: find.text(m)));
          expect(chip.right, lessThanOrEqualTo(card.right), reason: '$m is outside its card');
        }
      }
      await finish(tester);
    });
    testWidgets('all settled, $tag', (tester) async {
      await flow(tester, w, h, scale, route: '/bill/draft/done', setup: (n, ids) async {
        await n.sendBills();
        n.setMethod(ids['adnan']!, SettleMethod.bkash);
        n.setMethod(ids['siwom']!, SettleMethod.cash);
        n.setMethod(ids['hasanuzzaman']!, SettleMethod.owesMe);
        n.setOwed(ids['hasanuzzaman']!, 20000);
        n.setMethod(ids['karim']!, SettleMethod.cash);
        await n.finishBill();
      });
      await tester.pump(const Duration(milliseconds: 800)); // The tiles spring in.
      // All three tiles are on screen, above the two buttons, and the same height.
      final tiles = [for (var i = 0; i < 3; i++) tester.getRect(find.byType(RecapTile).at(i))];
      final buttonTop = tester.getRect(find.text('back to home')).top;
      for (final t in tiles) {
        // With a very large font it cannot all fit above the buttons; it scrolls clear of them.
        if (scale <= 1.15) expect(t.bottom, lessThanOrEqualTo(buttonTop), reason: 'a tile is hidden behind the buttons');
        expect(t.height, closeTo(tiles.first.height, 1));
        expect(t.left, greaterThanOrEqualTo(0));
        expect(t.right, lessThanOrEqualTo(w));
      }
      for (final label in ['split', 'friends']) {
        expect(tester.getSize(find.text(label)).height, lessThan(24), reason: '"$label" wrapped onto two lines');
      }
      await finish(tester);
    });
  }

  testWidgets('a scan whose total differs only by rounding says it matches', (tester) async {
    // GPR receipt: items 3189.92, VAT 159.50, printed total 3349.00 (rounding -0.42).
    await flow(tester, 390, 844, 1.0, route: '/bill/draft/items', setup: (n, _) {
      n.applyScan(const ScanResult(
        items: [ScannedItem(name: 'Everything', qty: 1, unitPrice: 318992)],
        vat: 15950,
        total: 334900,
      ));
    });
    expect(find.text('matches'), findsOneWidget);
    expect(find.text('differs'), findsNothing);
    await finish(tester);
  });

  for (final (w, scale) in [(320.0, 1.0), (320.0, 1.3), (411.0, 1.0)]) {
    testWidgets('the code boxes are six separate, modest boxes at $w dp, font x$scale', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(w, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        builder: (c, app) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: app!),
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: CodeField(onChanged: (_) {}))),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final boxes = [
        for (final e in tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)))
          tester.getRect(find.byWidget(e)),
      ];
      expect(boxes.length, 6);
      for (var i = 0; i < 6; i++) {
        expect(boxes[i].width, lessThanOrEqualTo(52.5), reason: 'box $i is too wide');
        expect(boxes[i].height, lessThanOrEqualTo(64));
        expect(boxes[i].left, greaterThanOrEqualTo(0));
        expect(boxes[i].right, lessThanOrEqualTo(w));
        if (i > 0) expect(boxes[i].left - boxes[i - 1].right, greaterThanOrEqualTo(4), reason: 'boxes $i and ${i - 1} touch');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the logo is the Splitbit mark and name', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: const Scaffold(body: Center(child: Logo()))));
    expect(find.text('splitbit'), findsOneWidget);
    expect(find.text('splitup'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  for (final (w, scale) in [(320.0, 1.0), (320.0, 1.3)]) {
    testWidgets('home with a big total and an open tab, $w dp, font x$scale', (tester) async {
      await flow(tester, w, 760, scale, route: '/home', setup: (n, ids) async {
        n.setItemsConfirmed(true);
        await n.sendBills();
        n.setMethod(ids['adnan']!, SettleMethod.owesMe);
        n.setOwed(ids['adnan']!, 106330);
      });
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(TabCard), findsOneWidget);
      // The tab's amount is one line, and the remind button is small.
      final tab = tester.getRect(find.byType(TabCard));
      final remind = tester.getRect(find.text('remind'));
      expect(remind.height, lessThan(24), reason: 'the remind text is on one line');
      final owes = tester.getSize(find.textContaining('owes you').first).height;
      expect(owes, lessThan(24), reason: 'the tab label wrapped');
      expect(tab.height, lessThan(130), reason: 'the tab card is too tall');
      await finish(tester);
    });
  }
}
