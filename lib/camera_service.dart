import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraService {
  CameraController? _cameraController;
  CameraController? get cameraController => _cameraController;

  List<CameraDescription> _cameras = [];
  final ResolutionPreset _resolutionPreset = ResolutionPreset.medium;
  final CameraLensDirection _cameraLensDirection = CameraLensDirection.front;
  final bool _enableAudio = false;
  final bool _enableFlash = false;
  final ImageFormatGroup _imageFormatGroup =
      Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

  Future<bool> initialize({
    required Future<void> Function(InputImage inputImage) onFrameAvailable,
  }) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('No cameras available');
        return false;
      }

      final camera = _cameras.firstWhere(
        (camera) => camera.lensDirection == _cameraLensDirection,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        camera,
        _resolutionPreset,
        enableAudio: _enableAudio,
        imageFormatGroup: _imageFormatGroup,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(
        _enableFlash ? FlashMode.auto : FlashMode.off,
      );

      startStreaming(onFrameAvailable);

      return true;
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      return false;
    }
  }

  void startStreaming(Function(InputImage) onImageAvailable) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint(
        'Cannot start streaming: CameraController is null or not initialized',
      );
      return;
    }

    try {
      _cameraController!.startImageStream((CameraImage image) {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage != null) {
          onImageAvailable(inputImage);
        }
      });
    } catch (e) {
      debugPrint('Error starting image stream: $e');
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final rotation = _calculateInputImageRotation();
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (!_isValidImageFormat(format)) {
      return null;
    }

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
    if (Platform.isAndroid && format != InputImageFormat.nv21) {
      return false;
    }
    if (Platform.isIOS && format != InputImageFormat.bgra8888) {
      return false;
    }
    return true;
  }

    Future<XFile?> capturePhoto() async {
    final CameraController? cameraController = _cameraController;

    if (cameraController!.value.isTakingPicture) {
      return null;
    }
    try {
      await cameraController.setFlashMode(FlashMode.off); //optional
      XFile file = await cameraController.takePicture();
      debugPrint('Photo taken: ${file.path}');
      return file;
    } on CameraException catch (e) {
      debugPrint('Error occured while taking picture: $e');
      return null;
    }
  }


  void resetCameraController() {
    _cameraController = null;
  }

  void dispose() {
    debugPrint('CameraService dispose');
    try {
      _cameraController?.stopImageStream();
      _cameraController?.dispose();
      _cameraController = null;
    } catch (e) {
      debugPrint('Error disposing CameraService: $e');
    }
  }
}
