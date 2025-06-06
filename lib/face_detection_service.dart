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
      _resetAutoCapture();
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

      if (_isBoundaryEnabled && !_checkFaceInBoundary(face, imageSize)) {
        allFacesInBoundary = false;
        _resetAutoCapture();
        break;
      }

      if (_lastFacePositions.containsKey(face.trackingId)) {
        final oldCenter = _lastFacePositions[face.trackingId]!;
        final distance = (oldCenter - newCenter).distance;
        final threshold =
            sqrt(pow(newBox.width, 2) + pow(newBox.height, 2)) * 0.1;

        if (distance > threshold) {
          allFacesStable = false;
          _resetAutoCapture();
        }
      } else {
        allFacesStable = false;
        _resetAutoCapture();
      }
    }

    _lastFacePositions = currentFacePositions;

    if (allFacesStable && allFacesInBoundary) {
      _faceStableStartTime ??= now;
      final elapsedSeconds = now.difference(_faceStableStartTime!).inSeconds;
      final remainingSeconds = 3 - elapsedSeconds;

      if (remainingSeconds <= 0 && _context != null) {
        _onAutoCapture?.call(_context!);
        _resetAutoCapture();
      } else if (remainingSeconds != _countdownSeconds) {
        _countdownSeconds = remainingSeconds;
        _isFaceInBoundary = true;
        notifyListeners();
      }
    } else {
      _resetAutoCapture();
    }
  }

  void _resetAutoCapture() {
    if (_countdownSeconds != null || _isFaceInBoundary != false) {
      _countdownSeconds = null;
      _isFaceInBoundary = false;
      notifyListeners();
    }
    _faceStableStartTime = null;
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
