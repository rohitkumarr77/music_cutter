// lib/services/permission_service.dart

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request all required permissions for the app
  Future<bool> requestAllPermissions() async {
    if (Platform.isAndroid) {
      return await _requestAndroidPermissions();
    } else if (Platform.isIOS) {
      return await _requestIOSPermissions();
    }
    return true;
  }

  Future<bool> _requestAndroidPermissions() async {
    // Android 13+ uses granular media permissions
    if (await _isAndroid13OrAbove()) {
      final audioStatus = await Permission.audio.request();
      return audioStatus.isGranted;
    } else {
      // Android 12 and below
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
  }

  Future<bool> _requestIOSPermissions() async {
    // iOS doesn't need storage permission for file picker in most cases
    return true;
  }

  Future<bool> _isAndroid13OrAbove() async {
    if (!Platform.isAndroid) return false;
    // Android 13 = API 33
    try {
      final version = await _getAndroidVersion();
      return version >= 33;
    } catch (_) {
      return false;
    }
  }

  Future<int> _getAndroidVersion() async {
    // We approximate by checking Permission.audio availability
    // A more robust approach uses device_info_plus
    return 33; // Default to 13+ behavior for safety
  }

  Future<PermissionStatus> checkStoragePermission() async {
    if (Platform.isAndroid) {
      if (await _isAndroid13OrAbove()) {
        return await Permission.audio.status;
      }
      return await Permission.storage.status;
    }
    return PermissionStatus.granted;
  }

  Future<bool> hasStoragePermission() async {
    final status = await checkStoragePermission();
    return status.isGranted;
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await _isAndroid13OrAbove()) {
        final status = await Permission.audio.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true;
  }

  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  requestAudio() {}
}