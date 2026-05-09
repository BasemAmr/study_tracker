// lib/core/sync/cloud_transport.dart
//
// Cloud transport: push/pull to a REST endpoint.
// Mirrors desktop cloudTransport.ts exactly.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/repositories/settings_repository.dart';
import 'sync_engine.dart';

class CloudTransportResult {
  final bool success;
  final int? rowsSent;
  final int? rowsReceived;
  final String? errorMessage;

  const CloudTransportResult({
    required this.success,
    this.rowsSent,
    this.rowsReceived,
    this.errorMessage,
  });
}

class CloudTransport {
  final SyncEngine _engine;
  final SettingsRepository _settings;

  CloudTransport(this._engine, this._settings);

  Future<bool> checkOnline() async {
    debugPrint('SYNC: [Cloud] Checking online status...');
    try {
      final enabled = await _settings.get('cloudSyncEnabled');
      if (enabled != 'true') {
        debugPrint('SYNC: [Cloud] Cloud sync disabled.');
        return false;
      }
      final url = await _settings.get('cloudSyncUrl');
      if (url == null || url.isEmpty) {
        debugPrint('SYNC: [Cloud] No cloud URL configured.');
        return false;
      }

      // Just a simple ping or check if we have network
      // (a real app might use connectivity_plus, but we use a simple HTTP GET/HEAD)
      final uri = Uri.parse(url).replace(path: '/ping');
      try {
        await http.get(uri).timeout(const Duration(seconds: 3));
        debugPrint('SYNC: [Cloud] Endpoint reachable.');
        return true;
      } catch (_) {
        // Fallback to checking google.com
        await http.get(Uri.parse('https://google.com')).timeout(const Duration(seconds: 3));
        debugPrint('SYNC: [Cloud] Endpoint unreachable but internet is up.');
        return true;
      }
    } catch (e) {
      debugPrint('SYNC: [Cloud] Error checking online status: $e');
      return false;
    }
  }

  Future<CloudTransportResult> runCloudSync() async {
    debugPrint('SYNC: [Cloud] Running cloud sync...');
    try {
      final enabled = await _settings.get('cloudSyncEnabled');
      if (enabled != 'true') {
        debugPrint('SYNC: [Cloud] Aborted: Cloud sync disabled.');
        return const CloudTransportResult(success: false, errorMessage: 'Cloud sync is disabled');
      }

      final url = await _settings.get('cloudSyncUrl');
      final anonKey = await _settings.get('cloudSyncAnonKey');

      if (url == null || url.isEmpty) {
        debugPrint('SYNC: [Cloud] Aborted: URL not configured.');
        return const CloudTransportResult(success: false, errorMessage: 'Cloud URL not configured');
      }

      final pushUrl = Uri.parse(url).replace(path: '/sync/push');
      final since = await _engine.getLastSyncedAt('cloud', 'cloud');
      final payload = await _engine.buildPayload(sinceTimestamp: since);
      final rowsSent = SyncEngine.countRows(payload);
      debugPrint('SYNC: [Cloud] Payload built, $rowsSent rows. Sending to $pushUrl...');

      final headers = {
        'Content-Type': 'application/json',
      };
      if (anonKey != null && anonKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $anonKey';
      }

      final response = await http.post(
        pushUrl,
        headers: headers,
        body: payload.serialize(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('SYNC: [Cloud] Sync failed: ${response.statusCode} ${response.body}');
        throw Exception('Cloud server returned ${response.statusCode}: ${response.body}');
      }

      debugPrint('SYNC: [Cloud] Response received. Applying payload...');
      final hostPayload = SyncEngine.deserializePayload(response.body);
      final applyResult = await _engine.applyPayload(hostPayload);
      final rowsReceived = applyResult.total;

      await _engine.updateSyncState(
        peerDeviceId: 'cloud',
        transport: 'cloud',
        direction: 'bidirectional',
        rowCount: rowsSent + rowsReceived,
      );

      await _engine.recordHistory(SyncHistoryEntry(
        peerDeviceId: 'cloud',
        peerDeviceName: 'Cloud Server',
        transport: 'cloud',
        direction: 'bidirectional',
        rowsSent: rowsSent,
        rowsReceived: rowsReceived,
        success: true,
      ));

      debugPrint('SYNC: [Cloud] Sync complete. $rowsReceived rows received.');
      return CloudTransportResult(
        success: true,
        rowsSent: rowsSent,
        rowsReceived: rowsReceived,
      );
    } catch (e) {
      debugPrint('SYNC: [Cloud] Sync error: $e');
      await _engine.recordHistory(SyncHistoryEntry(
        peerDeviceId: 'cloud',
        peerDeviceName: 'Cloud Server',
        transport: 'cloud',
        direction: 'bidirectional',
        success: false,
        errorMessage: e.toString(),
      ));
      return CloudTransportResult(success: false, errorMessage: e.toString());
    }
  }
}
