part of 'nearby_transfer.dart';

/// Receive-related methods for [NearbyTransfer]. Every decision is made by
/// [NearbyTransfer.door]; this part only moves the bytes the door let in.
extension NearbyTransferReceive on NearbyTransfer {
  void onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.FILE) {
      await _handleFilePayload(endpointId, payload);
      return;
    }
    final bytes = payload.bytes;
    if (payload.type != PayloadType.BYTES || bytes == null) {
      return;
    }
    Object? msg;
    try {
      msg = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      ApexLogger.instance.log('NEARBY', 'Parse error: $e', LogLevel.error);
      return;
    }
    if (msg is Map && msg['type'] == NearbyMessage.answer) {
      _pendingRequests.remove(endpointId)?.complete(msg);
      return;
    }
    await door.onMessage(endpointId, msg);
  }

  void onPayloadTransferUpdate(
      String endpointId, PayloadTransferUpdate update) {
    _transferCallbacks[update.id]?.call(update);
  }

  Future<void> _handleFilePayload(String endpointId, Payload payload) async {
    if (!door.expectsFile(endpointId)) {
      ApexLogger.instance.log(
          'NEARBY', 'FILE payload with no accepted offer dropped: $endpointId', LogLevel.warning);
      await _cancelPayload(payload.id);
      return;
    }
    final progress = TransferProgressService();
    final started = DateTime.now();

    _transferCallbacks[payload.id] = (update) async {
      final done = update.status == PayloadStatus.SUCCESS ||
          update.status == PayloadStatus.FAILURE ||
          update.status == PayloadStatus.CANCELED;
      if (!done) {
        if (progress.isCancelledReceive) {
          // The rest of the batch is refused too, not only this file.
          _transferCallbacks.remove(payload.id);
          door.forget(endpointId);
          await _cancelPayload(payload.id);
          progress.clearProgress();
          return;
        }
        progress.updateProgress(TransferProgress(
          fileName: door.announced(endpointId, payload.id)?.name ?? '',
          totalBytes: update.totalBytes,
          transferredBytes: update.bytesTransferred,
          status: TransferStatus.transferring,
          startTime: started,
        ));
        return;
      }

      _transferCallbacks.remove(payload.id);
      final file = await door.takeFile(endpointId, payload.id);
      final ok = update.status == PayloadStatus.SUCCESS;
      final temp = ok && file != null ? await _receivedFile(payload) : null;
      if (file == null || temp == null || await temp.length() != file.size) {
        await _deleteQuietly(temp);
        await _deleteRaw(payload);
        if (!ok) {
          progress.clearProgress();
        }
        ApexLogger.instance.log('NEARBY',
            'Payload ${payload.id} not saved (status=${update.status}, accepted=${file != null})',
            LogLevel.warning);
        return;
      }
      try {
        final path = await place(temp, file.name);
        _finished(endpointId, file.name, file.size, path);
      } catch (e) {
        await _deleteQuietly(temp);
        progress.clearProgress();
        ApexLogger.instance.log('NEARBY', 'Save error: $e', LogLevel.error);
      }
    };
  }

  void _finished(String endpointId, String name, int size, String path) {
    final progress = TransferProgressService()..nextFile();
    final isLast = progress.currentFileIndex >= progress.totalFiles;
    final sender = progress.senderDeviceName ?? endpointId;
    final total = progress.totalFiles;
    final index = progress.currentFileIndex;
    if (isLast) {
      progress.clearProgress();
    }
    onFileReceived(FileReceivedEvent(
      fileName: name,
      fileSize: size,
      fromDevice: sender,
      filePath: path,
      isLastInBatch: isLast,
      batchTotal: total,
      batchIndex: index,
    ));
  }

  /// The received bytes as a file of our own. Temp names never use the
  /// sender's name.
  Future<File?> _receivedFile(Payload payload) async {
    // ignore: deprecated_member_use
    final rawUri = payload.uri;
    final uri = rawUri == null ? null : Uri.tryParse(rawUri);
    if (uri != null && uri.scheme == 'content') {
      try {
        final dest =
            '${await PathUtils.getTempCachePath()}/${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}.part';
        final copied = await NearbyTransfer._nearbyChannel
            .invokeMethod<String>('copyContentUri', {'uri': rawUri, 'destPath': dest});
        return copied != null && await File(copied).exists() ? File(copied) : null;
      } catch (e) {
        ApexLogger.instance.log('NEARBY', 'ContentResolver copy failed: $e', LogLevel.error);
        return null;
      }
    }
    // ignore: deprecated_member_use
    final path = uri != null && uri.scheme == 'file' ? uri.toFilePath() : payload.filePath;
    return path != null && await File(path).exists() ? File(path) : null;
  }

  /// Before Android 10 the plugin writes the payload into a shared folder;
  /// a dropped one must not stay there.
  Future<void> _deleteRaw(Payload payload) async {
    // ignore: deprecated_member_use
    final rawUri = payload.uri;
    final uri = rawUri == null ? null : Uri.tryParse(rawUri);
    // ignore: deprecated_member_use
    final path = uri != null && uri.scheme == 'file' ? uri.toFilePath() : payload.filePath;
    await _deleteQuietly(path == null ? null : File(path));
  }

  Future<void> _deleteQuietly(File? f) async {
    try {
      if (f != null && await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  Future<void> _cancelPayload(int id) async {
    try {
      await Nearby().cancelPayload(id);
    } catch (_) {}
  }
}
