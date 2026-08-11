import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';

import '../models/device.dart';
import '../models/transfer_progress.dart';
import '../services/transfer_progress_service.dart';
import '../utils/apex_logger.dart';
import '../utils/path_utils.dart';
import '../utils/platform_detector.dart';
import 'core_models.dart';

part 'nearby_transfer_send.dart';
part 'nearby_transfer_receive.dart';
part 'nearby_transfer_connection.dart';

/// Manages Nearby Connections: send, receive, and connection lifecycle.
///
/// Implementation split into parts:
/// - [nearby_transfer_send.dart]: File sending logic
/// - [nearby_transfer_receive.dart]: File receiving & payload handling
/// - [nearby_transfer_connection.dart]: Connection management
class NearbyTransfer {
  final String? Function() getLocalName;
  final void Function(FileReceivedEvent) onFileReceived;
  final void Function(ConnectionRequest) onConnectionRequest;

  final Map<String, Completer<bool>> _connectCompleters = {};
  final Map<String, Completer<bool>> _pendingRequests = {};
  final Map<int, String> _pendingFileNames = {};
  final Map<int, void Function(PayloadTransferUpdate)> _transferCallbacks = {};
  final Set<String> connectedEndpoints = {};
  final Map<String, Device> discoveredDevices;

  static const _nearbyChannel = MethodChannel('com.apex.core/nearby');

  NearbyTransfer({
    required this.getLocalName,
    required this.onFileReceived,
    required this.onConnectionRequest,
    required this.discoveredDevices,
  });
}
