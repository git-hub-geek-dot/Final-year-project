import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';

import '../../services/token_service.dart';
import '../../services/admin_service.dart';
import '../auth/login_screen.dart';
import 'admin_events_screen.dart';
import 'admin_users_screen.dart';
import 'admin_applications_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_leaderboard_screen.dart';
import 'admin_badges_screen.dart';
import 'admin_verification_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = AdminService.getStats();
  }

  void _refreshStats() {
    setState(() {
      _statsFuture = AdminService.getStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<DashboardItem> items = [
      DashboardItem(
        icon: Icons.bar_chart,
        title: 'Stats',
        subtitle: 'View system statistics',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminStatsScreen())),
        color: Colors.blue,
      ),
      DashboardItem(
        icon: Icons.event,
        title: 'Events',
        subtitle: 'Manage events',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminEventsScreen())),
        color: Colors.green,
      ),
      DashboardItem(
        icon: Icons.people,
        title: 'Users',
        subtitle: 'Manage users',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
        color: Colors.orange,
      ),
      DashboardItem(
        icon: Icons.assignment,
        title: 'Applications',
        subtitle: 'Review applications',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminApplicationsScreen())),
        color: Colors.purple,
      ),
      DashboardItem(
        icon: Icons.verified_user,
        title: 'Verification',
        subtitle: 'Verify users',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminVerificationScreen())),
        color: Colors.cyan,
      ),
      DashboardItem(
        icon: Icons.notifications_active,
        title: 'Broadcast',
        subtitle: 'Send notifications',
        onTap: () => _showBroadcastDialog(context),
        color: Colors.teal,
      ),
      DashboardItem(
        icon: Icons.leaderboard,
        title: 'Leaderboard',
        subtitle: 'View leaderboard',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminLeaderboardScreen())),
        color: Colors.red,
      ),
      DashboardItem(
        icon: Icons.military_tech,
        title: 'Badges',
        subtitle: 'Manage badges',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminBadgesScreen())),
        color: Colors.amber,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStats,
          ),
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
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statsFuture,
          builder: (context, snapshot) {
            final stats = snapshot.data;
            final loadingStats =
                snapshot.connectionState == ConnectionState.waiting;
            final hasStatsError = snapshot.hasError;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      loadingStats
                          ? _statSkeletonCard()
                          : _statCard(
                              label: "Users",
                              value: stats?['totalUsers']?.toString() ?? "-",
                              icon: Icons.people,
                              color: Colors.blue,
                            ),
                      const SizedBox(width: 12),
                      loadingStats
                          ? _statSkeletonCard()
                          : _statCard(
                              label: "Events",
                              value: stats?['totalEvents']?.toString() ?? "-",
                              icon: Icons.event,
                              color: Colors.green,
                            ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      loadingStats
                          ? _statSkeletonCard()
                          : _statCard(
                              label: "Pending Verifications",
                              value:
                                  stats?['pendingVerifications']?.toString() ??
                                      "-",
                              icon: Icons.verified_user,
                              color: Colors.orange,
                            ),
                      const SizedBox(width: 12),
                      loadingStats
                          ? _statSkeletonCard()
                          : _statCard(
                              label: "Applications",
                              value: stats?['totalApplications']?.toString() ??
                                  "-",
                              icon: Icons.assignment,
                              color: Colors.purple,
                            ),
                    ],
                  ),
                ),
                if (hasStatsError && !loadingStats)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _statsErrorBanner(),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width < 600
                          ? 2
                          : width < 900
                              ? 3
                              : 4;
                      final childAspectRatio = width < 600 ? 1.1 : 1.0;

                      return GridView.builder(
                        padding: const EdgeInsets.all(16.0),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16.0,
                          mainAxisSpacing: 16.0,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Card(
                            elevation: 8.0,
                            shadowColor: item.color.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: InkWell(
                              onTap: item.onTap,
                              borderRadius: BorderRadius.circular(20.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.0),
                                  gradient: LinearGradient(
                                    colors: [
                                      item.color.withValues(alpha: 0.8),
                                      item.color.withValues(alpha: 0.6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        item.icon,
                                        size: 32.0,
                                        color: Colors.white,
                                      ),
                                    ),
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
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statsErrorBanner() {
    return Card(
      color: Colors.red.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Failed to load dashboard stats.",
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _refreshStats,
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statSkeletonCard() {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 36,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedRole = 'all';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Send Broadcast Notification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter notification title',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Enter notification message',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 500,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Target Audience',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(
                        value: 'volunteer', child: Text('Volunteers Only')),
                    DropdownMenuItem(
                        value: 'organiser', child: Text('Organizers Only')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty ||
                          messageController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all fields'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        await AdminService.sendBroadcastNotification(
                          title: titleController.text.trim(),
                          message: messageController.text.trim(),
                          targetRole: selectedRole,
                        );

                        if (context.mounted) {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Notification sent to ${selectedRole == 'all' ? 'all users' : selectedRole + 's'}!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to send notification: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send'),
            ),
          ],
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
