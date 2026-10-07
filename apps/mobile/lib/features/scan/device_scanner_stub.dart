import 'dart:typed_data';

import 'receipt_scanner.dart';
import 'scan_models.dart';

/// Platforms without on-device text recognition (the web build): say so, add items by hand.
ReceiptScanner createDeviceScanner() => _UnsupportedScanner();

class _UnsupportedScanner implements ReceiptScanner {
  @override
  Future<ScanResult> scan(Uint8List bytes) =>
      throw const ScanFailure('scanning works in the phone app. add the items by hand here.');
}
