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

  Widget _navIcon(IconData icon, int index) {
    final isActive = index == currentIndex;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: isActive
          ? BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Theme(
          data: Theme.of(context).copyWith(
            canvasColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            currentIndex: currentIndex,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
            onTap: (index) => _onTap(context, index),
            items: [
              BottomNavigationBarItem(
                  icon: _navIcon(Icons.home, 0), label: 'Home'),
              BottomNavigationBarItem(
                icon: _navIcon(Icons.leaderboard, 1),
                label: 'Leaderboard',
              ),
              BottomNavigationBarItem(
                icon: _navIcon(Icons.person, 2),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
