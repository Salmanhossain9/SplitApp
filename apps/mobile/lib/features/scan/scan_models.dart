import '../../core/ids.dart';
import '../bill/draft_bill.dart';

/// What reading a receipt found, all money in poisha. Never final: the person edits the list.
class ScanResult {
  const ScanResult({
    required this.items,
    this.place,
    this.vat,
    this.service,
    this.total,
  });

  final String? place;
  final List<ScannedItem> items;
  final int? vat;
  final int? service;
  final int? total;

  /// Sum of the item lines as read.
  int get subtotal => items.fold(0, (a, i) => a + i.qty * i.unitPrice);

  List<DraftItem> toDraftItems() => [
        for (final i in items) DraftItem(id: newUuid(), name: i.name, qty: i.qty, unitPrice: i.unitPrice),
      ];
}

class ScannedItem {
  const ScannedItem({required this.name, required this.qty, required this.unitPrice});
  final String name;
  final int qty;
  final int unitPrice;
}

/// A detected VAT or service amount as a rate on the items subtotal, in basis points,
/// rounded half up with integer maths. No detected amount means no charge (0).
int rateBpFromAmount(int? amount, int subtotal) {
  if (amount == null || amount <= 0 || subtotal <= 0) return 0;
  return (amount * 10000 + subtotal ~/ 2) ~/ subtotal;
}

/// Something went wrong reading a photo; [message] is fit to show on the screen.
class ScanFailure implements Exception {
  const ScanFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
