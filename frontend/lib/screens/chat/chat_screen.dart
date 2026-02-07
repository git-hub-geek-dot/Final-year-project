import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../services/chat_service.dart';
import '../../services/token_service.dart';

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
    _loadMessages();
    _initSocket();
  }

  Future<void> _loadMessages() async {
    try {
      final userId = await TokenService.getUserId();
      final data = await ChatService.fetchMessages(widget.threadId);
      setState(() {
        _userId = userId;
        _messages
          ..clear()
          ..addAll(data.map((e) => Map<String, dynamic>.from(e)));
        _loading = false;
      });
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

    socket.on("newMessage", (data) {
      if (!mounted) return;
      setState(() {
        _messages.add(Map<String, dynamic>.from(data));
      });
    });

    _socket = socket;
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _socket == null) return;

    _socket!.emit("sendMessage", {
      "threadId": widget.threadId,
      "message": text,
    });

    _messageController.clear();
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
