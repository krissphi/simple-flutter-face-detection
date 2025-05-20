import 'package:camera_widget/camera_service.dart';
import 'package:camera_widget/face_detection_service.dart';
import 'package:camera_widget/permission_manager.dart';
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
  debugRepaintRainbowEnabled = true;
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create:
            (_) => CameraPageController(
              permissionManager: PermissionManager(),
              cameraService: CameraService(),
              faceDetectionService: FaceDetectionService(),
            ),
        child: const Scaffold(body: CameraPage()),
      ),
    );
  }
}
