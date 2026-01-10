import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
class ApiConfig {
  static const bool useCloud = false; // false = local, true = Render

  static const String localWeb = "http://localhost:4000/api";
  static const String localAndroid = "http://10.0.2.2:4000/api";
  static const String cloudUrl = "https://final-year-project-4oi.onrender.com/api";

  static String get baseUrl {
    if (useCloud) return cloudUrl;

    if (kIsWeb) {
      return localWeb;
    } else if (Platform.isAndroid) {
      return localAndroid;
    } else {
      return localWeb;
    }
  }
}