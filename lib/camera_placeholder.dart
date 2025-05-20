import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPermissionPlaceholder extends StatelessWidget {
  const CameraPermissionPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              'Camera Not Available',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            //Text button
            TextButton(
              onPressed: () {
                openAppSettings();
              },
              child: Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
