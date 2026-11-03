import 'package:flutter/material.dart';

import '../models/device.dart';

/// One icon and color per device type, for the phone and the TV cards alike.
IconData deviceIcon(Device device) {
  switch (device.type.toLowerCase()) {
    case 'tv':
      return Icons.tv_rounded;
    case 'desktop':
      return Icons.computer_rounded;
    case 'tablet':
      return Icons.tablet_rounded;
    default:
      return Icons.smartphone_rounded;
  }
}

Color deviceColor(Device device) {
  switch (device.type.toLowerCase()) {
    case 'tv':
      return const Color(0xFF5856D6);
    case 'desktop':
      return const Color(0xFF007AFF);
    case 'tablet':
      return const Color(0xFFFF9500);
    default:
      return const Color(0xFF34C759);
  }
}
