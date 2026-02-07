import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import '../../services/token_service.dart';
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
                        item["last_message"] ?? "Tap to open";

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
                      subtitle: Text("$eventTitle · $lastMessage"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              threadId: item["id"],
                              title: peerName.toString(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
