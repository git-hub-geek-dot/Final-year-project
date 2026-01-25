import 'package:flutter/material.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _selectedTab = 0;

  final List<_LeaderboardEntry> _organiserLeaders = const [
    _LeaderboardEntry(rank: 1, name: "Ankit Verma", city: "Bengaluru", score: "98 pts"),
    _LeaderboardEntry(rank: 2, name: "Rahul Sharma", city: "Mumbai", score: "92 pts"),
    _LeaderboardEntry(rank: 3, name: "Neha Gupta", city: "Delhi", score: "88 pts"),
    _LeaderboardEntry(rank: 4, name: "Amit Patel", city: "Ahmedabad", score: "81 pts"),
    _LeaderboardEntry(rank: 5, name: "Sneha Iyer", city: "Chennai", score: "77 pts"),
  ];

  final List<_LeaderboardEntry> _volunteerLeaders = const [
    _LeaderboardEntry(rank: 1, name: "Pooja Menon", city: "Pune", score: "105 pts"),
    _LeaderboardEntry(rank: 2, name: "Vikram Joshi", city: "Hyderabad", score: "97 pts"),
    _LeaderboardEntry(rank: 3, name: "Ishita Roy", city: "Kolkata", score: "90 pts"),
    _LeaderboardEntry(rank: 4, name: "Karan Singh", city: "Jaipur", score: "84 pts"),
    _LeaderboardEntry(rank: 5, name: "Meera Nair", city: "Kochi", score: "79 pts"),
  ];

  @override
  Widget build(BuildContext context) {
    final leaders = _selectedTab == 0 ? _organiserLeaders : _volunteerLeaders;

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
                "Leaderboard",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _LeaderboardTabButton(
                      label: "Organisers",
                      selected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _LeaderboardTabButton(
                      label: "Volunteers",
                      selected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 📋 LEADERBOARD LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: leaders.length,
              itemBuilder: (context, index) {
                final leader = leaders[index];
                return LeaderboardTile(
                  rank: leader.rank,
                  name: leader.name,
                  city: leader.city,
                  score: leader.score,
                );
              },
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

class _LeaderboardEntry {
  final int rank;
  final String name;
  final String city;
  final String score;

  const _LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.city,
    required this.score,
  });
}

class _LeaderboardTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LeaderboardTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                )
              : null,
          color: selected ? null : Colors.white,
          border: Border.all(
            color: selected ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
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
