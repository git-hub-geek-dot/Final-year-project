import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminLeaderboardScreen extends StatefulWidget {
  const AdminLeaderboardScreen({super.key});

  @override
  State<AdminLeaderboardScreen> createState() =>
      _AdminLeaderboardScreenState();
}

class _AdminLeaderboardScreenState extends State<AdminLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget buildList(
  Future<List<dynamic>> leaderboardFuture,
  Future<List<dynamic>> badgesFuture,
)
 {
   return FutureBuilder<List<dynamic>>(
  future: Future.wait([leaderboardFuture, badgesFuture])
      .then((v) => [v[0], v[1]]),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final leaderboard = snapshot.data![0];
    final badgeRows = snapshot.data![1];
    final badgeMap = buildBadgeMap(badgeRows);

    return ListView.builder(
      itemCount: leaderboard.length,
      itemBuilder: (context, i) {
        final u = leaderboard[i];
        final badges = badgeMap[u["id"]] ?? [];

        return ListTile(
          leading: CircleAvatar(child: Text("#${i + 1}")),
          title: Text(u["name"]),
          subtitle: badges.isEmpty
              ? const Text("No badges yet")
              : Wrap(
                  spacing: 6,
                  children: badges
                      .map((b) => Chip(
                            label: Text(b),
                            backgroundColor: Colors.amber.shade100,
                          ))
                      .toList(),
                ),
          trailing: Text(
            "${u["completed_events"]} events",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  },
);

  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Volunteers"),
            Tab(text: "Organisers"),
          ],
        ),
        Expanded(
          child: TabBarView(
  controller: _tabController,
  children: [
    buildList(
      AdminService.getVolunteerLeaderboard(),
      AdminService.getUserBadges(),
    ),
    buildList(
      AdminService.getOrganiserLeaderboard(),
      AdminService.getUserBadges(),
    ),
  ],
),

        ),
      ],
    );
  }
}

/// ✅ ADDED (exactly as provided, no changes)
Map<int, List<String>> buildBadgeMap(List<dynamic> rows) {
  final map = <int, List<String>>{};
  for (final r in rows) {
    map.putIfAbsent(r["user_id"], () => []);
    map[r["user_id"]]!.add(r["name"]);
  }
  return map;
}
