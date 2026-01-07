import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TEMP: current organiser rank (later from backend)
    const int currentOrganiserRank = 3;

    return Scaffold(
      body: Column(
        children: [
          // 🔷 HEADER
          Container(
            height: 160,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(40),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "Organiser Leaderboard",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.emoji_events, color: Colors.white),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ⭐ CURRENT ORGANISER RANK CARD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.green),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "You (Current Organiser)",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Rank #3 • 12 Events • 4.7 ⭐",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.star, color: Colors.amber),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 📋 ORGANISER RANKING LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                organiserTile(
                  rank: 1,
                  name: "Rahul Events",
                  events: 22,
                  rating: "4.9",
                  isTop: true,
                ),
                organiserTile(
                  rank: 2,
                  name: "Goa Social Group",
                  events: 18,
                  rating: "4.8",
                ),
                organiserTile(
                  rank: 3,
                  name: "You",
                  events: 12,
                  rating: "4.7",
                  highlight: true,
                ),
                organiserTile(
                  rank: 4,
                  name: "Helping Hands",
                  events: 9,
                  rating: "4.5",
                ),
                organiserTile(
                  rank: 5,
                  name: "Youth Club",
                  events: 7,
                  rating: "4.2",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🧩 ORGANISER TILE
Widget organiserTile({
  required int rank,
  required String name,
  required int events,
  required String rating,
  bool highlight = false,
  bool isTop = false,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: highlight ? Colors.green.withOpacity(0.1) : Colors.white,
      border: Border.all(
        color: highlight ? Colors.green : Colors.grey.shade300,
        width: highlight ? 1.5 : 1,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        // Rank badge
        CircleAvatar(
          radius: 18,
          backgroundColor: isTop ? Colors.amber : Colors.grey.shade200,
          child: Text(
            "#$rank",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(width: 12),

        const CircleAvatar(child: Icon(Icons.business)),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$events Events • $rating ⭐",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        if (isTop)
          const Icon(Icons.emoji_events, color: Colors.amber),
      ],
    ),
  );
}

