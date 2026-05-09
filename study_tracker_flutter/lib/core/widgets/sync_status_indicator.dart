import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/global_sync_status_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../../app/router.dart';

/// Spec asks for teal while syncing — keep local so we don't widen [AppColors] for one widget.
const Color _syncingTeal = Color(0xFF14B8A6);

/// Full-width pill used inside the sidebar (desktop wide layouts). Hidden when sync is disabled.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  Color _getStatusColor(GlobalSyncStatus status) {
    switch (status) {
      case GlobalSyncStatus.idle:
        return AppColors.onSurfaceVariant;
      case GlobalSyncStatus.syncing:
        return _syncingTeal;
      case GlobalSyncStatus.success:
        return AppColors.primary;
      case GlobalSyncStatus.error:
        return AppColors.error;
      case GlobalSyncStatus.noPeers:
        return AppColors.outlineVariant;
    }
  }

  IconData _getStatusIcon(GlobalSyncStatus status) {
    switch (status) {
      case GlobalSyncStatus.idle:
        return Icons.wifi;
      case GlobalSyncStatus.syncing:
        return Icons.sync;
      case GlobalSyncStatus.success:
        return Icons.check_circle;
      case GlobalSyncStatus.error:
        return Icons.error;
      case GlobalSyncStatus.noPeers:
        return Icons.wifi_off;
    }
  }

  String _getStatusLabel(GlobalSyncStatus status) {
    switch (status) {
      case GlobalSyncStatus.idle:
        return 'Synced';
      case GlobalSyncStatus.syncing:
        return 'Syncing...';
      case GlobalSyncStatus.success:
        return 'Just synced';
      case GlobalSyncStatus.error:
        return 'Sync failed';
      case GlobalSyncStatus.noPeers:
        return 'No devices found';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide entirely when the user hasn't enabled sync. Spec: the indicator must only
    // appear once sync is configured, to avoid a "persistent but meaningless" chip.
    final enabled = ref.watch(settingsProvider.select((p) => p.settings.wifiSyncEnabled));
    if (!enabled) return const SizedBox.shrink();

    final globalStatus = ref.watch(globalSyncStatusProvider);
    final statusColor = _getStatusColor(globalStatus.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.go(AppRoutes.sync),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outline, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                globalStatus.status == GlobalSyncStatus.syncing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      )
                    : Icon(
                        _getStatusIcon(globalStatus.status),
                        size: 16,
                        color: statusColor,
                      ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusLabel(globalStatus.status),
                        style: AppTypography.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (globalStatus.lastError != null &&
                          globalStatus.status == GlobalSyncStatus.error)
                        Text(
                          globalStatus.lastError!,
                          style: AppTypography.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact, icon-only sync pill designed to sit alongside the floating media bar on phones.
/// Keeps the sync signal visible without stealing a whole row above the nav.
class SyncStatusPill extends ConsumerWidget {
  const SyncStatusPill({super.key});

  Color _statusColor(GlobalSyncStatus status) {
    switch (status) {
      case GlobalSyncStatus.idle:
        return AppColors.onSurfaceVariant;
      case GlobalSyncStatus.syncing:
        return _syncingTeal;
      case GlobalSyncStatus.success:
        return AppColors.primary;
      case GlobalSyncStatus.error:
        return AppColors.error;
      case GlobalSyncStatus.noPeers:
        return AppColors.outlineVariant;
    }
  }

  IconData _statusIcon(GlobalSyncStatus status) {
    switch (status) {
      case GlobalSyncStatus.idle:
        return Icons.wifi;
      case GlobalSyncStatus.syncing:
        return Icons.sync;
      case GlobalSyncStatus.success:
        return Icons.check_circle;
      case GlobalSyncStatus.error:
        return Icons.error;
      case GlobalSyncStatus.noPeers:
        return Icons.wifi_off;
    }
  }

  String _statusTooltip(GlobalSyncStatus status) {
    switch (status) {
      case GlobalSyncStatus.idle:
        return 'Synced';
      case GlobalSyncStatus.syncing:
        return 'Syncing…';
      case GlobalSyncStatus.success:
        return 'Just synced';
      case GlobalSyncStatus.error:
        return 'Sync failed';
      case GlobalSyncStatus.noPeers:
        return 'No devices found';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(settingsProvider.select((p) => p.settings.wifiSyncEnabled));
    if (!enabled) return const SizedBox.shrink();

    final status = ref.watch(globalSyncStatusProvider.select((s) => s.status));
    final color = _statusColor(status);

    return Tooltip(
      message: _statusTooltip(status),
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.outline, width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.go(AppRoutes.sync),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: status == GlobalSyncStatus.syncing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  : Icon(_statusIcon(status), size: 16, color: color),
            ),
          ),
        ),
      ),
    );
  }
}