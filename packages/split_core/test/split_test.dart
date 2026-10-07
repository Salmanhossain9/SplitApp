import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:split_core/split_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> loadFixture() => jsonDecode(
      File('../../fixtures/split_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;

int sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

void main() {
  final fx = loadFixture();

  group('splitEqually', () {
    for (final c in fx['splitEqually'] as List) {
      test('${c['total']} / ${c['n']}', () {
        expect(splitEqually(c['total'] as int, c['n'] as int),
            (c['expected'] as List).cast<int>());
      });
    }
    test('rejects n = 0', () {
      expect(() => splitEqually(100, 0), throwsArgumentError);
    });
  });

  group('splitByWeight', () {
    for (final c in fx['splitByWeight'] as List) {
      test('${c['total']} by ${c['weights']}', () {
        expect(
          splitByWeight(c['total'] as int, (c['weights'] as List).cast<int>()),
          (c['expected'] as List).cast<int>(),
        );
      });
    }
  });

  group('random property: shares always sum to total', () {
    final rng = Random(42);
    test('splitEqually / splitByWeight', () {
      for (var run = 0; run < 2000; run++) {
        final n = 1 + rng.nextInt(12);
        final total = rng.nextInt(5000000);
        expect(sum(splitEqually(total, n)), total);
        final weights = List.generate(n, (_) => rng.nextBool() ? 0 : rng.nextInt(300000));
        expect(sum(splitByWeight(total, weights)), total);
      }
    });

    test('computeShares in every mode', () {
      for (var run = 0; run < 1000; run++) {
        final n = 1 + rng.nextInt(12);
        final people = List.generate(n, (i) => 'p$i');
        final items = List.generate(
          1 + rng.nextInt(8),
          (i) => SplitItem(id: 'i$i', qty: 1 + rng.nextInt(4), unitPrice: rng.nextInt(200000)),
        );
        final claims = {
          for (final it in items)
            it.id: [
              for (final p in people)
                if (rng.nextInt(3) == 0) p,
            ].isEmpty
                ? [people[rng.nextInt(n)]]
                : [
                    for (final p in people)
                      if (rng.nextInt(3) == 0) p,
                  ],
        };
        // Re-roll claims deterministically non-empty.
        for (final it in items) {
          if (claims[it.id]!.isEmpty) claims[it.id] = [people[0]];
        }
        final vat = ChargeInput(rateBp: rng.nextInt(1500));
        final service = ChargeInput(rateBp: rng.nextInt(1500));

        for (final em in ExtrasMode.values) {
          final r = computeShares(
            participants: people,
            items: items,
            claims: claims,
            vat: vat,
            service: service,
            splitMode: SplitMode.items,
            extrasMode: em,
          );
          expect(r.sharesSum, r.total, reason: 'items/$em');
          for (final s in r.shares) {
            expect(s.total, s.itemsAmount + s.extrasAmount);
          }
        }

        final eq = computeShares(
          participants: people,
          items: items,
          claims: claims,
          vat: vat,
          service: service,
          splitMode: SplitMode.equally,
          sharing: people.sublist(0, 1 + rng.nextInt(n)),
        );
        expect(eq.sharesSum, eq.total, reason: 'equally');
        expect(eq.shares.every((s) => s.itemsAmount >= 0 && s.extrasAmount >= 0), isTrue);

        final total = eq.total;
        final custom = {
          for (final (i, p) in splitByWeight(
            total,
            List.generate(n, (_) => 1 + rng.nextInt(100)),
          ).indexed)
            people[i]: p,
        };
        final cu = computeShares(
          participants: people,
          items: items,
          claims: claims,
          vat: vat,
          service: service,
          splitMode: SplitMode.custom,
          customAmounts: custom,
        );
        expect(cu.sharesSum, cu.total, reason: 'custom');
      }
    });
  });

  group('Chillox golden', () {
    final c = fx['chillox'] as Map<String, dynamic>;
    final people = (c['participants'] as List).cast<String>();
    final items = [
      for (final i in c['items'] as List)
        SplitItem(
          id: i['id'] as String,
          qty: i['qty'] as int,
          unitPrice: i['unitPrice'] as int,
        ),
    ];
    final claims = {
      for (final e in (c['claims'] as Map<String, dynamic>).entries)
        e.key: (e.value as List).cast<String>(),
    };
    ChargeInput charge(String k) => ChargeInput(rateBp: (c[k] as Map)['rateBp'] as int);
    final expected = c['expected'] as Map<String, dynamic>;
    Map<String, int> exp(String k) => (expected[k] as Map).cast<String, int>();

    ComputeResult run(SplitMode m, [ExtrasMode e = ExtrasMode.equally]) => computeShares(
          participants: people,
          items: items,
          claims: claims,
          vat: charge('vat'),
          service: charge('service'),
          splitMode: m,
          extrasMode: e,
        );

    test('receipt maths', () {
      final r = run(SplitMode.items);
      expect(r.subtotal, expected['subtotal']);
      expect(r.vat, expected['vat']);
      expect(r.service, expected['service']);
      expect(r.total, expected['total']);
    });

    test('items only', () {
      final r = run(SplitMode.items);
      expect({for (final s in r.shares) s.participantId: s.itemsAmount}, exp('items'));
    });

    test('items, extras equally (extras 59 each)', () {
      final r = run(SplitMode.items);
      expect({for (final s in r.shares) s.participantId: s.total}, exp('itemsEqualExtras'));
      expect(r.sharesSum, r.total);
    });

    test('items, extras by what they ate', () {
      final r = run(SplitMode.items, ExtrasMode.byItems);
      expect({for (final s in r.shares) s.participantId: s.total}, exp('itemsByWeightExtras'));
      expect(r.sharesSum, r.total);
    });

    test('claim equally', () {
      final r = run(SplitMode.equally);
      expect({for (final s in r.shares) s.participantId: s.total}, exp('equallySplit'));
    });

    test('formats like the design', () {
      expect(formatTaka(61400), '৳614');
      expect(formatTaka(62049), '৳620.49');
      expect(formatTaka(223600), '৳2,236');
      expect(formatTaka(55500, forceDecimals: true), '৳555.00');
    });

    test('settle example', () {
      final s = c['settle'] as Map<String, dynamic>;
      final r = run(SplitMode.items);
      final byId = {for (final x in r.shares) x.participantId: x.total};
      final host = byId['you']!;
      expect(host, s['hostShare']);
      expect(r.total - host, s['target']);
      final summary = summarizeSettlement([
        (isHost: true, shareTotal: host, paid: host, owed: 0),
        (isHost: false, shareTotal: byId['rafi']!, paid: byId['rafi']!, owed: 0),
        (isHost: false, shareTotal: byId['nabil']!, paid: byId['nabil']!, owed: 0),
        (isHost: false, shareTotal: byId['tania']!, paid: s['taniaCashPaid'] as int, owed: s['openTab'] as int),
      ]);
      expect(summary.target, s['target']);
      expect(summary.collected, s['collected']);
      expect(summary.openTabs, s['openTab']);
    });
  });

  group('custom mode', () {
    test('rejects amounts that do not match total', () {
      expect(
        () => computeShares(
          participants: ['a', 'b'],
          items: const [SplitItem(id: 'x', qty: 1, unitPrice: 1000)],
          claims: const {},
          splitMode: SplitMode.custom,
          customAmounts: {'a': 400, 'b': 500},
        ),
        throwsA(isA<SplitException>()),
      );
    });
  });

  group('money', () {
    test('parsePoisha', () {
      expect(parsePoisha(''), 0);
      expect(parsePoisha('412'), 41200);
      expect(parsePoisha('412.5'), 41250);
      expect(parsePoisha('412.567'), 41256);
      expect(parsePoisha('1,200'), 120000);
      expect(parsePoisha('১২৩.৫'), 12350);
      expect(parsePoisha('.5'), 50);
      expect(parsePoisha('.'), isNull);
      expect(parsePoisha('1.2.3'), isNull);
      expect(parsePoisha('abc'), isNull);
    });
    test('poishaToInput round trips', () {
      for (final v in [0, 5, 50, 100, 41250, 41205, 123456]) {
        expect(parsePoisha(poishaToInput(v)), v);
      }
    });
  });
}
