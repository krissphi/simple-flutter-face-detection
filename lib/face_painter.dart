import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final Size widgetSize;
  final CameraLensDirection lensDirection;

  FacePainter(this.faces, this.imageSize, this.widgetSize, this.lensDirection);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    for (final face in faces) {
      final rect = face.boundingBox;

      final scaleX = widgetSize.width / imageSize.height;
      final scaleY = widgetSize.height / imageSize.width;

      var scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );

      if (lensDirection == CameraLensDirection.front) {
        scaledRect = Rect.fromLTRB(
          widgetSize.width - scaledRect.right,
          scaledRect.top,
          widgetSize.width - scaledRect.left,
          scaledRect.bottom,
        );
      }

      canvas.drawRect(scaledRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) {
    return faces != oldDelegate.faces ||
        imageSize != oldDelegate.imageSize ||
        widgetSize != oldDelegate.widgetSize;
  }
}
