import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/notification_log_repository.dart';
import '../../data/repositories/notification_settings_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/ai_challenge_repository.dart';
import '../../data/repositories/ai_challenge_history_repository.dart';
import '../../data/repositories/ai_feature_settings_repository.dart';
import '../../core/services/ai_challenge_service.dart';
import 'notification_decision_engine.dart';
import 'notification_dispatcher.dart';
import 'notification_scheduler.dart';

/// Single plugin instance; [main] calls [initialize] before [runApp].
final studyTrackerNotificationsPlugin = FlutterLocalNotificationsPlugin();

final flutterLocalNotificationsPluginProvider = Provider<FlutterLocalNotificationsPlugin>(
  (ref) => studyTrackerNotificationsPlugin,
);

String? _quietHourFragment(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

/// Rebuilt when invalidated so [NotificationDecisionEngine] picks up new quiet hours.
final notificationDispatcherProvider = FutureProvider<NotificationDispatcher>((ref) async {
  final plugin = ref.watch(flutterLocalNotificationsPluginProvider);
  final notifRepo = ref.watch(notificationSettingsRepositoryProvider);
  final settingsMap = await notifRepo.getSettings();
  final start = _quietHourFragment(settingsMap?['quiet_hours_start']) ?? '22:00';
  final end = _quietHourFragment(settingsMap?['quiet_hours_end']) ?? '08:00';

  final engine = NotificationDecisionEngine(
    quietHoursStart: start,
    quietHoursEnd: end,
  );
  final scheduler = NotificationScheduler(plugin);

  return NotificationDispatcher(
    plugin: plugin,
    scheduler: scheduler,
    engine: engine,
    logRepo: ref.watch(notificationLogRepositoryProvider),
    sessionRepo: ref.watch(sessionRepositoryProvider),
    settingsRepo: ref.watch(settingsRepositoryProvider),
    notifSettingsRepo: notifRepo,
    goalRepository: ref.watch(goalRepositoryProvider),
    aiChallengeService: ref.watch(aiChallengeServiceProvider),
    aiChallengeRepo: ref.watch(aiChallengeRepositoryProvider),
    aiChallengeHistoryRepo: ref.watch(aiChallengeHistoryRepositoryProvider),
    aiFeatureSettingsRepo: ref.watch(aiFeatureSettingsRepositoryProvider),
  );
});
