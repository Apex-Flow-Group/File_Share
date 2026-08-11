part of 'nearby_transfer.dart';

/// Send-related methods for [NearbyTransfer].
extension NearbyTransferSend on NearbyTransfer {
  Future<bool> sendFile(String filePath, String fileName, Device target) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }

    final fileSize = await file.length();
    final endpointId = target.endpointId!;
    final progress = TransferProgressService();
    progress.startBatch(1, targetDeviceId: target.id);

    if (!connectedEndpoints.contains(endpointId)) {
      if (!await connect(endpointId, target.name)) {
        ApexLogger.instance
            .log('NEARBY', '❌ Connection failed', LogLevel.error);
        progress.clearProgress();
        return false;
      }
    }

    final accepted =
        await _requestPermission(endpointId, fileName, fileSize, target.name);
    if (!accepted) {
      ApexLogger.instance.log('NEARBY', '❌ Rejected', LogLevel.warning);
      progress.clearProgress();
      return false;
    }

    try {
      return await _sendFilePayload(
          endpointId, filePath, fileName, fileSize, progress);
    } finally {
      progress.clearProgress();
    }
  }

  Future<bool> sendBatchFiles(
    List<({String path, String name, int size})> files,
    Device target,
  ) async {
    if (files.isEmpty) {
      return false;
    }

    final endpointId = target.endpointId!;
    final progress = TransferProgressService();
    progress.startBatch(files.length, targetDeviceId: target.id);

    if (!connectedEndpoints.contains(endpointId)) {
      if (!await connect(endpointId, target.name)) {
        ApexLogger.instance
            .log('NEARBY', '❌ Connection failed', LogLevel.error);
        progress.clearProgress();
        return false;
      }
    }

    final accepted =
        await _requestBatchPermission(endpointId, files, target.name);
    if (!accepted) {
      ApexLogger.instance.log('NEARBY', '❌ Batch rejected', LogLevel.warning);
      progress.clearProgress();
      return false;
    }

    try {
      int success = 0;
      for (final f in files) {
        if (progress.isCancelled) {
          break;
        }
        if (await _sendFilePayload(
            endpointId, f.path, f.name, f.size, progress)) {
          success++;
        }
        progress.nextFile();
      }
      return success == files.length;
    } finally {
      progress.clearProgress();
    }
  }

  Future<bool> _sendFilePayload(
    String endpointId,
    String filePath,
    String fileName,
    int fileSize,
    TransferProgressService progress,
  ) async {
    try {
      final startTime = DateTime.now();
      progress.updateProgress(TransferProgress(
        fileName: fileName,
        totalBytes: fileSize,
        transferredBytes: 0,
        status: TransferStatus.transferring,
        startTime: startTime,
      ));

      final completer = Completer<bool>();
      final payloadId = await Nearby().sendFilePayload(endpointId, filePath);

      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(jsonEncode({
          'type': 'file_name',
          'name': fileName,
          'payload_id': payloadId,
          'size': fileSize,
        }))),
      );

      _transferCallbacks[payloadId] = (update) {
        progress.updateProgress(TransferProgress(
          fileName: fileName,
          totalBytes: fileSize,
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

      final timeoutSecs = ((fileSize / (50 * 1024)) + 60).ceil();
      final ok = await completer.future
          .timeout(Duration(seconds: timeoutSecs), onTimeout: () => false);

      _transferCallbacks.remove(payloadId);
      ApexLogger.instance.log(
          'NEARBY',
          ok ? '✅ Sent: $fileName' : '❌ Failed: $fileName',
          ok ? LogLevel.success : LogLevel.error);
      return ok;
    } catch (e) {
      ApexLogger.instance.log('NEARBY', '❌ Send error: $e', LogLevel.error);
      return false;
    }
  }

  Future<bool> _requestPermission(String endpointId, String fileName,
      int fileSize, String senderName) async {
    final completer = Completer<bool>();
    _pendingRequests[endpointId] = completer;
    try {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(jsonEncode({
          'type': 'request',
          'name': fileName,
          'size': fileSize,
          'from': senderName,
        }))),
      );
    } catch (e) {
      _pendingRequests.remove(endpointId);
      return false;
    }
    return completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
      _pendingRequests.remove(endpointId);
      return false;
    });
  }

  Future<bool> _requestBatchPermission(
    String endpointId,
    List<({String path, String name, int size})> files,
    String senderName,
  ) async {
    final completer = Completer<bool>();
    _pendingRequests[endpointId] = completer;
    try {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(jsonEncode({
          'type': 'batch_request',
          'from': senderName,
          'total': files.length,
          'names': files.map((f) => f.name).toList(),
          'sizes': files.map((f) => f.size).toList(),
          'totalSize': files.fold<int>(0, (s, f) => s + f.size),
        }))),
      );
    } catch (e) {
      _pendingRequests.remove(endpointId);
      return false;
    }
    return completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
      _pendingRequests.remove(endpointId);
      return false;
    });
  }
}
