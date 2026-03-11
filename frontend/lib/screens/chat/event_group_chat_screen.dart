import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import '../../services/token_service.dart';

class EventGroupChatScreen extends StatefulWidget {
  final int eventId;
  final String eventTitle;

  const EventGroupChatScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<EventGroupChatScreen> createState() => _EventGroupChatScreenState();
}

class _EventGroupChatScreenState extends State<EventGroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool loading = true;
  bool sending = false;
  List<dynamic> messages = [];
  int? userId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final id = await TokenService.getUserId();
    if (!mounted) return;
    setState(() => userId = id);
    await _loadMessages();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() => loading = true);
      }

      final data = await ChatService.fetchEventGroupMessages(widget.eventId);
      if (!mounted) return;

      setState(() {
        messages = (data["messages"] as List?) ?? [];
        loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || sending) return;

    setState(() => sending = true);
    try {
      final sent = await ChatService.sendEventGroupMessage(
        eventId: widget.eventId,
        message: text,
      );

      _messageController.clear();
      if (!mounted) return;
      setState(() {
        messages = [...messages, sent];
        sending = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send: $e")),
      );
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return "";
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return "";
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.eventTitle} - Group Chat"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text("No messages yet"))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final row = messages[index] as Map<String, dynamic>;
                          final senderId = row["sender_id"] as int?;
                          final mine = senderId != null && senderId == userId;
                          final senderName =
                              (row["sender_name"] ?? "Member").toString();
                          final message = (row["message"] ?? "").toString();
                          final time = _formatTime(row["created_at"]);

                          return Align(
                            alignment:
                                mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.all(10),
                              constraints: const BoxConstraints(maxWidth: 320),
                              decoration: BoxDecoration(
                                color: mine
                                    ? const Color(0xFFD8F5E7)
                                    : const Color(0xFFF0F3F7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!mine)
                                    Text(
                                      senderName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(message),
                                  const SizedBox(height: 4),
                                  Text(
                                    time,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: "Type a message",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
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
