import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  final DateTime? readAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.receivedAt,
    this.readAt,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "body": body,
        "data": data,
        "receivedAt": receivedAt.toIso8601String(),
        "readAt": readAt?.toIso8601String(),
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json["id"] ?? "").toString(),
      title: (json["title"] ?? "").toString(),
      body: (json["body"] ?? "").toString(),
      data: (json["data"] as Map?)?.cast<String, dynamic>() ?? {},
      receivedAt: DateTime.tryParse(
            (json["receivedAt"] ?? "").toString(),
          ) ??
          DateTime.now(),
      readAt: json["readAt"] != null
          ? DateTime.tryParse(json["readAt"].toString())
          : null,
    );
  }
}

class NotificationStore {
  static const String _key = "notifications_v1";
  static const int _maxItems = 200;

  static Future<List<NotificationItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => NotificationItem.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(NotificationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();

    final updated = <NotificationItem>[
      item,
      ...existing.where((e) => e.id != item.id),
    ];

    if (updated.length > _maxItems) {
      updated.removeRange(_maxItems, updated.length);
    }

    await prefs.setString(
      _key,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    final updated = existing.map((item) {
      if (item.id != id) return item;
      return NotificationItem(
        id: item.id,
        title: item.title,
        body: item.body,
        data: item.data,
        receivedAt: item.receivedAt,
        readAt: item.readAt ?? DateTime.now(),
      );
    }).toList();

    await prefs.setString(
      _key,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    final now = DateTime.now();
    final updated = existing.map((item) {
      if (item.readAt != null) return item;
      return NotificationItem(
        id: item.id,
        title: item.title,
        body: item.body,
        data: item.data,
        receivedAt: item.receivedAt,
        readAt: now,
      );
    }).toList();

    await prefs.setString(
      _key,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
