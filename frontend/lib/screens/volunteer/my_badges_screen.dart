import 'package:flutter/material.dart';

import '../../services/badge_service.dart';
import '../../localization/localization_extensions.dart';

class MyBadgesScreen extends StatefulWidget {
  const MyBadgesScreen({super.key});

  @override
  State<MyBadgesScreen> createState() => _MyBadgesScreenState();
}

class _MyBadgesScreenState extends State<MyBadgesScreen> {
  bool _loading = true;
  String? _error;
  String _role = "";
  int _completedCount = 0;
  double _progress = 0;
  Map<String, dynamic>? _currentBadge;
  Map<String, dynamic>? _nextBadge;
  List<Map<String, dynamic>> _badges = const [];

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await BadgeService.fetchMyBadges();
      final badgesRaw = (data["badges"] as List?) ?? const [];

      if (!mounted) return;
      setState(() {
        _role = (data["role"] ?? "").toString().toLowerCase();
        _completedCount = _toInt(data["completedCount"]);
        _progress = _toDouble(data["progress"]).clamp(0.0, 1.0).toDouble();
        _currentBadge = _asMap(data["currentBadge"]);
        _nextBadge = _asMap(data["nextBadge"]);
        _badges = badgesRaw
            .whereType<Map>()
            .map((badge) => Map<String, dynamic>.from(badge))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.tr("Unable to load badges right now.");
        _loading = false;
      });
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry("$k", v));
    }
    return null;
  }

  String _badgeSubtitle(Map<String, dynamic> badge) {
    final description = (badge["description"] ?? "").toString().trim();
    final threshold = _toInt(badge["threshold"]);
    final noun = _role == "organiser"
        ? context.tr("hosted events")
        : context.tr("completed events");
    final requirement = context.tr(
      "Requires {threshold} {noun}",
      args: {
        "threshold": threshold.toString(),
        "noun": noun,
      },
    );

    if (description.isEmpty) return requirement;
    return "$description\n$requirement";
  }

  String _countLabel() {
    if (_role == "organiser") return context.tr("Hosted events");
    return context.tr("Completed events");
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr("My Badges"))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadBadges,
                  child: Text(context.tr("Retry")),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentBadgeName =
        (_currentBadge?["name"] ?? context.tr("No badge yet")).toString();
    final nextBadgeName = _nextBadge?["name"]?.toString();
    final nextBadgeThreshold = _toInt(_nextBadge?["threshold"]);
    final countLabel = _countLabel();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("My Badges")),
        actions: [
          IconButton(
            onPressed: _loadBadges,
            icon: const Icon(Icons.refresh),
            tooltip: context.tr("Refresh"),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                "Current Badge: {badge}",
                args: {"badge": currentBadgeName},
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              context.tr(
                "{label}: {count}",
                args: {
                  "label": countLabel,
                  "count": _completedCount.toString(),
                },
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (nextBadgeName != null) ...[
              const SizedBox(height: 4),
              Text(
                context.tr(
                  "Next badge: {name} at {threshold} {label}",
                  args: {
                    "name": nextBadgeName,
                    "threshold": nextBadgeThreshold.toString(),
                    "label": countLabel,
                  },
                ),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 20),
            if (_badges.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    context.tr("No badges configured in system yet."),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _badges.length,
                  itemBuilder: (context, index) {
                    final badge = _badges[index];
                    final earned = badge["earned"] == true;
                    final baseColor = _badgeBaseColor(badge);

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.emoji_events,
                          color: earned
                              ? baseColor
                              : baseColor.withValues(alpha: 0.35),
                        ),
                        title: Text(
                          (badge["name"] ?? context.tr("Badge")).toString(),
                        ),
                        subtitle: Text(_badgeSubtitle(badge)),
                        isThreeLine: true,
                        trailing: earned
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.lock_outline),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
