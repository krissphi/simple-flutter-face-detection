import 'package:camera_widget/camera_service.dart';
import 'package:camera_widget/face_detection_service.dart';
import 'package:camera_widget/permission_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:camera_widget/camera_page.dart';
import 'package:camera_widget/camera_controller.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint(
      'FlutterError: ${details.exceptionAsString()}\n${details.stack}',
    );
  };
  if (kDebugMode) {
    debugRepaintRainbowEnabled = true;
  }
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChangeNotifierProvider(
        create:
            (_) => CameraPageController(
              permissionManager: PermissionManager(),
              cameraService: CameraService(),
              faceDetectionService: FaceDetectionService(),
            ),
        child: Builder(
          builder: (context) {
            final controller = Provider.of<CameraPageController>(
              context,
              listen: false,
            );
            return MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: controller),
                ChangeNotifierProvider.value(
                  value: controller.faceDetectionService,
                ),
              ],
              child: const Scaffold(body: CameraPage()),
            );
          },
        ),
      ),
    );
  }
}
