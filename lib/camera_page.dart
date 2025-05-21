import 'dart:io';

import 'package:camera_widget/boundary_painter.dart';
import 'package:camera_widget/camera_preview.dart';
import 'package:camera_widget/face_detection_service.dart';
import 'package:camera_widget/face_painter_widget.dart';
import 'package:camera_widget/image_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'camera_controller.dart';
import 'camera_placeholder.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  late final CameraPageController controller =
      Provider.of<CameraPageController>(context, listen: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.initialize();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      controller.checkPermissionAndInitialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraPageController>(
      builder: (context, controller, child) {
        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildWidget(controller),
          ),
        );
      },
    );
  }

  Widget _buildWidget(CameraPageController controller) {
    debugPrint(
      controller.isAutoCapture
          ? 'Auto capture in 3 seconds enabled'
          : 'Auto capture in 3 seconds disabled',
    );

    if (!_isCameraSupported()) {
      return const Center(child: Text("Camera not supported on this platform"));
    }

    if (!controller.isCameraGranted && !controller.isLoading) {
      return const CameraPermissionPlaceholder();
    }

    if (controller.isLoading ||
        !controller.isInitialized ||
        controller.cameraController == null) {
      return Container(color: Colors.black);
    }

    return _buildCameraPreview();
  }

  bool _isCameraSupported() {
    return kIsWeb ? false : (Platform.isAndroid || Platform.isIOS);
  }

  Widget _buildCameraPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cameraController = controller.cameraController!;
        final cameraSize = cameraController.value.previewSize;
        if (cameraSize == null) {
          return const SizedBox();
        }

        return Stack(
          children: [
            RepaintBoundary(
              child: CameraPreviewWidget(cameraController: cameraController),
            ),
            RepaintBoundary(
              child: FacePainterWidget(
                faces: controller.faces,
                imageSize: cameraSize,
                widgetSize: Size(constraints.maxWidth, constraints.maxHeight),
                lensDirection: cameraController.description.lensDirection,
              ),
            ),
            if (controller.isAutoCaptureInBoundaryShape)
              Positioned(
                child: CustomPaint(
                  painter: BoundaryPainter(
                    widgetSize: Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    ),
                    isFaceInBoundary:
                        Provider.of<FaceDetectionService>(
                          context,
                        ).isFaceInBoundary,
                  ),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: RepaintBoundary(child: _buildAutoCaptureText()),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(child: _buildCameraFeature()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAutoCaptureText() {
    return Consumer<FaceDetectionService>(
      builder: (context, faceDetectionService, child) {
        debugPrint('Countdown: ${faceDetectionService.countdownSeconds}');
        debugPrint('Faces: ${faceDetectionService.faces}');
        debugPrint('Faces detected: ${faceDetectionService.faces.isNotEmpty}');
        debugPrint(
          'Face in boundary: ${faceDetectionService.isFaceInBoundary}',
        );
        return Column(
          children: [
            // Always show face detection status
            Text(
              faceDetectionService.faces.isNotEmpty
                  ? 'Face Detected'
                  : 'Face Not Detected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                backgroundColor: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            // Show boundary status when boundary mode is enabled
            if (controller.isAutoCaptureInBoundaryShape &&
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
            // Show countdown when auto-capture is active
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
        );
      },
    );
  }

  Widget _buildCameraFeature() {
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
                onPressed: () => controller.toggleAutoCaptureInBoundaryShape(),
                child: Icon(
                  controller.isAutoCaptureInBoundaryShape
                      ? Icons.grid_on_outlined
                      : Icons.grid_on,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
