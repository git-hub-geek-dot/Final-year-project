import 'package:flutter/material.dart';

import '../../widgets/organiser_bottom_nav.dart';
import '../shared/role_leaderboard_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Organiser screen should default to the Organisers tab.
    return const RoleLeaderboardScreen(
      initialTab: 0,
      bottomNavigationBar: OrganiserBottomNav(currentIndex: 1),
    );
  }
}
