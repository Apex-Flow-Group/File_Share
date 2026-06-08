import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import '../models/device.dart';
import '../models/transfer_progress.dart';
import '../services/transfer_progress_service.dart';
import '../utils/apex_logger.dart';
import '../utils/path_utils.dart';
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
    progress.startBatch(1);

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

  /// إرسال ملفات متعددة مع طلب إذن واحد فقط
  Future<bool> sendBatchFiles(
    List<({String path, String name, int size})> files,
    Device target,
  ) async {
    if (files.isEmpty) {
      return false;
    }

    final endpointId = target.endpointId!;
    final progress = TransferProgressService();
    progress.startBatch(files.length);

    // 1. الاتصال إذا لم يكن متصلاً
    if (!connectedEndpoints.contains(endpointId)) {
      if (!await connect(endpointId, target.name)) {
        ApexLogger.instance
            .log('NEARBY', '❌ Connection failed', LogLevel.error);
        progress.clearProgress();
        return false;
      }
    }

    // 2. طلب إذن واحد لجميع الملفات
    final accepted = await _requestBatchPermission(
      endpointId,
      files,
      target.name,
    );
    if (!accepted) {
      ApexLogger.instance.log('NEARBY', '❌ Batch rejected', LogLevel.warning);
      progress.clearProgress();
      return false;
    }

    // 3. إرسال الملفات واحداً تلو الآخر بدون طلب إذن إضافي
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

  /// إرسال ملف واحد (الـ payload الفعلي) بدون طلب إذن
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

      // أرسل اسم الملف وحجمه ليعرف المستقبل ما يحفظه ويعرض التقدم
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

  /// طلب إذن لمجموعة ملفات دفعة واحدة
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

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(endpointId);
        return false;
      },
    );
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
          // إكمال أي عملية معلقة فوراً عند انقطاع الاتصال
          _pendingRequests.remove(eid)?.complete(false);
          _connectCompleters.remove(eid)?.complete(false);
        },
      );
    } catch (e) {
      _connectCompleters.remove(endpointId)?.complete(false);
      return false;
    }

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _connectCompleters.remove(endpointId);
        return false;
      },
    );
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

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(endpointId);
        return false;
      },
    );
  }

  // ─── Receive ───────────────────────────────────────────────────────────────

  // تتبع معلومات الملفات المعلّقة على المستقبل قبل استلام payload الملف
  final Map<int, String> _pendingReceiveNames = {};
  final Map<int, int> _pendingReceiveSizes = {};

  void onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.FILE) {
      final device = discoveredDevices[endpointId];

      // اسم وحجم الملف: قد يكون وصل مسبقاً أو سيصل لاحقاً
      final pendingName = _pendingFileNames.remove(payload.id) ??
          _pendingReceiveNames.remove(payload.id);
      final pendingSize = _pendingReceiveSizes.remove(payload.id) ?? 0;
      final fileName = _sanitize(pendingName ?? 'file_${payload.id}');

      final progress = TransferProgressService();
      final startTime = DateTime.now();

      // إذا وصل الحجم، ابدأ تتبع التقدم على المستقبل
      if (pendingSize > 0) {
        progress.startBatch(1);
        progress.updateProgress(TransferProgress(
          fileName: fileName,
          totalBytes: pendingSize,
          transferredBytes: 0,
          status: TransferStatus.transferring,
          startTime: startTime,
        ));
      }

      _transferCallbacks[payload.id] = (update) async {
        // تحديث شريط التقدم على المستقبل
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

        if (update.status != PayloadStatus.SUCCESS) {
          progress.clearProgress();
          ApexLogger.instance.log('NEARBY',
              '❌ Receive failed/cancelled: $fileName', LogLevel.error);
          return;
        }

        // ignore: deprecated_member_use
        final tmpPath = payload.filePath;
        if (tmpPath == null) {
          progress.clearProgress();
          return;
        }
        try {
          final destDir = await PathUtils.getCategoryPath(fileName);
          final destPath = '$destDir/$fileName';
          await File(tmpPath).rename(destPath);
          final fileSize = await File(destPath).length();
          progress.clearProgress();
          onFileReceived(FileReceivedEvent(
            fileName: fileName,
            fileSize: fileSize,
            fromDevice: device?.name ?? endpointId,
            filePath: destPath,
          ));
          ApexLogger.instance
              .log('NEARBY', '✅ Saved: $destPath', LogLevel.success);
        } catch (e) {
          progress.clearProgress();
          ApexLogger.instance.log('NEARBY', '❌ Move error: $e', LogLevel.error);
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
            // إذا كان الـ FILE payload وصل مسبقاً، لا يمكن تحديث الاسم
            // لذلك نخزّن في _pendingReceiveNames أيضاً للمزامنة
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
}
