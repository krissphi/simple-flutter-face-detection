import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera_widget/face_detection_service.dart';
import 'package:camera_widget/image_preview_widget.dart';
import 'camera_service.dart';
import 'permission_manager.dart';

class CameraPageController extends ChangeNotifier {
  final PermissionManager permissionManager;
  final CameraService cameraService;
  final FaceDetectionService faceDetectionService;

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isCameraGranted = false;
  bool _isAutoCapture = false;
  bool _isBoundaryEnabled = false;

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isCameraGranted => _isCameraGranted;
  bool get isAutoCapture => _isAutoCapture;
  bool get isBoundaryEnabled => _isBoundaryEnabled;
  CameraController? get cameraController => cameraService.cameraController;
  List<Face> get faces => faceDetectionService.faces;

  CameraPageController({
    required this.permissionManager,
    required this.cameraService,
    required this.faceDetectionService,
  });

  bool isSupportCamera() => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> onTakePhotoPressed(BuildContext context) async {
    await cameraService.cameraController?.stopImageStream();
    final xFile = await cameraService.capturePhoto();

    if (context.mounted && xFile != null && xFile.path.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImagePreview(imagePath: xFile.path),
        ),
      );
    }
    if (_isCameraGranted && context.mounted) {
      await cameraWithMLKit();
    }
  }

  void toggleAutoCapture(BuildContext context) {
    _isAutoCapture = !_isAutoCapture;
    faceDetectionService.setAutoCapture(
      _isAutoCapture,
      context,
      (BuildContext? _) => onTakePhotoPressed(context),
      _isBoundaryEnabled,
    );
    notifyListeners();
  }

  void toggleBoundary(BuildContext context) {
    _isBoundaryEnabled = !_isBoundaryEnabled;
    faceDetectionService.setAutoCapture(
      _isAutoCapture,
      context,
      (BuildContext? _) => onTakePhotoPressed(context),
      _isBoundaryEnabled,
    );
    notifyListeners();
  }

  Future<bool> initialize() async {
    _isLoading = true;
    notifyListeners();

    await cameraService.cameraController?.dispose();
    cameraService.resetCameraController();

    _isCameraGranted = await permissionManager.requestCameraPermission();
    if (!_isCameraGranted) {
      _isInitialized = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    await cameraWithMLKit();
    _isLoading = false;
    notifyListeners();
    return _isInitialized;
  }

  Future<void> checkPermissionAndInitialize() async {
    _isCameraGranted = await Permission.camera.status.isGranted;
    if (_isCameraGranted) {
      await cameraWithMLKit();
    } else {
      _isInitialized = false;
    }
    notifyListeners();
  }

  Future<void> cameraWithMLKit() async {
    _isInitialized = await cameraService.initialize(
      onFrameAvailable: (inputImage) async {
        await faceDetectionService.processImage(inputImage);
        _isLoading = false;
        notifyListeners();
      },
    );
    notifyListeners();
  }

  Future<void> pauseCamera() async {
    await cameraService.cameraController?.stopImageStream();
    notifyListeners();
  }

  Future<void> disposeCamera() async {
    await cameraService.cameraController?.stopImageStream();
    await cameraService.cameraController?.dispose();
    cameraService.resetCameraController();
    _isInitialized = false;
    _isAutoCapture = false;
    _isBoundaryEnabled = false;
    faceDetectionService.setAutoCapture(false, null, null, false);
    notifyListeners();
  }

  @override
  void dispose() {
    cameraService.dispose();
    faceDetectionService.dispose();
    _isInitialized = false;
    super.dispose();
  }
}
