import 'dart:async';

class SessionManager {
  static final StreamController<void> _controller =
      StreamController<void>.broadcast();
  static bool _notified = false;

  static Stream<void> get onSessionExpired => _controller.stream;

  static void notifySessionExpired() {
    if (_notified) return;
    _notified = true;
    _controller.add(null);
  }

  static void reset() {
    _notified = false;
  }
}
