import 'package:camera_widget/camera_controller.dart';
import 'package:flutter/material.dart';

class CameraFeatureWidget extends StatelessWidget {
  final CameraPageController controller;
  final BuildContext context;

  const CameraFeatureWidget({
    super.key,
    required this.controller,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: () => controller.toggleAutoCapture(context),
                child: Icon(
                  controller.isAutoCapture ? Icons.timer : Icons.timer_off,
                ),
              ),
              ElevatedButton(
                onPressed: () => controller.onTakePhotoPressed(context),
                child: const Icon(Icons.camera),
              ),
              ElevatedButton(
                onPressed: () => controller.toggleBoundary(context),
                child: Icon(
                  controller.isBoundaryEnabled ? Icons.grid_on_outlined : Icons.grid_on,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}