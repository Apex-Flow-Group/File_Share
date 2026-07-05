import 'package:flutter/material.dart';

/// SnackBar موحد يُستخدم في كل أنحاء التطبيق
class ApexSnackBar {
  ApexSnackBar._();

  /// إظهار SnackBar نجاح
  static void success(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  /// إظهار SnackBar خطأ
  static void error(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  /// إظهار SnackBar معلومات عامة
  static void info(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  /// إظهار SnackBar بنتيجة عملية (نجاح أو فشل)
  static void result(
    BuildContext context, {
    required bool ok,
    required String successMessage,
    required String failMessage,
  }) {
    if (ok) {
      success(context, successMessage);
    } else {
      error(context, failMessage);
    }
  }
}
