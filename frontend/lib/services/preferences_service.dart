import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _newApplicationsKey = 'pref_new_applications';
  static const _eventUpdatesKey = 'pref_event_updates';
  static const _promotionsKey = 'pref_promotions';

  // 🔔 New Volunteer Applications
  static Future<void> setNewApplications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_newApplicationsKey, value);
  }

  static Future<bool> getNewApplications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_newApplicationsKey) ?? true;
  }

  // 📅 Event Updates
  static Future<void> setEventUpdates(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eventUpdatesKey, value);
  }

  static Future<bool> getEventUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_eventUpdatesKey) ?? true;
  }

  // 📢 Promotional Notifications
  static Future<void> setPromotions(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promotionsKey, value);
  }

  static Future<bool> getPromotions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promotionsKey) ?? false;
  }

  // 🔥 CLEAR ALL DATA (USED FOR DELETE ACCOUNT / LOGOUT)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
