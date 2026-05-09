// lib/core/sync/wifi_transport.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:nsd/nsd.dart' as nsd;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../providers/global_sync_status_provider.dart';
import 'sync_engine.dart';
import 'sync_debug_logger.dart';

/// Same settings key as desktop `wifiTransport.ts` (LAN bookmark list).
const String kWifiLanPeerBookmarksKey = 'wifiLanPeerBookmarks';

class WifiPeer {
  final String ip;
  final int port;
  final String deviceName;
  final String deviceId;
  final String? lastSyncedAt;

  /// When true, peer was saved by IPv4/host (manual); mDNS is unreliable phone↔PC.
  final bool fromLanBookmark;

  const WifiPeer({
    required this.ip,
    required this.port,
    required this.deviceName,
    required this.deviceId,
    this.lastSyncedAt,
    this.fromLanBookmark = false,
  });
}

class WifiTransportResult {
  final bool success;
  final int? rowsSent;
  final int? rowsReceived;
  final String? errorMessage;

  const WifiTransportResult({
    required this.success,
    this.rowsSent,
    this.rowsReceived,
    this.errorMessage,
  });
}

class WifiTransport {
  final SyncEngine _engine;
  final SettingsRepository _settings;

  /// [Ref] works from both Provider bodies (ProviderRef) and widgets — not [WidgetRef], which Providers don't receive.
  final Ref _ref;
  final SyncDebugLogger _logger = SyncDebugLogger.instance;
  HttpServer? _server;
  nsd.Registration? _registration;
  nsd.Discovery? _activeDiscovery;
  Timer? _autoSyncTimer;
  bool _isDiscovering = false;
  DateTime? _discoveryStartedAt;
  bool _isAutoSyncRunning = false;

  WifiTransport(this._engine, this._settings, this._ref);

