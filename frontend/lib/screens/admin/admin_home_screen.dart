import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';

import '../../services/token_service.dart';
import '../auth/login_screen.dart';
import 'admin_events_screen.dart';
import 'admin_users_screen.dart';
import 'admin_applications_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_leaderboard_screen.dart';
import 'admin_badges_screen.dart';
import 'admin_verification_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DashboardItem> items = [
      DashboardItem(
        icon: Icons.bar_chart,
        title: 'Stats',
        subtitle: 'View system statistics',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminStatsScreen())),
        color: Colors.blue,
      ),
      DashboardItem(
        icon: Icons.event,
        title: 'Events',
        subtitle: 'Manage events',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEventsScreen())),
        color: Colors.green,
      ),
      DashboardItem(
        icon: Icons.people,
        title: 'Users',
        subtitle: 'Manage users',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
        color: Colors.orange,
      ),
      DashboardItem(
        icon: Icons.assignment,
        title: 'Applications',
        subtitle: 'Review applications',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApplicationsScreen())),
        color: Colors.purple,
      ),
      DashboardItem(
        icon: Icons.verified_user,
        title: 'Verification',
        subtitle: 'Verify users',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminVerificationScreen())),
        color: Colors.cyan,
      ),
      DashboardItem(
        icon: Icons.leaderboard,
        title: 'Leaderboard',
        subtitle: 'View leaderboard',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLeaderboardScreen())),
        color: Colors.red,
      ),
      DashboardItem(
        icon: Icons.military_tech,
        title: 'Badges',
        subtitle: 'Manage badges',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBadgesScreen())),
        color: Colors.amber,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await TokenService.clearToken();
              if (!context.mounted) return;
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
        child: GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            childAspectRatio: 1.2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    gradient: LinearGradient(
                      colors: [item.color.withOpacity(0.7), item.color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 48.0, color: Colors.white),
                      const SizedBox(height: 12.0),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 12.0,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class DashboardItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  DashboardItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });
}
