import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../features/receive/logic/nearby_door.dart';
import '../features/send/data/send_http.dart' show OutgoingFile, SendOutcome;
import '../models/device.dart';
import '../models/transfer_progress.dart';
import '../services/transfer_progress_service.dart';
import '../utils/apex_logger.dart';
import '../utils/path_utils.dart';
import 'core_models.dart';
import 'one_question.dart';
import 'protocol/apex_protocol.dart';
import 'protocol/nearby_messages.dart';
import 'protocol/transfer_rules.dart';

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

  /// Moves a fully received temp file to where the user finds it.
  final Future<String> Function(File temp, String name) place;

  final Map<String, Completer<bool>> _connectCompleters = {};

  /// Answers to our own offers, per endpoint.
  final Map<String, Completer<Map>> _pendingRequests = {};
  final Map<int, void Function(PayloadTransferUpdate)> _transferCallbacks = {};
  final Set<String> connectedEndpoints = {};
  final Map<String, Device> discoveredDevices;
  final _random = Random();

  static const _nearbyChannel = MethodChannel('com.apex.core/nearby');

  late final NearbyDoor door = NearbyDoor(
    onConnectionRequest: onConnectionRequest,
    send: _sendJson,
    question: question,
    onAdmitted: (offer) => TransferProgressService().startReceive(
        senderDeviceName: offer.senderName, totalFiles: offer.files.length),
  );

  NearbyTransfer({
    required this.getLocalName,
    required this.onFileReceived,
    required this.onConnectionRequest,
    required this.place,
    required this.discoveredDevices,
    this.question,
  });

  /// Shared with the other doors, so two questions never stack.
  final OneQuestion? question;

  Future<void> _sendJson(String endpointId, Map<String, Object?> msg) =>
      Nearby().sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(jsonEncode(msg))));
}
