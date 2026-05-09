// lib/core/providers/sync_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/database_provider.dart';
import '../../data/repositories/settings_repository.dart';
import '../sync/sync_engine.dart';
import '../sync/wifi_transport.dart';
import '../sync/file_transport.dart';
import '../sync/cloud_transport.dart';
import '../sync/bluetooth_transport.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  return SyncEngine(db, settings);
});

final wifiTransportProvider = Provider<WifiTransport>((ref) {
  return WifiTransport(
    ref.watch(syncEngineProvider), 
    ref.watch(settingsRepositoryProvider),
    ref
  );
});

final fileTransportProvider = Provider<FileTransport>((ref) {
  return FileTransport(ref.watch(syncEngineProvider));
});

final cloudTransportProvider = Provider<CloudTransport>((ref) {
  return CloudTransport(
    ref.watch(syncEngineProvider),
    ref.watch(settingsRepositoryProvider),
  );
});

final bluetoothTransportProvider = Provider<BluetoothTransport>((ref) {
  return BluetoothTransport(ref.watch(syncEngineProvider));
});
