import 'package:flutter/material.dart';

class BoundaryPainter extends CustomPainter {
  final Size widgetSize;
  final bool? isFaceInBoundary;

  BoundaryPainter({required this.widgetSize, this.isFaceInBoundary});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = (isFaceInBoundary == true ? Colors.green : Colors.red)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;

    // Define oval dimensions
    final ovalWidth = widgetSize.width * 0.8;
    final ovalHeight = widgetSize.height * 0.45;
    final left = (widgetSize.width - ovalWidth) / 2;
    final top = (widgetSize.height - ovalHeight) / 2;

    // Draw oval
    final rect = Rect.fromLTWH(left, top, ovalWidth, ovalHeight);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
