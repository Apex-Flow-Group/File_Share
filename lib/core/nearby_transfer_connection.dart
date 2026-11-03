part of 'nearby_transfer.dart';

/// Connection management methods for [NearbyTransfer].
extension NearbyTransferConnection on NearbyTransfer {
  Future<bool> connect(String endpointId, String remoteName) async {
    final completer = Completer<bool>();
    _connectCompleters[endpointId] = completer;
    try {
      await Nearby().requestConnection(
        getLocalName() ?? 'Apex',
        endpointId,
        onConnectionInitiated: (eid, info) async {
          await Nearby().acceptConnection(
            eid,
            onPayLoadRecieved: onPayloadReceived,
            onPayloadTransferUpdate: (_, update) {
              _transferCallbacks[update.id]?.call(update);
            },
          );
        },
        onConnectionResult: (eid, status) {
          final c = _connectCompleters.remove(eid);
          if (status == Status.CONNECTED) {
            connectedEndpoints.add(eid);
            c?.complete(true);
          } else {
            c?.complete(false);
          }
        },
        onDisconnected: (eid) {
          forget(eid);
          _pendingRequests.remove(eid)?.completeError(StateError('disconnected'));
          _connectCompleters.remove(eid)?.complete(false);
        },
      );
    } catch (e) {
      _connectCompleters.remove(endpointId)?.complete(false);
      return false;
    }
    // The other phone asks its user before it accepts.
    return completer.future.timeout(TransferRules.decisionTimeout + const Duration(seconds: 10),
        onTimeout: () {
      _connectCompleters.remove(endpointId);
      return false;
    });
  }

  /// A phone asks to connect to us: accepted only when the user agrees.
  Future<bool> answerConnection(String endpointId, String endpointName) async {
    if (!await door.mayConnect(endpointId, endpointName)) {
      try {
        await Nearby().rejectConnection(endpointId);
      } catch (_) {}
      return false;
    }
    await Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: onPayloadReceived,
      onPayloadTransferUpdate: (_, update) {
        _transferCallbacks[update.id]?.call(update);
      },
    );
    connectedEndpoints.add(endpointId);
    return true;
  }

  void forget(String endpointId) {
    connectedEndpoints.remove(endpointId);
    door.forget(endpointId);
  }

  Future<void> stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
  }
}
