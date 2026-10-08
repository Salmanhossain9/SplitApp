import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitup/features/scan/receipt_parser.dart';
import 'package:splitup/features/scan/scan_models.dart';

/// Real Tesseract output for rendered receipts (tool/ocr_fixtures). Tesseract stands in for
/// ML Kit: both give text lines with boxes. "lines" keeps each printed row whole, "split" cuts
/// rows at wide gaps (name | price) the way ML Kit often does.
Map<String, List<OcrLine>> fixture(String name) {
  final json = jsonDecode(File('test/fixtures/ocr/$name.json').readAsStringSync()) as Map<String, dynamic>;
  List<OcrLine> read(String key) => [
        for (final l in json[key] as List)
          OcrLine(l['text'] as String,
              left: (l['left'] as num).toDouble(),
              top: (l['top'] as num).toDouble(),
              right: (l['right'] as num).toDouble(),
              bottom: (l['bottom'] as num).toDouble(),
              angle: (l['angle'] as num?)?.toDouble() ?? 0),
      ];
  return {'lines': read('lines'), 'split': read('split')};
}

List<List<Object>> summary(ScanResult r) => [for (final i in r.items) [i.name, i.qty, i.unitPrice]];

/// A line at row `y` (rows are 30 px apart) from x to x2.
OcrLine line(String text, int y, {double x = 0, double x2 = 300}) =>
    OcrLine(text, left: x, top: y * 30.0, right: x2, bottom: y * 30.0 + 22);

