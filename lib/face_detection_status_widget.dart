import 'package:camera_widget/camera_controller.dart';
import 'package:camera_widget/face_detection_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FaceDetectionStatusWidget extends StatelessWidget {
  final CameraPageController controller;

  const FaceDetectionStatusWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Consumer<FaceDetectionService>(
      builder: (context, faceDetectionService, child) {
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            children: [
              Text(
                faceDetectionService.faces.isNotEmpty
                    ? 'Faces Detected: ${faceDetectionService.faces.length}'
                    : 'No Faces Detected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              if (controller.isBoundaryEnabled &&
                  faceDetectionService.faces.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    faceDetectionService.isFaceInBoundary == true
                        ? 'Inside Boundary'
                        : 'Outside Boundary',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      backgroundColor: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (controller.isAutoCapture &&
                  faceDetectionService.countdownSeconds != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Don\'t Move: ${faceDetectionService.countdownSeconds}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      backgroundColor: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
