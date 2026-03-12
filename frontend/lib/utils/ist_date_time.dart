class IstDateTime {
  static const Duration offset = Duration(hours: 5, minutes: 30);
  static final RegExp _timezoneSuffix = RegExp(
    r'(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$',
  );

  static DateTime now() {
    return _wallClockFromAbsolute(DateTime.now());
  }

  static DateTime? tryParse(dynamic raw) {
    if (raw == null) return null;

    if (raw is DateTime) {
      return raw.isUtc ? _wallClockFromAbsolute(raw) : _wallClock(raw);
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;

    if (_timezoneSuffix.hasMatch(text)) {
      return _wallClockFromAbsolute(parsed);
    }

    return _wallClock(parsed);
  }

  static DateTime startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String formatDateTime(dynamic raw) {
    final value = tryParse(raw);
    if (value == null) return "-";

    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return "$y-$m-$d $hh:$mm";
  }

  static String formatDate(dynamic raw) {
    final value = tryParse(raw);
    if (value == null) return "-";

    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  static String formatTime(dynamic raw) {
    if (raw == null) return "-";
    final text = raw.toString().trim();
    if (text.isEmpty) return "-";

    if (!text.contains("T")) {
      return text.length >= 5 ? text.substring(0, 5) : text;
    }

    final value = tryParse(text);
    if (value == null) return "-";

    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  static DateTime _wallClockFromAbsolute(DateTime value) {
    final ist = value.toUtc().add(offset);
    return _wallClock(ist);
  }

  static DateTime _wallClock(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }
}
