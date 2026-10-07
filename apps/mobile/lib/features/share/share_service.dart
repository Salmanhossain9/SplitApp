import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bill/draft_bill.dart';

/// "Chillox is split. See your share: https://..." One message for the whole group: the link
/// shows each friend their own bill.
String shareMessage(DraftBill d) {
  final link = d.shareUrl ?? '';
  return '${d.place.trim()} is split. See your share${link.isEmpty ? '' : ': $link'}';
}

Uri whatsappAppUri(String text) => Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
Uri whatsappWebUri(String text) => Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');

/// Everything that leaves the app through the OS. Behind an interface so tests can record it.
abstract class ShareService {
  Future<void> shareText(String text);
  Future<void> shareImage(Uint8List png, {required String text, required String fileName});

  /// Opens WhatsApp with the text ready to send. False when it could not be opened.
  Future<bool> openWhatsapp(String text);
}

class DeviceShareService implements ShareService {
  @override
  Future<void> shareText(String text) => SharePlus.instance.share(ShareParams(text: text));

  @override
  Future<void> shareImage(Uint8List png, {required String text, required String fileName}) {
    return SharePlus.instance.share(ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
      fileNameOverrides: [fileName],
    ));
  }

  @override
  Future<bool> openWhatsapp(String text) async {
    try {
      if (await launchUrl(whatsappAppUri(text), mode: LaunchMode.externalApplication)) return true;
    } catch (_) {}
    try {
      return await launchUrl(whatsappWebUri(text), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final shareServiceProvider = Provider<ShareService>((ref) => DeviceShareService());

/// Renders the widget under [key] (a RepaintBoundary) to PNG bytes.
Future<Uint8List> capturePng(GlobalKey key, {double pixelRatio = 3}) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
