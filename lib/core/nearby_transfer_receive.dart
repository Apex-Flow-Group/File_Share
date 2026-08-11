part of 'nearby_transfer.dart';

/// Receive-related methods for [NearbyTransfer].
extension NearbyTransferReceive on NearbyTransfer {
  static final Map<int, String> _pendingReceiveNames = {};
  static final Map<int, int> _pendingReceiveSizes = {};

  void onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.FILE) {
      _handleFilePayload(endpointId, payload);
      return;
    }

    if (payload.type != PayloadType.BYTES) {
      return;
    }
    final bytes = payload.bytes!;

    try {
      final msg = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      switch (msg['type'] as String?) {
        case 'request':
          await _handleTransferRequest(endpointId, msg);
        case 'batch_request':
          await _handleBatchTransferRequest(endpointId, msg);
        case 'response':
          _pendingRequests
              .remove(endpointId)
              ?.complete(msg['accepted'] as bool? ?? false);
        case 'file_name':
          final pid = (msg['payload_id'] as num?)?.toInt();
          final name = msg['name'] as String?;
          final size = (msg['size'] as num?)?.toInt() ?? 0;
          if (pid != null && name != null) {
            _pendingFileNames[pid] = name;
            _pendingReceiveNames[pid] = name;
            if (size > 0) {
              _pendingReceiveSizes[pid] = size;
            }
          }
      }
    } catch (e) {
      ApexLogger.instance.log('NEARBY', 'Parse error: $e', LogLevel.error);
    }
  }

  void onPayloadTransferUpdate(
      String endpointId, PayloadTransferUpdate update) {
    _transferCallbacks[update.id]?.call(update);
  }

  void _handleFilePayload(String endpointId, Payload payload) async {
    final device = discoveredDevices[endpointId];
    ApexLogger.instance.log(
        'NEARBY',
        '📥 FILE payload | id=${payload.id} | endpoint=$endpointId | device=${device?.name ?? "unknown"}',
        LogLevel.info);

    final pendingName = _pendingFileNames.remove(payload.id) ??
        _pendingReceiveNames.remove(payload.id);
    final pendingSize = _pendingReceiveSizes.remove(payload.id) ?? 0;
    final fileName = _sanitize(pendingName ?? 'file_${payload.id}');
    ApexLogger.instance.log(
        'NEARBY',
        '📄 fileName=$fileName | pendingName=$pendingName | pendingSize=$pendingSize',
        LogLevel.info);

    final progress = TransferProgressService();
    final startTime = DateTime.now();

    if (pendingSize > 0) {
      progress.startReceive(senderDeviceName: device?.name ?? endpointId);
      progress.updateProgress(TransferProgress(
        fileName: fileName,
        totalBytes: pendingSize,
        transferredBytes: 0,
        status: TransferStatus.transferring,
        startTime: startTime,
      ));
    }

    _transferCallbacks[payload.id] = (update) async {
      if (update.status != PayloadStatus.SUCCESS &&
          update.status != PayloadStatus.FAILURE &&
          update.status != PayloadStatus.CANCELED) {
        if (pendingSize > 0) {
          progress.updateProgress(TransferProgress(
            fileName: fileName,
            totalBytes: pendingSize,
            transferredBytes: update.bytesTransferred,
            status: TransferStatus.transferring,
            startTime: startTime,
          ));
        }
        return;
      }

      _transferCallbacks.remove(payload.id);
      ApexLogger.instance.log(
          'NEARBY',
          '🏁 Transfer done | status=${update.status} | fileName=$fileName | bytes=${update.bytesTransferred}',
          LogLevel.info);

      if (update.status != PayloadStatus.SUCCESS) {
        progress.clearProgress();
        ApexLogger.instance.log(
            'NEARBY', '❌ Receive failed/cancelled: $fileName', LogLevel.error);
        return;
      }

      // ignore: deprecated_member_use
      final rawUri = payload.uri;
      // ignore: deprecated_member_use
      final rawPath = payload.filePath;
      ApexLogger.instance.log('NEARBY',
          '📂 payload.uri=$rawUri | payload.filePath=$rawPath', LogLevel.info);

      String? tmpPath;

      if (rawUri != null) {
        final uri = Uri.tryParse(rawUri);
        if (uri != null && uri.scheme == 'file') {
          tmpPath = uri.toFilePath();
        } else if (uri != null && uri.scheme == 'content') {
          try {
            final cacheDir = await getTemporaryDirectory();
            final tmpFile = '${cacheDir.path}/nearby_tmp_${payload.id}';
            ApexLogger.instance.log(
                'NEARBY',
                '📋 Copying via ContentResolver: $rawUri → $tmpFile',
                LogLevel.info);
            final result =
                await NearbyTransfer._nearbyChannel.invokeMethod<String>(
              'copyContentUri',
              {'uri': rawUri, 'destPath': tmpFile},
            );
            if (result != null && await File(result).exists()) {
              tmpPath = result;
              ApexLogger.instance.log('NEARBY',
                  '✅ ContentResolver copy OK: $tmpPath', LogLevel.success);
            } else {
              ApexLogger.instance.log(
                  'NEARBY',
                  '❌ ContentResolver returned null or file missing',
                  LogLevel.error);
            }
          } catch (e) {
            ApexLogger.instance
                .log('NEARBY', '❌ ContentResolver failed: $e', LogLevel.error);
          }
        }
      }

      // Fallback for Android <10
      tmpPath ??= rawPath;

      ApexLogger.instance.log('NEARBY', '📂 tmpPath=$tmpPath', LogLevel.info);

      if (tmpPath == null) {
        progress.clearProgress();
        ApexLogger.instance.log('NEARBY', '❌ tmpPath is null!', LogLevel.error);
        return;
      }

      try {
        final destDir = await PathUtils.getTempCachePath();
        final destPath = '$destDir/$fileName';
        ApexLogger.instance
            .log('NEARBY', '🚚 Moving: $tmpPath → $destPath', LogLevel.info);
        try {
          await File(tmpPath).rename(destPath);
          ApexLogger.instance.log('NEARBY', '✅ rename() OK', LogLevel.success);
        } catch (renameErr) {
          ApexLogger.instance.log(
              'NEARBY',
              '⚠️ rename() failed: $renameErr → trying copy()',
              LogLevel.warning);
          await File(tmpPath).copy(destPath);
          try {
            await File(tmpPath).delete();
          } catch (_) {}
          ApexLogger.instance.log('NEARBY', '✅ copy() OK', LogLevel.success);
        }

        final finalPath =
            await PathUtils.saveToPublicDownloads(fileName, destPath) ??
                destPath;
        if (finalPath != destPath) {
          try {
            await File(destPath).delete();
          } catch (_) {}
        }

        final fileSize = await File(finalPath).length();
        ApexLogger.instance.log('NEARBY',
            '✅ Saved: $finalPath | size=$fileSize bytes', LogLevel.success);

        final progress = TransferProgressService();
        progress.nextFile();
        final isLast = progress.currentFileIndex >= progress.totalFiles;
        if (isLast) {
          progress.clearProgress();
        }

        onFileReceived(FileReceivedEvent(
          fileName: fileName,
          fileSize: fileSize,
          fromDevice: device?.name ?? endpointId,
          filePath: finalPath,
          isLastInBatch: isLast,
          batchTotal: progress.totalFiles,
          batchIndex: progress.currentFileIndex,
        ));
      } catch (e) {
        progress.clearProgress();
        ApexLogger.instance
            .log('NEARBY', '❌ Move/save error: $e', LogLevel.error);
      }
    };
  }

  Future<void> _handleTransferRequest(String endpointId, Map msg) async {
    final fileName = msg['name'] as String? ?? 'unknown';
    final fileSize = (msg['size'] as num?)?.toInt() ?? 0;
    final fromName = msg['from'] as String? ?? 'Unknown';

    if (PlatformDetector.instance.isTV) {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(
            utf8.encode(jsonEncode({'type': 'response', 'accepted': true}))),
      );
      ApexLogger.instance
          .log('NEARBY', '✅ TV auto-accepted: $fileName', LogLevel.success);
      return;
    }

    final completer = Completer<bool>();
    _pendingRequests[endpointId] = completer;

    onConnectionRequest(ConnectionRequest(
      device: discoveredDevices[endpointId] ??
          Device(
              id: endpointId,
              name: fromName,
              type: 'phone',
              endpointId: endpointId),
      fileName: fileName,
      fileSize: fileSize,
      onResponse: (v) async {
        if (!completer.isCompleted) {
          completer.complete(v);
        }
        await Nearby().sendBytesPayload(
          endpointId,
          Uint8List.fromList(
              utf8.encode(jsonEncode({'type': 'response', 'accepted': v}))),
        );
      },
    ));
  }

  Future<void> _handleBatchTransferRequest(String endpointId, Map msg) async {
    final fromName = msg['from'] as String? ?? 'Unknown';
    final total = (msg['total'] as num?)?.toInt() ?? 1;
    final names = (msg['names'] as List?)?.cast<String>() ?? [];
    final totalSize = (msg['totalSize'] as num?)?.toInt() ?? 0;

    if (PlatformDetector.instance.isTV) {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(
            utf8.encode(jsonEncode({'type': 'response', 'accepted': true}))),
      );
      ApexLogger.instance.log(
          'NEARBY', '✅ TV auto-accepted batch: $total files', LogLevel.success);
      return;
    }

    final displayName = '$total ملفات';
    final completer = Completer<bool>();
    _pendingRequests[endpointId] = completer;

    onConnectionRequest(ConnectionRequest(
      device: discoveredDevices[endpointId] ??
          Device(
              id: endpointId,
              name: fromName,
              type: 'phone',
              endpointId: endpointId),
      fileName: displayName,
      fileSize: totalSize,
      fileCount: total,
      fileNames: names,
      onResponse: (v) async {
        if (!completer.isCompleted) {
          completer.complete(v);
        }
        await Nearby().sendBytesPayload(
          endpointId,
          Uint8List.fromList(
              utf8.encode(jsonEncode({'type': 'response', 'accepted': v}))),
        );
        // ابدأ وضع الاستقبال مع عدد الملفات
        if (v) {
          TransferProgressService().startReceive(
            senderDeviceName: fromName,
            totalFiles: total,
          );
        }
      },
    ));
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[\\/\x00]'), '_').replaceAll('..', '_');
}