void main() {
  group('clean receipts (real OCR output)', () {
    for (final variant in ['lines', 'split']) {
      test('Chillox, $variant', () {
        final r = ReceiptParser.parse(fixture('chillox')[variant]!);
        expect(r.place, 'Chillox');
        expect(summary(r), [
          ['Chicken burger', 1, 34500],
          ['Beef kala bhuna', 1, 114500],
          ['Fries', 1, 24000],
          ['Coke', 3, 9000],
        ]);
        expect([r.vat, r.service, r.total], [11800, 11800, 223600]);
        expect(r.subtotal, 200000); // The lines add up to the printed subtotal.
      });

      test('table with serial, qty, rate and amount columns, $variant', () {
        final r = ReceiptParser.parse(fixture('backyard')[variant]!);
        expect(r.place, 'The Backyard');
        expect(summary(r), [
          ['Chicken Biryani', 2, 32000],
          ['Beef Tehari', 1, 28000],
          ['Borhani', 3, 6000],
          ['Mineral Water 500ml', 4, 2500],
        ]);
        expect([r.vat, r.service, r.total], [19800, 12000, 151800]);
        expect(r.subtotal, 120000);
      });

      test('Tk and /- currency marks, $variant', () {
        final r = ReceiptParser.parse(fixture('pizza')[variant]!);
        expect(r.place, 'Pizza Roma');
        expect(summary(r), [
          ['Margherita Pizza', 1, 95000],
          ['Garlic Bread', 1, 22000],
          ['Lemonade', 2, 15000],
        ]);
        expect([r.vat, r.service, r.total], [null, null, 147000]);
      });
    }
  });

  group('noisy phone-photo style OCR', () {
    // Tesseract misreads some digits here ("345.06", "118.060", "640,00"). The parser must
    // still get every item, quantity and extra, within a taka, and flag nothing as an item that is not.
    void within(int actual, int truth, String what) =>
        expect((actual - truth).abs(), lessThanOrEqualTo(100), reason: '$what: $actual vs $truth');

    for (final variant in ['lines', 'split']) {
      test('Chillox, $variant', () {
        final r = ReceiptParser.parse(fixture('chillox_noisy')[variant]!);
        expect(r.items.map((i) => [i.name, i.qty]), [
          ['Chicken burger', 1], ['Beef kala bhuna', 1], ['Fries', 1], ['Coke', 3],
        ]);
        const truth = [34500, 114500, 24000, 9000];
        for (var i = 0; i < 4; i++) {
          within(r.items[i].unitPrice, truth[i], r.items[i].name);
        }
        within(r.vat!, 11800, 'vat');
        within(r.service!, 11800, 'service');
        expect(r.total, 223600);
      });

      test('table, $variant', () {
        final r = ReceiptParser.parse(fixture('backyard_noisy')[variant]!);
        expect(r.items.map((i) => [i.name, i.qty]), [
          ['Chicken Biryani', 2], ['Beef Tehari', 1], ['Borhani', 3], ['Mineral Water 500ml', 4],
        ]);
        const truth = [32000, 28000, 6000, 2500];
        for (var i = 0; i < 4; i++) {
          within(r.items[i].unitPrice, truth[i], r.items[i].name);
        }
        expect([r.vat, r.service, r.total], [19800, 12000, 151800]);
      });
    }
  });

  group('rows from positions', () {
    test('name and price as separate pieces on the same row, even a few pixels apart', () {
      final r = ReceiptParser.parse([
        line('Fries', 5, x: 0, x2: 80),
        line('240.00', 5, x: 220, x2: 300).shift(dy: 4),
        line('Coke x3', 6, x: 0, x2: 90),
        line('270', 6, x: 230, x2: 300).shift(dy: -3),
        line('Total', 9, x: 0, x2: 70),
        line('510', 9, x: 230, x2: 300),
      ]);
      expect(summary(r), [['Fries', 1, 24000], ['Coke', 3, 9000]]);
      expect(r.total, 51000);
    });

    test('a tilted photo: the tilt reported by the OCR straightens the rows', () {
      // 3 degrees clockwise: the right end of each row sits lower than the left end.
      const tilt = 0.0524;
      OcrLine tilted(String t, int row, double x, double x2) =>
          OcrLine(t, left: x, top: row * 40.0 + x * 0.0524, right: x2, bottom: row * 40.0 + 20 + x2 * 0.0524, angle: tilt);
      final r = ReceiptParser.parse([
        tilted('Fries', 1, 0, 80), tilted('240.00', 1, 520, 600),
        tilted('Coke x3', 2, 0, 90), tilted('270.00', 2, 520, 600),
        tilted('Total', 4, 0, 70), tilted('510.00', 4, 520, 600),
      ]);
      expect(summary(r), [['Fries', 1, 24000], ['Coke', 3, 9000]]);
      expect(r.total, 51000);
    });

    test('lines may arrive in any order', () {
      final r = ReceiptParser.parse([
        line('Total 510', 9),
        line('Coke x3 270', 6),
        line('Fries 240', 5),
      ]);
      expect(summary(r), [['Fries', 1, 24000], ['Coke', 3, 9000]]);
      expect(r.total, 51000);
    });

    test('a wrapped name with the price on the next row', () {
      final r = ReceiptParser.parse([
        line('Chicken burger with', 5),
        line('345', 6),
        line('Fries', 7),
        line('240', 7, x: 250),
      ]);
      expect(r.items.length, 2);
      expect(r.items.first.unitPrice, 34500);
      expect(r.items.last.name, 'Fries');
    });
  });

  group('quantities', () {
    List<List<Object>> parse(List<String> rows) =>
        summary(ReceiptParser.parse([for (var i = 0; i < rows.length; i++) line(rows[i], i)]));

    test('the usual ways a receipt writes them', () {
      expect(parse(['Coke x3 270']), [['Coke', 3, 9000]]);
      expect(parse(['Coke 3x 270']), [['Coke', 3, 9000]]);
      expect(parse(['Coke qty 3 270']), [['Coke', 3, 9000]]);
      expect(parse(['Coke 3 x 90.00 270.00']), [['Coke', 3, 9000]]);
      expect(parse(['Coke 3 90.00 270.00']), [['Coke', 3, 9000]]);
      expect(parse(['Coke 90.00 270.00']), [['Coke', 3, 9000]]);
      expect(parse(['Fries 2 480']), [['Fries', 2, 24000]]);
      expect(parse(['2 Chicken burger 690']), [['Chicken burger', 2, 34500]]);
    });

    test('a serial number is not a quantity', () {
      expect(parse(['1. Chicken burger 345', '2) Fries 240']), [['Chicken burger', 1, 34500], ['Fries', 1, 24000]]);
      expect(parse(['3  Borhani 60.00 60.00']), [['Borhani', 1, 6000]]);
    });

    test('a line total that does not divide by the quantity stays exact', () {
      // 3 x 33.34 printed as 100.01: one unit at the full price keeps the subtotal right.
      expect(parse(['Mix platter x3 100.01']), [['Mix platter x3', 1, 10001]]);
    });
  });

  group('what is not an item', () {
    test('header, contact, date, payment and footer lines', () {
      final r = ReceiptParser.parse([
        line('THE BACKYARD', 0),
        line('Mirpur 10, Dhaka 1216', 1),
        line('Tel: 01711123456', 2),
        line('Date: 21/09/2026 21:04', 3),
        line('Bill No 10492   Table 4', 4),
        line('Item Qty Price Amount', 5),
        line('Chicken Biryani 320', 6),
        line('Sub Total 320', 7),
        line('VAT 15% 48', 8),
        line('Grand Total 368', 9),
        line('Cash 500', 10),
        line('Change 132', 11),
        line('Thank you, visit again', 12),
      ]);
      expect(summary(r), [['Chicken Biryani', 1, 32000]]);
      expect([r.vat, r.service, r.total], [4800, null, 36800]);
      expect(r.place, 'The Backyard');
    });

    test('discounts and rounding are not items, "Total Items" is not the total', () {
      final r = ReceiptParser.parse([
        line('Fries 240', 0),
        line('Total Items 1', 1),
        line('Discount 20', 2),
        line('Rounding 0.40', 3),
        line('Net Payable 220', 4),
      ]);
      expect(summary(r), [['Fries', 1, 24000]]);
      expect(r.total, 22000);
    });

    test('a food name that merely contains a keyword is kept', () {
      final r = ReceiptParser.parse([
        line('Vegetable Soup 180', 0),
        line('Card Special Burger 250', 1),
        line('Total 430', 2),
      ]);
      expect(r.items.map((i) => i.name), ['Vegetable Soup', 'Card Special Burger']);
    });
  });

  group('extras', () {
    test('CGST and SGST rows add up as VAT; the grand total wins over a plain total', () {
      final r = ReceiptParser.parse([
        line('Fries 240', 0),
        line('Total 240', 1),
        line('CGST 2.5% 6', 2),
        line('SGST 2.5% 6', 3),
        line('Service Charge 10% 24', 4),
        line('Grand Total 276', 5),
      ]);
      expect([r.vat, r.service, r.total], [1200, 2400, 27600]);
    });

    test('no extras printed means none found', () {
      final r = ReceiptParser.parse([line('Tea 40', 0), line('Total 40', 1)]);
      expect([r.vat, r.service, r.total], [null, null, 4000]);
    });
  });

  group('Bangla digits and symbols', () {
    test('digits, the taka sign and /-', () {
      final r = ReceiptParser.parse([
        line('Chicken burger ৳৩৪৫', 0),
        line('Fries ২৪০/-', 1),
        line('Total ৫৮৫', 2),
      ]);
      expect(summary(r), [['Chicken burger', 1, 34500], ['Fries', 1, 24000]]);
      expect(r.total, 58500);
    });
  });

  group('names', () {
    test('SHOUTING names are title-cased, leaders and bullets removed', () {
      final r = ReceiptParser.parse([
        line('CHICKEN BURGER ........ 345', 0),
        line('• Fries --- 240', 1),
      ]);
      expect(r.items.map((i) => i.name), ['Chicken Burger', 'Fries']);
    });

    test('OCR comma mistakes in amounts', () {
      final r = ReceiptParser.parse([
        line('Beef kala bhuna 1, 145,00', 0),
        line('Fries 240,00', 1),
        line('Big feast 1,00,000.00', 2),
      ]);
      expect(r.items.map((i) => i.unitPrice), [114500, 24000, 10000000]);
    });
  });

  group('nothing usable', () {
    test('empty and garbage input give no items instead of invented ones', () {
      expect(ReceiptParser.parse(const []).items, isEmpty);
      expect(ReceiptParser.parse([line('', 0), line('   ', 1)]).items, isEmpty);
      expect(ReceiptParser.parse([line('asdf qwer', 0), line('!!! ???', 1), line('12345', 2)]).items, isEmpty);
    });

    test('a receipt with items but no totals still returns the items', () {
      final r = ReceiptParser.parse([line('Fries 240', 0), line('Coke 90', 1)]);
      expect(r.items.length, 2);
      expect([r.vat, r.service, r.total], [null, null, null]);
    });
  });

  group('wrapped names and a Qty / Item / Price / T.Price table (Delectus receipt)', () {
    // Rows as ML Kit reads that receipt: the header block is noisy, two names wrap onto a second
    // row, and "Guest Bill" has spaced out letters. Net Total is before VAT, Gross Total after.
    List<OcrLine> delectus(List<String> rows) => [for (var i = 0; i < rows.length; i++) line(rows[i], i)];

    final rows = [
      'DELECTUS',
      'Block-G,Plot-2',
      'Rupayan Shooping Squre',
      'Phone#+8801330218502',
      'BIN:006355581-0101',
      'Mushak-6.3',
      'able: Outdoor_3',
      'Waiter:Rayhan.',
      'G u e s t B i l l',
      'Date:26-Sep-26 Time:04:49 PM',
      'Invoice No:T-79336 Number Of Guests:0',
      'Qty Item Name Price T.Price',
      '2 Sakura Water 330 ml 15.00 30.00',
      '1 Chocolate Brownie Cream',
      '.REGULAR 499.00 499.00',
      '1 Choco Lava Ice Cream 399.00 399.00',
      '1 Vanilla Cream.REGULAR 399.00 399.00',
      '1 Chicken Combo 499.00 499.00',
      '1 Caramel Banana French T',
      'cast 599.00 599.00',
      '1 Tiramisu 369.00 369.00',
      'Ticket Total: 2,794.00',
      'Net Total: 2,794.00',
      'Vat-5.00%: 138.20',
      'Auto Round --1.00%: -0.20',
      'Gross Total: 2,932.00',
      'REMAINING AMOUNT: 2,932.00',
      'Notes:',
      'THANK YOU,COME AGAIN',
      'Powered by:Otomatic,01712615605',
    ];

    test('every dish once, wrapped names joined, nothing from the header', () {
      final r = ReceiptParser.parse(delectus(rows));
      expect(summary(r), [
        ['Sakura Water 330 ml', 2, 1500],
        ['Chocolate Brownie Cream Regular', 1, 49900],
        ['Choco Lava Ice Cream', 1, 39900],
        ['Vanilla Cream.REGULAR', 1, 39900],
        ['Chicken Combo', 1, 49900],
        ['Caramel Banana French Tcast', 1, 59900],
        ['Tiramisu', 1, 36900],
      ]);
      expect(r.subtotal, 279400);
    });

    test('the receipt total is the final amount, not the one before VAT', () {
      final r = ReceiptParser.parse(delectus(rows));
      expect(r.total, 293200);
      expect(r.vat, 13820);
      expect(r.place, 'Delectus');
    });

    test('works when the printed header row is misread', () {
      final noisy = [...rows]..[11] = 'Oty ltem Name Price T.Price';
      final r = ReceiptParser.parse(delectus(noisy));
      expect(r.subtotal, 279400);
      expect(r.items.length, 7);
    });

    test('spaced out letters in a heading are not an item', () {
      final r = ReceiptParser.parse(delectus(['G u e s t B i l l 11', ...rows.sublist(12)]));
      expect(r.items.any((i) => i.name.toLowerCase().contains('u e s')), isFalse);
      expect(r.subtotal, 279400);
    });
  });

  group('price x quantity rows and VAT already inside the total (CafeNjoy receipt)', () {
    // One dish printed as "unit price x qty" with a second line holding the size and the line total.
    // The x is often read as a multiplication sign. VAT 26.19 is already inside the 550.
    List<OcrLine> cafe(String times) => [
          for (final (i, t) in [
            'CAFENJOY',
            'Panir Pump Mor,Namapara,khilkhet-1229',
            'Mobile: 01811545559',
            'Customer Type: Takeaway',
            'http://cafenjoybd.com/',
            'Mushak-6.3',
            'Date: 23-08-2026',
            'Time: 07:35 PM',
            'Item Total',
            'Jalapeno Pizza (Chicken) 550.00 $times 1',
            'SMALL 550.00 ৳',
            'Subtotal 550.00 ৳',
            'SD 0.00 ৳',
            'Total Discount(%) 0.00 ৳',
            'Vat (5%) 26.19 ৳',
            'Grand Total 550.00 ৳',
            'Customer Paid 550.00 ৳',
            'Cash Payment 550.00 ৳',
            'Change Due 0.00 ৳',
            'Total payment 550.00৳',
            'Bill To: Walkin',
            'Order No.: SA-2308',
            'Payment Status: Paid',
          ].indexed)
            line(t, i),
        ];

    for (final times in ['x', '×', 'X']) {
      test('one dish at 550, not 1 taka ("$times")', () {
        final r = ReceiptParser.parse(cafe(times));
        expect(summary(r), [
          ['Jalapeno Pizza (Chicken) Small', 1, 55000],
        ]);
        expect(r.subtotal, 55000);
        expect(r.total, 55000);
        expect(r.place, 'Cafenjoy');
      });
    }

    test('VAT that is already inside the total is not added again', () {
      final r = ReceiptParser.parse(cafe('x'));
      expect(r.vat, isNull);
      expect(r.service, isNull);
    });

    test('unit price x quantity: 2 at 275 is 550 for the line', () {
      final r = ReceiptParser.parse([
        line('Item Total', 0),
        line('Cold Coffee 275.00 x 2', 1),
        line('Burger 300.00 × 1', 2),
        line('Grand Total 850.00', 3),
      ]);
      expect(summary(r), [
        ['Cold Coffee', 2, 27500],
        ['Burger', 1, 30000],
      ]);
    });

    test('two different dishes at the same price are not merged', () {
      final r = ReceiptParser.parse([
        line('Item Total', 0),
        line('Coke 90.00', 1),
        line('Sprite 90.00', 2),
        line('Total 180.00', 3),
      ]);
      expect(summary(r), [
        ['Coke', 1, 9000],
        ['Sprite', 1, 9000],
      ]);
    });

    test('a discount row is not the receipt total', () {
      final r = ReceiptParser.parse([
        line('Item Total', 0),
        line('Pizza 500.00', 1),
        line('Total Discount(%) 50.00', 2),
        line('Grand Total 450.00', 3),
      ]);
      expect(r.total, 45000);
    });
  });
}

extension on OcrLine {
  OcrLine shift({double dy = 0}) => OcrLine(text, left: left, top: top + dy, right: right, bottom: bottom + dy);
}
