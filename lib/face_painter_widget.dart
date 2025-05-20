import 'package:camera/camera.dart';
import 'package:camera_widget/face_painter.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainterWidget extends StatelessWidget {
  final List<Face> faces;
  final Size imageSize;
  final Size widgetSize;
  final CameraLensDirection lensDirection;

  const FacePainterWidget({
    super.key,
    required this.faces,
    required this.imageSize,
    required this.widgetSize,
    required this.lensDirection,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FacePainter(
        faces,
        imageSize,
        widgetSize,
        lensDirection,
      ),
    );
  }
}
