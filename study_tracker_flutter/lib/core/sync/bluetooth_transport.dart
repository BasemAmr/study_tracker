// lib/core/sync/bluetooth_transport.dart

import 'sync_engine.dart';

class BluetoothPeer {
  final String address;
  final String name;
  final String? lastSyncedAt;

  const BluetoothPeer({
    required this.address,
    required this.name,
    this.lastSyncedAt,
  });
}

class BluetoothTransportResult {
  final bool success;
  final int? rowsSent;
  final int? rowsReceived;
  final String? errorMessage;

  const BluetoothTransportResult({
    required this.success,
    this.rowsSent,
    this.rowsReceived,
    this.errorMessage,
  });
}

class BluetoothTransport {
  final SyncEngine _engine;

  BluetoothTransport(this._engine);

  Future<bool> get isEnabled async => false; // Stubbed for now

  Future<void> startServer() async {
    // Bluetooth server implementation pending
    throw UnimplementedError('Bluetooth server mode requires custom RFCOMM setup.');
  }

  Future<void> stopServer() async {
    // Stub
  }

  Future<List<BluetoothPeer>> discoverPeers() async {
    return [];
  }

  Future<BluetoothTransportResult> syncWithPeer(BluetoothPeer peer) async {
    return const BluetoothTransportResult(
      success: false,
      errorMessage: 'Bluetooth sync not fully implemented yet. Please use WiFi or File transport.',
    );
  }
}
