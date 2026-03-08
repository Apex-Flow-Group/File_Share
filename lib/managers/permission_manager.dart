import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static Future<bool> requestAll() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    // طلب الموقع فقط - باقي الصلاحيات تُمنح تلقائياً
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static Future<bool> isLocationServiceEnabled() async {
    if (!Platform.isAndroid) {
      return true;
    }
    
    try {
      final locationService = await Permission.location.serviceStatus;
      return locationService.isEnabled;
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> checkRequirements() async {
    if (!Platform.isAndroid) {
      return [];
    }

    final issues = <String>[];

    final location = await Permission.location.status;
    final bluetooth = await Permission.bluetoothScan.status;
    final nearby = await Permission.nearbyWifiDevices.status;

    if (!location.isGranted) {
      issues.add('• صلاحية الموقع');
    }
    if (!bluetooth.isGranted) {
      issues.add('• صلاحية البلوتوث');
    }
    if (!nearby.isGranted) {
      issues.add('• صلاحية الأجهزة القريبة');
    }

    final locationEnabled = await isLocationServiceEnabled();
    if (!locationEnabled) {
      issues.add('• خدمة الموقع (GPS) مطفأة');
    }

    return issues;
  }
}
