import 'dart:io';

import 'package:camera_widget/camera_preview.dart';
import 'package:camera_widget/face_painter_widget.dart';
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
                onPressed: () => controller.setAutoCaptureIn3Seconds(),
                child: const Icon(Icons.timer),
              ),
              ElevatedButton(
                onPressed: () => controller.takePicture(),
                child: const Icon(Icons.camera),
              ),
              ElevatedButton(
                onPressed: () => controller.setAutoCaptureInBoundaryShape(),
                child: const Icon(Icons.square_foot),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
