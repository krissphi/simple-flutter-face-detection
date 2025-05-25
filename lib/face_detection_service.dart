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
  bool _isBoundaryEnabled = false;
  bool? _isFaceInBoundary;

  List<Face> get faces => _faces;
  int? get countdownSeconds => _countdownSeconds;
  bool? get isFaceInBoundary => _isFaceInBoundary;

  FaceDetectionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
  }

  void setAutoCapture(
    bool enabled,
    BuildContext? context,
    Function(BuildContext)? onAutoCapture,
    bool isBoundaryEnabled,
  ) {
    _isAutoCaptureEnabled = enabled;
    _context = context;
    _onAutoCapture = onAutoCapture;
    _isBoundaryEnabled = isBoundaryEnabled;
    if (!enabled) {
      _faceStableStartTime = null;
      _lastFacePositions.clear();
      _countdownSeconds = null;
      _isFaceInBoundary = null;
    }
    notifyListeners();
  }

  Future<void> processImage(InputImage inputImage) async {
    if (inputImage.bytes == null && inputImage.filePath == null) return;

    final now = DateTime.now();
    if (now.difference(_lastDetectionTime) < detectionInterval) return;
    _lastDetectionTime = now;

    final newFaces = await _faceDetector.processImage(inputImage);
    if (_shouldUpdateFaces(newFaces)) {
      _faces = newFaces;
      _isFaceInBoundary =
          _isBoundaryEnabled && newFaces.isNotEmpty
              ? _checkFaceInBoundary(newFaces.first, inputImage.metadata!.size)
              : null;
      notifyListeners();
    }

    if (_isAutoCaptureEnabled && newFaces.length == 1) {
      _checkFaceStability(newFaces, now, inputImage.metadata!.size);
    }
  }

  bool _shouldUpdateFaces(List<Face> newFaces) {
    if (_faces.length != newFaces.length || newFaces.isEmpty) return true;

    for (var i = 0; i < newFaces.length; i++) {
      if (i >= _faces.length ||
          _faces[i].trackingId != newFaces[i].trackingId ||
          !isFacePositionSimilar(_faces[i], newFaces[i])) {
        return true;
      }
    }
    return false;
  }

  bool _checkFaceInBoundary(Face face, Size imageSize) {
    if (!_isBoundaryEnabled) return true;

    final ovalWidth = imageSize.width * 0.8;
    final ovalHeight = imageSize.height * 0.45;
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
      if (_countdownSeconds != null || _isFaceInBoundary == true) {
        _resetAutoCapture();
      }
      return;
    }

    bool allFacesStable = true;
    bool allFacesInBoundary = true; 
    Map<int, Offset> currentFacePositions = {};
    bool needsReset = false; // Introduced flag, initialized to false

    for (var face in newFaces) {
      if (face.trackingId == null) continue;

      final newBox = face.boundingBox;
      final newCenter = Offset(
        newBox.left + newBox.width / 2,
        newBox.top + newBox.height / 2,
      );
      currentFacePositions[face.trackingId!] = newCenter;

      // Boundary Check
      if (_isBoundaryEnabled) {
        if (!_checkFaceInBoundary(face, imageSize)) {
          allFacesInBoundary = false; // A face is out of bounds
          needsReset = true;          // Signal that a reset might be needed
          break;                      // Exit loop: if one face is out, allFacesInBoundary is false
        }
      }

      // Stability Check (only proceeds if face is within boundary or boundary check is off)
      if (_lastFacePositions.containsKey(face.trackingId)) {
        final oldCenter = _lastFacePositions[face.trackingId]!;
        final distance = (oldCenter - newCenter).distance;
        final threshold =
            sqrt(pow(newBox.width, 2) + pow(newBox.height, 2)) * 0.1;
        if (distance > threshold) {
          allFacesStable = false; // A face is unstable
          needsReset = true;      // Signal that a reset might be needed
        }
      } else {
        // New face detected, considered unstable for this frame
        allFacesStable = false;
        needsReset = true; // Signal that a reset might be needed
      }
    }

    // Conditional Reset Call:
    // If needsReset is true (due to instability or out-of-bounds) AND
    // there was an active countdown or the face was marked in bounds (as true).
    if (needsReset && (_countdownSeconds != null || _isFaceInBoundary == true)) {
      _resetAutoCapture();
    }

    // Logic for countdown or further reset:
    if (allFacesStable && allFacesInBoundary) {
      // Only update _lastFacePositions if all faces are stable AND within boundary
      _lastFacePositions = currentFacePositions; 
      _faceStableStartTime ??= now; // Start or continue stability timer

      final elapsedSeconds = now.difference(_faceStableStartTime!).inSeconds;
      final remainingSeconds = 3 - elapsedSeconds;

      if (remainingSeconds <= 0 && _context != null) {
        _onAutoCapture?.call(_context!);
        _resetAutoCapture(); // Reset after successful capture
      } else if (remainingSeconds != _countdownSeconds) {
        _countdownSeconds = remainingSeconds;
        _isFaceInBoundary = true; // Mark face as in boundary for countdown UI
        notifyListeners();
      }
    } else {
      // This 'else' block handles cases where faces are not stable OR not in boundary.
      // If 'needsReset' was false (e.g., very first frame, no movement yet to trigger instability,
      // but all conditions for countdown are not met) AND there's an existing countdown state,
      // then clear that state by calling _resetAutoCapture.
      if (!needsReset && (_countdownSeconds != null || _isFaceInBoundary == true)) {
        _resetAutoCapture();
      }
    }
  }

  void _resetAutoCapture() {
    // Determine if a UI update (notification) is needed BEFORE resetting state.
    bool shouldNotify = _countdownSeconds != null || _isFaceInBoundary == true;

    _countdownSeconds = null;
    _isFaceInBoundary = false;     // Explicitly set to false.
    _faceStableStartTime = null; // Reset the stable start time.

    if (shouldNotify) {
      notifyListeners();
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
    final threshold = sqrt(pow(oldBox.width, 2) + pow(oldBox.height, 2)) * 0.01;

    return distance < threshold;
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }
}
