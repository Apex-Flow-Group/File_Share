import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;

import '../../../core/protocol/apex_protocol.dart';
import '../../../core/protocol/transfer_rules.dart';
import '../../../models/device.dart';
import '../../../models/transfer_progress.dart';
import '../../../services/transfer_progress_service.dart';
import '../../../utils/apex_logger.dart';

enum SendOutcome { sent, declined, updateRequired, failed, cancelled }

typedef OutgoingFile = ({String path, String name, int size});

/// Sends a batch: one offer with every name and size, then one upload per file
/// with the token the receiver issued when its user accepted.
class SendHttp {
  SendHttp({required this.getLocalName});

  final String? Function() getLocalName;

  TransferProgressService get _progress => TransferProgressService();

  Future<SendOutcome> sendFiles(List<OutgoingFile> files, Device target) async {
    final progress = _progress..startBatch(files.length, targetDeviceId: target.id);
    try {
      final offer = await _offer(files, target);
      final tokens = offer.tokens;
      if (tokens == null) {
        return offer.outcome;
      }
      var allSent = true;
      for (var i = 0; i < files.length; i++) {
        if (progress.isCancelled) {
          return SendOutcome.cancelled;
        }
        allSent = await _upload(files[i], tokens[i], target) && allSent;
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

  Future<({SendOutcome outcome, List<String>? tokens})> _offer(
      List<OutgoingFile> files, Device target) async {
    const failed = (outcome: SendOutcome.failed, tokens: null);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(Uri.http('${target.ip}:${target.port}', ApexProtocol.offerPath));
      req.headers
        ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
        ..contentType = ContentType.json;
      final body = utf8.encode(jsonEncode({
        'name': getLocalName() ?? '',
        'files': [for (final f in files) {'name': f.name, 'size': f.size}],
      }));
      req.contentLength = body.length;
      req.add(body);
      final res = await req.close().timeout(TransferRules.decisionTimeout + const Duration(seconds: 10));
      final text = await res.transform(utf8.decoder).join();
      // An old copy has no /offer (404); another version answers 426.
      if (res.statusCode == HttpStatus.notFound || res.statusCode == HttpStatus.upgradeRequired) {
        return (outcome: SendOutcome.updateRequired, tokens: null);
      }
      if (res.statusCode != HttpStatus.ok) {
        return failed;
      }
      final json = jsonDecode(text);
      if (json is! Map || json['accepted'] != true) {
        return (outcome: SendOutcome.declined, tokens: null);
      }
      final tokens = json['tokens'];
      if (tokens is! List || tokens.length != files.length || tokens.any((t) => t is! String)) {
        return failed;
      }
      return (outcome: SendOutcome.sent, tokens: tokens.cast<String>());
    } catch (e) {
      ApexLogger.instance.log('SEND', 'Offer failed: $e', LogLevel.error);
      return failed;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _upload(OutgoingFile file, String token, Device target) async {
    final progress = _progress;
    final started = DateTime.now();
    void report(int sent) => progress.updateProgress(TransferProgress(
          fileName: file.name,
          totalBytes: file.size,
          transferredBytes: sent,
          status: TransferStatus.transferring,
          startTime: started,
        ));

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = Duration(seconds: (file.size / (100 * 1024) + 60).ceil());
    HttpClientRequest? req;
    RandomAccessFile? source;
    try {
      report(0);
      req = await client.postUrl(Uri.http('${target.ip}:${target.port}', ApexProtocol.uploadPath));
      req.headers
        ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
        ..set(ApexProtocol.tokenHeader, token);
      req.contentLength = file.size;
      req.bufferOutput = false;

      const chunkSize = 256 * 1024;
      const progressStep = 512 * 1024;
      source = await File(file.path).open();
      var sent = 0;
      while (sent < file.size) {
        if (progress.isCancelled) {
          req.abort();
          return false;
        }
        final chunk = await source.read(min(chunkSize, file.size - sent));
        if (chunk.isEmpty) {
          // The file shrank since it was listed; the receiver refuses a short body.
          req.abort();
          return false;
        }
        req.add(chunk);
        sent += chunk.length;
        if (sent % progressStep < chunk.length || sent >= file.size) {
          report(sent);
        }
      }
      final res = await req.close();
      req = null;
      final json = jsonDecode(await res.transform(utf8.decoder).join());
      return res.statusCode == HttpStatus.ok && json is Map && json['success'] == true;
    } catch (e) {
      ApexLogger.instance.log('SEND', 'Upload failed: $e', LogLevel.error);
      try {
        req?.abort();
      } catch (_) {}
      return false;
    } finally {
      await source?.close();
      client.close(force: true);
    }
  }
}