  String? _decodeTxtValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List<int>) return utf8.decode(value, allowMalformed: true);
    try {
      return utf8.decode((value as dynamic).cast<int>() as List<int>, allowMalformed: true);
    } catch (_) {
      return value.toString();
    }
  }

  /// Best-effort guess at our primary LAN IPv4 — the one the user should type on
  /// another device when mDNS fails. Prefers private/RFC1918 ranges (192.168/x, 10/8,
  /// 172.16-31) and skips loopback/link-local/VPN interfaces.
  Future<String?> getLocalLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      String? best;
      for (final iface in interfaces) {
        // Skip common virtual / tunnel interfaces that look private but aren't reachable
        // from other devices on the real Wi-Fi.
        final n = iface.name.toLowerCase();
        if (n.contains('tun') || n.contains('tap') || n.contains('docker') ||
            n.contains('vbox') || n.contains('vmnet') || n.contains('virtual')) {
          continue;
        }
        for (final addr in iface.addresses) {
          final a = addr.address;
          if (a.startsWith('169.254.')) continue; // link-local safety net
          if (a.startsWith('192.168.') || a.startsWith('10.') ||
              (a.startsWith('172.') && _isInCgNatOr172Private(a))) {
            return a; // first private hit wins
          }
          best ??= a;
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  bool _isInCgNatOr172Private(String a) {
    final second = int.tryParse(a.split('.').elementAt(1));
    return second != null && second >= 16 && second <= 31;
  }

  Future<Set<String>> _getLocalInterfaceAddresses() async {
    final out = <String>{'127.0.0.1', 'localhost'};
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        includeLinkLocal: true,
        type: InternetAddressType.any,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          out.add(addr.address);
        }
      }
    } catch (_) {}
    return out;
  }

  Future<Map<String, dynamic>> startServer(int port, String pairingCode) async {
    final deviceId = await _engine.getDeviceId();
    final deviceName = await _engine.getDeviceName();

    if (_server != null || _registration != null) {
      _logger.log('WiFi', 'Server already running, restarting with fresh registration');
      await stopServer();
    }

    _logger.log('WiFi', 'Starting local server', data: {
      'port': port,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'pairingCodeLength': pairingCode.length,
    });

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _logger.log('WiFi', 'Server started', data: {'port': port});
    
    _server!.listen((HttpRequest request) async {
      _logger.log('WiFi', 'Incoming HTTP request', data: {
        'method': request.method,
        'path': request.uri.path,
        'remote': request.connectionInfo?.remoteAddress.address,
      });

      // LAN discovery parity with desktop Axum (`src-tauri/sync_server.rs`) — probes use GET /sync/status.
      final path = request.uri.path;
      final normalized = path.endsWith('/') && path.length > 1 ? path.substring(0, path.length - 1) : path;
      if (normalized == '/sync/status' && request.method == 'GET') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'device_id': deviceId,
            'device_name': deviceName,
            'service': 'studysync-v1',
          }))
          ..close();
        return;
      }

      if (request.uri.path == '/sync/exchange' && request.method == 'POST') {
        final authHeader = request.headers.value('Authorization');
        if (authHeader != 'Bearer $pairingCode') {
          _logger.log('WiFi', 'Unauthorized exchange request', data: {
            'reason': 'pairing_mismatch',
            'receivedAuth': authHeader,
            'expectedAuth': 'Bearer $pairingCode',
          });
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..write('Invalid pairing code')
            ..close();
          return;
        }

        String content = '';
        try {
          content = await utf8.decoder.bind(request).join();
          _logger.log('WiFi', 'Received request body', data: {
            'bytes': content.length,
          });
          if (content.isNotEmpty) {
            try {
              final outer = jsonDecode(content) as Map<String, dynamic>?;
              final rem = outer?['timestamp'];
              if (rem != null) {
                final n = rem is int ? rem : int.tryParse(rem.toString());
                if (n != null) {
                  final skew = n - DateTime.now().millisecondsSinceEpoch;
                  if (skew.abs() > 60000) {
                    _logger.log('WiFi', 'Clock skew detected', data: {
                      'skewMs': skew,
                    });
                  }
                }
              }
            } catch (_) {
              // ignore
            }
          }
          final clientPayload = SyncEngine.deserializePayload(content);
          _logger.log('WiFi', 'Decoded payload from client', data: {
            'deviceId': clientPayload.deviceId,
            'deviceName': clientPayload.deviceName,
            'tables': clientPayload.tables.keys.toList(),
          });
          
          SyncEngine.isSyncing = true;
          try {
            final applyResult = await _engine.applyPayload(clientPayload);
            final rowsReceived = applyResult.total;

            final hostPayload = await _engine.buildPayload(
              sinceTimestamp: clientPayload.sinceTimestamp
            );
            final rowsSent = SyncEngine.countRows(hostPayload);
            _logger.log('WiFi', 'Prepared response payload', data: {
              'rowsSent': rowsSent,
              'rowsReceived': rowsReceived,
            });

            if (rowsSent > 0 || rowsReceived > 0) {
              await _engine.updateSyncState(
                peerDeviceId: clientPayload.deviceId,
                transport: 'wifi',
                direction: 'bidirectional',
                rowCount: rowsSent + rowsReceived,
              );
            }

            await _engine.recordHistory(SyncHistoryEntry(
              peerDeviceId: clientPayload.deviceId,
              peerDeviceName: clientPayload.deviceName,
              transport: 'wifi',
              direction: 'bidirectional',
              rowsSent: rowsSent,
              rowsReceived: rowsReceived,
              success: true,
            ));

            final responseBody = jsonEncode({
              'accepted': true,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'device_id': deviceId,
              'device_name': deviceName,
              'payload': hostPayload.serialize(),
            });
            request.response
              ..headers.contentType = ContentType.json
              ..write(responseBody)
              ..close();
            _logger.log('WiFi', 'Exchange completed successfully');
          } finally {
            SyncEngine.isSyncing = false;
          }
        } catch (e) {
          _logger.log('WiFi', 'Exchange handler failed', data: {
            'error': '$e',
            'rawContentSnippet': content.length > 500 ? content.substring(0, 500) : content,
          });
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write(e.toString())
            ..close();
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    });

    // mDNS registration is best-effort. NSD on Android often hits "Maximum
    // outstanding requests" / saturated state; that does NOT mean the HTTP
    // server failed — peers reaching us via saved LAN IP still work. We log
    // the failure but treat the server as running.
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: deviceName,
          type: '_studysync._tcp',
          port: port,
          txt: {
            'id': utf8.encode(deviceId),
            'device_id': utf8.encode(deviceId),
            'name': utf8.encode(deviceName),
            'v': utf8.encode('1'),
          },
        ),
      );
      _logger.log('WiFi', 'mDNS service registered', data: {
        'type': '_studysync._tcp',
        'name': deviceName,
        'port': port,
        'advertisedDeviceId': deviceId,
        'txt': ['id', 'device_id', 'name', 'v'],
      });
    } catch (e) {
      _registration = null;
      _logger.log('WiFi', 'mDNS register failed — continuing without advertisement', data: {
        'error': '$e',
        'note': 'HTTP server is up; peers can still connect via saved LAN IP.',
      });
    }

    _startAutoSyncLoop();

    return {'port': port, 'pairingCode': pairingCode};
  }

  /// True iff the local HTTP server is currently bound. Used by the Sync UI
  /// so a failing-but-non-fatal mDNS registration doesn't make us look offline.
  bool get isServerRunning => _server != null;

  Future<void> stopServer() async {
    _logger.log('WiFi', 'Stopping server and discovery');
    _isDiscovering = false;
    _discoveryStartedAt = null;
    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }
    if (_activeDiscovery != null) {
      try {
        await nsd.stopDiscovery(_activeDiscovery!).timeout(const Duration(seconds: 2));
      } catch (_) {}
      _activeDiscovery = null;
    }
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    await _server?.close(force: true);
    _server = null;
    _logger.log('WiFi', 'Server stopped');
  }

  void _startAutoSyncLoop() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      await syncWithPairedPeers();
    });
    _logger.log('WiFi', '[AutoSync] Client loop started', data: {
      'intervalMinutes': 10,
    });
  }

  bool _isOutstandingDiscoveryError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('maximum outstanding requests reached') ||
        msg.contains('maxlimit') ||
        msg.contains('outstanding requests');
  }

  Future<void> _stopActiveDiscoveryQuietly() async {
    if (_activeDiscovery == null) return;
    try {
      await nsd.stopDiscovery(_activeDiscovery!).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Best-effort cleanup.
    } finally {
      _activeDiscovery = null;
    }
  }

  Future<List<WifiPeer>> _performDiscovery({required bool allowRetry}) async {
    try {
      final myDeviceId = await _engine.getDeviceId();
      final localAddresses = await _getLocalInterfaceAddresses();
      _logger.log('WiFi', 'Discovery identity', data: {'myDeviceId': myDeviceId});
      _logger.log('WiFi', 'Local addresses snapshot', data: {
        'addresses': localAddresses.take(10).toList(),
        'count': localAddresses.length,
      });

      _activeDiscovery = await nsd.startDiscovery('_studysync._tcp');
      await Future.delayed(const Duration(seconds: 3));

      final services = _activeDiscovery?.services ?? [];
      _logger.log('WiFi', 'Discovery complete', data: {'rawServices': services.length});

      final Map<String, WifiPeer> peerMap = {};
      for (final s in services) {
        if (s.host == null || s.port == null) {
          _logger.log('WiFi', 'Skipping service without host/port', data: {
            'name': s.name,
            'host': s.host,
            'port': s.port,
          });
          continue;
        }
        final peerId = _decodeTxtValue(s.txt?['id']) ?? _decodeTxtValue(s.txt?['device_id']) ?? 'unknown';
        final peerName = _decodeTxtValue(s.txt?['name'])
            ?? _decodeTxtValue(s.txt?['device_name'])
            ?? s.name
            ?? 'Unknown Device';
        final host = s.host!;
        _logger.log('WiFi', 'Resolved service candidate', data: {
          'name': s.name,
          'host': host,
          'port': s.port,
          'peerId': peerId,
          'peerName': peerName,
          'txtKeys': s.txt?.keys.toList(),
        });
        if (peerId == myDeviceId) {
          _logger.log('WiFi', 'Skipping self service', data: {
            'peerId': peerId,
            'myDeviceId': myDeviceId,
          });
          continue;
        }

        if (host == '127.0.0.1' || host == 'localhost' || host.endsWith('.local')) {
          _logger.log('WiFi', 'Skipping non-routable host', data: {'host': host});
          continue;
        }

        if (localAddresses.contains(host)) {
          _logger.log('WiFi', 'Skipping local interface host candidate', data: {
            'host': host,
            'peerName': peerName,
            'peerId': peerId,
          });
          continue;
        }

        final lastSynced = await _engine.getLastSyncedAt(peerId, 'wifi');
        peerMap[peerId] = WifiPeer(
          ip: host,
          port: s.port!,
          deviceName: peerName,
          deviceId: peerId,
          lastSyncedAt: lastSynced,
          fromLanBookmark: false,
        );
      }
      return await mergeLanBookmarksWithMdns(peerMap.values.toList());
    } catch (e) {
      if (allowRetry && _isOutstandingDiscoveryError(e)) {
        _logger.log('WiFi', 'Discovery saturated, retrying once', data: {'error': '$e'});
        await _stopActiveDiscoveryQuietly();
        await Future.delayed(const Duration(milliseconds: 1200));
        return _performDiscovery(allowRetry: false);
      }
      _logger.log('WiFi', 'Discovery failed', data: {'error': '$e'});
      return await mergeLanBookmarksWithMdns(const <WifiPeer>[]);
    }
  }

  Future<List<Map<String, dynamic>>> _parseStoredBookmarksRaw() async {
    final raw = await _settings.get(kWifiLanPeerBookmarksKey);
    if (raw == null || raw.isEmpty || raw.trim() == '[]') return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return [];
      final out = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) out.add(item);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<List<WifiPeer>> mergeLanBookmarksWithMdns(List<WifiPeer> mdnsPeers) async {
    final myId = await _engine.getDeviceId();
    final raw = await _parseStoredBookmarksRaw();
    final byId = <String, WifiPeer>{};

    for (final m in raw) {
      final id = '${m['deviceId'] ?? m['device_id'] ?? ''}';
      if (id.isEmpty || id == 'unknown') continue;
      final name = '${m['deviceName'] ?? m['device_name'] ?? 'Device'}';
      final host = '${m['host'] ?? ''}'.trim();
      final portRaw = m['port'];
      final port = portRaw is int ? portRaw : int.tryParse('$portRaw');
      if (host.isEmpty || port == null || port < 1 || port > 65535) continue;
      if (id == myId) continue;

      final lastSynced = await _engine.getLastSyncedAt(id, 'wifi');
      byId[id] = WifiPeer(
        ip: host,
        port: port,
        deviceName: name,
        deviceId: id,
        lastSyncedAt: lastSynced,
        fromLanBookmark: true,
      );
    }

    for (final p in mdnsPeers) {
      if (p.deviceId == myId) continue;
      final lastSynced = p.lastSyncedAt ?? await _engine.getLastSyncedAt(p.deviceId, 'wifi');
      byId[p.deviceId] = WifiPeer(
        ip: p.ip,
        port: p.port,
        deviceName: p.deviceName,
        deviceId: p.deviceId,
        lastSyncedAt: lastSynced,
        fromLanBookmark: false,
      );
    }

    final nMarks = byId.values.where((e) => e.fromLanBookmark).length;
    if (mdnsPeers.isEmpty && nMarks > 0) {
      _logger.log('WiFi', 'mDNS peers empty; using saved LAN host entries', data: {'count': nMarks});
    }
    
    final peers = byId.values.toList();
    
    // Set global sync status based on peer discovery results
    if (peers.isEmpty) {
      _ref.read(globalSyncStatusProvider.notifier).setNoPeers();
    }
    
    return peers;
  }

  /// Probe GET `/sync/status` — same routes as Rust `probe_sync_status` / desktop Axum host.
  Future<(String, String)?> probeLanHostForDevice(String host, int port) async {
    for (final path in ['/sync/status', '/sync/status/']) {
      final uri = Uri.parse('http://${host.trim()}:$port$path');
      try {
        final r = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 6));
        if (r.statusCode != 200 || r.body.trim().isEmpty) continue;
        final decoded = jsonDecode(r.body);
        if (decoded is! Map<String, dynamic>) continue;
        final idRaw = decoded['device_id'] ?? decoded['deviceId'] ?? decoded['id'];
        if (idRaw == null || '$idRaw'.isEmpty) continue;
        final name =
            '${decoded['device_name'] ?? decoded['deviceName'] ?? decoded['name'] ?? 'Device'}';
        return ('$idRaw', name);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Persists LAN peer JSON (parity with desktop) and merges into discovery instantly.
  Future<({WifiPeer? peer, String error})> addLanBookmarkPeer(String hostInput, int port) async {
    final host = hostInput.trim();
    if (host.isEmpty || port < 1 || port > 65535) {
      return (peer: null, error: 'Enter a valid host and port.');
    }
    final probed = await probeLanHostForDevice(host, port);
    if (probed == null) {
      return (
        peer: null,
        error: 'Nothing answered at GET /sync/status on http://$host:$port '
            '(StudyTracker desktop must show “Hosting” on same Wi‑Fi).',
      );
    }
    final (deviceId, deviceName) = probed;

    final list = await _parseStoredBookmarksRaw();
    final merged = [
      ...list.where((m) =>
          '${m['deviceId'] ?? m['device_id'] ?? ''}' != deviceId &&
          '${m['device_id'] ?? m['deviceId'] ?? ''}' != deviceId),
      {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'host': host,
        'port': port,
      }
    ];

    await _settings.set(kWifiLanPeerBookmarksKey, jsonEncode(merged));

    final lastSynced = await _engine.getLastSyncedAt(deviceId, 'wifi');
    final peer = WifiPeer(
      ip: host,
      port: port,
      deviceName: deviceName,
      deviceId: deviceId,
      lastSyncedAt: lastSynced,
      fromLanBookmark: true,
    );

    _logger.log('WiFi', 'Saved LAN bookmark', data: {
      'deviceId': deviceId,
      'host': host,
      'port': port,
    });

    return (peer: peer, error: '');
  }

  Future<void> removeLanBookmarkPeer(String deviceId) async {
    final list = await _parseStoredBookmarksRaw();
    final merged = [
      ...list.where((m) =>
          '${m['deviceId'] ?? m['device_id'] ?? ''}' != deviceId &&
          '${m['device_id'] ?? m['deviceId'] ?? ''}' != deviceId)
    ];
    await _settings.set(kWifiLanPeerBookmarksKey, jsonEncode(merged));
    _logger.log('WiFi', 'Forgot LAN bookmark', data: {'deviceId': deviceId});
  }

  /// Bookmarks merged only (instant; avoids full mDNS when list was updated).
  Future<List<WifiPeer>> reloadPeersMergedWithoutMdns() async {
    return mergeLanBookmarksWithMdns(const <WifiPeer>[]);
  }

  Future<List<WifiPeer>> discoverPeers() async {
    if (_isDiscovering) {
      final started = _discoveryStartedAt;
      final stale = started == null || DateTime.now().difference(started) > const Duration(seconds: 10);
      if (!stale) {
        _logger.log('WiFi', 'Discovery already in progress, using saved LAN entries');
        return mergeLanBookmarksWithMdns(const <WifiPeer>[]);
      }

      _logger.log('WiFi', 'Stale discovery detected; resetting discovery state');
      await _stopActiveDiscoveryQuietly();
      _isDiscovering = false;
      _discoveryStartedAt = null;
    }
    _isDiscovering = true;
    _discoveryStartedAt = DateTime.now();
    _logger.log('WiFi', 'Starting mDNS discovery', data: {'service': '_studysync._tcp'});
    
    // Stop any existing discovery session before starting a new one
    if (_activeDiscovery != null) {
      _logger.log('WiFi', 'Stopping existing discovery session before new scan');
      try {
        await nsd.stopDiscovery(_activeDiscovery!).timeout(const Duration(seconds: 2));
      } catch (e) {
        _logger.log('WiFi', 'Failed to stop existing discovery', data: {'error': '$e'});
      }
      _activeDiscovery = null;
      // Give Android NSD time to release the session
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      return await _performDiscovery(allowRetry: true).timeout(
        const Duration(seconds: 9),
        onTimeout: () async {
          _logger.log('WiFi', 'Discovery timed out; using saved LAN entries');
          await _stopActiveDiscoveryQuietly();
          return mergeLanBookmarksWithMdns(const <WifiPeer>[]);
        },
      );
    } finally {
      if (_activeDiscovery != null) {
        try {
          await nsd.stopDiscovery(_activeDiscovery!).timeout(const Duration(seconds: 2));
          _logger.log('WiFi', 'Discovery stopped cleanly');
        } catch (_) {}
        _activeDiscovery = null;
      }
      _isDiscovering = false;
      _discoveryStartedAt = null;
    }
  }

  Future<WifiTransportResult> syncWithPeer(WifiPeer peer, String pairingCode) async {
    _logger.log('WiFi', 'Initiating peer sync', data: {
      'peerName': peer.deviceName,
      'peerId': peer.deviceId,
      'peerIp': peer.ip,
      'peerPort': peer.port,
      'pairingCodeLength': pairingCode.length,
    });

    if (pairingCode.isEmpty) {
      final savedCode = await _engine.getPeerPairingCode(peer.deviceId);
      if (savedCode != null && savedCode.isNotEmpty) {
        pairingCode = savedCode;
      } else {
        final hostCode = await _engine.getHostPairingCode();
        if (hostCode == null || hostCode.isEmpty) {
          _logger.log('WiFi', 'No pairing code for peer, skipping', data: {'peerId': peer.deviceId});
          return const WifiTransportResult(success: false, errorMessage: 'No pairing code stored');
        }
        pairingCode = hostCode;
        _logger.log('WiFi', 'Using host pairing code fallback', data: {
          'peerId': peer.deviceId,
          'codeLength': hostCode.length,
        });
      }
    }

    try {
      // Set global sync status to syncing
      _ref.read(globalSyncStatusProvider.notifier).setSyncing();
      
      final since = await _engine.getLastSyncedAt(peer.deviceId, 'wifi');
      final payload = await _engine.buildPayload(sinceTimestamp: since);
      final rowsSent = SyncEngine.countRows(payload);
      _logger.log('WiFi', 'Client payload prepared', data: {
        'rowsSent': rowsSent,
        'since': since,
      });

      final url = Uri.parse('http://${peer.ip}:${peer.port}/sync/exchange');
      _logger.log('WiFi', 'Sending exchange request', data: {'url': '$url'});
      
      final requestBody = {
        'device_id': await _engine.getDeviceId(),
        'device_name': await _engine.getDeviceName(),
        'pairing_code': pairingCode,
        'payload': payload.serialize(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $pairingCode',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        _logger.log('WiFi', 'Peer returned non-200', data: {
          'statusCode': response.statusCode,
          'body': response.body,
        });

        if (response.statusCode == 401) {
          final hostCode = await _engine.getHostPairingCode();
          if (hostCode != null && hostCode.isNotEmpty && hostCode != pairingCode) {
            _logger.log('WiFi', 'Pairing rejected, retrying with host code fallback', data: {
              'peerId': peer.deviceId,
              'retryCodeLength': hostCode.length,
            });
            return await syncWithPeer(peer, hostCode);
          }
        }

        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }

      _logger.log('WiFi', 'Received exchange response', data: {
        'statusCode': response.statusCode,
        'bytes': response.body.length,
      });
      
      String payloadStr = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('timestamp')) {
            final ts = decoded['timestamp'];
            final n = ts is int ? ts : int.tryParse(ts.toString());
            if (n != null) {
              final skew = n - DateTime.now().millisecondsSinceEpoch;
              if (skew.abs() > 60000) {
                _logger.log('WiFi', 'Clock skew detected from peer', data: {
                  'peer': peer.deviceName,
                  'skewMs': skew,
                });
              }
            }
          }
          if (decoded.containsKey('payload')) {
            payloadStr = decoded['payload'] as String? ?? '{}';
          }
        }
      } catch (_) {
        // Fallback to raw body if not JSON wrapper
      }
      
      SyncEngine.isSyncing = true;
      try {
        final hostPayload = SyncEngine.deserializePayload(payloadStr);
        final applyResult = await _engine.applyPayload(hostPayload);
        final rowsReceived = applyResult.total;

        // Save pairing code for future auto-sync
        if (pairingCode.isNotEmpty) {
          await _engine.savePeerPairingCode(peer.deviceId, pairingCode);
        }

        if (response.statusCode == 200 && (rowsSent > 0 || rowsReceived > 0)) {
          await _engine.updateSyncState(
            peerDeviceId: peer.deviceId,
            transport: 'wifi',
            direction: 'bidirectional',
            rowCount: rowsSent + rowsReceived,
          );
        }

        await _engine.recordHistory(SyncHistoryEntry(
          peerDeviceId: peer.deviceId,
          peerDeviceName: peer.deviceName,
          transport: 'wifi',
          direction: 'bidirectional',
          rowsSent: rowsSent,
          rowsReceived: rowsReceived,
          success: true,
        ));

        _logger.log('WiFi', 'Peer sync complete', data: {
          'rowsSent': rowsSent,
          'rowsReceived': rowsReceived,
        });

        // Set global sync status to success with metadata
        _ref.read(globalSyncStatusProvider.notifier).setSuccess(
          lastSyncedAt: DateTime.now(),
          lastPeerName: peer.deviceName,
          lastRowsReceived: rowsReceived,
        );

        return WifiTransportResult(
          success: true,
          rowsSent: rowsSent,
          rowsReceived: rowsReceived,
        );
      } finally {
        SyncEngine.isSyncing = false;
      }
    } catch (e) {
      _logger.log('WiFi', 'Peer sync failed', data: {'error': '$e'});
      
      // Set global sync status to error
      _ref.read(globalSyncStatusProvider.notifier).setError(e.toString());
      
      await _engine.recordHistory(SyncHistoryEntry(
        peerDeviceId: peer.deviceId,
        peerDeviceName: peer.deviceName,
        transport: 'wifi',
        direction: 'bidirectional',
        success: false,
        errorMessage: e.toString(),
      ));
      return WifiTransportResult(success: false, errorMessage: e.toString());
    }
  }

  /// Discover and sync with all previously paired peers on the network.
  Future<void> syncWithPairedPeers() async {
    if (_isAutoSyncRunning) {
      _logger.log('WiFi', '[AutoSync] Run already in progress, skipping');
      return;
    }

    _isAutoSyncRunning = true;
    _logger.log('WiFi', '[AutoSync] Starting discovery...');
    try {
      final peers = await discoverPeers();
      bool foundTrusted = false;

      for (final peer in peers) {
        final savedCode = await _engine.getPeerPairingCode(peer.deviceId);
        final hostCode = await _engine.getHostPairingCode();
        final effectiveCode = (savedCode != null && savedCode.isNotEmpty)
            ? savedCode
            : ((hostCode != null && hostCode.isNotEmpty) ? hostCode : null);

        _logger.log('WiFi', '[AutoSync] Pairing code lookup', data: {
          'peerId': peer.deviceId,
          'found': effectiveCode != null,
          'codeLength': effectiveCode?.length ?? 0,
        });

        if (effectiveCode == null) {
          _logger.log('WiFi', '[AutoSync] No stored code for peer, skipping', data: {
            'peerId': peer.deviceId,
          });
          continue;
        }

        foundTrusted = true;
        _logger.log('WiFi', '[AutoSync] Found trusted peer, syncing...', data: {
          'peerId': peer.deviceId,
          'peerIp': peer.ip,
        });
        await syncWithPeer(peer, effectiveCode);
      }

      if (!foundTrusted) {
        _logger.log('WiFi', '[AutoSync] No trusted peers found on network');
      }
    } catch (e) {
      _logger.log('WiFi', '[AutoSync] Failed during discovery/sync', data: {'error': '$e'});
    } finally {
      _isAutoSyncRunning = false;
    }
  }
}
