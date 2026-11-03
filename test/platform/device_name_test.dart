@TestOn('windows || linux')
library;

import 'dart:io';

import 'package:apex_file_share/core/text/device_label.dart';
import 'package:apex_file_share/managers/device_manager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Registers the real Windows/Linux implementations, as the running app does.
  if (Platform.isWindows) {
    DeviceInfoPlusWindowsPlugin.registerWith();
  } else {
    DeviceInfoPlusLinuxPlugin.registerWith();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Owner decision (2026-11-03): a MAC-like hostname ("58-11-22-A8-AB-8E",
  // given by DHCP to a Linux PC with no static name) is not shown; the
  // default name becomes "<user> · <system> · <last 4>".
  final host = Platform.localHostname;
  final macLike = looksLikeMac(host);

  test('the shown host name is this machine\'s name, not the OS name', () async {
    final shown = await DeviceManager.getHostname();
    expect(shown?.toLowerCase(), macLike ? isNull : host.toLowerCase(),
        reason: 'On Linux the code returns the distribution name '
            '("Ubuntu 24.04 LTS"), so every Linux PC shows the same name.');
  });

  test('the default device name tells two machines apart', () async {
    final name = await DeviceManager.getDeviceName('fallback');
    if (macLike) {
      final hex = host.replaceAll(RegExp('[-:]'), '').toUpperCase();
      expect(name, endsWith(' · ${hex.substring(hex.length - 4)}'),
          reason: 'Two PCs of the same user and system differ only here.');
    } else {
      expect(name.toLowerCase(), host.toLowerCase(),
          reason: 'On Linux the default name is the first word of the '
              'distribution ("Ubuntu"), the same on every Ubuntu PC.');
    }
  });
}
