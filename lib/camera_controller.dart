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

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isCameraGranted = false;
  bool get isCameraGranted => _isCameraGranted;

  CameraController? get cameraController => cameraService.cameraController;

  DateTime _lastDetectionTime = DateTime.now();
  final Duration detectionInterval = const Duration(milliseconds: 200);

  final options = FaceDetectorOptions(
    enableClassification: false,
    enableTracking: true,
    enableLandmarks: false,
    performanceMode: FaceDetectorMode.fast,
    minFaceSize: 0.15,
  );

  List<Face> _faces = [];
  List<Face> get faces => _faces;

  late FaceDetector _faceDetector;

  CameraPageController({
    required this.permissionManager,
    required this.cameraService,
  }) {
    _faceDetector = FaceDetector(options: options);
  }

  Future<bool> initialize() async {
    try {
      if (cameraService.cameraController != null) {
        await cameraService.cameraController?.dispose();
        cameraService.resetCameraController();
      }

      final granted = await permissionManager.requestPermission(
        permission: Permission.camera,
      );

      _isCameraGranted = granted;
      debugPrint('initialize - Permission granted: $granted');

      if (!granted) {
        _isInitialized = false;
        notifyListeners();
        return false;
      }

      await cameraWithMLKit();
      notifyListeners();
      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      _isInitialized = false;
      _isCameraGranted = false;
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
      } else {
        _isInitialized = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking permission and initializing: $e');
      _isInitialized = false;
      _isCameraGranted = false;
      notifyListeners();
    }
  }

  Future<void> cameraWithMLKit() async {
    try {
      _isInitialized = await cameraService.initialize(
        onFrameAvailable: (inputImage) async {
          final now = DateTime.now();
          if (now.difference(_lastDetectionTime) < detectionInterval) {
            return;
          }
          _lastDetectionTime = now;

          final newFaces = await _faceDetector.processImage(inputImage);
          setFaces(newFaces);

          for (Face face in _faces) {
            debugPrint('Face detected: ${face.boundingBox}');
            debugPrint('Smiling probability: ${face.smilingProbability}');
            debugPrint('Tracking ID: ${face.trackingId}');
          }
        },
      );
      debugPrint('cameraWithMLKit - isInitialized: $_isInitialized');
    } catch (e) {
      debugPrint('Error in cameraWithMLKit: $e');
      _isInitialized = false;
      notifyListeners();
    }
  }

  void setFaces(List<Face> newFaces) {
    final hasChanged = !listEquals(_faces, newFaces);
    if (hasChanged) {
      _faces = newFaces;
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error disposing camera: $e');
    }
  }

  @override
  void dispose() {
    cameraService.dispose();
    _faceDetector.close();
    _isInitialized = false;
    super.dispose();
  }
}
