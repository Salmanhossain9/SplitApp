import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitup/features/bill/draft_bill.dart';
import 'package:splitup/features/bill/draft_bill_notifier.dart';
import 'package:splitup/features/scan/camera_gateway.dart';
import 'package:splitup/features/scan/receipt_scanner.dart';
import 'package:splitup/features/scan/scan_models.dart';
import 'package:splitup/features/share/share_bills_sheet.dart';
import 'package:splitup/features/share/share_service.dart';
import 'package:splitup/features/share/shared_bill.dart';
import 'package:splitup/features/share/share_view_screen.dart';
import 'package:splitup/router.dart';
import 'package:splitup/theme/app_theme.dart';
import 'package:splitup/ui/ui.dart';

class NoCamera implements CameraGateway {
  @override
  Future<CameraSession?> open() async => null;
}

class FakeShare implements ShareService {
  final texts = <String>[];
  final images = <(Uint8List, String)>[];
  final whatsapp = <String>[];
  bool whatsappWorks = true;

  @override
  Future<void> shareText(String text) async => texts.add(text);

  @override
  Future<void> shareImage(Uint8List png, {required String text, required String fileName}) async =>
      images.add((png, fileName));

  @override
  Future<bool> openWhatsapp(String text) async {
    whatsapp.add(text);
    return whatsappWorks;
  }
}

class StubScanner implements ReceiptScanner {
  StubScanner(this.result);
  final Object result; // ScanResult or ScanFailure
  Uint8List? lastBytes;
  String? lastBillId;

  @override
  Future<ScanResult> scan({required String billId, required Uint8List bytes}) async {
    lastBytes = bytes;
    lastBillId = billId;
    final r = result;
    if (r is ScanFailure) throw r;
    return r as ScanResult;
  }
}

const chilloxScan = ScanResult(
  place: 'Chillox',
  items: [
    ScannedItem(name: 'Chicken burger', qty: 1, unitPrice: 34500),
    ScannedItem(name: 'Beef kala bhuna', qty: 1, unitPrice: 114500),
    ScannedItem(name: 'Fries', qty: 1, unitPrice: 24000),
    ScannedItem(name: 'Coke', qty: 3, unitPrice: 9000),
  ],
  vat: 11800,
  service: 11800,
  total: 223600,
  receiptPath: 'u/b/1.jpg',
);

