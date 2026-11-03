import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../core/core_models.dart';
import '../../../core/files/safe_file_name.dart';
import '../../../core/protocol/apex_protocol.dart';
import '../../../core/protocol/transfer_rules.dart';
import '../../../core/text/clean_label.dart';
import '../../../models/device.dart';
import '../../../models/transfer_progress.dart';
import '../../../services/transfer_progress_service.dart';
import '../../../utils/apex_logger.dart';
import '../logic/offer.dart';
import '../logic/receive_gate.dart';
import 'receive_store.dart';

/// The receiving door: /ping, /offer, /upload. Every request must carry the
/// current protocol version; every upload must carry a token the user's
/// acceptance issued. Anything else is refused before a byte is written.
class ReceiveHttp {
  ReceiveHttp({
    required this.gate,
    required this.store,
    required this.onConnectionRequest,
    required this.onFileReceived,
    this.freeBytes,
    this.decisionTimeout = TransferRules.decisionTimeout,
    this.bodyIdleLimit = TransferRules.bodyIdleLimit,
  });

  final ReceiveGate gate;
  final ReceiveStore store;
  final void Function(ConnectionRequest) onConnectionRequest;
  final void Function(FileReceivedEvent) onFileReceived;

  /// Free space where files are saved; null when it cannot be read.
  final Future<int?> Function()? freeBytes;
  final Duration decisionTimeout;
  final Duration bodyIdleLimit;

  final _random = Random();

  /// One offer waits for the user at a time. Others are refused, so dialogs
  /// never pile up and a new one cannot appear under the finger mid-tap.
  bool _asking = false;

  TransferProgressService get _progress => TransferProgressService();

  /// False when [req] is not for this door.
  Future<bool> handle(HttpRequest req) async {
    final path = req.uri.path;
    if (path != ApexProtocol.pingPath && path != ApexProtocol.offerPath && path != ApexProtocol.uploadPath) {
      return false;
    }
    if (!ApexProtocol.accepts(req.headers.value(ApexProtocol.versionHeader))) {
      await _reply(req, HttpStatus.upgradeRequired,
          {'error': ApexProtocol.updateRequired, 'version': ApexProtocol.version});
      return true;
    }
    final method = path == ApexProtocol.pingPath ? 'GET' : 'POST';
    if (req.method != method) {
      await _reply(req, HttpStatus.methodNotAllowed, {'error': 'method'});
      return true;
    }
    switch (path) {
      case ApexProtocol.pingPath:
        await _reply(req, HttpStatus.ok, {'version': ApexProtocol.version});
      case ApexProtocol.offerPath:
        await _offer(req);
      case ApexProtocol.uploadPath:
        await _upload(req);
    }
    return true;
  }

  // ─── Offer ─────────────────────────────────────────────────────────────────

  Future<void> _offer(HttpRequest req) async {
    final address = req.connectionInfo?.remoteAddress.address;
    final String? text;
    try {
      text = await _readLimited(req, TransferRules.offerBodyLimit);
    } on TimeoutException {
      // Leaving the body loop early closes the connection; a stalled sender
      // is not reading, so it gets no answer.
      return;
    }
    final offer = address == null || text == null ? null : _parseOffer(text, address);
    if (offer == null) {
      await _reply(req, HttpStatus.badRequest, {'error': 'bad_offer'});
      return;
    }
    final problem = checkOffer(offer, freeBytes: await freeBytes?.call());
    if (problem != null) {
      await _reply(req, HttpStatus.unprocessableEntity, {'error': problem.name});
      return;
    }
    if (_asking) {
      await _reply(req, HttpStatus.tooManyRequests, {'error': 'busy'});
      return;
    }
    _asking = true;
    final bool? accepted;
    try {
      accepted = await _ask(offer);
    } finally {
      _asking = false;
    }
    if (accepted != true) {
      await _reply(req, HttpStatus.ok,
          {'accepted': false, if (accepted == null) 'reason': ApexProtocol.noAnswer});
      return;
    }
    final tokens = gate.admit(offer);
    _progress.startReceive(senderDeviceName: offer.senderName, totalFiles: offer.files.length);
    await _reply(req, HttpStatus.ok, {'accepted': true, 'tokens': tokens});
  }

  /// True or false as the user answered; null when no answer came in time.
  Future<bool?> _ask(Offer offer) {
    final answer = Completer<bool?>();
    onConnectionRequest(ConnectionRequest(
      device: Device(
          id: 'http:${offer.senderAddress}',
          name: offer.senderName,
          type: 'unknown',
          ip: offer.senderAddress),
      fileName: offer.files.first.name,
      fileSize: offer.totalBytes,
      fileCount: offer.files.length,
      fileNames: [for (final f in offer.files) f.name],
      onResponse: (accepted) {
        if (!answer.isCompleted) {
          answer.complete(accepted);
        }
      },
    ));
    return answer.future.timeout(decisionTimeout, onTimeout: () => null);
  }

