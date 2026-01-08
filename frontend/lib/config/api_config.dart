import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:4000/api";
    } else if (Platform.isAndroid) {
      return "http://10.0.2.2:4000/api";
    } else {
      return "http://localhost:4000/api";
    }
  }
}