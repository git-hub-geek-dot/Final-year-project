import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import '../../services/token_service.dart';
import '../../utils/ist_date_time.dart';
import 'chat_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  bool loading = true;
  List<dynamic> threads = [];
  int? userId;

  @override
  void initState() {
    super.initState();
    loadThreads();
  }

  Future<void> loadThreads() async {
    try {
      final id = await TokenService.getUserId();
      final data = await ChatService.fetchThreads();
      setState(() {
        userId = id;
        threads = data;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  String _formatThreadTime(dynamic raw) {
    if (raw == null) return "";
    final dt = IstDateTime.tryParse(raw);
    if (dt == null) return "";
    final now = IstDateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return "$hh:$mm";
    }
    final month = _shortMonth(dt.month);
    return "$month ${dt.day}";
  }

  String _shortMonth(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inbox"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadThreads,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : threads.isEmpty
              ? const Center(child: Text("No conversations yet"))
              : ListView.builder(
                  itemCount: threads.length,
                  itemBuilder: (context, index) {
                    final item = threads[index] as Map<String, dynamic>;
                    final organiserId = item["organiser_id"] as int?;
                    final eventTitle = item["event_title"] ?? "Event";
                    final lastMessage =
                        item["last_message"] ?? "No messages yet";
                    final unreadCount = item["unread_count"] is int
                        ? item["unread_count"] as int
                        : int.tryParse(
                                item["unread_count"]?.toString() ?? "") ??
                            0;
                    final timeText = _formatThreadTime(item["last_message_at"]);

                    final isOrganiser = organiserId == userId;
                    final peerName = isOrganiser
                        ? (item["volunteer_name"] ?? "Volunteer")
                        : (item["organiser_name"] ?? "Organiser");

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          peerName.toString().isNotEmpty
                              ? peerName.toString().substring(0, 1)
                              : "?",
                        ),
                      ),
                      title: Text(peerName.toString()),
                      subtitle: Text(
                        "$eventTitle\n$lastMessage",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (timeText.isNotEmpty)
                            Text(
                              timeText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          if (unreadCount > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? "99+"
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              threadId: item["id"],
                              title: peerName.toString(),
                            ),
                          ),
                        );
                        await loadThreads();
                      },
                    );
                  },
                ),
    );
  }
}
