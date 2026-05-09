import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_debug_logger.dart';
import '../../core/sync/wifi_transport.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/db/database.dart' show SyncHistoryData;
import '../../core/utils/responsive.dart';

enum PeerStatusKind { available, syncing, synced, failed, notSeen }

class _PeerStatus {
  final PeerStatusKind kind;
  final String? lastError;
  final DateTime? lastSyncedAt;
  final int? rowsSent;
  final int? rowsReceived;

  _PeerStatus({
    required this.kind,
    this.lastError,
    this.lastSyncedAt,
    this.rowsSent,
    this.rowsReceived,
  });
}



class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  // Device identity
  String _deviceId = '';
  String _deviceName = 'My Device';
  bool _editingName = false;
  late final TextEditingController _nameController;

  // Settings
  // Until _loadState() reads persisted wifiSyncEnabled, assume off — avoids flashing
  // downstream UI that depended on stale defaults while the Sync tab was never opened.
  bool _wifiEnabled = false;
  int _wifiPort = 47821;
  String _wifiPairingCode = '';
  String _passphrase = '';
  
  bool _cloudEnabled = false;
  String _cloudProvider = 'supabase';
  late final TextEditingController _cloudUrlController;
  late final TextEditingController _cloudAnonKeyController;

  // WiFi Transport State
  bool _wifiServerRunning = false;
  bool _discoveringPeers = false;
  List<WifiPeer> _peers = [];
  String? _syncingPeerId;
  WifiPeer? _selectedPeer;
  bool _showPairingInput = false;
  late final TextEditingController _pairingCodeController;
  late final TextEditingController _lanHostController;
  late final TextEditingController _lanPortController;
  Map<String, _PeerStatus> _peerStatus = {};
  bool _lanBookmarkSaving = false;
  /// Our own LAN IPv4 — shown at the top of this screen so the user can type it
  /// onto the other device when mDNS discovery fails on the current network.
  String? _localIp;

  // File Transport State

  bool _fileExporting = false;
  bool _fileImporting = false;
  String? _lastFileExport;
  String? _lastFileImport;
  late final TextEditingController _passphraseController;

  // Cloud Transport State
  bool _cloudOnline = false;
  bool _cloudSyncing = false;
  String? _lastCloudSync;

  // History
  List<SyncHistoryData> _syncHistory = [];
  bool _historyExpanded = false;
  int _unsyncedCount = 0;


  // Debug
  bool _syncDebugEnabled = true;
  bool _syncDebugAlwaysVisible = false;
  final SyncDebugLogger _syncLogger = SyncDebugLogger.instance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _cloudUrlController = TextEditingController();
    _cloudAnonKeyController = TextEditingController();
    _pairingCodeController = TextEditingController();
    _lanHostController = TextEditingController();
    _lanPortController = TextEditingController(text: '47821');
    _passphraseController = TextEditingController();
    
    // Load state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadState();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cloudUrlController.dispose();
    _cloudAnonKeyController.dispose();
    _pairingCodeController.dispose();
    _lanHostController.dispose();
    _lanPortController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }


  Future<void> _loadState() async {
    final engine = ref.read(syncEngineProvider);
    final settings = ref.read(settingsRepositoryProvider);
    
    _deviceId = await engine.getDeviceId();
    _deviceName = await engine.getDeviceName();
    _nameController.text = _deviceName;

    // One-shot LAN IPv4 lookup — this is a local OS call, won't block UI meaningfully.
    try {
      _localIp = await ref.read(wifiTransportProvider).getLocalLanIp();
    } catch (_) {
      _localIp = null;
    }

    final wifiEn = await settings.get('wifiSyncEnabled');
    final wifiPort = await settings.get('wifiSyncPort');
    final wifiCode = await settings.get('wifiSyncPairingCode');
    final pass = await settings.get('syncPassphrase');
    final cloudEn = await settings.get('cloudSyncEnabled');
    final cloudProv = await settings.get('cloudSyncProvider');
    final cloudUrl = await settings.get('cloudSyncUrl');
    final cloudAnon = await settings.get('cloudSyncAnonKey');
    final debugEnabled = await settings.get('syncDebugEnabled');
    final debugAlwaysVisible = await settings.get('syncDebugAlwaysVisible');

    if (!mounted) return;
    setState(() {
      _wifiEnabled = wifiEn == 'true';
      _wifiPort = int.tryParse(wifiPort ?? '') ?? 47821;
      _wifiPairingCode = wifiCode ?? '';
      _passphrase = pass ?? '';
      _passphraseController.text = _passphrase;
      
      _cloudEnabled = cloudEn == 'true';
      _cloudProvider = cloudProv ?? 'supabase';
      _cloudUrlController.text = cloudUrl ?? '';
      _cloudAnonKeyController.text = cloudAnon ?? '';

      _syncDebugEnabled = debugEnabled != 'false';
      _syncDebugAlwaysVisible = debugAlwaysVisible == 'true';
    });

    _syncLogger.setEnabled(_syncDebugEnabled);
    _syncLogger.setAlwaysVisible(_syncDebugAlwaysVisible);
    _syncLogger.log('UI', 'Sync screen loaded', data: {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'wifiEnabled': _wifiEnabled,
    });

    final cloudTransport = ref.read(cloudTransportProvider);
    _cloudOnline = await cloudTransport.checkOnline();
    if (!mounted) return;

    await _refreshHistory();
    if (!mounted) return;

    if (_wifiEnabled) {
      await _startWifiServer();
      if (!mounted) return;
      _triggerAutoSync(); // one immediate attempt after server start
    }
    _refreshUnsyncedCount();
  }


  void _triggerAutoSync() {
    if (!_wifiEnabled || !_wifiServerRunning ||
        _discoveringPeers ||
        _syncingPeerId != null) {
      return;
    }

    _syncLogger.log('UI', 'Auto-sync triggered');
    ref.read(wifiTransportProvider).syncWithPairedPeers().then((_) {
      if (mounted) {
        _refreshHistory();
        _refreshUnsyncedCount();
      }
    }).catchError((e) {
      _syncLogger.log('UI', 'Auto-sync failed', data: {'error': e.toString()});
    });
  }


  Future<void> _refreshHistory() async {
    final engine = ref.read(syncEngineProvider);
    final history = await engine.getHistory(limit: 20);
    if (!mounted) return;
    setState(() {
      _syncHistory = history;
    });
  }

  Future<void> _refreshUnsyncedCount() async {
    try {
      final engine = ref.read(syncEngineProvider);
      final count = await engine.getUnsyncedCount();
      if (!mounted) return;
      setState(() {
        _unsyncedCount = count;
      });
    } catch (e) {
      _syncLogger.log('UI', 'Failed to refresh unsynced count', data: {'error': e.toString()});
    }
  }


  Future<void> _saveDeviceName() async {
    final engine = ref.read(syncEngineProvider);
    await engine.setDeviceName(_nameController.text);
    if (!mounted) return;
    setState(() {
      _deviceName = _nameController.text;
      _editingName = false;
    });
    _showSyncToast('Device name updated.');

  }

  // ── WiFi ────────────────────────────────────────────────────────────────────

  Future<void> _startWifiServer() async {
    final wifi = ref.read(wifiTransportProvider);
    final settings = ref.read(settingsRepositoryProvider);
    try {
      final pairingCode = _wifiPairingCode.isEmpty
          ? SyncEngine.generatePairingCode()
          : _wifiPairingCode;

      final info = await wifi.startServer(_wifiPort, pairingCode);
      if (!mounted) return;

      setState(() {
        _wifiServerRunning = wifi.isServerRunning;
        _wifiPairingCode = info['pairingCode'];
      });

      // Mirror desktop semantics: opting into hosting implies sync is configured on.
      // Persists across restarts and drives Shell pill visibility via settingsProvider.
      await settings.set('wifiSyncEnabled', 'true');
      if (mounted) {
        setState(() => _wifiEnabled = true);
      }

      await settings.set('wifiSyncPairingCode', _wifiPairingCode);

      await _discoverPeers();
    } catch (e) {
      // The HTTP socket may have bound successfully even if a downstream step
      // (e.g. NSD register) errored. Reflect the true state instead of pretending
      // we're stopped — otherwise the UI says "Server stopped" while the server
      // is happily serving exchanges, which is what users have been seeing.
      if (!mounted) return;
      final actuallyRunning = wifi.isServerRunning;
      setState(() {
        _wifiServerRunning = actuallyRunning;
      });
      if (actuallyRunning) {
        await settings.set('wifiSyncEnabled', 'true');
        if (mounted) setState(() => _wifiEnabled = true);
        _showSyncToast(
          'WiFi server is up, but mDNS advertisement failed. Other devices can still reach us via LAN IP. ($e)',
        );
      } else {
        _showSyncToast('Failed to start WiFi server: $e', isError: true);
      }
    }
  }

  Future<void> _refreshLanPeersMerged() async {
    final wifi = ref.read(wifiTransportProvider);
    final merged = await wifi.reloadPeersMergedWithoutMdns();
    if (!mounted) return;
    setState(() => _peers = merged);
  }

  Future<void> _addLanBookmark() async {
    if (!_wifiServerRunning) return;
    final port =
        int.tryParse(_lanPortController.text.trim()) ?? _wifiPort;
    if (_lanHostController.text.trim().isEmpty) {
      _showSyncToast('Enter the other device’s LAN IPv4.', isError: true);
      return;
    }
    setState(() => _lanBookmarkSaving = true);
    try {
      final wifi = ref.read(wifiTransportProvider);
      final result = await wifi.addLanBookmarkPeer(_lanHostController.text, port);
      if (!mounted) return;
      if (result.error.isNotEmpty) {
        _showSyncToast(result.error, isError: true);
        return;
      }
      final merged = await wifi.reloadPeersMergedWithoutMdns();
      if (!mounted) return;
      setState(() {
        _peers = merged;
        _lanHostController.clear();
      });
      _showSyncToast('Peer added — use PC’s pairing code when pairing the first time.');
      _triggerAutoSync();
    } finally {
      if (mounted) setState(() => _lanBookmarkSaving = false);
    }
  }

  Future<void> _forgetLanBookmark(WifiPeer peer) async {
    final wifi = ref.read(wifiTransportProvider);
    await wifi.removeLanBookmarkPeer(peer.deviceId);
    if (!mounted) return;
    await _refreshLanPeersMerged();
    _showSyncToast('Forgot saved LAN address for ${peer.deviceName}.');
  }

  Future<void> _stopWifiServer() async {
    // Persist first so Shell pill + SyncService read the real flag even if Rust stop
    // is slow — and cancel any outbound auto-sync that was scheduled by SyncTrigger
    // (which must not trust the pre-debounce settingsProvider snapshot).
    final settings = ref.read(settingsRepositoryProvider);
    await settings.set('wifiSyncEnabled', 'false');
    if (!mounted) return;

    try {
      final wifi = ref.read(wifiTransportProvider);
      await wifi.stopServer();
      if (!mounted) return;
      setState(() {
        _wifiEnabled = false;
        _wifiServerRunning = false;
        _peers = [];
      });
    } catch (e) {
      if (mounted) _showSyncToast('Failed to stop WiFi server: $e', isError: true);
    }
  }

  Future<void> _discoverPeers() async {
    if (!mounted) return;
    setState(() => _discoveringPeers = true);
    try {
      final wifi = ref.read(wifiTransportProvider);
      final found = await wifi.discoverPeers();
      if (mounted) {
        setState(() {
          _peers = found;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSyncToast('Peer discovery failed: $e', isError: true);

      }
    } finally {
      if (mounted) {
        setState(() => _discoveringPeers = false);
      }
    }

    // Discovery is async across stop-server; never kick auto-sync once hosting is off or
    // the user disabled sync — this was firing right after logs showed "Stopping server".
    if (!mounted || !_wifiEnabled || !_wifiServerRunning) return;

    if (_peers.isNotEmpty) {
      final engine = ref.read(syncEngineProvider);
      for (final peer in _peers) {
        final code = await engine.getPeerPairingCode(peer.deviceId);
        if (code != null) {
          _triggerAutoSync();
          break;
        }
      }
    }
  }


  Future<void> _regeneratePairingCode() async {
    final newCode = SyncEngine.generatePairingCode();
    final settings = ref.read(settingsRepositoryProvider);
    await settings.set('wifiSyncPairingCode', newCode);
    if (!mounted) return;
    setState(() {
      _wifiPairingCode = newCode;
    });
    await _stopWifiServer();
    if (!mounted) return;
    await _startWifiServer();
    if (!mounted) return;
    _showSyncToast('New pairing code generated.');

  }

  Future<void> _resetSyncState(WifiPeer peer) async {
    // BEHAVIOR-B2 "Force full sync": null-out lastSyncedAt so buildPayload() emits every row,
    // then kick off a real sync right away. Just resetting would force the user to tap Sync
    // again, which is a footgun — we never want a half-applied "reset but not yet synced" state.
    final engine = ref.read(syncEngineProvider);
    await engine.updateSyncState(
      peerDeviceId: peer.deviceId,
      transport: 'wifi',
      direction: 'bidirectional',
      rowCount: 0,
      clear: true,
    );
    _showSyncToast('Full sync starting with ${peer.deviceName}…');

    final code = await engine.getPeerPairingCode(peer.deviceId)
        ?? await engine.getHostPairingCode()
        ?? '';
    if (code.isEmpty) {
      await _discoverPeers();
      return;
    }
    await _syncWithPeer(peer, code);
  }

  Future<void> _syncWithPeer(WifiPeer peer, String pairingCode) async {
    if (!mounted) return;
    setState(() {
      _syncingPeerId = peer.deviceId;
      _peerStatus[peer.deviceId] = _PeerStatus(kind: PeerStatusKind.syncing);
    });
    try {
      final wifi = ref.read(wifiTransportProvider);
      final result = await wifi.syncWithPeer(peer, pairingCode);
      if (!mounted) return;
      
      if (result.success) {
        final total = (result.rowsSent ?? 0) + (result.rowsReceived ?? 0);

        // One-time host-code model: when user enters a code and sync succeeds,
        // reuse that code locally so this device can be synced silently later.
        if (pairingCode.trim().isNotEmpty && pairingCode.trim() != _wifiPairingCode) {
          final normalized = pairingCode.trim();
          final settings = ref.read(settingsRepositoryProvider);
          await settings.set('wifiSyncPairingCode', normalized);
          if (!mounted) return;
          setState(() {
            _wifiPairingCode = normalized;
          });
          if (_wifiServerRunning) {
            await _stopWifiServer();
            if (!mounted) return;
            await _startWifiServer();
            if (!mounted) return;
          }
        }

        setState(() {
          _peerStatus[peer.deviceId] = _PeerStatus(
            kind: PeerStatusKind.synced,
            lastSyncedAt: DateTime.now(),
            rowsSent: result.rowsSent,
            rowsReceived: result.rowsReceived,
          );
          _showPairingInput = false;
          _selectedPeer = null;
        });
        _showSyncToast('Synced with ${peer.deviceName}: $total rows exchanged.');
      } else {
        setState(() {
          _peerStatus[peer.deviceId] = _PeerStatus(
            kind: PeerStatusKind.failed,
            lastError: result.errorMessage,
          );
        });
        
        // If sync failed because we have no saved code, allow the user to enter it
        if (result.errorMessage?.contains('pairing code') == true || 
            result.errorMessage?.contains('stored') == true) {
          setState(() {
            _selectedPeer = peer;
            _showPairingInput = true;
            _pairingCodeController.clear();
          });
        }
        
        _showSyncToast(result.errorMessage ?? 'Sync failed', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingPeerId = null;
        });
        await _refreshHistory();
        await _refreshUnsyncedCount();
      }
    }
  }



  // ── File ────────────────────────────────────────────────────────────────────

  Future<void> _savePassphrase() async {
    final settings = ref.read(settingsRepositoryProvider);
    final val = _passphraseController.text;
    await settings.set('syncPassphrase', val);
    if (!mounted) return;
    setState(() {
      _passphrase = val;
    });
    _showSyncToast('Passphrase saved.');

  }

  Future<void> _handleExportFile() async {
    if (!mounted) return;
    setState(() => _fileExporting = true);
    try {
      final fileT = ref.read(fileTransportProvider);
      final result = await fileT.export(passphrase: _passphrase);
      if (!mounted) return;
      
      if (result.success) {
        if (!mounted) return;
        setState(() {
          _lastFileExport = DateTime.now().toUtc().toIso8601String();
        });
        _showSyncToast('Exported ${result.rowsExported ?? 0} rows.');

        await _refreshHistory();
      } else {
        _showSyncToast(result.errorMessage ?? 'Export failed', isError: true);

      }
    } finally {
      if (mounted) {
        setState(() => _fileExporting = false);
      }
    }
  }

  Future<void> _handleImportFile() async {
    if (!mounted) return;
    setState(() => _fileImporting = true);
    try {
      final fileT = ref.read(fileTransportProvider);
      final result = await fileT.import(passphrase: _passphrase);
      if (!mounted) return;
      
      if (result.success) {
        if (!mounted) return;
        setState(() {
          _lastFileImport = DateTime.now().toUtc().toIso8601String();
        });
        _showSyncToast('Imported ${result.rowsImported ?? 0} rows.');

        await _refreshHistory();
      } else {
        _showSyncToast(result.errorMessage ?? 'Import failed', isError: true);

      }
    } finally {
      if (mounted) {
        setState(() => _fileImporting = false);
      }
    }
  }

  // ── Cloud ───────────────────────────────────────────────────────────────────

  Future<void> _saveCloudSettings() async {
    final settings = ref.read(settingsRepositoryProvider);
    await settings.set('cloudSyncEnabled', _cloudEnabled.toString());
    await settings.set('cloudSyncProvider', _cloudProvider);
    await settings.set('cloudSyncUrl', _cloudUrlController.text);
    await settings.set('cloudSyncAnonKey', _cloudAnonKeyController.text);
    if (!mounted) return;
    _showSyncToast('Cloud settings saved.');

  }

  Future<void> _handleCloudSync() async {
    if (!mounted) return;
    setState(() => _cloudSyncing = true);
    try {
      final cloudT = ref.read(cloudTransportProvider);
      final result = await cloudT.runCloudSync();
      if (!mounted) return;
      
      if (result.success) {
        if (!mounted) return;
        setState(() {
          _lastCloudSync = DateTime.now().toUtc().toIso8601String();
        });
        final total = (result.rowsSent ?? 0) + (result.rowsReceived ?? 0);
        _showSyncToast('Cloud sync: $total rows exchanged.');

        await _refreshHistory();
      } else {
        _showSyncToast(result.errorMessage ?? 'Cloud sync failed', isError: true);

      }
    } finally {
      if (mounted) {
        setState(() => _cloudSyncing = false);
      }
    }
  }

  void _showSyncToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red[700] : Colors.green[700],
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }




  String _transportIcon(String transport) {
    if (transport == 'wifi') return '📶';
    if (transport == 'file') return '📁';
    if (transport == 'cloud') return '☁️';
    if (transport == 'bluetooth') return '🔵';
    return '🔄';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !R.isPhone(context) && !R.isLandscape(context);
    final cardPadding = EdgeInsets.all(isDesktop ? 24.0 : 16.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 16,
            vertical: isDesktop ? 32 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildDeviceIdentity(cardPadding),
              const SizedBox(height: 24),
              _buildWifiSection(cardPadding),
              const SizedBox(height: 24),
              _buildBluetoothSection(cardPadding),
              const SizedBox(height: 24),
              _buildFileSection(cardPadding),
              const SizedBox(height: 24),
              _buildCloudSection(cardPadding),
              const SizedBox(height: 24),
              _buildHistorySection(cardPadding),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: AppTypography.textTheme.labelMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(LucideIcons.arrowUpDown, size: 28, color: AppColors.onSurface),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Device Sync',
                style: AppTypography.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Transfer your study data between devices — no cloud account required.\nUses WiFi first, then file export as fallback.',
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceIdentity(EdgeInsets padding) {
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(LucideIcons.settings, size: 16, color: AppColors.onSurface),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'This Device',
                        style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.shield, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Local Only',
                      style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ID: ${_deviceId.length > 16 ? '${_deviceId.substring(0, 16)}…' : _deviceId}',
            style: AppTypography.textTheme.labelSmall?.copyWith(
              color: AppColors.outlineVariant,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          // On-LAN banner. Shown prominently so the user can type this verbatim on
          // the other device when auto-discovery fails (guest Wi-Fi, blocked mDNS, etc).
          // Tap the chip to copy "ip:port" to the clipboard.
          Row(
            children: [
              Text(
                'ON THIS LAN',
                style: AppTypography.textTheme.labelSmall?.copyWith(
                  color: AppColors.outlineVariant,
                  letterSpacing: 1.4,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              if (_localIp != null)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final text = '$_localIp:$_wifiPort';
                    // ignore: deprecated_member_use
                    Clipboard.setData(ClipboardData(text: text));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Copied $text'), duration: const Duration(seconds: 2)),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.wifi, size: 11, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          '$_localIp:$_wifiPort',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  'offline',
                  style: AppTypography.textTheme.labelSmall?.copyWith(
                    color: AppColors.outlineVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_editingName)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Device name',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  text: 'Save',
                  onPressed: _saveDeviceName,
                ),
                const SizedBox(width: 8),
                AppButton(
                  text: 'Cancel',
                  onPressed: () => setState(() => _editingName = false),
                  type: AppButtonType.secondary,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    _deviceName,
                    style: AppTypography.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    _nameController.text = _deviceName;
                    setState(() => _editingName = true);
                  },
                  child: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWifiSection(EdgeInsets padding) {
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(LucideIcons.wifi, size: 16),
                    Text(
                      'Local WiFi',
                      style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (_unsyncedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.alertCircle, size: 10, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              '$_unsyncedCount unsynced',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PRIORITY 1',
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_wifiServerRunning)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Hosting on :$_wifiPort',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.wifiOff, size: 12, color: AppColors.outlineVariant),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Server stopped',
                          style: TextStyle(fontSize: 12, color: AppColors.outlineVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Same Wi‑Fi as the PC. Scan often only lists this phone (Android NSD). To reach the desktop, add its LAN IPv4 below — no multicast required.',
            style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_wifiServerRunning && _wifiPairingCode.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.1),
                border: Border.all(color: AppColors.primaryContainer),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pairing code (share with other device)', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          _wifiPairingCode,
                          style: AppTypography.textTheme.headlineMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4.0,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _regeneratePairingCode,
                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                    label: const Text('New code', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!_wifiServerRunning)
                AppButton(
                  text: 'Start hosting',
                  icon: LucideIcons.wifi,
                  onPressed: _startWifiServer,
                )
              else ...[
                AppButton(
                  text: 'Stop server',
                  icon: LucideIcons.wifiOff,
                  type: AppButtonType.secondary,
                  onPressed: _stopWifiServer,
                ),
                AppButton(
                  text: _discoveringPeers ? 'Scanning…' : 'Scan for peers',
                  icon: _discoveringPeers ? LucideIcons.loader : LucideIcons.radio,
                  type: AppButtonType.secondary,
                  onPressed: _discoveringPeers ? () {} : () => _discoverPeers(),
                ),
              ],
            ],
          ),
          if (_wifiServerRunning) ...[
            // Compact saved-bookmarks panel. Chips for each saved peer (tap × to remove),
            // with the add-peer form packed tightly below. Keeps the block short on phones.
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (context) {
                    final bookmarks = _peers.where((p) => p.fromLanBookmark).toList();
                    return Row(
                      children: [
                        Text(
                          'Saved peers',
                          style: AppTypography.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bookmarks.isEmpty ? 'none yet' : '${bookmarks.length} saved',
                          style: AppTypography.textTheme.labelSmall?.copyWith(
                            color: AppColors.outlineVariant,
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 6),
                  // Chips for saved bookmarks — name + ip:port + remove. Wraps naturally.
                  Builder(builder: (context) {
                    final bookmarks = _peers.where((p) => p.fromLanBookmark).toList();
                    if (bookmarks.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: bookmarks.map((bm) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  bm.deviceName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${bm.ip}:${bm.port}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: AppColors.outlineVariant,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _forgetLanBookmark(bm),
                                  borderRadius: BorderRadius.circular(10),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(LucideIcons.x, size: 12, color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                  Text(
                    'Add peer — IPv4 + port of the other device (hosting must be on).',
                    style: TextStyle(fontSize: 11, height: 1.3, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lanHostController,
                          enabled: !_lanBookmarkSaving,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: 'Host / IPv4',
                            hintText: 'e.g. 192.168.1.9',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _lanPortController,
                          enabled: !_lanBookmarkSaving,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Port',
                            hintText: '47821',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        text: _lanBookmarkSaving ? '…' : 'Add',
                        onPressed: !_lanBookmarkSaving ? _addLanBookmark : () {},
                        size: AppButtonSize.small,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_peers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3), style: BorderStyle.none),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(LucideIcons.radio, size: 24, color: AppColors.outlineVariant),
                    const SizedBox(height: 8),
                    Text('No devices found nearby.', style: TextStyle(color: AppColors.onSurfaceVariant)),
                    Text('Tap “Add” above with the PC’s LAN IP, or use Scan if your router allows mDNS between devices.', style: TextStyle(fontSize: 12, color: AppColors.outlineVariant)),
                    const SizedBox(height: 8),
                    Text('Device ID: ${_deviceId.isEmpty ? 'unknown' : _deviceId}', style: TextStyle(fontSize: 11, color: AppColors.outlineVariant)),
                  ],
                ),
              )
            else
              Column(
                children: _peers.map((peer) {
                  final status = _peerStatus[peer.deviceId];
                  final isSyncing = status?.kind == PeerStatusKind.syncing || _syncingPeerId == peer.deviceId;
                  final showInput = _selectedPeer?.deviceId == peer.deviceId && _showPairingInput;
                  
                  // Status UI helper
                  Color statusColor = AppColors.outlineVariant;
                  String statusText = 'Available';
                  String shortId = peer.deviceId.length > 8 ? '${peer.deviceId.substring(0, 8)}...' : peer.deviceId;
                  String metaText = 'ID: $shortId | ${peer.ip}:${peer.port}';


                  if (isSyncing) {
                    statusColor = Colors.orange;
                    statusText = 'Syncing...';

                  } else if (status?.kind == PeerStatusKind.synced) {
                    statusColor = AppColors.primary;
                    statusText = 'Synced just now';
                    if (status?.rowsSent != null || status?.rowsReceived != null) {
                      statusText += ' · ↑${status?.rowsSent} ↓${status?.rowsReceived}';
                    }

                  } else if (status?.kind == PeerStatusKind.failed) {
                    statusColor = Colors.red;
                    statusText = 'Failed: ${status?.lastError ?? 'Unknown error'}';

                  } else if (peer.lastSyncedAt != null) {
                    statusColor = AppColors.primary.withOpacity(0.6);
                    statusText = 'Last sync: ${SyncEngine.formatSyncTime(DateTime.tryParse(peer.lastSyncedAt!))}';

                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSyncing ? AppColors.primary.withOpacity(0.5) : AppColors.outlineVariant.withOpacity(0.2),
                        width: isSyncing ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          peer.deviceName,
                                          style: AppTypography.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (peer.lastSyncedAt != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryContainer.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'TRUSTED',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: statusColor.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    metaText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.onSurfaceVariant.withOpacity(0.5),
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!showInput) ...[
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: isSyncing ? null : () => _resetSyncState(peer),
                                      ),
                                      if (peer.fromLanBookmark) ...[
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Forget saved LAN IP',
                                          icon: Icon(LucideIcons.mapPinOff, size: 16, color: AppColors.outlineVariant),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: isSyncing ? null : () => _forgetLanBookmark(peer),
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      AppButton(
                                        text: isSyncing ? 'Syncing' : (peer.lastSyncedAt != null ? 'Sync' : 'Pair'),
                                        size: AppButtonSize.small,
                                        type: AppButtonType.secondary,
                                        onPressed: isSyncing ? () {} : () {
                                          if (peer.lastSyncedAt != null) {
                                            _syncWithPeer(peer, '');
                                          } else {
                                            setState(() {
                                              _selectedPeer = peer;
                                              _showPairingInput = true;
                                              _pairingCodeController.clear();
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        if (showInput) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _pairingCodeController,
                                  decoration: InputDecoration(
                                    hintText: 'Pairing code',
                                    isDense: true,
                                    prefixIcon: const Icon(LucideIcons.lock, size: 16),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                text: 'Pair',
                                onPressed: () => _syncWithPeer(peer, _pairingCodeController.text),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(LucideIcons.x, size: 20),
                                onPressed: () => setState(() {
                                  _showPairingInput = false;
                                  _selectedPeer = null;
                                }),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );

                }).toList(),
              ),
          ],
          // BEHAVIOR-B3: Flutter auto-syncs on a 10-minute timer while WiFi is enabled.
          const SizedBox(height: 12),
          Text(
            'Auto-sync: every 10 minutes while this app is open.',
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothSection(EdgeInsets padding) {
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(LucideIcons.bluetooth, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Bluetooth',
                        style: AppTypography.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.outlineVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PRIORITY 2',
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.outlineVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Bluetooth sync will be fully available in the next Android update.\nWindows 10 does not reliably support acting as a Bluetooth peripheral without custom drivers. Use WiFi or File sync on desktop.',
            style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.outlineVariant),
          ),
        ],
      ),
    );
  }



  Widget _buildFileSection(EdgeInsets padding) {
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(LucideIcons.fileDown, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'File Export / Import',
                        style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRIORITY 4',
                  style: AppTypography.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Export your data as an encrypted .studysync file. Send it via USB, email, messaging app, or cloud storage. Import on the other device to sync.',
            style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text('Encryption passphrase', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _passphraseController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Leave blank for no encryption',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                text: 'Save',
                onPressed: _savePassphrase,
                type: AppButtonType.secondary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Must match on both devices to decrypt the file.', style: TextStyle(fontSize: 12, color: AppColors.outlineVariant)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AppButton(
                text: _fileExporting ? 'Exporting...' : 'Export sync file',
                icon: LucideIcons.fileDown,
                onPressed: _fileExporting ? () {} : () => _handleExportFile(),
              ),
              AppButton(
                text: _fileImporting ? 'Importing...' : 'Import sync file',
                icon: LucideIcons.fileUp,
                type: AppButtonType.secondary,
                onPressed: _fileImporting ? () {} : () => _handleImportFile(),
              ),
            ],
          ),
          if (_lastFileExport != null || _lastFileImport != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (_lastFileExport != null)
                    Text('Last export: ${SyncEngine.formatSyncTime(DateTime.tryParse(_lastFileExport!))}', style: TextStyle(fontSize: 12, color: AppColors.outlineVariant)),
                  if (_lastFileImport != null)
                    Text('Last import: ${SyncEngine.formatSyncTime(DateTime.tryParse(_lastFileImport!))}', style: TextStyle(fontSize: 12, color: AppColors.outlineVariant)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCloudSection(EdgeInsets padding) {
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(_cloudOnline ? LucideIcons.cloud : LucideIcons.cloudOff, size: 16, color: _cloudOnline ? AppColors.onSurface : AppColors.outlineVariant),
                    Text(
                      'Cloud Sync',
                      style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PRIORITY 5 · OPTIONAL',
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _cloudEnabled,
                onChanged: (val) {
                  setState(() => _cloudEnabled = val);
                  _saveCloudSettings();
                },
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Background sync over the internet. Disabled by default. Supports Supabase (free), or any custom endpoint that accepts the sync payload. No data leaves this device when disabled.',
            style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          if (_cloudEnabled) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _cloudUrlController,
              decoration: const InputDecoration(labelText: 'Endpoint URL', hintText: 'https://your-project.supabase.co'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cloudAnonKeyController,
              decoration: const InputDecoration(labelText: 'API key / anon key', hintText: 'eyJ...'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AppButton(
                  text: 'Save cloud settings',
                  type: AppButtonType.secondary,
                  onPressed: _saveCloudSettings,
                ),
                AppButton(
                  text: _cloudSyncing ? 'Syncing...' : 'Sync now',
                  icon: LucideIcons.refreshCw,
                  onPressed: _cloudUrlController.text.isEmpty || _cloudSyncing ? () {} : () => _handleCloudSync(),
                ),
              ],
            ),
            if (_lastCloudSync != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Last cloud sync: ${SyncEngine.formatSyncTime(DateTime.tryParse(_lastCloudSync!))}', style: TextStyle(fontSize: 12, color: AppColors.outlineVariant)),
              ),
            if (!_cloudOnline)
              Container(
                margin: const EdgeInsets.only(top: 12.0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.cloudOff, size: 16, color: Colors.amber[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('No internet connection detected. Cloud sync will retry automatically.', style: TextStyle(color: Colors.amber[800], fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorySection(EdgeInsets padding) {
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _historyExpanded = !_historyExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Sync History',
                          style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${_syncHistory.length} events)',
                        style: TextStyle(color: AppColors.outlineVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(_historyExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 16, color: AppColors.outlineVariant),
              ],
            ),
          ),
          if (_historyExpanded) ...[
            const SizedBox(height: 16),
            if (_syncHistory.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No sync events yet.', style: TextStyle(color: Colors.grey))))
            else
              Column(
                children: _syncHistory.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.surfaceVariant,
                    ),
                    child: Row(
                      children: [
                        Text(_transportIcon(entry.transport), style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.peerDeviceName ?? 'Unknown device', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                              Text(
                                '↑ ${entry.rowsSent} sent · ↓ ${entry.rowsReceived} received · ${SyncEngine.formatSyncTime(entry.syncedAt)}',
                                style: TextStyle(fontSize: 12, color: AppColors.outlineVariant),
                              ),
                            ],
                          ),
                        ),
                        if (entry.success)
                          const Icon(LucideIcons.checkCircle2, size: 16, color: Colors.green)
                        else
                          Tooltip(
                            message: entry.errorMessage ?? 'Failed',
                            child: const Icon(LucideIcons.xCircle, size: 16, color: Colors.red),
                          ),
                        const SizedBox(width: 4), // Added some spacing
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }
}
