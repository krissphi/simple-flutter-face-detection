import 'package:flutter/material.dart';

class BoundaryPainter extends CustomPainter {
  final Size widgetSize;

  BoundaryPainter({required this.widgetSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // Define boundary (60% of widget size, centered)
    final boundaryWidth = widgetSize.width * 0.6;
    final boundaryHeight = widgetSize.height * 0.6;
    final boundaryLeft = (widgetSize.width - boundaryWidth) / 2;
    final boundaryTop = (widgetSize.height - boundaryHeight) / 2;

    final rect = Rect.fromLTWH(
      boundaryLeft,
      boundaryTop,
      boundaryWidth,
      boundaryHeight,
    );

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}