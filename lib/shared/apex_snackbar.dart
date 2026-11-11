import 'package:flutter/material.dart';

/// SnackBar موحد يُستخدم في كل أنحاء التطبيق
class ApexSnackBar {
  ApexSnackBar._();

  /// Material's snackbar on a wide window: centered, 344 to 672 wide. On a
  /// phone (narrower than 600) null keeps the full width with its margins.
  static double? _width(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w < 600 ? null : (w - 48).clamp(344.0, 672.0);
  }

  /// إظهار SnackBar نجاح
  static void success(BuildContext context, String message,
      {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      width: _width(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: duration,
    ));
  }

  /// إظهار SnackBar خطأ
  static void error(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      width: _width(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  /// إظهار SnackBar معلومات عامة
  static void info(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      width: _width(context),
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
