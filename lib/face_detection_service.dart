import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';

class FaceDetectionService with ChangeNotifier {
  late FaceDetector _faceDetector;
  List<Face> _faces = [];
  DateTime _lastDetectionTime = DateTime.now();
  final Duration detectionInterval = const Duration(milliseconds: 200);
  DateTime? _faceStableStartTime;
  Map<int, Offset> _lastFacePositions = {};
  bool _isAutoCaptureEnabled = false;
  Function(BuildContext)? _onAutoCapture;
  BuildContext? _context;
  int? _countdownSeconds;
  bool _isAutoCaptureInBoundaryShape = false;
  bool? _isFaceInBoundary;

  List<Face> get faces => _faces;
  int? get countdownSeconds => _countdownSeconds;
  bool? get isFaceInBoundary => _isFaceInBoundary;
  BuildContext? get context => _context;
  Function(BuildContext)? get onAutoCapture => _onAutoCapture;

  FaceDetectionService() {
    _initializeFaceDetector();
  }

  void _initializeFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableTracking: true,
        enableLandmarks: false,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
  }

  void setAutoCapture(
    bool enabled,
    BuildContext? context,
    Function(BuildContext)? onAutoCapture,
    bool isAutoCaptureInBoundaryShape, // New parameter
  ) {
    _isAutoCaptureEnabled = enabled;
    _context = context;
    _onAutoCapture = onAutoCapture;
    _isAutoCaptureInBoundaryShape = isAutoCaptureInBoundaryShape;
    if (!enabled) {
      _faceStableStartTime = null;
      _lastFacePositions.clear();
      _countdownSeconds = null;
      _isFaceInBoundary = null;
      notifyListeners();
    }
    notifyListeners();
  }

  Future<void> processImage(InputImage inputImage) async {
    if (inputImage.bytes == null && inputImage.filePath == null) {
      debugPrint('Invalid InputImage: No bytes or file path provided');
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastDetectionTime) < detectionInterval) {
      return;
    }
    _lastDetectionTime = now;

    try {
      final newFaces = await _faceDetector.processImage(inputImage);

      if (_shouldUpdateFaces(newFaces)) {
        _faces = newFaces;
        if (_isAutoCaptureInBoundaryShape && newFaces.isNotEmpty) {
          _isFaceInBoundary = _checkFaceInBoundary(
            newFaces.first,
            inputImage.metadata!.size,
          );
        } else {
          _isFaceInBoundary =
              null; // No boundary status if no faces or boundary mode is off
        }
        logFaceInfo();
        notifyListeners();
      }

      if (_isAutoCaptureEnabled) {
        _checkFaceStability(newFaces, now, inputImage.metadata!.size);
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    }
  }

  bool _shouldUpdateFaces(List<Face> newFaces) {
    if (_faces.isEmpty ||
        newFaces.isEmpty ||
        _faces.length != newFaces.length) {
      return true;
    }

    for (var i = 0; i < newFaces.length && i < _faces.length; i++) {
      final oldFace = _faces[i];
      final newFace = newFaces[i];

      if (oldFace.trackingId != newFace.trackingId ||
          !isFacePositionSimilar(oldFace, newFace)) {
        return true;
      }
    }

    return false;
  }

  bool _checkFaceInBoundary(Face face, Size imageSize) {
    if (!_isAutoCaptureInBoundaryShape) return true;

    final ovalWidth = imageSize.width * 0.9;
    final ovalHeight = imageSize.height * 0.5;
    final centerX = imageSize.width / 2;
    final centerY = imageSize.height / 2;
    final a = ovalWidth / 2;
    final b = ovalHeight / 2;

    final faceBox = face.boundingBox;
    final faceCenterX = faceBox.left + faceBox.width / 2;
    final faceCenterY = faceBox.top + faceBox.height / 2;

    final normalizedX = (faceCenterX - centerX) / a;
    final normalizedY = (faceCenterY - centerY) / b;

    return (normalizedX * normalizedX) + (normalizedY * normalizedY) <= 1;
  }

  void _checkFaceStability(List<Face> newFaces, DateTime now, Size imageSize) {
    if (newFaces.isEmpty) {
      _faceStableStartTime = null;
      _lastFacePositions.clear();
      if (_countdownSeconds != null) {
        _countdownSeconds = null;
        notifyListeners();
      }
      return;
    }

    bool allFacesStable = true;
    bool allFacesInBoundary = true;
    Map<int, Offset> currentFacePositions = {};

    for (var face in newFaces) {
      if (face.trackingId == null) continue;

      final newBox = face.boundingBox;
      final newCenter = Offset(
        newBox.left + newBox.width / 2,
        newBox.top + newBox.height / 2,
      );

      currentFacePositions[face.trackingId!] = newCenter;

      // Check boundary condition
      if (_isAutoCaptureInBoundaryShape &&
          !_checkFaceInBoundary(face, imageSize)) {
        allFacesInBoundary = false;
        _faceStableStartTime = null;
        if (_countdownSeconds != null || _isFaceInBoundary != true) {
          _countdownSeconds = null;
          _isFaceInBoundary = false;
          notifyListeners();
        }
        break;
      }

      if (_lastFacePositions.containsKey(face.trackingId)) {
        final oldCenter = _lastFacePositions[face.trackingId]!;
        final imageDiagonal = sqrt(
          pow(newBox.width, 2) + pow(newBox.height, 2),
        );
        final threshold = imageDiagonal * 0.1;
        final distance = (oldCenter - newCenter).distance;

        if (distance > threshold) {
          allFacesStable = false;
          _faceStableStartTime = null;
          if (_countdownSeconds != null) {
            _countdownSeconds = null;
            notifyListeners();
          }
        }
      } else {
        allFacesStable = false;
        _faceStableStartTime = null;
        if (_countdownSeconds != null) {
          _countdownSeconds = null;
          notifyListeners();
        }
      }
    }

    _lastFacePositions = currentFacePositions;

    if (allFacesStable && allFacesInBoundary && newFaces.isNotEmpty) {
      _faceStableStartTime ??= now;

      final elapsedSeconds = now.difference(_faceStableStartTime!).inSeconds;
      final remainingSeconds = 3 - elapsedSeconds;

      if (remainingSeconds <= 0 && _context != null) {
        _onAutoCapture?.call(_context!);
        _faceStableStartTime = null;
        _lastFacePositions.clear();
        _countdownSeconds = null;
        notifyListeners();
      } else if (remainingSeconds != _countdownSeconds) {
        _countdownSeconds = remainingSeconds;
        _isFaceInBoundary = true;
        notifyListeners();
      }
    } else {
      if (_countdownSeconds != null) {
        _countdownSeconds = null;
        notifyListeners();
      }
      _faceStableStartTime = null;
    }
  }

  void logFaceInfo() {
    if (_faces.isEmpty) {
      debugPrint('No faces detected');
    } else {
      debugPrint('Detected ${_faces.length} faces');
      for (Face face in _faces) {
        debugPrint('Face detected: ${face.boundingBox}');
        debugPrint('Tracking ID: ${face.trackingId}');
      }
    }
  }

  bool isFacePositionSimilar(Face oldFace, Face newFace) {
    final oldBox = oldFace.boundingBox;
    final newBox = newFace.boundingBox;

    final oldCenter = Offset(
      oldBox.left + oldBox.width / 2,
      oldBox.top + oldBox.height / 2,
    );

    final newCenter = Offset(
      newBox.left + newBox.width / 2,
      newBox.top + newBox.height / 2,
    );

    final distance = (oldCenter - newCenter).distance;
    final imageDiagonal = sqrt(pow(oldBox.width, 2) + pow(oldBox.height, 2));
    final threshold = imageDiagonal * 0.01;

    return distance < threshold;
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }
}
