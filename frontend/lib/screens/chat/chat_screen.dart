import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/chat_service.dart';
import '../../services/token_service.dart';
import '../../services/report_service.dart';

class ChatScreen extends StatefulWidget {
  final int threadId;
  final String title;

  const ChatScreen({
    super.key,
    required this.threadId,
    required this.title,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  io.Socket? _socket;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadCachedMessages();
    _loadMessages();
    _initSocket();
  }

  String _cacheKey() => "chat_messages_${widget.threadId}";

  Future<void> _loadCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey());
      if (cached == null || cached.isEmpty) return;
      final decoded = (jsonDecode(cached) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(decoded);
        _loading = false;
      });
    } catch (_) {
      // Ignore cache errors
    }
  }

  Future<void> _saveCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(), jsonEncode(_messages));
    } catch (_) {
      // Ignore cache errors
    }
  }

  Future<void> _loadMessages() async {
    try {
      final userId = await TokenService.getUserId();
      final data = await ChatService.fetchMessages(widget.threadId);
      final messages = data
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        _userId = userId;
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
      });
      await _saveCachedMessages();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _initSocket() async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) return;

    final socket = io.io(
      ChatService.socketUrl(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({"token": token})
          .build(),
    );

    socket.onConnect((_) {
      socket.emit("joinThread", {"threadId": widget.threadId});
    });

    socket.on("reconnect", (_) {
      socket.emit("joinThread", {"threadId": widget.threadId});
    });

    socket.on("newMessage", (data) {
      if (!mounted) return;
      setState(() {
        _messages.add(Map<String, dynamic>.from(data));
      });
      _saveCachedMessages();
    });

    socket.on("rateLimited", (data) {
      if (!mounted) return;
      final message = data is Map && data["message"] != null
          ? data["message"].toString()
          : "Too many messages. Please slow down.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });

    _socket = socket;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_socket != null && _socket!.connected) {
      _socket!.emit("sendMessage", {
        "threadId": widget.threadId,
        "message": text,
      });

      _messageController.clear();
      return;
    }

    try {
      final sent = await ChatService.sendMessage(
        threadId: widget.threadId,
        message: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(Map<String, dynamic>.from(sent));
      });
      await _saveCachedMessages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message not sent. Please try again.")),
      );
    }

    _messageController.clear();
  }

  Future<void> _reportMessage(Map<String, dynamic> msg) async {
    final messageId = msg["id"] as int?;
    if (messageId == null) return;

    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Report message"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Tell us why this message is being reported."),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: "Reason",
                  errorText: errorText,
                ),
                maxLength: 255,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(
                  labelText: "Details (optional)",
                ),
                maxLines: 3,
                maxLength: 1000,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  setState(() => errorText = "Reason is required");
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );

    final reason = reasonController.text.trim();
    final details = detailsController.text.trim();

    reasonController.dispose();
    detailsController.dispose();

    if (confirmed != true) return;

    try {
      await ReportService.submitReport(
        targetType: "chat_message",
        targetId: messageId,
        reason: reason,
        details: details.isEmpty ? null : details,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report submitted")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to report: $e")),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final senderId = msg["sender_id"] as int?;
                      final isMe = senderId != null && senderId == _userId;
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: isMe ? null : () => _reportMessage(msg),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.blueAccent.withOpacity(0.8)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg["message"] ?? "",
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
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
