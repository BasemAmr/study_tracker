import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_engine.dart';

/// Lightweight singleton to notify the Sync system about local database writes.
/// Repositories call notifyWrite() after any INSERT/UPDATE/DELETE on a synced table.
/// The SyncScreen registers a callback that triggers an auto-sync after a short debounce.
class SyncTrigger extends ChangeNotifier {
  SyncTrigger._();
  static final instance = SyncTrigger._();

  Timer? _debounce;

  bool _suppressed = false;

  /// Temporarily stop the trigger from firing (e.g. during sync bookkeeping)
  void suppress() => _suppressed = true;
  void unsuppress() => _suppressed = false;

  /// Notify that a synced row was written.
  /// Starts or resets a 5-second debounce timer before triggering the sync.
  void notifyWrite() {
    // T11: Don't trigger auto-sync if the write is coming from a sync application
    // or if the trigger is explicitly suppressed.
    if (SyncEngine.isSyncing || _suppressed) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), () {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
