import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';

import '../../services/token_service.dart';
import '../auth/login_screen.dart';
import 'admin_events_screen.dart';
import 'admin_users_screen.dart';
import 'admin_applications_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_leaderboard_screen.dart';
import  'admin_badges_screen.dart';


class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Stats"),
            Tab(text: "Events"),
            Tab(text: "Users"),
            Tab(text: "Applications"),
            Tab(text: "Leaderboard"),
            Tab(text: "Badges"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await TokenService.clearToken();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          )
        ],
      ),
      body: AppBackground(
        child: TabBarView(
          controller: _tabController,
          children: const [
            AdminStatsScreen(),
            AdminEventsScreen(),
            AdminUsersScreen(),
            AdminApplicationsScreen(),
            AdminLeaderboardScreen(),
            AdminBadgesScreen(),
          ],
        ),
      ),
    );
  }
}
