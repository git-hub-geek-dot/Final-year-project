import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../services/chat_service.dart';
import '../../utils/ist_date_time.dart';
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
  static const Duration _ackTimeout = Duration(seconds: 8);

  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final Map<String, Timer> _ackTimers = {};
  bool _loading = true;
  String? _loadError;
  bool _threadUnavailable = false;
  bool _isSocketConnected = false;
  io.Socket? _socket;
  int? _userId;
  int _localMessageSeed = 0;

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
          .map((e) => _normalizeMessage(Map<String, dynamic>.from(e)))
          .toList();

      for (final msg in decoded) {
        if (_deliveryStatus(msg) == "sending") {
          msg["delivery_status"] = "failed";
        }
      }

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
      if (mounted) {
        setState(() {
          _loading = true;
          _loadError = null;
          _threadUnavailable = false;
        });
      }
      final userId = await TokenService.getUserId();
      final data = await ChatService.fetchMessages(widget.threadId);
      final pendingLocal = _messages
          .where((m) =>
              _deliveryStatus(m) == "failed" || _deliveryStatus(m) == "sending")
          .map((m) {
        final copy = _normalizeMessage(Map<String, dynamic>.from(m));
        if (_deliveryStatus(copy) == "sending") {
          copy["delivery_status"] = "failed";
        }
        return copy;
      }).toList();

      final messages = data
          .map((e) => _normalizeMessage(Map<String, dynamic>.from(e)))
          .toList();

      for (final local in pendingLocal) {
        final localClientId = (local["client_message_id"] ?? "").toString();
        final localServerId = local["id"];

        final exists = messages.any((server) {
          final serverClientId = (server["client_message_id"] ?? "").toString();
          final sameClientId = localClientId.isNotEmpty &&
              serverClientId.isNotEmpty &&
              localClientId == serverClientId;
          final sameServerId =
              localServerId != null && server["id"] == localServerId;
          return sameClientId || sameServerId;
        });

        if (!exists) {
          messages.add(local);
        }
      }

      setState(() {
        _userId = userId;
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
        _loadError = null;
        _threadUnavailable = false;
      });
      await _saveCachedMessages();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst("Exception: ", "").trim();
      final lower = raw.toLowerCase();
      final unavailable = lower.contains("not found") ||
          lower.contains("not allowed") ||
          lower.contains("no longer available");
      setState(() {
        _loading = false;
        _loadError = raw.isEmpty ? "Failed to load messages" : raw;
        _threadUnavailable = unavailable;
      });
    }
  }

  Future<void> _initSocket() async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) return;

    final socket = io.io(
      ChatService.socketUrl(),
      io.OptionBuilder()
          // Try websocket-only to isolate polling handshake issues on emulator.
          .setTransports(['websocket'])
          .setTimeout(20000)
          .setAuth({"token": token})
          .enableReconnection()
          .enableForceNew()
          .build(),
    );

    socket.onConnect((_) {
      debugPrint("Chat socket connected");
      if (mounted) {
        setState(() {
          _isSocketConnected = true;
        });
      }
      socket.emit("joinThread", {"threadId": widget.threadId});
      _retryFailedMessages();
    });

    socket.on("reconnect", (_) {
      debugPrint("Chat socket reconnected");
      if (mounted) {
        setState(() {
          _isSocketConnected = true;
        });
      }
      socket.emit("joinThread", {"threadId": widget.threadId});
      _retryFailedMessages();
    });

    socket.onDisconnect((reason) {
      debugPrint("Chat socket disconnected: $reason");
      if (!mounted) return;
      setState(() {
        _isSocketConnected = false;
      });
    });

    socket.onConnectError((error) {
      debugPrint("Chat socket connect error: $error");
      if (!mounted) return;
      setState(() {
        _isSocketConnected = false;
      });
    });

    socket.on("newMessage", (data) {
      if (data is! Map) return;
      _upsertIncomingMessage(Map<String, dynamic>.from(data));
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

    socket.on("messageAck", (data) {
      if (data is! Map) return;
      final payload = Map<String, dynamic>.from(data);
      final clientMessageId = (payload["clientMessageId"] ?? "").toString();
      if (clientMessageId.isNotEmpty) {
        _cancelAckTimer(clientMessageId);
      }

      final message = payload["message"];
      if (message is Map) {
        final normalized = Map<String, dynamic>.from(message);
        if (normalized["client_message_id"] == null &&
            clientMessageId.isNotEmpty) {
          normalized["client_message_id"] = clientMessageId;
        }
        _upsertIncomingMessage(normalized);
      } else if (clientMessageId.isNotEmpty) {
        _markMessageSent(clientMessageId);
      }
    });

    socket.on("messageFailed", (data) {
      if (data is! Map) return;
      final payload = Map<String, dynamic>.from(data);
      final clientMessageId = (payload["clientMessageId"] ?? "").toString();
      final errorMessage = (payload["message"] ?? "").toString();
      if (clientMessageId.isEmpty) return;
      _cancelAckTimer(clientMessageId);
      _markMessageFailed(
        clientMessageId,
        snackMessage: errorMessage.isEmpty ? null : errorMessage,
      );
    });

    _socket = socket;
  }

  Future<void> _sendMessage() async {
    if (_threadUnavailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This chat is no longer available.")),
      );
      return;
    }
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_socket != null && _socket!.connected) {
      await _emitSocketMessage(text: text);
      _messageController.clear();
      return;
    }

    final message = await _connectionErrorMessage();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _emitSocketMessage({
    required String text,
    int? replaceIndex,
  }) async {
    if (_socket == null || !_socket!.connected) return;

    final clientMessageId = _newClientMessageId();
    final local = _normalizeMessage({
      "thread_id": widget.threadId,
      "sender_id": _userId,
      "message": text,
      "created_at": IstDateTime.now().toIso8601String(),
      "client_message_id": clientMessageId,
      "delivery_status": "sending",
      "local_only": true,
    });

    if (!mounted) return;
    setState(() {
      if (replaceIndex != null &&
          replaceIndex >= 0 &&
          replaceIndex < _messages.length) {
        _messages[replaceIndex] = {
          ..._messages[replaceIndex],
          ...local,
        };
      } else {
        _messages.add(local);
      }
    });
    await _saveCachedMessages();

    _socket!.emit("sendMessage", {
      "threadId": widget.threadId,
      "message": text,
      "clientMessageId": clientMessageId,
    });

    _startAckTimer(clientMessageId);
  }

  Future<void> _retryMessage(Map<String, dynamic> msg) async {
    if (_socket == null || !_socket!.connected) {
      final error = await _connectionErrorMessage();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final text = (msg["message"] ?? "").toString().trim();
    if (text.isEmpty) return;

    final idx = _messages.indexOf(msg);
    await _emitSocketMessage(
      text: text,
      replaceIndex: idx >= 0 ? idx : null,
    );
  }

  Future<void> _retryFailedMessages() async {
    if (_socket == null || !_socket!.connected) return;

    final failedIndexes = <int>[];
    for (var i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (!_isMine(msg)) continue;
      if (_deliveryStatus(msg) != "failed") continue;
      failedIndexes.add(i);
    }

    for (final idx in failedIndexes) {
      if (idx < 0 || idx >= _messages.length) continue;
      final text = (_messages[idx]["message"] ?? "").toString().trim();
      if (text.isEmpty) continue;
      await _emitSocketMessage(text: text, replaceIndex: idx);
    }
  }

  void _startAckTimer(String clientMessageId) {
    _cancelAckTimer(clientMessageId);
    _ackTimers[clientMessageId] = Timer(_ackTimeout, () {
      _ackTimers.remove(clientMessageId);
      _markMessageFailed(clientMessageId);
    });
  }

  void _cancelAckTimer(String clientMessageId) {
    final timer = _ackTimers.remove(clientMessageId);
    timer?.cancel();
  }

  void _markMessageSent(String clientMessageId) {
    final idx = _messages.indexWhere(
      (m) => (m["client_message_id"] ?? "").toString() == clientMessageId,
    );
    if (idx < 0) return;

    final current =
        _normalizeMessage(Map<String, dynamic>.from(_messages[idx]));
    if (_deliveryStatus(current) == "sent") return;

    if (!mounted) return;
    setState(() {
      _messages[idx] = {
        ...current,
        "delivery_status": "sent",
        "local_only": false,
      };
    });
    _saveCachedMessages();
  }

  void _markMessageFailed(
    String clientMessageId, {
    String? snackMessage,
  }) {
    final idx = _messages.indexWhere(
      (m) => (m["client_message_id"] ?? "").toString() == clientMessageId,
    );
    if (idx < 0) return;

    final current =
        _normalizeMessage(Map<String, dynamic>.from(_messages[idx]));
    if (_deliveryStatus(current) == "sent") return;

    if (!mounted) return;
    setState(() {
      _messages[idx] = {
        ...current,
        "delivery_status": "failed",
      };
    });
    _saveCachedMessages();

    if (snackMessage != null && snackMessage.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snackMessage)),
      );
    }
  }

  void _upsertIncomingMessage(Map<String, dynamic> incoming) {
    final normalized = _normalizeMessage(incoming);
    final incomingClientId =
        (normalized["client_message_id"] ?? "").toString().trim();

    var updated = false;

    if (incomingClientId.isNotEmpty) {
      final byClientId = _messages.indexWhere(
        (m) => (m["client_message_id"] ?? "").toString() == incomingClientId,
      );
      if (byClientId >= 0) {
        _cancelAckTimer(incomingClientId);
        if (mounted) {
          setState(() {
            _messages[byClientId] = {
              ..._messages[byClientId],
              ...normalized,
              "delivery_status": "sent",
              "local_only": false,
            };
          });
        }
        updated = true;
      }
    }

    final incomingId = normalized["id"];
    if (!updated && incomingId != null) {
      final byServerId = _messages.indexWhere((m) => m["id"] == incomingId);
      if (byServerId >= 0) {
        if (mounted) {
          setState(() {
            _messages[byServerId] = {
              ..._messages[byServerId],
              ...normalized,
              "delivery_status": "sent",
              "local_only": false,
            };
          });
        }
        updated = true;
      }
    }

    if (!updated && mounted) {
      setState(() {
        _messages.add({
          ...normalized,
          "delivery_status": "sent",
          "local_only": false,
        });
      });
    }

    _saveCachedMessages();
  }

  String _newClientMessageId() {
    _localMessageSeed += 1;
    return "${DateTime.now().millisecondsSinceEpoch}_$_localMessageSeed";
  }

  Map<String, dynamic> _normalizeMessage(Map<String, dynamic> input) {
    final normalized = Map<String, dynamic>.from(input);
    normalized["delivery_status"] =
        (normalized["delivery_status"] ?? "sent").toString();
    return normalized;
  }

  bool _isMine(Map<String, dynamic> msg) {
    final sender = msg["sender_id"];
    final senderId = sender is int ? sender : int.tryParse("$sender");
    return _userId != null && senderId == _userId;
  }

  String _deliveryStatus(Map<String, dynamic> msg) {
    return (msg["delivery_status"] ?? "sent").toString();
  }

  Widget _deliveryMeta(Map<String, dynamic> msg) {
    final status = _deliveryStatus(msg);
    if (status == "sending") {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.schedule, size: 12, color: Colors.white70),
          SizedBox(width: 4),
          Text(
            "Sending...",
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      );
    }

    if (status == "failed") {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.error_outline, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            "Not sent. Tap to retry",
            style: TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _connectionStatusPill() {
    final isConnected = _isSocketConnected;
    final color = isConnected ? Colors.green : Colors.orange;
    final text = isConnected ? "Connected" : "Connecting";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _connectionErrorMessage() async {
    final baseUrl = ChatService.socketUrl();
    try {
      await http.get(Uri.parse(baseUrl)).timeout(const Duration(seconds: 2));
      return "Disconnected from chat server. Please try again.";
    } on TimeoutException {
      return "Disconnected from chat server. Please try again.";
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains("failed host lookup") ||
          msg.contains("network is unreachable") ||
          msg.contains("socketexception")) {
        return "No internet connection.";
      }
      return "Disconnected from chat server. Please try again.";
    }
  }

  Future<void> _reportMessage(Map<String, dynamic> msg) async {
    final messageId = msg["id"] as int?;
    if (messageId == null) return;

    const reasonOptions = [
      "Harassment or abuse",
      "Spam",
      "Fraud or scam",
      "Hate speech",
      "Inappropriate content",
      "Other",
    ];
    final customReasonController = TextEditingController();
    final detailsController = TextEditingController();
    String? selectedReason;
    String? reasonErrorText;
    String? customReasonErrorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Report message"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Tell us why this message is being reported."),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: InputDecoration(
                    labelText: "Reason category",
                    errorText: reasonErrorText,
                  ),
                  isExpanded: true,
                  items: reasonOptions
                      .map(
                        (reason) => DropdownMenuItem<String>(
                          value: reason,
                          child: Text(reason),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                      reasonErrorText = null;
                      if (value != "Other") {
                        customReasonErrorText = null;
                      }
                    });
                  },
                ),
                if (selectedReason == "Other") ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customReasonController,
                    decoration: InputDecoration(
                      labelText: "Custom reason",
                      errorText: customReasonErrorText,
                    ),
                    maxLength: 255,
                    onChanged: (_) {
                      if (customReasonErrorText != null) {
                        setState(() => customReasonErrorText = null);
                      }
                    },
                  ),
                ],
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final selected = selectedReason?.trim();
                final custom = customReasonController.text.trim();

                if (selected == null || selected.isEmpty) {
                  setState(() => reasonErrorText = "Reason is required");
                  return;
                }

                if (selected == "Other" && custom.isEmpty) {
                  setState(
                    () => customReasonErrorText = "Custom reason is required",
                  );
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

    final selected = (selectedReason ?? "").trim();
    final reason =
        selected == "Other" ? customReasonController.text.trim() : selected;
    final details = detailsController.text.trim();

    customReasonController.dispose();
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
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    _ackTimers.clear();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputDisabled = _threadUnavailable;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(widget.title)),
            _connectionStatusPill(),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_loadError != null)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loadError!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadMessages,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          if (!_isSocketConnected)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: const [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Connecting to chat... messages may not send.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = _isMine(msg);
                      final status = _deliveryStatus(msg);
                      final isFailed = isMe && status == "failed";
                      final showDeliveryMeta =
                          isMe && (status == "sending" || status == "failed");

                      final bubbleColor = isMe
                          ? (isFailed
                              ? Colors.red.shade400
                              : Colors.blueAccent.withValues(alpha: 0.8))
                          : Colors.grey.shade200;

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: isFailed ? () => _retryMessage(msg) : null,
                          onLongPress: isMe ? null : () => _reportMessage(msg),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: bubbleColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  msg["message"] ?? "",
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              if (showDeliveryMeta)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      right: 4, left: 4, bottom: 2),
                                  child: _deliveryMeta(msg),
                                ),
                            ],
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
                      enabled: !inputDisabled,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: inputDisabled ? null : _sendMessage,
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
