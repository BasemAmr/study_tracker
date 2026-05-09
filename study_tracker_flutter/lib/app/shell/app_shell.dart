import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/media_player_provider.dart';
import '../../core/providers/timer_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/sync_status_indicator.dart';
import '../router.dart';
import '../../features/sessions/widgets/session_debrief_card.dart';
import '../../l10n/app_localizations.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(timerProvider).syncFromService();
    }
  }

  List<_NavItem> _destinations(AppLocalizations l10n) => [
        _NavItem(
          icon: Icons.grid_view,
          label: l10n.navDashboard,
          path: AppRoutes.dashboard,
        ),
        _NavItem(
          icon: Icons.menu_book,
          label: l10n.navSessions,
          path: AppRoutes.sessions,
        ),
        _NavItem(
          icon: Icons.bar_chart,
          label: l10n.navAnalytics,
          path: AppRoutes.analytics,
        ),
        _NavItem(
          icon: Icons.workspace_premium,
          label: l10n.navAchievements,
          path: AppRoutes.achievements,
        ),
        _NavItem(
          icon: Icons.settings,
          label: l10n.navSettings,
          path: AppRoutes.settings,
        ),
        const _NavItem(
          icon: Icons.sync,
          label: 'Sync',
          path: AppRoutes.sync,
        ),
      ];

  int _currentIndex(BuildContext context, List<_NavItem> destinations) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < destinations.length; i++) {
      if (location == destinations[i].path) return i;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index, List<_NavItem> destinations) {
    context.go(destinations[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final destinations = _destinations(l10n);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = R.isPhone(context);
    final isLandscape = R.isLandscape(context);
    final index = _currentIndex(context, destinations);
    final barState = ref.watch(mediaPlayerProvider.select((p) => p.floatingBarState));
    final sidebarWidth = screenWidth >= 1300
        ? 240.0
        : (screenWidth >= 1000 ? 208.0 : 184.0);
    final compactSidebar = screenWidth < 1100;

    final content = isPhone
        ? widget.child
        : Row(
            children: [
              _buildSidebar(
                context,
                index,
                destinations,
                width: sidebarWidth,
                compact: compactSidebar,
              ),
              const VerticalDivider(width: 2, thickness: 2, color: AppColors.outline),
              Expanded(child: widget.child),
            ],
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null,
      body: Stack(
        children: [
          content,
          Positioned(
            left: (isPhone && barState == FloatingMediaBarState.minimized) ? null : (isPhone ? 10 : 24),
            right: isPhone ? 10 : 24,
            bottom: isPhone ? (isLandscape ? 62 : 82) : 18,
            child: const _FloatingMediaBar(),
          ),
          // Small sync pill, tucked near the floating media bar. Hidden entirely when
          // sync is disabled so inactive users see no extra chrome.
          if (isPhone)
            Positioned(
              right: isPhone ? 10 : 24,
              bottom: (isLandscape ? 62 : 82) + 52,
              child: const SyncStatusPill(),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: const SessionDebriefCard(),
          ),
        ],
      ),
      bottomNavigationBar: isPhone
          ? _buildBottomNavBar(index, context, destinations, isLandscape: isLandscape)
          : null,
    );
  }

  Widget _buildBottomNavBar(
    int currentIndex,
    BuildContext context,
    List<_NavItem> destinations, {
    required bool isLandscape,
  }) {
    return Container(
      height: isLandscape ? 58 : 76,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.outline, width: 2)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(destinations.length, (index) {
            final dest = destinations[index];
            final isSelected = currentIndex == index;

            return Expanded(
              child: InkWell(
                onTap: () => _onTap(context, index, destinations),
                child: Container(
                  decoration: isSelected
                      ? const BoxDecoration(
                          border: Border(top: BorderSide(color: AppColors.primary, width: 4)),
                        )
                      : null,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tiny = constraints.maxHeight < 34;
                      return Center(
                        child: tiny
                            ? Icon(
                                dest.icon,
                                size: 18,
                                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      dest.icon,
                                      size: 24,
                                      color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    int currentIndex,
    List<_NavItem> destinations, {
    required double width,
    required bool compact,
  }) {
    return Container(
      width: width,
      color: AppColors.surface,
      child: Column(
        children: [
          const SizedBox(height: 32),
          ...List.generate(destinations.length, (index) {
            final dest = destinations[index];
            final isSelected = currentIndex == index;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: 4),
              child: InkWell(
                onTap: () => _onTap(context, index, destinations),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 16,
                    vertical: compact ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.outline : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        dest.icon,
                        color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                        size: compact ? 22 : 24,
                      ),
                      SizedBox(width: compact ? 10 : 16),
                      Expanded(
                        child: Text(
                          dest.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: compact ? 11 : null,
                            color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FloatingMediaBar extends ConsumerWidget {
  const _FloatingMediaBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final media = ref.watch(mediaPlayerProvider);
    final barState = media.floatingBarState;

    if (barState == FloatingMediaBarState.hidden && !media.isPlaying) {
      return const SizedBox.shrink();
    }

    final isExpanded = barState == FloatingMediaBarState.expanded;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: AppColors.outline,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: isExpanded
            ? LayoutBuilder(
                key: const ValueKey('expanded'),
                builder: (context, constraints) {
                  final viewportWidth = MediaQuery.of(context).size.width;
                  final resolvedWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : viewportWidth;
                  final compact = resolvedWidth < 360;
                  final veryCompact = resolvedWidth < 330;
                  final controlsWidth = veryCompact ? 168.0 : (compact ? 206.0 : 250.0);
                  final titleWidth = (resolvedWidth - controlsWidth).clamp(72.0, 220.0);

                  return SizedBox(
                    width: resolvedWidth,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: media.togglePlayPause,
                            icon: Icon(media.isPlaying ? Icons.pause : Icons.play_arrow),
                            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                            padding: EdgeInsets.zero,
                          ),
                          if (!compact)
                            IconButton(
                              onPressed: media.rewind10s,
                              icon: const Icon(Icons.replay_10),
                              constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                              padding: EdgeInsets.zero,
                            ),
                          IconButton(
                            onPressed: media.nextTrack,
                            icon: const Icon(Icons.skip_next),
                            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: titleWidth,
                            child: Text(
                              media.currentTrack?.title ?? l10n.noMediaPlaying,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.textTheme.bodyMedium?.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: media.toggleFloatingBarExpanded,
                            icon: const Icon(Icons.unfold_less),
                            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                            padding: EdgeInsets.zero,
                            tooltip: l10n.tooltipMinimizePlayer,
                          ),
                          IconButton(
                            onPressed: () => media.setFloatingBarState(FloatingMediaBarState.hidden),
                            icon: const Icon(Icons.close),
                            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                            padding: EdgeInsets.zero,
                            tooltip: l10n.tooltipHidePlayer,
                          ),
                          if (veryCompact)
                            IconButton(
                              onPressed: () => context.go(AppRoutes.focusAudio),
                              icon: const Icon(Icons.library_music),
                              constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                              padding: EdgeInsets.zero,
                              tooltip: l10n.tooltipFocusAudio,
                            )
                          else
                            TextButton(
                              onPressed: () => context.go(AppRoutes.focusAudio),
                              child: Text(
                                l10n.tooltipFocusAudio,
                                style: AppTypography.textTheme.labelMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : Row(
                key: const ValueKey('minimized'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: media.togglePlayPause,
                        onLongPress: media.toggleFloatingBarExpanded,
                        child: Icon(
                          media.isPlaying ? Icons.pause_circle : Icons.play_circle,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
  });
}
