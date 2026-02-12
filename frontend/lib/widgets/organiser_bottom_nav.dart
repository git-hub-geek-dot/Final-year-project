import 'package:flutter/material.dart';

import '../screens/organiser/leaderboard_screen.dart';

class OrganiserBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isRootScreen;

  const OrganiserBottomNav({
    super.key,
    required this.currentIndex,
    this.isRootScreen = true,
  });

  void _onTap(BuildContext context, int index) {
    if (isRootScreen && index == currentIndex) return;

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/organiser-home');
      return;
    }

    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
      );
      return;
    }

    Navigator.pushReplacementNamed(context, '/organiser-profile');
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: const Color(0xFF22C55E),
      unselectedItemColor: Colors.grey,
      onTap: (index) => _onTap(context, index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.leaderboard),
          label: 'Leaderboard',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
