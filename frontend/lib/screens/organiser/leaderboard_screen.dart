import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 🔷 HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
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
                  "Volunteerx",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.notifications, color: Colors.white),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 🏆 TITLE
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Organisers Leaderboard",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 📋 LEADERBOARD LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: const [
                LeaderboardTile(
                  rank: 1,
                  name: "Ankit Verma",
                  city: "Bengaluru",
                  score: "98 pts",
                ),
                LeaderboardTile(
                  rank: 2,
                  name: "Rahul Sharma",
                  city: "Mumbai",
                  score: "92 pts",
                ),
                LeaderboardTile(
                  rank: 3,
                  name: "Neha Gupta",
                  city: "Delhi",
                  score: "88 pts",
                ),
                LeaderboardTile(
                  rank: 4,
                  name: "Amit Patel",
                  city: "Ahmedabad",
                  score: "81 pts",
                ),
                LeaderboardTile(
                  rank: 5,
                  name: "Sneha Iyer",
                  city: "Chennai",
                  score: "77 pts",
                ),
              ],
            ),
          ),
        ],
      ),

      // 🔻 BOTTOM NAVIGATION BAR
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // 👈 Leaderboard selected
        selectedItemColor: const Color(0xFF22C55E),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/organiser-home');
          } else if (index == 2) {
            Navigator.pushReplacementNamed(
                context, '/organiser-profile');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: "Leaderboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

/// 🏅 LEADERBOARD TILE
class LeaderboardTile extends StatelessWidget {
  final int rank;
  final String name;
  final String city;
  final String score;

  const LeaderboardTile({
    super.key,
    required this.rank,
    required this.name,
    required this.city,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Text(
              rank.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF22C55E),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  city,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            score,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
