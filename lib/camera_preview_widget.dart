import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;

  const CameraPreviewWidget({super.key, required this.cameraController});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth * cameraController.value.aspectRatio,
              child: CameraPreview(cameraController),
            ),
          ),
        );
      },
    );
  }
}
