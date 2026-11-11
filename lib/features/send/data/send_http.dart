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

enum SendOutcome { sent, declined, noAnswer, updateRequired, busy, tooManyFiles, noSpace, failed, cancelled }

enum ChatOutcome { sent, declined, noAnswer, updateRequired, busy, tooLong, failed }

typedef OutgoingFile = ({String path, String name, int size});

/// Sends a batch: one offer with every name and size, then one upload per file
/// with the token the receiver issued when its user accepted.
class SendHttp {
  SendHttp({required this.getLocalName});

  final String? Function() getLocalName;

  /// The receiver's answer when its user cancelled.
  static const _cancelledStatus = 499;

  TransferProgressService get _progress => TransferProgressService();

  Future<SendOutcome> sendFiles(List<OutgoingFile> files, Device target) async {
    // Checked here first, so the user hears why at once; the receiver checks
    // again and refuses with 422.
    if (files.length > TransferRules.maxFilesPerBatch) {
      return SendOutcome.tooManyFiles;
    }
    final progress = _progress..startBatch(files.length, targetDeviceId: target.id);
    try {
      final offer = await _offer(files, target);
      final tokens = offer.tokens;
      if (tokens == null) {
        return offer.outcome;
      }
      for (var i = 0; i < files.length; i++) {
        if (progress.isCancelled) {
          return SendOutcome.cancelled;
        }
        // One failed file ends the batch. When the receiver cancels mid-file,
        // the connection closes before its 499 can be read, and the rest of
        // the batch is refused anyway.
        final outcome = await _upload(files[i], tokens[i], target);
        progress.nextFile();
        if (outcome != SendOutcome.sent) {
          return outcome;
        }
      }
      return progress.isCancelled ? SendOutcome.cancelled : SendOutcome.sent;
    } finally {
      progress.clearProgress();
    }
  }

  /// One chat message. [token] is the one the receiver gave when its user
  /// accepted; without it the receiver asks its user first, and a token comes
  /// back on acceptance.
  Future<({ChatOutcome outcome, String? token})> sendChat(
      String text, Device target, String? token) async {
    if (text.runes.length > TransferRules.chatTextLimit) {
      return (outcome: ChatOutcome.tooLong, token: null);
    }
    const failed = (outcome: ChatOutcome.failed, token: null);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(Uri.http('${target.ip}:${target.port}', ApexProtocol.chatPath));
      req.headers
        ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
        ..contentType = ContentType.json;
      if (token != null) {
        req.headers.set(ApexProtocol.tokenHeader, token);
      }
      final body = utf8.encode(jsonEncode({'name': getLocalName() ?? '', 'text': text}));
      req.contentLength = body.length;
      req.add(body);
      final res = await req.close().timeout(TransferRules.decisionTimeout + const Duration(seconds: 10));
      final reply = await res.transform(utf8.decoder).join();
      switch (res.statusCode) {
        case HttpStatus.notFound || HttpStatus.upgradeRequired:
          return (outcome: ChatOutcome.updateRequired, token: null);
        case HttpStatus.tooManyRequests:
          return (outcome: ChatOutcome.busy, token: null);
        case HttpStatus.requestEntityTooLarge:
          return (outcome: ChatOutcome.tooLong, token: null);
        case HttpStatus.ok:
          break;
        default:
          return failed;
      }
      final json = jsonDecode(reply);
      if (json is! Map) {
        return failed;
      }
      if (json['delivered'] == true) {
        final issued = json['token'];
        return (outcome: ChatOutcome.sent, token: issued is String ? issued : token);
      }
      final unanswered = json['reason'] == ApexProtocol.noAnswer;
      return (outcome: unanswered ? ChatOutcome.noAnswer : ChatOutcome.declined, token: null);
    } catch (e) {
      ApexLogger.instance.log('SEND', 'Chat failed: $e', LogLevel.error);
      return failed;
    } finally {
      client.close(force: true);
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
      // The receiver is already asking its user about another offer.
      if (res.statusCode == HttpStatus.tooManyRequests) {
        return (outcome: SendOutcome.busy, tokens: null);
      }
      // The receiver refused the batch before asking its user.
      if (res.statusCode == HttpStatus.unprocessableEntity) {
        final error = (jsonDecode(text) as Map?)?['error'];
        return (
          outcome: switch (error) {
            'tooManyFiles' => SendOutcome.tooManyFiles,
            'notEnoughSpace' => SendOutcome.noSpace,
            _ => SendOutcome.failed,
          },
          tokens: null,
        );
      }
      if (res.statusCode != HttpStatus.ok) {
        return failed;
      }
      final json = jsonDecode(text);
      if (json is! Map || json['accepted'] != true) {
        final unanswered = json is Map && json['reason'] == ApexProtocol.noAnswer;
        return (outcome: unanswered ? SendOutcome.noAnswer : SendOutcome.declined, tokens: null);
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

  Future<SendOutcome> _upload(OutgoingFile file, String token, Device target) async {
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
          return SendOutcome.cancelled;
        }
        final chunk = await source.read(min(chunkSize, file.size - sent));
        if (chunk.isEmpty) {
          // The file shrank since it was listed; the receiver refuses a short body.
          req.abort();
          return SendOutcome.failed;
        }
        req.add(chunk);
        sent += chunk.length;
        if (sent % progressStep < chunk.length || sent >= file.size) {
          report(sent);
        }
      }
      final res = await req.close();
      req = null;
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode == _cancelledStatus) {
        return SendOutcome.cancelled;
      }
      final json = jsonDecode(text);
      return res.statusCode == HttpStatus.ok && json is Map && json['success'] == true
          ? SendOutcome.sent
          : SendOutcome.failed;
    } catch (e) {
      ApexLogger.instance.log('SEND', 'Upload failed: $e', LogLevel.error);
      try {
        req?.abort();
      } catch (_) {}
      return SendOutcome.failed;
    } finally {
      await source?.close();
      client.close(force: true);
    }
  }
}
