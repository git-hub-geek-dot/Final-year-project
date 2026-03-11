import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/notification_store.dart';
import '../../services/notification_api_service.dart';
import '../../services/token_service.dart';
import '../../widgets/app_background.dart';
import '../chat/chat_screen.dart';
import '../organiser/attendance_feedback_screen.dart';
import '../chat/event_group_chat_screen.dart';
import '../organiser/event_details_screen.dart';
import '../organiser/organiser_profile_screen.dart';
import '../volunteer/my_applications_screen.dart';
import '../volunteer/event_announcements_screen.dart';
import '../volunteer/view_event_screen.dart';
import '../volunteer/volunteer_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _usingLocal = false;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loadingMore) return;

    if (reset) {
      setState(() {
        _loading = true;
        _items.clear();
        _page = 1;
        _totalPages = 1;
        _usingLocal = false;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final data = await NotificationApiService.fetchNotifications(
        page: _page,
        limit: 20,
      );
      final rows = (data["items"] as List?) ?? [];
      final mapped = rows
          .map((e) => _fromApi(Map<String, dynamic>.from(e)))
          .toList();
      final totalPages = (data["totalPages"] as num?)?.toInt() ?? _page;

      setState(() {
        _items.addAll(mapped);
        _page += 1;
        _totalPages = totalPages;
        _loading = false;
        _loadingMore = false;
        _usingLocal = false;
      });
    } catch (_) {
      if (!reset) {
        setState(() => _loadingMore = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load more notifications")),
        );
        return;
      }

      final local = await NotificationStore.getAll();
      setState(() {
        _items
          ..clear()
          ..addAll(local);
        _loading = false;
        _usingLocal = true;
      });
    }
  }

  Future<void> _clearAll() async {
    if (_usingLocal) {
      await NotificationStore.clear();
      await _fetch(reset: true);
      return;
    }

    try {
      await NotificationApiService.clearNotifications();
      await NotificationStore.clear();
      await _fetch(reset: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to clear notifications")),
      );
    }
  }

  String _formatTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$y-$m-$d $hh:$mm";
  }

  NotificationItem _fromApi(Map<String, dynamic> row) {
    final createdRaw = row["created_at"] ?? row["createdAt"];
    final createdAt = DateTime.tryParse(createdRaw?.toString() ?? "") ??
        DateTime.now();
    final readRaw = row["read_at"] ?? row["readAt"];
    final readAt = readRaw != null
        ? DateTime.tryParse(readRaw.toString())
        : null;
    final data = (row["data"] as Map?)?.cast<String, dynamic>() ?? {};

    return NotificationItem(
      id: row["id"]?.toString() ?? "",
      title: (row["title"] ?? "Notification").toString(),
      body: (row["body"] ?? "").toString(),
      data: data,
      receivedAt: createdAt,
      readAt: readAt,
    );
  }

  bool _isUnread(NotificationItem item) => item.readAt == null;

  NotificationItem _withReadAt(NotificationItem item, DateTime? readAt) {
    return NotificationItem(
      id: item.id,
      title: item.title,
      body: item.body,
      data: item.data,
      receivedAt: item.receivedAt,
      readAt: readAt,
    );
  }

  void _setItemRead(String id, DateTime when) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    setState(() {
      _items[idx] = _withReadAt(_items[idx], when);
    });
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.id.isEmpty || !_isUnread(item)) return;

    final now = DateTime.now();
    if (_usingLocal) {
      await NotificationStore.markRead(item.id);
      _setItemRead(item.id, now);
      return;
    }

    try {
      await NotificationApiService.markRead(item.id);
    } catch (_) {
      // Ignore; still update local state for UX
    }
    _setItemRead(item.id, now);
  }

  Future<void> _markAllRead() async {
    final now = DateTime.now();
    if (_usingLocal) {
      await NotificationStore.markAllRead();
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          if (_items[i].readAt == null) {
            _items[i] = _withReadAt(_items[i], now);
          }
        }
      });
      return;
    }

    try {
      await NotificationApiService.markAllRead();
      await NotificationStore.markAllRead();
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          if (_items[i].readAt == null) {
            _items[i] = _withReadAt(_items[i], now);
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to mark all as read")),
      );
    }
  }

  Future<void> _openEventDetails(int eventId) async {
    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/events/$eventId"),
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load event details")),
        );
        return;
      }

      final data = jsonDecode(res.body);
      final event = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map);

      final role = (await TokenService.getRole())?.toLowerCase();
      if (!mounted) return;

      if (role == "organiser") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailsScreen(event: event),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewEventScreen(event: event),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load event details")),
      );
    }
  }

  Future<void> _openProfile() async {
    final role = (await TokenService.getRole())?.toLowerCase();
    if (!mounted) return;
    if (role == "organiser") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OrganiserProfileScreen(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const VolunteerProfileScreen(),
        ),
      );
    }
  }

  Future<void> _handleTap(NotificationItem item) async {
    await _markRead(item);

    final data = item.data;
    final type = (data["type"] ?? "").toString();

    if (type == "chat_message") {
      final raw = data["threadId"] ?? data["thread_id"];
      final threadId = int.tryParse(raw?.toString() ?? "");
      if (threadId != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              threadId: threadId,
              title: "Chat",
            ),
          ),
        );
      }
      return;
    }

    if (type == "attendance_feedback_required") {
      final raw = data["eventId"] ?? data["event_id"];
      final eventId = int.tryParse(raw?.toString() ?? "");
      if (eventId != null) {
        final role = (await TokenService.getRole())?.toLowerCase();
        if (!mounted) return;

        if (role == "organiser") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AttendanceFeedbackScreen(eventId: eventId),
            ),
          );
        } else {
          await _openEventDetails(eventId);
        }
      }
      return;
    }

    if (type == "event_group_chat") {
      final raw = data["eventId"] ?? data["event_id"];
      final eventId = int.tryParse(raw?.toString() ?? "");
      if (eventId != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventGroupChatScreen(
              eventId: eventId,
              eventTitle: "Event",
            ),
          ),
        );
      }
      return;
    }

    if (type == "event_announcement") {
      final raw = data["eventId"] ?? data["event_id"];
      final eventId = int.tryParse(raw?.toString() ?? "");
      if (eventId != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventAnnouncementsScreen(
              eventId: eventId,
              eventTitle: "Event",
            ),
          ),
        );
      }
      return;
    }

    if (type == "event_update" ||
        type == "event_broadcast" ||
        type == "event_removed" ||
        type == "event_cancelled" ||
        type == "event_announcement") {
      final raw = data["eventId"] ?? data["event_id"];
      final eventId = int.tryParse(raw?.toString() ?? "");
      if (eventId != null) {
        await _openEventDetails(eventId);
      }
      return;
    }

    if (type == "application_status" || type == "application_cancelled") {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyApplicationsScreen()),
      );
      return;
    }

    if (type == "account_status" ||
        type == "account_strike" ||
        type == "account_suspension") {
      await _openProfile();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetch(reset: true),
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _items.isEmpty ? null : _markAllRead,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Clear notifications"),
                  content:
                      const Text("Delete all notifications?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Clear"),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _clearAll();
              }
            },
          ),
        ],
      ),
      body: AppBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text("No notifications yet."))
                : Column(
                    children: [
                      if (_usingLocal)
                        Container(
                          width: double.infinity,
                          color: Colors.orange.shade100,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: const Text(
                            "Showing local notifications (offline).",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _items.length +
                              (_usingLocal || _page > _totalPages ? 0 : 1),
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (!_usingLocal && index == _items.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: ElevatedButton(
                                    onPressed: _loadingMore
                                        ? null
                                        : () => _fetch(),
                                    child: _loadingMore
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text("Load More"),
                                  ),
                                ),
                              );
                            }

                            final item = _items[index];
                            final isUnread = _isUnread(item);
                            final subtitleParts = <String>[];
                            if (item.body.isNotEmpty) {
                              subtitleParts.add(item.body);
                            }
                            subtitleParts.add(_formatTime(item.receivedAt));

                            return ListTile(
                              leading: Icon(
                                Icons.notifications,
                                color: isUnread
                                    ? Colors.blueAccent
                                    : Colors.grey.shade600,
                              ),
                              title: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight:
                                      isUnread ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(subtitleParts.join("\n")),
                              isThreeLine: item.body.isNotEmpty,
                              trailing: isUnread
                                  ? Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                              onTap: () => _handleTap(item),
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
