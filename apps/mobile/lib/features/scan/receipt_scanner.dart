import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../auth/auth_providers.dart';
import 'scan_models.dart';

abstract class ReceiptScanner {
  /// Upload the photo and read it. Throws [ScanFailure] with a message fit for the screen.
  Future<ScanResult> scan({required String billId, required Uint8List bytes});
}

/// "jpg", "png" or "webp" from the file's first bytes.
String imageExtension(Uint8List b) {
  if (b.length > 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'png';
  if (b.length > 12 && b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57 && b[9] == 0x45) return 'webp';
  return 'jpg';
}

String contentTypeFor(String ext) => switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

class SupabaseReceiptScanner implements ReceiptScanner {
  SupabaseReceiptScanner(this._client, this._userId);
  final SupabaseClient _client;
  final String? Function() _userId;

  @override
  Future<ScanResult> scan({required String billId, required Uint8List bytes}) async {
    final user = _userId();
    if (user == null) throw const ScanFailure('you are signed out. log in again.');
    final ext = imageExtension(bytes);
    // {user_id}/{bill_id}/... is the only folder the storage policy lets this user write.
    final path = '$user/$billId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await _client.storage.from('receipts').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentTypeFor(ext), upsert: true),
          );
      final res = await _client.functions.invoke('scan-receipt', body: {'path': path});
      return ScanResult.fromJson(res.data as Map<String, dynamic>, receiptPath: path);
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map && details['error'] is Map ? details['error']['code'] as String? : null;
      throw ScanFailure(scanMessageForCode(code));
    } on StorageException {
      throw const ScanFailure('could not upload the photo. check your connection.');
    } catch (_) {
      throw const ScanFailure('could not scan this photo. add items by hand or try again.');
    }
  }
}

/// Demo mode: pretends to read the Chillox sample from the spec.
class DemoReceiptScanner implements ReceiptScanner {
  @override
  Future<ScanResult> scan({required String billId, required Uint8List bytes}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    return const ScanResult(
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
    );
  }
}

final receiptScannerProvider = Provider<ReceiptScanner>((ref) {
  if (!Env.isConfigured) return DemoReceiptScanner();
  return SupabaseReceiptScanner(Supabase.instance.client, () => ref.read(authRepositoryProvider).userId);
});