  /// The address comes from the connection; any address in the body is ignored.
  Offer? _parseOffer(String text, String address) {
    try {
      final json = jsonDecode(text);
      final files = json is Map ? json['files'] : null;
      if (files is! List) {
        return null;
      }
      final parsed = <OfferedFile>[];
      for (final f in files) {
        final size = f is Map ? f['size'] : null;
        if (size is! int) {
          return null;
        }
        final name = f['name'];
        parsed.add(OfferedFile(safeFileName(name is String ? name : null), size));
      }
      final rawName = json['name'];
      final senderName = cleanLabel(rawName is String ? rawName : null);
      return Offer(
        senderAddress: address,
        senderName: senderName.isEmpty ? address : senderName,
        files: parsed,
      );
    } on FormatException {
      return null;
    }
  }

  // ─── Upload ────────────────────────────────────────────────────────────────

  Future<void> _upload(HttpRequest req) async {
    final address = req.connectionInfo?.remoteAddress.address ?? '';
    final upload = gate.take(req.headers.value(ApexProtocol.tokenHeader), address);
    if (upload == null) {
      await _reply(req, HttpStatus.forbidden, {'error': 'not_accepted'});
      return;
    }
    try {
      await _receive(req, upload);
    } finally {
      upload.finish();
    }
  }

  Future<void> _receive(HttpRequest req, Upload upload) async {
    final file = upload.file;
    if (req.contentLength != file.size) {
      await _reply(req, HttpStatus.badRequest, {'error': 'size'});
      return;
    }

    final temp = File('${(await store.tempFolder()).path}/${_partName()}');
    IOSink? sink;
    var written = 0;
    try {
      sink = temp.openWrite();
      final started = DateTime.now();
      const progressStep = 256 * 1024;
      if (_progress.isCancelledReceive) {
        throw const _Cancelled();
      }
      await for (final chunk in req.timeout(bodyIdleLimit)) {
        if (_progress.isCancelledReceive) {
          // Answer inside the loop: leaving it closes the connection first,
          // and the sender would never read the answer.
          await _discard(sink, temp);
          await _cancel(req, upload);
          return;
        }
        written += chunk.length;
        if (written > file.size) {
          throw const _WrongSize();
        }
        sink.add(chunk);
        if (written % progressStep < chunk.length) {
          _progress.updateProgress(TransferProgress(
            fileName: file.name,
            totalBytes: file.size,
            transferredBytes: written,
            status: TransferStatus.transferring,
            startTime: started,
          ));
        }
      }
      await sink.close();
      sink = null;
      if (written != file.size) {
        throw const _WrongSize();
      }
      final path = await store.place(temp, file.name);
      await _reply(req, HttpStatus.ok, {'success': true});
      _finished(file, path, req);
    } catch (e) {
      await _discard(sink, temp);
      if (e is TimeoutException) {
        // The connection is already closed, as for the offer above.
      } else if (e is _Cancelled) {
        await _cancel(req, upload);
      } else if (e is _WrongSize) {
        await _reply(req, HttpStatus.badRequest, {'error': 'size'});
      } else {
        ApexLogger.instance.log('RECEIVE', 'Upload failed: $e', LogLevel.error);
        await _reply(req, HttpStatus.internalServerError, {'error': 'failed'});
      }
    }
  }

  /// Cancel ends the whole batch, not only this file: the rest of its tokens
  /// are revoked, so the sender cannot go on with the next file.
  Future<void> _cancel(HttpRequest req, Upload upload) async {
    upload.revokeBatch();
    _progress.clearProgress();
    await _reply(req, _cancelledStatus, {'error': 'cancelled'});
  }

  Future<void> _discard(IOSink? sink, File temp) async {
    try {
      await sink?.close();
    } catch (_) {}
    try {
      if (await temp.exists()) {
        await temp.delete();
      }
    } catch (_) {}
  }

  void _finished(OfferedFile file, String path, HttpRequest req) {
    final progress = _progress..nextFile();
    final isLast = progress.currentFileIndex >= progress.totalFiles;
    final sender = progress.senderDeviceName ?? req.connectionInfo?.remoteAddress.address ?? '';
    final total = progress.totalFiles;
    final index = progress.currentFileIndex;
    if (isLast) {
      progress.clearProgress();
    }
    onFileReceived(FileReceivedEvent(
      fileName: file.name,
      fileSize: file.size,
      fromDevice: sender,
      filePath: path,
      isLastInBatch: isLast,
      batchTotal: total,
      batchIndex: index,
    ));
  }

  /// Temp names never use the sender's name (":" opens a hidden NTFS stream).
  String _partName() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}.part';

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static const _cancelledStatus = 499;

  Future<String?> _readLimited(HttpRequest req, int limit) async {
    if (req.contentLength > limit) {
      return null;
    }
    final bytes = <int>[];
    await for (final chunk in req.timeout(bodyIdleLimit)) {
      bytes.addAll(chunk);
      if (bytes.length > limit) {
        return null;
      }
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }

  Future<void> _reply(HttpRequest req, int status, Map<String, Object?> body) async {
    try {
      req.response
        ..statusCode = status
        ..persistentConnection = status < 400
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    } catch (_) {
      // The sender is gone; nothing to tell.
    }
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

class _WrongSize implements Exception {
  const _WrongSize();
}
