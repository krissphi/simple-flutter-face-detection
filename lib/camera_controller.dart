import 'package:camera_widget/face_detection_service.dart';
import 'package:camera_widget/image_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'camera_service.dart';
import 'permission_manager.dart';

class CameraPageController extends ChangeNotifier {
  final PermissionManager permissionManager;
  final CameraService cameraService;
  final FaceDetectionService faceDetectionService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isCameraGranted = false;
  bool get isCameraGranted => _isCameraGranted;

  bool _isAutoCapture = false;
  bool get isAutoCapture => _isAutoCapture;

  bool _isAutoCaptureInBoundaryShape = false;
  bool get isAutoCaptureInBoundaryShape => _isAutoCaptureInBoundaryShape;

  CameraController? get cameraController => cameraService.cameraController;

  List<Face> get faces => faceDetectionService.faces;

  CameraPageController({
    required this.permissionManager,
    required this.cameraService,
    required this.faceDetectionService,
  });

  Future<void> onTakePhotoPressed(BuildContext context) async {
    bool isMounted = context.mounted;
    await cameraService.cameraController?.stopImageStream();
    final xFile = await cameraService.capturePhoto();

    if (!isMounted || !context.mounted) {
      debugPrint('Context is not mounted, skipping navigation');
      if (_isCameraGranted) {
        await cameraWithMLKit();
      }
      return;
    }

    if (xFile != null && xFile.path.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImagePreview(imagePath: xFile.path),
        ),
      );
      if (_isCameraGranted && context.mounted) {
        await cameraWithMLKit();
      }
    } else {
      if (_isCameraGranted && context.mounted) {
        await cameraWithMLKit();
      }
    }
  }

  void toggleAutoCapture(BuildContext context) {
    _isAutoCapture = !_isAutoCapture;
    faceDetectionService.setAutoCapture(
      _isAutoCapture,
      context,
      (BuildContext? _) => onTakePhotoPressed(context),
      _isAutoCaptureInBoundaryShape,
    );
    notifyListeners();
  }

  void toggleAutoCaptureInBoundaryShape() {
    _isAutoCaptureInBoundaryShape = !_isAutoCaptureInBoundaryShape;
    faceDetectionService.setAutoCapture(
      _isAutoCapture,
      faceDetectionService.context,
      faceDetectionService.onAutoCapture,
      _isAutoCaptureInBoundaryShape,
    );
    notifyListeners();
  }

  Future<bool> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (cameraService.cameraController != null) {
        await cameraService.cameraController?.dispose();
        cameraService.resetCameraController();
      }

      final granted = await permissionManager.requestCameraPermission();

      _isCameraGranted = granted;
      debugPrint('initialize - Permission granted: $granted');

      if (!granted) {
        _isInitialized = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await cameraWithMLKit();
      _isLoading = false;
      notifyListeners();
      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      _isInitialized = false;
      _isCameraGranted = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> checkPermissionAndInitialize() async {
    try {
      final status = await Permission.camera.status;
      _isCameraGranted = status.isGranted;
      debugPrint(
        'checkPermissionAndInitialize - isCameraGranted: $_isCameraGranted',
      );

      if (_isCameraGranted) {
        await cameraWithMLKit();
        notifyListeners();
      } else {
        _isInitialized = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking permission and initializing: $e');
      _isInitialized = false;
      _isCameraGranted = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cameraWithMLKit() async {
    try {
      _isInitialized = await cameraService.initialize(
        onFrameAvailable: (inputImage) async {
          await faceDetectionService.processImage(inputImage);
          _isLoading = false;
          notifyListeners();
        },
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error in cameraWithMLKit: $e');
      _isInitialized = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pauseCamera() async {
    try {
      debugPrint('Pausing camera');
      await cameraService.cameraController?.stopImageStream();
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing camera: $e');
    }
  }

  Future<void> disposeCamera() async {
    try {
      await cameraService.cameraController?.stopImageStream();
      await cameraService.cameraController?.dispose();
      cameraService.resetCameraController();
      _isInitialized = false;
      _isAutoCapture = false;
      _isAutoCaptureInBoundaryShape = false;
      faceDetectionService.setAutoCapture(false, null, null, false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error disposing camera: $e');
    }
  }

  @override
  void dispose() {
    cameraService.dispose();
    faceDetectionService.dispose();
    _isInitialized = false;
    super.dispose();
  }
}
