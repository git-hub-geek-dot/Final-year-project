import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/localization/app_localizations.dart';
import 'package:flutter/material.dart';

void main() {
  test('repairs corrupted Hindi localization strings', () {
    final hi = AppLocalizations(const Locale('hi'));

    expect(hi.t('Hindi'), 'हिंदी');
    expect(hi.t('App Language'), 'ऐप भाषा');
    expect(hi.t('Profile'), 'प्रोफ़ाइल');
  });
}
