import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedEventsService {
  static const String _storageKey = "saved_events";

  static Future<List<Map<String, dynamic>>> getSavedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];

    return raw
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();
  }

  static Future<bool> isSaved(String eventId) async {
    final saved = await getSavedEvents();
    return saved.any((event) => event["id"].toString() == eventId);
  }

  static Future<void> saveEvent(Map<String, dynamic> event) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await getSavedEvents();
    final id = event["id"].toString();

    final updated = saved
        .where((item) => item["id"].toString() != id)
        .toList();
    updated.add(event);

    final encoded = updated.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  static Future<void> removeEvent(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await getSavedEvents();

    final updated = saved
        .where((item) => item["id"].toString() != eventId)
        .toList();

    final encoded = updated.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  static Future<bool> toggleSaved(Map<String, dynamic> event) async {
    final id = event["id"].toString();
    final alreadySaved = await isSaved(id);

    if (alreadySaved) {
      await removeEvent(id);
      return false;
    }

    await saveEvent(event);
    return true;
  }
}
