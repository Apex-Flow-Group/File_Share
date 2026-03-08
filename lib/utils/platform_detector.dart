import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class PlatformDetector {
  static final PlatformDetector _instance = PlatformDetector._();
  static PlatformDetector get instance => _instance;
  
  PlatformDetector._();
  
  bool _isTV = false;
  bool _initialized = false;
  
  bool get isTV => _isTV;
  bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS) && !_isTV;
  bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  bool get isWeb => kIsWeb;
  
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        
        _isTV = androidInfo.systemFeatures.contains('android.software.leanback') ||
                androidInfo.systemFeatures.contains('android.hardware.type.television');
      } catch (e) {
        _isTV = false;
      }
    }
    
    _initialized = true;
  }
}
