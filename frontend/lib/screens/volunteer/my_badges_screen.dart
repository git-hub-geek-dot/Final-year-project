import 'package:flutter/material.dart';

class MyBadgesScreen extends StatelessWidget {
  const MyBadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final badges = [
      {"name": "Bronze", "range": "1–5 Events", "earned": true},
      {"name": "Silver", "range": "6–15 Events", "earned": true},
      {"name": "Gold", "range": "16–40 Events", "earned": false},
      {"name": "Platinum", "range": "41–75 Events", "earned": false},
      {"name": "Diamond", "range": "76+ Events", "earned": false},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("My Badges")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Current Badge: Silver",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const LinearProgressIndicator(value: 0.4),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  final badge = badges[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.emoji_events,
                        color: badge["earned"] as bool
                            ? Colors.amber
                            : Colors.grey,
                      ),
                      title: Text(badge["name"] as String),
                      subtitle: Text(badge["range"] as String),
                      trailing: badge["earned"] as bool
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.lock_outline),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
