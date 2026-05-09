import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'shell/app_shell.dart';
import '../domain/domain.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/sessions/sessions_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/media_player/media_player_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/sync/sync_screen.dart';

/// Named route constants.
abstract class AppRoutes {
  static const dashboard = '/';
  static const sessions = '/sessions';
  static const analytics = '/analytics';
  static const achievements = '/achievements';
  static const focusAudio = '/focus-audio';
  static const focusSound = '/focus-sound';
  static const focusSoundSpaced = '/focus sound';
  static const settings = '/settings';
  static const sync = '/sync';
}

StudySessionMode? _parseLaunchMode(String? mode) {
  if (mode == null || mode.isEmpty) return null;
  if (mode == StudySessionMode.pomodoro.dbValue) return StudySessionMode.pomodoro;
  if (mode == StudySessionMode.longSession.dbValue) return StudySessionMode.longSession;
  return null;
}

SessionTab? _parseTabMode(String? tab) {
  if (tab == 'history') return SessionTab.history;
  if (tab == 'timer') return SessionTab.timer;
  if (tab == 'stopwatch') return SessionTab.stopwatch;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.sessions,
            pageBuilder: (context, state) => NoTransitionPage(
              child: SessionsScreen(
                launchMode: _parseLaunchMode(state.uri.queryParameters['mode']),
                autoStart: state.uri.queryParameters['autostart'] == '1',
                initialTab: _parseTabMode(state.uri.queryParameters['tab']),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.achievements,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AchievementsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.focusAudio,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MediaPlayerScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.focusSound,
            redirect: (context, state) => AppRoutes.focusAudio,
          ),
          GoRoute(
            path: AppRoutes.focusSoundSpaced,
            redirect: (context, state) => AppRoutes.focusAudio,
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.sync,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SyncScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
