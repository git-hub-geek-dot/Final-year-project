import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF1E63F3);
  static const Color primaryGreen = Color(0xFF2ECC71);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, primaryGreen],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [
      Color(0xFF2F6CF6),
      Color(0xFF2ECC71),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF2C2C2C);
  static const Color textLight = Color(0xFF9E9E9E);
}
