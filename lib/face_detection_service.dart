import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionService {
  late FaceDetector _faceDetector;
  List<Face> _faces = [];
  DateTime _lastDetectionTime = DateTime.now();
  final Duration detectionInterval = const Duration(milliseconds: 200);

  List<Face> get faces => _faces;

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
        logFaceInfo();
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

  void logFaceInfo() {
    if (_faces.isEmpty) {
      debugPrint('No faces detected');
    } else {
      debugPrint('Detected ${_faces.length} faces');
      for (Face face in _faces) {
        debugPrint('Face detected: ${face.boundingBox}');
        debugPrint('Tracking ID: ${face.trackingId}');
        debugPrint('Smiling probability: ${face.smilingProbability}');
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

  void dispose() {
    _faceDetector.close();
  }
}
