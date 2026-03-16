import 'package:flutter/material.dart';
import 'app_localizations.dart';

extension LocalizationContextX on BuildContext {
  String tr(String key, {Map<String, String> args = const {}}) {
    return AppLocalizations.of(this).t(key, args: args);
  }
}

extension LocalizationStringX on String {
  String tr(BuildContext context, {Map<String, String> args = const {}}) {
    return AppLocalizations.of(context).t(this, args: args);
  }
}
