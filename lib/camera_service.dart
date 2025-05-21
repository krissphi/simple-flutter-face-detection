import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraService {
  CameraController? _cameraController;
  CameraController? get cameraController => _cameraController;

  List<CameraDescription> _cameras = [];

  final ResolutionPreset resolutionPreset;
  final CameraLensDirection cameraLensDirection;
  final bool enableAudio;
  final bool enableFlash;

  CameraService({
    this.resolutionPreset = ResolutionPreset.medium,
    this.cameraLensDirection = CameraLensDirection.front,
    this.enableAudio = false,
    this.enableFlash = false,
  });

  final ImageFormatGroup _imageFormatGroup =
      Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

  Future<bool> initialize({
    required Future<void> Function(InputImage inputImage) onFrameAvailable,
  }) async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return false;

    final camera = _cameras.firstWhere(
      (camera) => camera.lensDirection == cameraLensDirection,
      orElse: () => _cameras.first,
    );

    _cameraController = CameraController(
      camera,
      resolutionPreset,
      enableAudio: enableAudio,
      imageFormatGroup: _imageFormatGroup,
    );

    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(
      enableFlash ? FlashMode.auto : FlashMode.off,
    );

    startStreaming(onFrameAvailable);
    return true;
  }

  void startStreaming(Function(InputImage) onImageAvailable) {
    if (_cameraController?.value.isInitialized != true) return;

    _cameraController!.startImageStream((CameraImage image) {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage != null) {
        onImageAvailable(inputImage);
      }
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final rotation = _calculateInputImageRotation();
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (!_isValidImageFormat(format)) return null;

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _calculateInputImageRotation() {
    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;

      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }

      return InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    return null;
  }

  bool _isValidImageFormat(InputImageFormat? format) {
    if (format == null) return false;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return false;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return false;
    return true;
  }

  Future<XFile?> capturePhoto() async {
    final CameraController? controller = _cameraController;
    if (controller?.value.isTakingPicture != false) return null;

    await controller!.setFlashMode(FlashMode.off);
    return await controller.takePicture();
  }

  void resetCameraController() {
    _cameraController = null;
  }

  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _cameraController = null;
  }
}
