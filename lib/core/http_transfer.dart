import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/device.dart';
import '../models/transfer_progress.dart';
import '../services/transfer_progress_service.dart';
import '../utils/apex_logger.dart';
import '../utils/path_utils.dart';
import '../utils/platform_detector.dart';
import 'core_models.dart';

class _CancelException implements Exception {
  const _CancelException();
}

class HttpTransfer {
  final String? Function() getLocalName;
  final String? Function() getLocalIp;
  final void Function(FileReceivedEvent) onFileReceived;
  final void Function(ConnectionRequest) onConnectionRequest;

  HttpTransfer({
    required this.getLocalName,
    required this.getLocalIp,
    required this.onFileReceived,
    required this.onConnectionRequest,
  });

  // ─── Receive ───────────────────────────────────────────────────────────────

  Future<void> handlePermissionRequest(HttpRequest req) async {
    final fileName = req.uri.queryParameters['name'] ?? 'unknown';
    final fromDevice = req.uri.queryParameters['from'] ?? 'Unknown';
    final fromIp = req.uri.queryParameters['ip'] ?? '';
    final fileSize = int.tryParse(req.uri.queryParameters['size'] ?? '') ?? 0;

    final totalStr = req.uri.queryParameters['total'];
    final namesStr = req.uri.queryParameters['names'];
    final sizesStr = req.uri.queryParameters['sizes'];
    final isBatch = totalStr != null && namesStr != null;

    final displayName =
        isBatch ? '${int.tryParse(totalStr) ?? 1} ملفات' : fileName;
    final totalSize = isBatch
        ? (sizesStr
                ?.split(',')
                .fold<int>(0, (s, v) => s + (int.tryParse(v.trim()) ?? 0)) ??
            fileSize)
        : fileSize;
    final fileCount = isBatch ? (int.tryParse(totalStr) ?? 1) : 1;
    final fileNamesList = isBatch ? (namesStr.split(',')) : <String>[];

    final requestId = '${fromIp}_${DateTime.now().millisecondsSinceEpoch}';

    // على TV نقبل تلقائياً بدون نافذة
    if (PlatformDetector.instance.isTV) {
      req.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'accepted': true}));
      await req.response.close();
      return;
    }

    final completer = Completer<bool>();

    onConnectionRequest(ConnectionRequest(
      device:
          Device(id: requestId, name: fromDevice, type: 'unknown', ip: fromIp),
      fileName: displayName,
      fileSize: totalSize,
      fileCount: fileCount,
      fileNames: fileNamesList,
      onResponse: (v) {
        if (!completer.isCompleted) {
          completer.complete(v);
        }
      },
    ));

    final accepted = await completer.future
        .timeout(const Duration(seconds: 30), onTimeout: () => false);

    req.response
      ..statusCode = HttpStatus.ok
      ..write(jsonEncode({'accepted': accepted}));
    await req.response.close();
  }

  Future<void> handleUpload(HttpRequest req) async {
    final fileName = _sanitize(req.uri.queryParameters['name'] ?? 'unknown');
    final fromDevice = req.uri.queryParameters['from'] ?? 'Unknown';
    final expectedSize =
        int.tryParse(req.headers.value('content-length') ?? '') ?? 0;

    // Write to temp cache first, then move to public Downloads via MediaStore
    final tempDir = await PathUtils.getCategoryPath(fileName);
    final tempPath = '$tempDir/$fileName';
    IOSink? sink;

    try {
      sink = File(tempPath).openWrite(mode: FileMode.write);
      int received = 0;
      final startTime = DateTime.now();
      const updateInterval = 256 * 1024;

      // أبلغ عن بدء الاستقبال مع اسم الجهاز المُرسِل
      TransferProgressService().startReceive(senderDeviceName: fromDevice);

      await for (final chunk in req) {
        if (TransferProgressService().isCancelledReceive) {
          throw const _CancelException();
        }
        sink.add(chunk);
        received += chunk.length;

        if (expectedSize > 0 && received % updateInterval < chunk.length) {
          TransferProgressService().updateProgress(TransferProgress(
            fileName: fileName,
            totalBytes: expectedSize,
            transferredBytes: received,
            status: TransferStatus.transferring,
            startTime: startTime,
          ));
        }
      }

      // flush بعد انتهاء stream كاملاً — مرة واحدة فقط
      await sink.flush();
      await sink.close();
      sink = null;
      TransferProgressService().clearProgress();

      // Move to public Downloads via MediaStore (Android 10+)
      final finalPath =
          await PathUtils.saveToPublicDownloads(fileName, tempPath) ?? tempPath;
      // Clean up temp if moved successfully
      if (finalPath != tempPath) {
        try {
          await File(tempPath).delete();
        } catch (_) {}
      }

      req.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': true}));
      await req.response.close();

      onFileReceived(FileReceivedEvent(
        fileName: fileName,
        fileSize: received,
        fromDevice: fromDevice,
        filePath: finalPath,
      ));
    } on _CancelException {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        final partial = File(tempPath);
        if (await partial.exists()) {
          await partial.delete();
        }
      } catch (_) {}
      TransferProgressService().clearProgress();
      try {
        req.response.statusCode = 499;
        await req.response.close();
      } catch (_) {}
    } catch (e) {
      ApexLogger.instance.log('HTTP', '❌ Upload error: $e', LogLevel.error);
      try {
        await sink?.close();
      } catch (_) {}
      try {
        final partial = File(tempPath);
        if (await partial.exists()) {
          await partial.delete();
        }
      } catch (_) {}
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  // ─── Send ──────────────────────────────────────────────────────────────────

  Future<bool> sendFiles(
    List<({String path, String name, int size})> files,
    Device target,
  ) async {
    final progress = TransferProgressService();
    progress.startBatch(files.length, targetDeviceId: target.id);
    try {
      if (!await ping(target)) {
        return false;
      }
      if (!await _requestBatch(target, files)) {
        return false;
      }

      int success = 0;
      for (final f in files) {
        if (progress.isCancelled) {
          break;
        }
        if (await _upload(f.path, f.name, f.size, target)) {
          success++;
        }
        progress.nextFile();
      }
      return success == files.length;
    } finally {
      progress.clearProgress();
    }
  }

  Future<bool> ping(Device device) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.get(device.ip, device.port, '/ping');
      final res = await req.close();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> _requestBatch(
    Device target,
    List<({String path, String name, int size})> files,
  ) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.http('${target.ip}:${target.port}', '/request', {
        'from': getLocalName() ?? 'Unknown',
        'ip': getLocalIp() ?? '',
        'name': files.length == 1 ? files.first.name : '${files.length} ملفات',
        'size': files.fold<int>(0, (s, f) => s + f.size).toString(),
        'total': files.length.toString(),
        'names': files.map((f) => f.name).join(','),
        'sizes': files.map((f) => f.size.toString()).join(','),
      });
      final req = await client.postUrl(uri);
      final res = await req.close();
      final body = jsonDecode(await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 35)));
      return body['accepted'] == true;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> _upload(
      String filePath, String fileName, int fileSize, Device target) async {
    final progress = TransferProgressService();
    final startTime = DateTime.now();
    HttpClient? client;
    HttpClientRequest? req;
    try {
      progress.updateProgress(TransferProgress(
        fileName: fileName,
        totalBytes: fileSize,
        transferredBytes: 0,
        status: TransferStatus.transferring,
        startTime: startTime,
      ));

      final timeoutSecs = ((fileSize / (100 * 1024)) + 60).ceil();
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30)
        ..idleTimeout = Duration(seconds: timeoutSecs);

      final uri = Uri.http('${target.ip}:${target.port}', '/upload', {
        'name': fileName,
        'from': getLocalName() ?? 'Unknown',
      });
      req = await client.postUrl(uri);
      req.headers.set('Content-Length', fileSize.toString());
      req.bufferOutput = false; // إرسال مباشر بدون buffer إضافي

      int transferred = 0;
      const chunkSize =
          256 * 1024; // 256 KB per chunk للتحقق من الإلغاء بتكرار كافٍ
      const updateInterval = 512 * 1024;

      final file = await File(filePath).open(mode: FileMode.read);
      try {
        while (transferred < fileSize) {
          // تحقق من الإلغاء قبل كل chunk
          if (progress.isCancelled) {
            throw const _CancelException();
          }
          final remaining = fileSize - transferred;
          final toRead = remaining < chunkSize ? remaining : chunkSize;
          final chunk = await file.read(toRead);
          if (chunk.isEmpty) {
            break;
          }
          req.add(chunk);
          transferred += chunk.length;
          if (transferred % updateInterval < chunk.length ||
              transferred >= fileSize) {
            progress.updateProgress(TransferProgress(
              fileName: fileName,
              totalBytes: fileSize,
              transferredBytes: transferred,
              status: TransferStatus.transferring,
              startTime: startTime,
            ));
          }
        }
      } finally {
        await file.close();
      }

      final res = await req.close();
      req = null;
      // 499 = المستقبل ألغى — نعتبره فشل
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
      return body['success'] == true;
    } on _CancelException {
      try {
        req?.abort();
      } catch (_) {}
      return false;
    } catch (e) {
      ApexLogger.instance.log('HTTP', '❌ $e', LogLevel.error);
      try {
        req?.abort();
      } catch (_) {}
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[\\/\x00]'), '_').replaceAll('..', '_');
}
