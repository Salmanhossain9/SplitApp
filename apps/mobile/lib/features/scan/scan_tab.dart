import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../bill/draft_bill_notifier.dart';
import 'camera_gateway.dart';
import 'receipt_scanner.dart';
import 'scan_models.dart';

/// The "scan receipt" tab: live viewfinder, take photo, upload from photos. While the photo is
/// being read the scan line sweeps over it. The result goes to [onScanned] for editing.
class ScanTab extends ConsumerStatefulWidget {
  const ScanTab({super.key, required this.onScanned});
  final ValueChanged<ScanResult> onScanned;

  @override
  ConsumerState<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends ConsumerState<ScanTab> {
  CameraSession? _camera;
  bool _cameraTried = false;
  bool _scanning = false;
  Uint8List? _photo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  Future<void> _openCamera() async {
    final session = await ref.read(cameraGatewayProvider).open();
    if (!mounted) {
      await session?.dispose();
      return;
    }
    setState(() {
      _camera = session;
      _cameraTried = true;
    });
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null) {
      // No camera (or no permission): the gallery still works.
      return _pickFromGallery();
    }
    try {
      await _scan(await camera.capture());
    } catch (_) {
      if (mounted) setState(() => _error = 'could not take the photo. try again or upload one.');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _scan(await picked.readAsBytes());
    } catch (_) {
      if (mounted) setState(() => _error = 'could not open that photo.');
    }
  }

  Future<void> _scan(Uint8List bytes) async {
    setState(() {
      _photo = bytes;
      _scanning = true;
      _error = null;
    });
    try {
      final billId = ref.read(draftBillProvider).id;
      final result = await ref.read(receiptScannerProvider).scan(billId: billId, bytes: bytes);
      if (!mounted) return;
      widget.onScanned(result);
    } on ScanFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _photo = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReceiptViewfinder(
          scanning: _scanning,
          camera: _photo != null
              ? Image.memory(_photo!, fit: BoxFit.cover)
              : _camera?.preview,
        ),
        const SizedBox(height: AppSpacing.s12),
        Center(
          child: Text(
            _scanning
                ? 'reading your receipt...'
                : _cameraTried && _camera == null
                    ? 'camera is off. upload a photo of the receipt instead.'
                    : 'place the receipt inside the frame',
            style: AppType.label14.copyWith(color: AppColors.slate),
            textAlign: TextAlign.center,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s16),
          ClaimedBanner(text: _error!, variant: BannerVariant.error),
        ],
        const SizedBox(height: AppSpacing.s16),
        WideButton(
          label: 'take photo',
          variant: WideButtonVariant.photo,
          loading: _scanning,
          enabled: !_scanning,
          onPressed: _takePhoto,
        ),
        const SizedBox(height: AppSpacing.s12),
        WideButton(
          label: 'upload from photos',
          variant: WideButtonVariant.upload,
          enabled: !_scanning,
          onPressed: _pickFromGallery,
        ),
      ],
    );
  }
}
