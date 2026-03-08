import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/apex_core.dart';
import '../l10n/app_localizations.dart';
import '../models/device.dart';

class TextChatSheet extends StatefulWidget {
  final List<Device> devices;

  const TextChatSheet({required this.devices, super.key});

  @override
  State<TextChatSheet> createState() => _TextChatSheetState();
}

class _TextChatSheetState extends State<TextChatSheet> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final Map<String, List<ChatMessage>> _chatHistory = {}; // دردشة منفصلة لكل جهاز
  Device? _selectedDevice;
  StreamSubscription? _messageSubscription;

  List<ChatMessage> get _messages => _selectedDevice == null 
      ? [] 
      : _chatHistory[_selectedDevice!.id] ?? [];

  @override
  void initState() {
    super.initState();
    _messageSubscription = ApexCore.instance.messageReceivedStream.listen((event) {
      // إيجاد الجهاز المرسل
      final senderDevice = widget.devices.firstWhere(
        (d) => d.ip == event.fromIp,
        orElse: () => Device(
          id: event.fromIp,
          name: event.fromDevice,
          ip: event.fromIp,
          type: 'unknown',
          port: 8080,
        ),
      );
      
      setState(() {
        _chatHistory[senderDevice.id] ??= [];
        _chatHistory[senderDevice.id]!.add(ChatMessage(
          text: event.message,
          isSent: false,
          timestamp: event.timestamp,
          status: MessageStatus.read,
        ));
      });
      
      // التمرير فقط إذا كانت الدردشة مفتوحة مع هذا الجهاز
      if (_selectedDevice?.id == senderDevice.id) {
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    if (_textController.text.trim().isEmpty || _selectedDevice == null) {
      return;
    }

    final text = _textController.text.trim();
    final message = ChatMessage(
      text: text,
      isSent: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    setState(() {
      _chatHistory[_selectedDevice!.id] ??= [];
      _chatHistory[_selectedDevice!.id]!.add(message);
      _textController.clear();
    });

    _scrollToBottom();

    // إرسال الرسالة مباشرة
    try {
      final success = await ApexCore.instance.sendMessage(text, _selectedDevice!);
      
      setState(() {
        message.status = success ? MessageStatus.sent : MessageStatus.failed;
      });
    } catch (e) {
      setState(() {
        message.status = MessageStatus.failed;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _deleteMessage(int index) {
    if (_selectedDevice == null) {
      return;
    }
    setState(() {
      _chatHistory[_selectedDevice!.id]?.removeAt(index);
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.textCopied),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleMessageStatus(int index) {
    if (_selectedDevice == null) {
      return;
    }
    setState(() {
      final msg = _chatHistory[_selectedDevice!.id]?[index];
      if (msg != null) {
        msg.status = msg.status == MessageStatus.sent 
            ? MessageStatus.read 
            : MessageStatus.sent;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.message, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.sendText,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Device selector
                  DropdownButtonFormField<Device>(
                    initialValue: _selectedDevice,
                    decoration: InputDecoration(
                      labelText: l10n.selectDevice,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: widget.devices.map((device) {
                      return DropdownMenuItem(
                        value: device,
                        child: Text(device.name),
                      );
                    }).toList(),
                    onChanged: (device) {
                      setState(() {
                        _selectedDevice = device;
                        if (device != null) {
                          _chatHistory[device.id] ??= [];
                        }
                      });
                      _scrollToBottom();
                    },
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noMessages,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageBubble(message, index);
                      },
                    ),
            ),

            // Input
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: SingleChildScrollView(
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: l10n.typeMessage,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _selectedDevice == null ? null : _sendText,
                    mini: true,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isSent 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status emoji
                      InkWell(
                        onTap: () => _toggleMessageStatus(index),
                        child: Text(
                          message.status == MessageStatus.sending
                              ? '⏳'
                              : message.status == MessageStatus.failed
                                  ? '❌'
                                  : message.status == MessageStatus.read
                                      ? '✅'
                                      : '✓',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      // Copy button
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () => _copyMessage(message.text),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // Delete button
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: () => _deleteMessage(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isSent;
  final DateTime timestamp;
  MessageStatus status;

  ChatMessage({
    required this.text,
    required this.isSent,
    required this.timestamp,
    required this.status,
  });
}

enum MessageStatus {
  sending,
  sent,
  failed,
  read,
}
