import 'package:flutter/foundation.dart';

class SyncDebugLogger {
  SyncDebugLogger._();

  static final SyncDebugLogger instance = SyncDebugLogger._();

  static const int _maxEntries = 600;

  final ValueNotifier<List<String>> entries = ValueNotifier<List<String>>(<String>[]);

  bool _enabled = true;
  bool _alwaysVisible = false;

  bool get enabled => _enabled;
  bool get alwaysVisible => _alwaysVisible;

  void setEnabled(bool value) {
    _enabled = value;
    log('Debug', 'Logging ${value ? 'enabled' : 'disabled'}');
  }

  void setAlwaysVisible(bool value) {
    _alwaysVisible = value;
    log('Debug', 'Debug panel ${value ? 'always visible' : 'hidden by default'}');
  }

  void clear() {
    entries.value = <String>[];
  }

  void log(String scope, String message, {Object? data}) {
    if (!_enabled) return;

    final now = DateTime.now().toIso8601String();
    final formatted = data == null
        ? '[$now] [$scope] $message'
        : '[$now] [$scope] $message | $data';

    final next = List<String>.from(entries.value)..add(formatted);
    if (next.length > _maxEntries) {
      next.removeRange(0, next.length - _maxEntries);
    }

    entries.value = next;
    debugPrint(formatted);
  }
}
