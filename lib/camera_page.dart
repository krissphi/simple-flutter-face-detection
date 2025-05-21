import 'package:camera_widget/boundary_painter.dart';
import 'package:camera_widget/camera_feature_widget.dart';
import 'package:camera_widget/camera_preview_widget.dart';
import 'package:camera_widget/face_detection_service.dart';
import 'package:camera_widget/face_painter.dart';
import 'package:camera_widget/face_detection_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'camera_controller.dart';
import 'camera_placeholder_widget.dart';

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
    if (!controller.isSupportCamera()) {
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
              child: CustomPaint(
                painter: FacePainter(
                  faces: controller.faces,
                  imageSize: cameraSize,
                  widgetSize: Size(constraints.maxWidth, constraints.maxHeight),
                  lensDirection: cameraController.description.lensDirection,
                ),
              ),
            ),
            if (controller.isBoundaryEnabled)
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
              child: RepaintBoundary(
                child: FaceDetectionStatusWidget(controller: controller),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: CameraFeatureWidget(
                  controller: controller,
                  context: context,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
