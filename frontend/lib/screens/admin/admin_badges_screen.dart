import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import '../../services/admin_service.dart';

class AdminBadgesScreen extends StatefulWidget {
  const AdminBadgesScreen({super.key});

  @override
  State<AdminBadgesScreen> createState() => _AdminBadgesScreenState();
}

class _AdminBadgesScreenState extends State<AdminBadgesScreen> {
  late Future<List<dynamic>> badgesFuture;

  @override
  void initState() {
    super.initState();
    badgesFuture = AdminService.getBadges();
  }

  void refresh() {
    setState(() {
      badgesFuture = AdminService.getBadges();
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Color _badgeBaseColor(Map<String, dynamic> badge) {
    final name = (badge["name"] ?? "").toString().toLowerCase();
    final threshold = _toInt(badge["threshold"]);

    if (name.contains("bronze")) return const Color(0xFFCD7F32);
    if (name.contains("silver")) return const Color(0xFFC0C0C0);
    if (name.contains("gold")) return const Color(0xFFFFD700);
    if (name.contains("platinum")) return const Color(0xFFE5E4E2);
    if (name.contains("diamond")) return const Color(0xFF4FC3F7);

    if (threshold >= 50) return const Color(0xFFFFD700);
    if (threshold >= 20) return const Color(0xFFC0C0C0);
    return const Color(0xFFCD7F32);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badge Overview'),
        actions: [
          IconButton(
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: AppBackground(
        child: FutureBuilder<List<dynamic>>(
          future: badgesFuture,
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text("No badges configured in system."),
              );
            }

            final badges = snapshot.data!;

            return ListView.builder(
              itemCount: badges.length,
              itemBuilder: (_, i) {
                final badge = Map<String, dynamic>.from(badges[i] as Map);
                final color = _badgeBaseColor(badge);
                return ListTile(
                  leading: Icon(Icons.emoji_events, color: color, size: 36),
                  title: Text(
                    (badge["name"] ?? "Badge").toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${badge["role"]} - Requires ${badge["threshold"]} events",
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "System",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
