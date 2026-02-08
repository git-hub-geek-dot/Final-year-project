import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import 'package:frontend/widgets/error_state.dart';
import 'admin_users_screen.dart';
import 'admin_events_screen.dart';
import 'admin_applications_screen.dart';
import '../../services/admin_service.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  late Future<Map<String, dynamic>> statsFuture;
  late Future<List<dynamic>> timeseriesFuture;
  DateTime? lastUpdated;
  int selectedRangeDays = 7;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      statsFuture = AdminService.getStats().then((data) {
        if (mounted) {
          setState(() => lastUpdated = DateTime.now());
        }
        return data;
      });
      timeseriesFuture =
          AdminService.getStatsTimeseries(days: selectedRangeDays);
    });
  }

  void _setRange(int days) {
    if (selectedRangeDays == days) return;
    setState(() {
      selectedRangeDays = days;
      timeseriesFuture = AdminService.getStatsTimeseries(days: days);
    });
  }

  @override
  Widget build(BuildContext context) {
    final updatedText = _formatLastUpdated(lastUpdated);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: AppBackground(
        child: FutureBuilder<Map<String, dynamic>>(
          future: statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Last updated: $updatedText"),
                    const SizedBox(height: 8),
                    Expanded(child: _skeletonGrid()),
                  ],
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return ErrorState(
                message: "Failed to load stats",
                onRetry: _refresh,
              );
            }

            final s = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Last updated: $updatedText"),
                  const SizedBox(height: 12),
                  const Text(
                    "Activity",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _rangeChip("7D", 7),
                      _rangeChip("30D", 30),
                      _rangeChip("90D", 90),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: FutureBuilder<List<dynamic>>(
                      future: timeseriesFuture,
                      builder: (context, seriesSnapshot) {
                        if (seriesSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (seriesSnapshot.hasError ||
                            !seriesSnapshot.hasData) {
                          return const Center(
                            child: Text("Failed to load activity"),
                          );
                        }

                        final series = _mapSeries(seriesSnapshot.data!);
                        if (series.isEmpty) {
                          return const Center(child: Text("No activity data"));
                        }

                        return _buildChart(series);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminUsersScreen(),
                              ),
                            );
                          },
                          child: statCard("Users", s["totalUsers"]),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminEventsScreen(),
                              ),
                            );
                          },
                          child: statCard("Events", s["totalEvents"]),
                        ),
                        statCard("Active Events", s["activeEvents"]),
                        statCard(
                          "Pending Verifications",
                          s["pendingVerifications"],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminApplicationsScreen(),
                              ),
                            );
                          },
                          child:
                              statCard("Applications", s["totalApplications"]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget statCard(String title, int? value) {
    final safeValue = value ?? 0;
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              safeValue.toString(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget _rangeChip(String label, int days) {
    final selected = selectedRangeDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _setRange(days),
    );
  }

  List<_TimePoint> _mapSeries(List<dynamic> rows) {
    return rows.map((row) {
      final day = (row["day"] ?? "").toString();
      final events = (row["events"] as num?)?.toInt() ?? 0;
      final applications = (row["applications"] as num?)?.toInt() ?? 0;
      return _TimePoint(day: day, events: events, applications: applications);
    }).toList();
  }

  Widget _buildChart(List<_TimePoint> series) {
    final maxValue = series.fold<int>(
      0,
      (m, p) => math.max(m, math.max(p.events, p.applications)),
    );
    final maxY = maxValue == 0 ? 4.0 : (maxValue * 1.2).ceilToDouble();

    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(show: true, horizontalInterval: maxY / 4),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(series.length, (index) {
          final point = series[index];
          return BarChartGroupData(
            x: index,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: point.events.toDouble(),
                width: 6,
                color: Colors.blue,
                borderRadius: BorderRadius.circular(2),
              ),
              BarChartRodData(
                toY: point.applications.toDouble(),
                width: 6,
                color: Colors.green,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= series.length) {
                  return const SizedBox.shrink();
                }

                final step = selectedRangeDays <= 7
                    ? 1
                    : selectedRangeDays <= 30
                        ? 3
                        : 10;

                if (index % step != 0) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatDayLabel(series[index].day),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatDayLabel(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final mm = parsed.month.toString().padLeft(2, '0');
    final dd = parsed.day.toString().padLeft(2, '0');
    return "$mm/$dd";
  }

  Widget _skeletonGrid() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: List.generate(5, (index) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 28,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 14,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _formatLastUpdated(DateTime? value) {
    if (value == null) return "Last updated: -";
    final now = DateTime.now();
    final diff = now.difference(value);

    if (diff.inSeconds < 10) return "Last updated: just now";
    if (diff.inSeconds < 60) {
      return "Last updated: ${diff.inSeconds}s ago";
    }
    if (diff.inMinutes < 60) {
      return "Last updated: ${diff.inMinutes}m ago";
    }
    if (diff.inHours < 24) {
      return "Last updated: ${diff.inHours}h ago";
    }
    return "Last updated: ${value.toLocal()}".split(".")[0];
  }

}

class _TimePoint {
  final String day;
  final int events;
  final int applications;

  _TimePoint({
    required this.day,
    required this.events,
    required this.applications,
  });
}
