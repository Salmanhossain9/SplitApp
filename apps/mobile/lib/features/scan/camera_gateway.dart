import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A live camera. The scan tab only knows this interface, so tests can swap it out.
abstract class CameraSession {
  /// Fills its parent (covers it, cropping the overflow).
  Widget get preview;
  Future<Uint8List> capture();
  Future<void> dispose();
}

abstract class CameraGateway {
  /// Null when there is no camera or the permission was refused.
  Future<CameraSession?> open();
}

class DeviceCameraGateway implements CameraGateway {
  @override
  Future<CameraSession?> open() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false);
      await controller.initialize();
      return _DeviceCameraSession(controller);
    } on CameraException {
      return null; // Permission denied or camera busy: the scan tab falls back to the gallery.
    }
  }
}

class _DeviceCameraSession implements CameraSession {
  _DeviceCameraSession(this._controller);
  final CameraController _controller;

  @override
  Widget get preview {
    final size = _controller.value.previewSize;
    if (size == null) return CameraPreview(_controller);
    // previewSize is landscape; the phone is portrait, so swap, then cover the frame.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: size.height, height: size.width, child: CameraPreview(_controller)),
      ),
    );
  }

  @override
  Future<Uint8List> capture() async => (await _controller.takePicture()).readAsBytes();

  @override
  Future<void> dispose() => _controller.dispose();
}

final cameraGatewayProvider = Provider<CameraGateway>((ref) => DeviceCameraGateway());
