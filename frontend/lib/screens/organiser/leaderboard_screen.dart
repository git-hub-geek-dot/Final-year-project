import 'dart:math';

import 'package:flutter/material.dart';
import '../../services/event_service.dart';
import '../../widgets/organiser_bottom_nav.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  bool isWeekly = true;
  int _selectedTab = 0; // 0: Organisers, 1: Volunteers
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _leaders = [];

  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final role = _selectedTab == 0 ? "organisers" : "volunteers";
      final period = isWeekly ? "weekly" : "monthly";
      final raw = await EventService.fetchLeaderboard(role: role, period: period);

      final parsed = <Map<String, dynamic>>[];
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i] as Map;
        final name = item["name"]?.toString() ?? "Unknown";
        final events = int.tryParse(item["completed_events"].toString()) ?? 0;
        parsed.add({
          "rank": i + 1,
          "name": name,
          "events": events,
        });
      }

      if (!mounted) return;
      setState(() {
        _leaders = parsed;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Failed to load leaderboard";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _leaders;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Leaderboard"),
        backgroundColor: const Color(0xFF2E6BE6),
      ),
      body: RefreshIndicator(
        onRefresh: _loadLeaderboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const SizedBox(height: 12),
            _roleToggleBar(),
            const SizedBox(height: 12),
            _periodToggleBar(),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 120),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _loadLeaderboard,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            else if (data.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 120),
                child: Center(child: Text("No leaderboard data available")),
              )
            else ...[
              _topThree(data),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: data.map((user) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _rankCard(
                        key: ValueKey("${user["rank"]}-$_selectedTab-$isWeekly"),
                        rank: user["rank"],
                        name: user["name"],
                        events: user["events"],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const OrganiserBottomNav(currentIndex: 1),
    );
  }

  Widget _roleToggleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _toggleButton("Organisers", _selectedTab == 0, () {
            if (_selectedTab == 0) return;
            setState(() => _selectedTab = 0);
            _loadLeaderboard();
          }),
          _toggleButton("Volunteers", _selectedTab == 1, () {
            if (_selectedTab == 1) return;
            setState(() => _selectedTab = 1);
            _loadLeaderboard();
          }),
        ],
      ),
    );
  }

  Widget _periodToggleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _toggleButton("Weekly", isWeekly, () {
            if (isWeekly) return;
            setState(() => isWeekly = true);
            _loadLeaderboard();
          }),
          _toggleButton("Monthly", !isWeekly, () {
            if (!isWeekly) return;
            setState(() => isWeekly = false);
            _loadLeaderboard();
          }),
        ],
      ),
    );
  }

  Widget _toggleButton(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2E6BE6) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _topThree(List<Map<String, dynamic>> data) {
    final top3 = data.take(3).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: top3.map((user) {
        final rank = user["rank"] as int;
        final isFirst = rank == 1;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: 90,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isFirst ? Colors.amber.withOpacity(0.6) : Colors.black12,
                    blurRadius: isFirst ? 16 : 6,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 32,
                    color: rank == 1
                        ? Colors.amber
                        : rank == 2
                            ? Colors.grey
                            : Colors.brown,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user["name"].toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${user["events"]} events",
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isFirst)
              Positioned(
                top: -10,
                child: _confetti(),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _confetti() {
    return AnimatedBuilder(
      animation: _confettiController,
      builder: (_, __) {
        return Row(
          children: List.generate(5, (i) {
            return Transform.translate(
              offset: Offset(
                sin(_confettiController.value * 2 * pi + i) * 6,
                _confettiController.value * 10,
              ),
              child: const Icon(Icons.circle, size: 6, color: Colors.amber),
            );
          }),
        );
      },
    );
  }

  Widget _rankCard({
    required int rank,
    required String name,
    required int events,
    Key? key,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E6BE6),
          child: Text(
            "#$rank",
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(name),
        subtitle: Text("$events events completed"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