void main() {
  group('scan models', () {
    test('parses the function JSON (poisha)', () {
      final r = ScanResult.fromJson({
        'place': 'Chillox',
        'items': [
          {'name': ' Coke ', 'qty': 3, 'unit_price': 9000},
          {'name': 'Fries', 'unit_price': 24000},
        ],
        'vat': 11800,
        'service': null,
        'total': 223600,
      }, receiptPath: 'p');
      expect(r.items.map((i) => [i.name, i.qty, i.unitPrice]), [['Coke', 3, 9000], ['Fries', 1, 24000]]);
      expect(r.subtotal, 27000 + 24000);
      expect([r.vat, r.service, r.total, r.receiptPath], [11800, null, 223600, 'p']);
    });

    test('detected vat and service become rates on the items subtotal', () {
      expect(rateBpFromAmount(11800, 200000), 590); // 5.9%
      expect(rateBpFromAmount(null, 200000), 0);
      expect(rateBpFromAmount(500, 0), 0);
      expect(rateBpFromAmount(15000, 100000), 1500);
      // Rounds half up and never goes through floats.
      expect(rateBpFromAmount(1, 3), 3333);
    });

    test('image type comes from the file header', () {
      expect(imageExtension(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0])), 'png');
      expect(imageExtension(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0])), 'jpg');
      final webp = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0]);
      expect(imageExtension(webp), 'webp');
      expect(contentTypeFor('png'), 'image/png');
    });

    test('error codes map to messages a person can act on', () {
      expect(scanMessageForCode('rate_limited'), contains('add items by hand'));
      expect(scanMessageForCode('unreadable'), contains('clearer photo'));
      expect(scanMessageForCode(null), contains('add items by hand'));
    });
  });

  group('applyScan', () {
    test('fills items, place, rates and the receipt total; the person still has to confirm', () {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(draftBillProvider.notifier);
      n.addGuest('Rafi');
      n.applyScan(chilloxScan);
      final d = c.read(draftBillProvider);
      expect(d.place, 'Chillox');
      expect(d.items.length, 4);
      expect(d.subtotal, 200000);
      expect([d.vatRateBp, d.serviceRateBp], [590, 590]);
      expect(d.total, 223600);
      expect(d.scannedTotal, 223600);
      expect(d.receiptPath, 'u/b/1.jpg');
      expect(d.itemsConfirmed, isFalse);
      expect(d.itemsStepValid, isFalse);
    });

    test('a place the person already typed is kept', () {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(draftBillProvider.notifier);
      n.setPlace('Our place');
      n.applyScan(chilloxScan);
      expect(c.read(draftBillProvider).place, 'Our place');
    });

    test('a receipt with no vat line sets the rate to zero', () {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(draftBillProvider.notifier).applyScan(const ScanResult(
        items: [ScannedItem(name: 'Tea', qty: 1, unitPrice: 5000)],
      ));
      final d = c.read(draftBillProvider);
      expect([d.vatRateBp, d.serviceRateBp, d.scannedTotal], [0, 0, null]);
    });
  });

  group('items screen with a scan', () {
    Future<(ProviderContainer, StubScanner)> pump(WidgetTester tester, Object scanResult) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final scanner = StubScanner(scanResult);
      final c = ProviderContainer(overrides: [
        cameraGatewayProvider.overrideWithValue(NoCamera()),
        receiptScannerProvider.overrideWithValue(scanner),
      ]);
      addTearDown(c.dispose);
      final n = c.read(draftBillProvider.notifier);
      n.setPlace('Chillox');
      n.addGuest('Rafi');
      c.listen(routerProvider, (_, _) {});
      final router = c.read(routerProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildAppTheme(), routerConfig: router),
      ));
      await tester.pumpAndSettle();
      router.go('/bill/${c.read(draftBillProvider).id}/items');
      await tester.pumpAndSettle();
      return (c, scanner);
    }

    testWidgets('no camera: the tab says so and the gallery path still scans', (tester) async {
      final (c, scanner) = await pump(tester, chilloxScan);
      expect(find.text('camera is off. upload a photo of the receipt instead.'), findsOneWidget);
      expect(find.byType(ReceiptViewfinder), findsOneWidget);
      expect(find.text('upload from photos'), findsOneWidget);
      expect(scanner.lastBytes, isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/scan_tab.png'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.read(draftBillProvider).items, isEmpty);
    });
  });

  group('sharing', () {
    Future<(ProviderContainer, FakeShare)> openSheet(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final share = FakeShare();
      final c = ProviderContainer(overrides: [shareServiceProvider.overrideWithValue(share)]);
      addTearDown(c.dispose);
      final n = c.read(draftBillProvider.notifier);
      n.setPlace('Chillox');
      n.addGuest('Rafi');
      n.applyScan(chilloxScan);
      for (final item in c.read(draftBillProvider).items) {
        n.toggleClaim(item.id, hostId);
      }
      expect((await n.sendBills()).ok, isTrue);
      c.listen(routerProvider, (_, _) {});
      final router = c.read(routerProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildAppTheme(), routerConfig: router),
      ));
      await tester.pumpAndSettle();
      router.go('/bill/${c.read(draftBillProvider).id}/charges');
      await tester.pumpAndSettle();
      await tester.tap(find.text('send bills'));
      await tester.pumpAndSettle();
      return (c, share);
    }

    testWidgets('send bills opens the share sheet with link, whatsapp and image', (tester) async {
      final (c, share) = await openSheet(tester);
      expect(find.text('bills sent.'), findsOneWidget);
      expect(find.byType(ShareImageCard), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/share_sheet.png'));

      await tester.tap(find.text('send link'));
      await tester.pumpAndSettle();
      expect(share.texts.single, startsWith('Chillox is split. See your share: https://'));
      expect(share.texts.single, contains('/s/'));

      await tester.tap(find.text('whatsapp'));
      await tester.pumpAndSettle();
      expect(share.whatsapp.single, share.texts.single);

      share.whatsappWorks = false;
      await tester.tap(find.text('whatsapp'));
      await tester.pumpAndSettle();
      expect(find.text('could not open sharing. copy the link instead.'), findsOneWidget);

      await tester.tap(find.text('settle up'));
      await tester.pumpAndSettle();
      expect(find.text('collected'), findsOneWidget); // On the settle screen now.
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.read(draftBillProvider).shareUrl, isNotNull);
    });

    testWidgets('share as image captures a PNG of everyone\'s share', (tester) async {
      final (_, share) = await openSheet(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('share as image'));
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await tester.pumpAndSettle();
      expect(share.images.length, 1);
      final (png, name) = share.images.single;
      expect(name, 'splitup-chillox.png');
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]); // PNG signature
      await tester.pump(const Duration(milliseconds: 400));
    });

    test('share message and whatsapp links', () {
      final d = DraftBill.fresh().copyWith(place: ' Chillox ', shareUrl: 'https://splitup.app/s/abc');
      expect(shareMessage(d), 'Chillox is split. See your share: https://splitup.app/s/abc');
      expect(whatsappAppUri('a b&c').toString(), 'whatsapp://send?text=a%20b%26c');
      expect(whatsappWebUri('hi').host, 'wa.me');
    });
  });

  group('share view (deep link /s/:token)', () {
    SharedBill bill() => SharedBill.fromJson({
          'place': 'Chillox',
          'host_name': 'Demo',
          'host_bkash': '01700000000',
          'status': 'open',
          'total': 223600,
          'billed_at': '2026-09-12T14:42:00Z',
          'people': [
            {'name': 'Demo', 'is_host': true, 'items_amount': 55500, 'extras_amount': 5900, 'total': 61400, 'items': [{'name': 'Coke', 'qty': 3}]},
            {'name': 'Rafi', 'is_host': false, 'items_amount': 66250, 'extras_amount': 5900, 'total': 72150, 'items': []},
          ],
        });

    test('parses people and item labels', () {
      final b = bill();
      expect(b.people.first.items, ['Coke x3']);
      expect(b.total, 223600);
      expect(b.hostBkash, '01700000000');
    });

    testWidgets('shows the bill and the bKash number', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1200);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedBillProvider('tok').overrideWith((ref) async => bill())],
        child: MaterialApp(theme: buildAppTheme(), home: const ShareViewScreen(token: 'tok')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Chillox'), findsOneWidget);
      expect(find.text('01700000000'), findsOneWidget);
      expect(find.byType(BillCard), findsNWidgets(2));
    });

    testWidgets('an unknown token says so', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedBillProvider('nope').overrideWith((ref) async => null)],
        child: MaterialApp(theme: buildAppTheme(), home: const ShareViewScreen(token: 'nope')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('this link does not exist.'), findsOneWidget);
    });
  });
}
