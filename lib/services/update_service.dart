import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import 'transfer_progress_service.dart';

/// يدير دورة حياة In-App Update مع مراعاة حالة الإرسال/الاستقبال
class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  // هل التحديث جُمِّع وجاهز للتثبيت؟
  bool _updateDownloaded = false;
  bool get updateDownloaded => _updateDownloaded;

  // هل يوجد تحديث متاح للتحميل؟
  bool _updateAvailable = false;
  bool get updateAvailable => _updateAvailable;

  // Stream لإخطار الـ UI بالتغييرات
  final _stateController = StreamController<UpdateState>.broadcast();
  Stream<UpdateState> get stateStream => _stateController.stream;

  UpdateState _state = UpdateState.idle;
  UpdateState get state => _state;

  // هل التطبيق مشغول بإرسال أو استقبال؟
  bool get _isBusy => TransferProgressService().isTransferring;

  /// يتحقق من وجود تحديث عند فتح التطبيق
  Future<void> checkForUpdate() async {
    // In-App Update متاح على Android فقط
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        _updateAvailable = true;
        _emit(UpdateState.available);
      }
    } catch (_) {
      // Play Store غير متاح أو لا يوجد اتصال — نتجاهل بصمت
    }
  }

  /// يبدأ تحميل التحديث في الخلفية (Flexible)
  Future<void> startFlexibleDownload() async {
    if (!_updateAvailable) {
      return;
    }
    try {
      _emit(UpdateState.downloading);
      await InAppUpdate.startFlexibleUpdate();
      // التحميل اكتمل
      _updateDownloaded = true;
      _updateAvailable = false;
      // إذا التطبيق مشغول الآن، ننتظر حتى يفرغ
      if (_isBusy) {
        _emit(UpdateState.waitingForIdle);
        _waitForIdle();
      } else {
        _emit(UpdateState.readyToInstall);
      }
    } catch (_) {
      _emit(UpdateState.idle);
    }
  }

  /// ينتظر انتهاء الإرسال/الاستقبال ثم يُخطر الـ UI
  void _waitForIdle() {
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isBusy) {
        timer.cancel();
        if (_updateDownloaded) {
          _emit(UpdateState.readyToInstall);
        }
      }
    });
  }

  /// يُثبّت التحديث — يُستدعى فقط عند موافقة المستخدم وعدم الانشغال
  Future<void> completeUpdate() async {
    if (!_updateDownloaded) {
      return;
    }
    // حماية إضافية: لا تُثبّت أثناء إرسال
    if (_isBusy) {
      _emit(UpdateState.waitingForIdle);
      _waitForIdle();
      return;
    }
    try {
      await InAppUpdate.completeFlexibleUpdate();
      _updateDownloaded = false;
      _emit(UpdateState.idle);
    } catch (_) {
      _emit(UpdateState.idle);
    }
  }

  /// يُستدعى عند عودة التطبيق من الخلفية
  /// يتحقق إذا كان التحديث جاهزاً وينتظر إذا كان مشغولاً
  void onAppResumed() {
    if (!_updateDownloaded) {
      return;
    }
    if (_isBusy) {
      _emit(UpdateState.waitingForIdle);
      _waitForIdle();
    } else {
      _emit(UpdateState.readyToInstall);
    }
  }

  void _emit(UpdateState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    _stateController.close();
  }
}

enum UpdateState {
  idle, // لا شيء
  available, // يوجد تحديث — انتظر أمر التحميل
  downloading, // يُحمَّل الآن
  waitingForIdle, // جاهز لكن التطبيق مشغول
  readyToInstall, // جاهز للتثبيت
}
