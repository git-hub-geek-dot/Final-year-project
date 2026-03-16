import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController {
  static const _storageKey = 'app_locale';
  static final ValueNotifier<Locale?> locale = ValueNotifier(null);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_storageKey);
    if (code == null || code.isEmpty) return;
    locale.value = Locale(code);
  }

  static Future<void> setLocale(Locale localeValue) async {
    locale.value = localeValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, localeValue.languageCode);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    locale.value = null;
  }

  static Future<void> clearAllPreserveLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_storageKey);
    await prefs.clear();
    if (code != null && code.isNotEmpty) {
      await prefs.setString(_storageKey, code);
    }
  }
}
