import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  Future<bool> requestPermission({required Permission permission}) async {
    var status = await permission.status;

    if (status.isDenied) {
      status = await permission.request();
    }

    if (status.isPermanentlyDenied) {
      debugPrint('Permission permanently denied');
      return false;
    }

    final isGranted = status.isGranted;
    debugPrint('Permission ${isGranted ? 'granted' : 'denied'}');
    return isGranted;
  }

  Future<bool> requestPermissionWithSettings() => openAppSettings();
}
