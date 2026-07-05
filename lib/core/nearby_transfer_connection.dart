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
          connectedEndpoints.remove(eid);
          _pendingRequests.remove(eid)?.complete(false);
          _connectCompleters.remove(eid)?.complete(false);
        },
      );
    } catch (e) {
      _connectCompleters.remove(endpointId)?.complete(false);
      return false;
    }
    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      _connectCompleters.remove(endpointId);
      return false;
    });
  }

  Future<void> acceptConnection(String endpointId) async {
    await Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: onPayloadReceived,
      onPayloadTransferUpdate: (_, update) {
        _transferCallbacks[update.id]?.call(update);
      },
    );
    connectedEndpoints.add(endpointId);
  }

  Future<void> stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
  }
}
