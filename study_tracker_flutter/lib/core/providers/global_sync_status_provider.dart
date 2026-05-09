import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global sync status types matching desktop implementation
enum GlobalSyncStatus {
  idle('idle'),
  syncing('syncing'),
  success('success'),
  error('error'),
  noPeers('no_peers');

  const GlobalSyncStatus(this.value);
  final String value;

  static GlobalSyncStatus fromString(String value) {
    return GlobalSyncStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => GlobalSyncStatus.idle,
    );
  }
}

/// Global sync state data
class GlobalSyncState {
  final GlobalSyncStatus status;
  final DateTime? lastSyncedAt;
  final String? lastPeerName;
  final int? lastRowsReceived;
  final String? lastError;

  const GlobalSyncState({
    required this.status,
    this.lastSyncedAt,
    this.lastPeerName,
    this.lastRowsReceived,
    this.lastError,
  });

  GlobalSyncState copyWith({
    GlobalSyncStatus? status,
    DateTime? lastSyncedAt,
    String? lastPeerName,
    int? lastRowsReceived,
    String? lastError,
  }) {
    return GlobalSyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastPeerName: lastPeerName ?? this.lastPeerName,
      lastRowsReceived: lastRowsReceived ?? this.lastRowsReceived,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Global sync status provider
class GlobalSyncStatusNotifier extends StateNotifier<GlobalSyncState> {
  GlobalSyncStatusNotifier()
      : super(const GlobalSyncState(status: GlobalSyncStatus.idle));

  /// Set global sync status with optional metadata
  void setStatus(
    GlobalSyncStatus status, {
    DateTime? lastSyncedAt,
    String? lastPeerName,
    int? lastRowsReceived,
    String? lastError,
  }) {
    state = state.copyWith(
      status: status,
      lastSyncedAt: lastSyncedAt,
      lastPeerName: lastPeerName,
      lastRowsReceived: lastRowsReceived,
      lastError: lastError,
    );

    // Auto-transition from 'success' to 'idle' after 4 seconds
    if (status == GlobalSyncStatus.success) {
      Future.delayed(const Duration(seconds: 4), () {
        if (state.status == GlobalSyncStatus.success) {
          state = state.copyWith(status: GlobalSyncStatus.idle);
        }
      });
    }
  }

  /// Convenience methods for common status updates
  void setSyncing() => setStatus(GlobalSyncStatus.syncing);
  
  void setSuccess({
    required DateTime lastSyncedAt,
    required String lastPeerName,
    required int lastRowsReceived,
  }) => setStatus(
    GlobalSyncStatus.success,
    lastSyncedAt: lastSyncedAt,
    lastPeerName: lastPeerName,
    lastRowsReceived: lastRowsReceived,
  );
  
  void setError(String error) => setStatus(
    GlobalSyncStatus.error,
    lastError: error,
  );
  
  void setNoPeers() => setStatus(GlobalSyncStatus.noPeers);
  
  void setIdle() => setStatus(GlobalSyncStatus.idle);
}

/// Global sync status provider
final globalSyncStatusProvider =
    StateNotifierProvider<GlobalSyncStatusNotifier, GlobalSyncState>((ref) {
  return GlobalSyncStatusNotifier();
});