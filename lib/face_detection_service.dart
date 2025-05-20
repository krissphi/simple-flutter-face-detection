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

  List<Face> get faces => _faces;
  int? get countdownSeconds => _countdownSeconds;

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
    bool isAutoCaptureInBoundaryShape,
  ) {
    _isAutoCaptureEnabled = enabled;
    _context = context;
    _onAutoCapture = onAutoCapture;
    _isAutoCaptureInBoundaryShape = isAutoCaptureInBoundaryShape;

    if (!enabled) {
      _faceStableStartTime = null;
      _lastFacePositions.clear();
      _countdownSeconds = null;
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
        // logFaceInfo();
        notifyListeners();
      }

      if (_isAutoCaptureEnabled) {
        _checkFaceStability(newFaces, now);
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

  bool _isFaceInBoundary(Face face, Size imageSize) {
    if (!_isAutoCaptureInBoundaryShape) {
      return true; // No boundary check if disabled
    }

    // Define boundary (e.g., 60% of the image width/height, centered)
    final boundaryWidth = imageSize.width * 0.6;
    final boundaryHeight = imageSize.height * 0.6;
    final boundaryLeft = (imageSize.width - boundaryWidth) / 2;
    final boundaryTop = (imageSize.height - boundaryHeight) / 2;
    final boundaryRight = boundaryLeft + boundaryWidth;
    final boundaryBottom = boundaryTop + boundaryHeight;

    final faceBox = face.boundingBox;
    final faceCenterX = faceBox.left + faceBox.width / 2;
    final faceCenterY = faceBox.top + faceBox.height / 2;

    // Check if the face's center is within the boundary
    return faceCenterX >= boundaryLeft &&
        faceCenterX <= boundaryRight &&
        faceCenterY >= boundaryTop &&
        faceCenterY <= boundaryBottom;
  }

  void _checkFaceStability(List<Face> newFaces, DateTime now) {
    if (newFaces.isEmpty) {
      _faceStableStartTime = null;
      _lastFacePositions.clear();
      return;
    }

    bool allFacesStable = true;
    Map<int, Offset> currentFacePositions = {};

    for (var face in newFaces) {
      if (face.trackingId == null) continue;

      final newBox = face.boundingBox;
      final newCenter = Offset(
        newBox.left + newBox.width / 2,
        newBox.top + newBox.height / 2,
      );

      currentFacePositions[face.trackingId!] = newCenter;

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
        }
      } else {
        allFacesStable = false;
        _faceStableStartTime = null;
      }
    }

    _lastFacePositions = currentFacePositions;

    if (allFacesStable && newFaces.isNotEmpty) {
      _faceStableStartTime ??= now;

      final elapsedSeconds = now.difference(_faceStableStartTime!).inSeconds;
      final remainingSeconds = 3 - elapsedSeconds;

      if (remainingSeconds <= 0 && _context != null) {
        _onAutoCapture?.call(_context!);
        _faceStableStartTime = null;
        _lastFacePositions.clear();
        _countdownSeconds = null;
      } else if (remainingSeconds != _countdownSeconds) {
        _countdownSeconds = remainingSeconds;
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
        // debugPrint('Face detected: ${face.boundingBox}');
        // debugPrint('Tracking ID: ${face.trackingId}');
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
