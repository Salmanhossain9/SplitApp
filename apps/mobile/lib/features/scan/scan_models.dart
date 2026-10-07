import '../../core/ids.dart';
import '../bill/draft_bill.dart';

/// What `scan-receipt` returns, all money in poisha. Never saved as is: the person edits it.
class ScanResult {
  const ScanResult({
    required this.items,
    this.place,
    this.vat,
    this.service,
    this.total,
    this.receiptPath,
  });

  final String? place;
  final List<ScannedItem> items;
  final int? vat;
  final int? service;
  final int? total;

  /// Where the photo went in the receipts bucket (kept on the bill).
  final String? receiptPath;

  factory ScanResult.fromJson(Map<String, dynamic> j, {String? receiptPath}) => ScanResult(
        place: j['place'] as String?,
        items: [
          for (final i in (j['items'] as List? ?? const []))
            ScannedItem(
              name: (i['name'] as String).trim(),
              qty: ((i['qty'] as num?) ?? 1).toInt().clamp(1, 999),
              unitPrice: (i['unit_price'] as num).toInt(),
            ),
        ],
        vat: (j['vat'] as num?)?.toInt(),
        service: (j['service'] as num?)?.toInt(),
        total: (j['total'] as num?)?.toInt(),
        receiptPath: receiptPath,
      );

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

class ScanFailure implements Exception {
  const ScanFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The function's error code to something a person can act on.
String scanMessageForCode(String? code) => switch (code) {
      'rate_limited' => 'you have scanned a lot in the last hour. add items by hand for now.',
      'unsupported_type' => 'use a jpg, png or webp photo.',
      'too_large' => 'that photo is too big. try a smaller one.',
      'unreadable' => 'could not read this receipt. try a clearer photo or add items by hand.',
      'not_configured' => 'receipt scanning is not switched on yet. add items by hand.',
      'upstream_unreachable' || 'upstream_error' => 'the scanner is busy. add items by hand or try again.',
      _ => 'could not scan this photo. add items by hand or try again.',
    };
