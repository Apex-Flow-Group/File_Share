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

  // ─── Send ──────────────────────────────────────────────────────────────────

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

  // ─── Receive ───────────────────────────────────────────────────────────────

  final Map<int, String> _pendingReceiveNames = {};
  final Map<int, int> _pendingReceiveSizes = {};

  void onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.FILE) {
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
          ApexLogger.instance.log('NEARBY',
              '❌ Receive failed/cancelled: $fileName', LogLevel.error);
          return;
        }

        // ignore: deprecated_member_use
        final rawUri = payload.uri;
        // ignore: deprecated_member_use
        final rawPath = payload.filePath;
        ApexLogger.instance.log(
            'NEARBY',
            '📂 payload.uri=$rawUri | payload.filePath=$rawPath',
            LogLevel.info);

        String? tmpPath;

        if (rawUri != null) {
          final uri = Uri.tryParse(rawUri);
          if (uri != null && uri.scheme == 'file') {
            // file:// مباشر — نادر لكن ندعمه
            tmpPath = uri.toFilePath();
          } else if (uri != null && uri.scheme == 'content') {
            // content:// من Google Play Services FileProvider
            // نستخدم ContentResolver عبر MethodChannel لنسخه لملف مؤقت
            try {
              final cacheDir = await getTemporaryDirectory();
              final tmpFile = '${cacheDir.path}/nearby_tmp_${payload.id}';
              ApexLogger.instance.log(
                  'NEARBY',
                  '📋 Copying via ContentResolver: $rawUri → $tmpFile',
                  LogLevel.info);
              final result = await _nearbyChannel.invokeMethod<String>(
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
              ApexLogger.instance.log(
                  'NEARBY', '❌ ContentResolver failed: $e', LogLevel.error);
            }
          }
        }

        // Fallback for Android <10
        tmpPath ??= rawPath;

        ApexLogger.instance.log('NEARBY', '📂 tmpPath=$tmpPath', LogLevel.info);

        if (tmpPath == null) {
          progress.clearProgress();
          ApexLogger.instance
              .log('NEARBY', '❌ tmpPath is null!', LogLevel.error);
          return;
        }

        try {
          final destDir = await PathUtils.getCategoryPath(fileName);
          final destPath = '$destDir/$fileName';
          ApexLogger.instance
              .log('NEARBY', '🚚 Moving: $tmpPath → $destPath', LogLevel.info);
          try {
            await File(tmpPath).rename(destPath);
            ApexLogger.instance
                .log('NEARBY', '✅ rename() OK', LogLevel.success);
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

          // Move to public Downloads via MediaStore (Android 10+)
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
          progress.clearProgress();
          onFileReceived(FileReceivedEvent(
            fileName: fileName,
            fileSize: fileSize,
            fromDevice: device?.name ?? endpointId,
            filePath: finalPath,
          ));
        } catch (e) {
          progress.clearProgress();
          ApexLogger.instance
              .log('NEARBY', '❌ Move/save error: $e', LogLevel.error);
        }
      };
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

  Future<void> _handleTransferRequest(String endpointId, Map msg) async {
    final fileName = msg['name'] as String? ?? 'unknown';
    final fileSize = (msg['size'] as num?)?.toInt() ?? 0;
    final fromName = msg['from'] as String? ?? 'Unknown';

    // على TV نقبل تلقائياً بدون أي نافذة
    if (PlatformDetector.instance.isTV) {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(
            utf8.encode(jsonEncode({'type': 'response', 'accepted': true}))),
      );
      ApexLogger.instance.log('NEARBY', '✅ TV auto-accepted: $fileName', LogLevel.success);
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

    // على TV نقبل تلقائياً
    if (PlatformDetector.instance.isTV) {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(
            utf8.encode(jsonEncode({'type': 'response', 'accepted': true}))),
      );
      ApexLogger.instance.log('NEARBY', '✅ TV auto-accepted batch: $total files', LogLevel.success);
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
      },
    ));
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[\\/\x00]'), '_').replaceAll('..', '_');

  Future<void> stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
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
}
