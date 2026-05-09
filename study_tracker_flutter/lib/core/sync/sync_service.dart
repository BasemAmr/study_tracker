import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../providers/sync_provider.dart';
import 'sync_engine.dart';
import 'sync_trigger.dart';

/// Background service to handle automatic synchronization.
class SyncService {
  final Ref _ref;
  bool _initialized = false;

  SyncService(this._ref);

  void init() {
    if (_initialized) return;
    _initialized = true;

    // Initialize profile ownership and normalize sync IDs
    _ref.read(syncEngineProvider).initializeOwnership();

    // Listen to data changes and trigger auto-sync
    SyncTrigger.instance.addListener(_handleDataChange);

    // Initial sync on startup only when the DB truly has sync enabled — read the row
    // directly. settingsProvider.snapshot can still be stale for tick(s) while
    // loadSettings()'s structured merge runs; `wifiSyncEnabled: false` + notifyWrite led
    // to spurious outbound sync before the Shell pill flipped off for users.
    Future.delayed(const Duration(seconds: 10), () async {
      final raw =
          await _ref.read(settingsRepositoryProvider).get('wifiSyncEnabled');
      if (raw != 'true') return;
      await _triggerAutoSync();
    });
  }

  Future<void> _handleDataChange() async {
    // Defence in depth: if a sync is actively running, the notification is almost
    // certainly a side effect of that sync's bookkeeping (e.g. sync_state writes).
    // Re-triggering here is how we got the every-~5-seconds storm from the logs.
    if (SyncEngine.isSyncing) return;

    final raw =
        await _ref.read(settingsRepositoryProvider).get('wifiSyncEnabled');
    if (raw != 'true') return;
    await _triggerAutoSync();
  }

  Future<void> _triggerAutoSync() async {
    final raw =
        await _ref.read(settingsRepositoryProvider).get('wifiSyncEnabled');
    if (raw != 'true') return;

    final wifiTransport = _ref.read(wifiTransportProvider);
    await wifiTransport.syncWithPairedPeers();
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});
