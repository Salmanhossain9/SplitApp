import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_parser.dart';
import 'receipt_scanner.dart';
import 'scan_models.dart';

ReceiptScanner createDeviceScanner() => MlKitReceiptScanner();

/// Google ML Kit text recognition (Latin script, bundled model, works offline), then
/// [ReceiptParser] to find the items. ML Kit does not read Bangla script; Bangla digits are
/// handled when it does return them, and the person can always edit the list.
class MlKitReceiptScanner implements ReceiptScanner {
  @override
  Future<ScanResult> scan(Uint8List bytes) async {
    final dir = await Directory.systemTemp.createTemp('splitup_receipt_');
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final file = File('${dir.path}/receipt.jpg');
      await file.writeAsBytes(bytes, flush: true);
      final text = await recognizer.processImage(InputImage.fromFilePath(file.path));
      final lines = ocrLinesFrom(text);
      if (lines.isEmpty) {
        throw const ScanFailure('no text found. try a clearer photo in good light, or add the items by hand.');
      }
      final result = ReceiptParser.parse(lines);
      if (result.items.isEmpty) {
        throw const ScanFailure('could not find items on this receipt. try a flatter, closer photo, or add them by hand.');
      }
      return result;
    } on ScanFailure {
      rethrow;
    } catch (_) {
      throw const ScanFailure('could not read this photo. try again, or add the items by hand.');
    } finally {
      await recognizer.close();
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }
}

/// ML Kit lines with their position and tilt. The tilt comes from the corner points
/// (clockwise from the top left), so a receipt photographed at a slant still lines up.
List<OcrLine> ocrLinesFrom(RecognizedText text) {
  return [
    for (final block in text.blocks)
      for (final line in block.lines)
        OcrLine(
          line.text,
          left: line.boundingBox.left,
          top: line.boundingBox.top,
          right: line.boundingBox.right,
          bottom: line.boundingBox.bottom,
          angle: line.cornerPoints.length >= 2
              ? math.atan2(
                  (line.cornerPoints[1].y - line.cornerPoints[0].y).toDouble(),
                  (line.cornerPoints[1].x - line.cornerPoints[0].x).toDouble(),
                )
              : 0,
        ),
  ];
}
