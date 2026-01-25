import 'package:flutter/material.dart';
import 'dart:math';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  bool isWeekly = true;
  int _selectedTab = 1;

  late AnimationController _confettiController;

  /// ✅ VOLUNTEER DATA
  final List<Map<String, dynamic>> volunteerWeeklyData = [
    {"rank": 1, "name": "Amit Sharma", "events": 42},
    {"rank": 2, "name": "Neha Verma", "events": 36},
    {"rank": 3, "name": "Rahul Mehta", "events": 31},
    {"rank": 4, "name": "You", "events": 24},
    {"rank": 5, "name": "Sanjay Rao", "events": 22},
  ];

  final List<Map<String, dynamic>> volunteerMonthlyData = [
    {"rank": 1, "name": "Neha Verma", "events": 120},
    {"rank": 2, "name": "Amit Sharma", "events": 115},
    {"rank": 3, "name": "You", "events": 98},
    {"rank": 4, "name": "Rahul Mehta", "events": 91},
    {"rank": 5, "name": "Sanjay Rao", "events": 84},
  ];

  /// ✅ ORGANISER DATA
  final List<Map<String, dynamic>> organiserWeeklyData = [
    {"rank": 1, "name": "Ankit Verma", "events": 18},
    {"rank": 2, "name": "Rahul Sharma", "events": 16},
    {"rank": 3, "name": "Neha Gupta", "events": 15},
    {"rank": 4, "name": "Amit Patel", "events": 12},
    {"rank": 5, "name": "Sneha Iyer", "events": 11},
  ];

  final List<Map<String, dynamic>> organiserMonthlyData = [
    {"rank": 1, "name": "Rahul Sharma", "events": 54},
    {"rank": 2, "name": "Ankit Verma", "events": 49},
    {"rank": 3, "name": "Neha Gupta", "events": 47},
    {"rank": 4, "name": "Amit Patel", "events": 41},
    {"rank": 5, "name": "Sneha Iyer", "events": 38},
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _getLeaderboardData();

    final yourRank =
        data.firstWhere((e) => e["name"] == "You", orElse: () => {});

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Leaderboard"),
        backgroundColor: const Color(0xFF2E6BE6),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          /// 🔁 ORGANISER / VOLUNTEER TOGGLE
          _roleToggleBar(),

          const SizedBox(height: 12),

          /// 🔁 WEEK / MONTH TOGGLE
          _toggleBar(),

          const SizedBox(height: 16),

          /// 🥇 TOP 3
          _topThree(data),

          const SizedBox(height: 16),

          /// 📌 YOUR RANK (PINNED)
          if (yourRank.isNotEmpty) _yourRankCard(yourRank),

          const SizedBox(height: 12),

          /// 📋 FULL LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final user = data[index];

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _rankCard(
                    key: ValueKey("${user["rank"]}-${isWeekly}"),
                    rank: user["rank"],
                    name: user["name"],
                    events: user["events"],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ================= TOGGLE =================
  List<Map<String, dynamic>> _getLeaderboardData() {
    if (_selectedTab == 0) {
      return isWeekly ? organiserWeeklyData : organiserMonthlyData;
    }
    return isWeekly ? volunteerWeeklyData : volunteerMonthlyData;
  }

  Widget _roleToggleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _roleToggleButton("Organisers", _selectedTab == 0, () {
            setState(() => _selectedTab = 0);
          }),
          _roleToggleButton("Volunteers", _selectedTab == 1, () {
            setState(() => _selectedTab = 1);
          }),
        ],
      ),
    );
  }

  Widget _roleToggleButton(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2E6BE6) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _toggleButton("Weekly", isWeekly, () {
            setState(() => isWeekly = true);
          }),
          _toggleButton("Monthly", !isWeekly, () {
            setState(() => isWeekly = false);
          }),
        ],
      ),
    );
  }

  Widget _toggleButton(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2E6BE6) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// ================= TOP 3 =================
  Widget _topThree(List<Map<String, dynamic>> data) {
    final top3 = data.take(3).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: top3.map((user) {
        final rank = user["rank"];
        final isFirst = rank == 1;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: 90,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isFirst
                        ? Colors.amber.withOpacity(0.6)
                        : Colors.black12,
                    blurRadius: isFirst ? 16 : 6,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 32,
                    color: rank == 1
                        ? Colors.amber
                        : rank == 2
                            ? Colors.grey
                            : Colors.brown,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user["name"],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text("${user["events"]} events",
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),

            /// 🎉 CONFETTI (RANK 1 ONLY)
            if (isFirst)
              Positioned(
                top: -10,
                child: _confetti(),
              ),
          ],
        );
      }).toList(),
    );
  }

  /// ================= CONFETTI =================
  Widget _confetti() {
    return AnimatedBuilder(
      animation: _confettiController,
      builder: (_, __) {
        return Row(
          children: List.generate(5, (i) {
            return Transform.translate(
              offset: Offset(
                sin(_confettiController.value * 2 * pi + i) * 6,
                _confettiController.value * 10,
              ),
              child: const Icon(Icons.circle, size: 6, color: Colors.amber),
            );
          }),
        );
      },
    );
  }

  /// ================= YOUR RANK =================
  Widget _yourRankCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2E6BE6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Your Rank: #${user["rank"]}",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            "${user["events"]} events",
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// ================= RANK CARD =================
  Widget _rankCard({
    required int rank,
    required String name,
    required int events,
    Key? key,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E6BE6),
          child: Text(
            "#$rank",
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(name),
        subtitle: Text("$events events completed"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
