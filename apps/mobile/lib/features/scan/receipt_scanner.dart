import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_scanner_stub.dart' if (dart.library.io) 'device_scanner_io.dart';
import 'scan_models.dart';

/// Reads a receipt photo into items, VAT, service charge and total.
abstract class ReceiptScanner {
  /// Throws [ScanFailure] with a message fit for the screen.
  Future<ScanResult> scan(Uint8List bytes);
}

/// Text recognition runs on the phone (Google ML Kit): free, offline, and the photo never
/// leaves the device.
final receiptScannerProvider = Provider<ReceiptScanner>((ref) => createDeviceScanner());
