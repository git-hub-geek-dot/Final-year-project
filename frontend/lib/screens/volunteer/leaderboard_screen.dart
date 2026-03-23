import 'package:flutter/material.dart';

import '../shared/role_leaderboard_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Volunteer screen should default to the Volunteers tab.
    return const RoleLeaderboardScreen(initialTab: 1);
  }
}
