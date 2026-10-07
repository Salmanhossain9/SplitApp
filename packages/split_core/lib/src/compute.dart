import 'split.dart';

enum SplitMode { items, equally, custom }

enum ExtrasMode { equally, byItems }

class SplitItem {
  const SplitItem({required this.id, required this.qty, required this.unitPrice});
  final String id;
  final int qty;

  /// poisha. Line total = qty * unitPrice.
  final int unitPrice;

  int get lineTotal => qty * unitPrice;
}

/// A charge is a rate (basis points) on the items subtotal, or a flat amount.
class ChargeInput {
  const ChargeInput({this.rateBp, this.amount = 0});
  final int? rateBp;
  final int amount;
}

class Share {
  const Share({
    required this.participantId,
    required this.itemsAmount,
    required this.extrasAmount,
  });
  final String participantId;
  final int itemsAmount;
  final int extrasAmount;
  int get total => itemsAmount + extrasAmount;
}

class ComputeResult {
  const ComputeResult({
    required this.subtotal,
    required this.vat,
    required this.service,
    required this.shares,
  });
  final int subtotal;
  final int vat;
  final int service;
  final List<Share> shares;

  int get extras => vat + service;
  int get total => subtotal + extras;
  int get sharesSum => shares.fold(0, (a, s) => a + s.total);
}

class SplitException implements Exception {
  const SplitException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'SplitException($code): $message';
}

int itemsSubtotal(List<SplitItem> items) =>
    items.fold(0, (a, i) => a + i.lineTotal);

int chargeAmount(int subtotal, ChargeInput? charge) {
  if (charge == null) return 0;
  final rate = charge.rateBp;
  return rate != null ? applyRateBp(subtotal, rate) : charge.amount;
}

/// Items with nobody on them yet.
List<String> unclaimedItemIds(
  List<SplitItem> items,
  Map<String, List<String>> claims,
) =>
    [for (final i in items) if ((claims[i.id] ?? const []).isEmpty) i.id];

/// Each participant's slice of the item lines only (no extras). Items with no claimant are
/// skipped here so live previews work mid-claim; [computeShares] rejects them.
Map<String, int> itemSubtotals(
  List<String> participants,
  List<SplitItem> items,
  Map<String, List<String>> claims,
) {
  final totals = {for (final p in participants) p: 0};
  for (final item in items) {
    final claimants = [
      for (final p in participants)
        if ((claims[item.id] ?? const []).contains(p)) p,
    ];
    if (claimants.isEmpty) continue;
    final parts = splitEqually(item.lineTotal, claimants.length);
    for (var i = 0; i < claimants.length; i++) {
      totals[claimants[i]] = totals[claimants[i]]! + parts[i];
    }
  }
  return totals;
}

/// Pure, shared by live previews in the app. The server recomputes with the TS port.
ComputeResult computeShares({
  required List<String> participants,
  required List<SplitItem> items,
  required Map<String, List<String>> claims,
  ChargeInput? vat,
  ChargeInput? service,
  required SplitMode splitMode,
  ExtrasMode extrasMode = ExtrasMode.equally,
  Map<String, int> customAmounts = const {},
  List<String>? sharing,
}) {
  if (participants.isEmpty) {
    throw const SplitException('NO_PARTICIPANTS', 'a bill needs participants');
  }
  for (final ids in claims.values) {
    for (final id in ids) {
      if (!participants.contains(id)) {
        throw SplitException('UNKNOWN_PARTICIPANT', 'unknown participant $id');
      }
    }
  }
  final subtotal = itemsSubtotal(items);
  final vatAmt = chargeAmount(subtotal, vat);
  final serviceAmt = chargeAmount(subtotal, service);
  final extras = vatAmt + serviceAmt;
  final total = subtotal + extras;

  ComputeResult done(List<Share> shares) => ComputeResult(
        subtotal: subtotal,
        vat: vatAmt,
        service: serviceAmt,
        shares: shares,
      );

  switch (splitMode) {
    case SplitMode.equally:
      final who = [
        for (final p in participants)
          if ((sharing ?? participants).contains(p)) p,
      ];
      if (who.isEmpty) {
        throw const SplitException('NO_PARTICIPANTS', 'nobody is sharing');
      }
      final totals = splitEqually(total, who.length);
      final itemParts = splitEqually(subtotal, who.length);
      return done([
        for (final p in participants)
          if (who.contains(p))
            () {
              final idx = who.indexOf(p);
              final items = itemParts[idx] < totals[idx] ? itemParts[idx] : totals[idx];
              return Share(
                participantId: p,
                itemsAmount: items,
                extrasAmount: totals[idx] - items,
              );
            }()
          else
            Share(participantId: p, itemsAmount: 0, extrasAmount: 0),
      ]);

    case SplitMode.custom:
      final amounts = [for (final p in participants) customAmounts[p] ?? 0];
      if (amounts.any((a) => a < 0)) {
        throw const SplitException('INVALID_AMOUNT', 'negative custom amount');
      }
      final assigned = amounts.fold(0, (a, b) => a + b);
      if (assigned != total) {
        throw SplitException(
          'CUSTOM_MISMATCH',
          'custom amounts ($assigned) differ from total ($total)',
        );
      }
      final extraParts = splitByWeight(extras, amounts);
      return done([
        for (var i = 0; i < participants.length; i++)
          Share(
            participantId: participants[i],
            itemsAmount: amounts[i] - extraParts[i],
            extrasAmount: extraParts[i],
          ),
      ]);

    case SplitMode.items:
      final unclaimed = unclaimedItemIds(items, claims);
      if (unclaimed.isNotEmpty) {
        throw SplitException('UNCLAIMED_ITEMS', 'unclaimed: ${unclaimed.join(',')}');
      }
      final per = itemSubtotals(participants, items, claims);
      final itemAmounts = [for (final p in participants) per[p]!];
      final extraParts = extrasMode == ExtrasMode.equally
          ? splitEqually(extras, participants.length)
          : splitByWeight(extras, itemAmounts);
      return done([
        for (var i = 0; i < participants.length; i++)
          Share(
            participantId: participants[i],
            itemsAmount: itemAmounts[i],
            extrasAmount: extraParts[i],
          ),
      ]);
  }
}

/// Collected / target / open tabs for the settle screen. The host's own share is excluded.
class SettleSummary {
  const SettleSummary(this.target, this.collected, this.openTabs);
  final int target;
  final int collected;
  final int openTabs;
}

SettleSummary summarizeSettlement(
  List<({bool isHost, int shareTotal, int paid, int owed})> rows,
) {
  var target = 0, collected = 0, open = 0;
  for (final r in rows) {
    if (r.isHost) continue;
    target += r.shareTotal;
    collected += r.paid;
    open += r.owed;
  }
  return SettleSummary(target, collected, open);
}
