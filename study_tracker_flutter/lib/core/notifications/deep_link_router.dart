import 'package:go_router/go_router.dart';

import '../../app/router.dart' show AppRoutes;

/// Binds [GoRouter] after [MaterialApp.router] builds so notification taps can navigate.
class NotificationRouterScope {
  static GoRouter? _router;

  static void bind(GoRouter router) {
    _router = router;
  }

  static void handlePayload(String? payload) {
    final r = _router;
    if (r == null || payload == null) return;
    DeepLinkRouter(r).handlePayload(payload);
  }
}

/// Deep link router — maps payload → go_router location.
/// Wired to notification_scheduler.onAction AND to flutter_local_notifications' launch-from-cold-start payload.
class DeepLinkRouter {
  final GoRouter _router;

  DeepLinkRouter(this._router);

  /// Handle a notification payload by navigating to the appropriate screen.
  void handlePayload(String? payload) {
    if (payload == null) return;

    final location = _mapPayloadToLocation(payload);
    if (location != null) {
      _router.go(location);
    }
  }

  String? _mapPayloadToLocation(String payload) {
    switch (payload) {
      case '1001': // Pre-Study → start a session
        return AppRoutes.sessions;
      case '1002': // Streak
      case '1005': // Re-engage 3
      case '1006': // Re-engage 7
        return AppRoutes.dashboard;
      case '1003': // Weekly
        return AppRoutes.analytics;
      case '1004': // Goal (no dedicated /goals route — open dashboard)
        return AppRoutes.dashboard;
      default:
        return null;
    }
  }
}