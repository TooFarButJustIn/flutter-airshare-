import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static Future<bool> requestPermissions() async {
    final permissions = [
      Permission.storage,
      Permission.camera,
      Permission.microphone,
      Permission.location,
      Permission.nearbyWifiDevices,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every((status) =>
        status == PermissionStatus.granted ||
        status == PermissionStatus.limited);
  }

  static Future<bool> hasStoragePermission() async {
    return await Permission.storage.isGranted;
  }

  static Future<bool> hasLocationPermission() async {
    return await Permission.location.isGranted;
  }
}
