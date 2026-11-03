part of 'nearby_transfer.dart';

/// Send-related methods for [NearbyTransfer].
extension NearbyTransferSend on NearbyTransfer {
  /// One offer for the whole batch, then each file announced with the token
  /// the receiver issued when its user accepted.
  Future<SendOutcome> sendBatch(List<OutgoingFile> files, Device target) async {
    if (files.isEmpty) {
      return SendOutcome.failed;
    }
    final endpointId = target.endpointId!;
    final progress = TransferProgressService()
      ..startBatch(files.length, targetDeviceId: target.id);
    try {
      if (!connectedEndpoints.contains(endpointId) &&
          !await connect(endpointId, target.name)) {
        ApexLogger.instance.log('NEARBY', '❌ Connection failed', LogLevel.error);
        return SendOutcome.failed;
      }
      final answer = await _offer(endpointId, files);
      if (answer == null) {
        return SendOutcome.failed;
      }
      if (answer['error'] == ApexProtocol.updateRequired) {
        return SendOutcome.updateRequired;
      }
      if (answer['accepted'] != true) {
        return SendOutcome.declined;
      }
      final tokens = answer['tokens'];
      if (tokens is! List || tokens.length != files.length || tokens.any((t) => t is! String)) {
        return SendOutcome.failed;
      }
      var allSent = true;
      for (var i = 0; i < files.length; i++) {
        if (progress.isCancelled) {
          return SendOutcome.cancelled;
        }
        allSent = await _sendFilePayload(endpointId, files[i], tokens[i] as String, progress) &&
            allSent;
        progress.nextFile();
      }
      if (progress.isCancelled) {
        return SendOutcome.cancelled;
      }
      return allSent ? SendOutcome.sent : SendOutcome.failed;
    } finally {
      progress.clearProgress();
    }
  }

  Future<bool> _sendFilePayload(
    String endpointId,
    OutgoingFile file,
    String token,
    TransferProgressService progress,
  ) async {
    try {
      final startTime = DateTime.now();
      progress.updateProgress(TransferProgress(
        fileName: file.name,
        totalBytes: file.size,
        transferredBytes: 0,
        status: TransferStatus.transferring,
        startTime: startTime,
      ));

      final completer = Completer<bool>();
      final payloadId = await Nearby().sendFilePayload(endpointId, file.path);
      _transferCallbacks[payloadId] = (update) {
        progress.updateProgress(TransferProgress(
          fileName: file.name,
          totalBytes: file.size,
          transferredBytes: update.bytesTransferred,
          status: TransferStatus.transferring,
          startTime: startTime,
        ));
        if (update.status == PayloadStatus.SUCCESS) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        } else if (update.status == PayloadStatus.FAILURE ||
            update.status == PayloadStatus.CANCELED) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        }
      };
      await _sendJson(endpointId,
          {'type': NearbyMessage.file, 'token': token, 'payload_id': payloadId});

      final timeoutSecs = ((file.size / (50 * 1024)) + 60).ceil();
      final ok = await completer.future
          .timeout(Duration(seconds: timeoutSecs), onTimeout: () => false);

      _transferCallbacks.remove(payloadId);
      ApexLogger.instance.log(
          'NEARBY',
          ok ? '✅ Sent: ${file.name}' : '❌ Failed: ${file.name}',
          ok ? LogLevel.success : LogLevel.error);
      return ok;
    } catch (e) {
      ApexLogger.instance.log('NEARBY', '❌ Send error: $e', LogLevel.error);
      return false;
    }
  }

  /// The receiver's answer, or null when it never came.
  Future<Map?> _offer(String endpointId, List<OutgoingFile> files) async {
    final completer = Completer<Map>();
    _pendingRequests[endpointId] = completer;
    try {
      await _sendJson(endpointId, {
        'type': NearbyMessage.offer,
        'version': ApexProtocol.version,
        'name': getLocalName() ?? '',
        'files': [for (final f in files) {'name': f.name, 'size': f.size}],
      });
      return await completer.future
          .timeout(TransferRules.decisionTimeout + const Duration(seconds: 10));
    } catch (e) {
      ApexLogger.instance.log('NEARBY', 'Offer failed: $e', LogLevel.error);
      return null;
    } finally {
      _pendingRequests.remove(endpointId);
    }
  }
}
