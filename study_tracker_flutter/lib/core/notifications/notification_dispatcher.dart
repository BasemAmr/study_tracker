import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../l10n/app_localizations.dart';
import 'notification_scheduler.dart';
import 'notification_decision_engine.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/notification_log_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/notification_settings_repository.dart';
import '../../core/services/ai_challenge_service.dart';
import '../../data/repositories/ai_challenge_repository.dart';
import '../../data/repositories/ai_challenge_history_repository.dart';
import '../../data/repositories/ai_feature_settings_repository.dart';
import '../../domain/domain.dart';

bool _notifMapBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return fallback;
}

String? _notifMapString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

/// Notification dispatcher — invoked from notification callback and on app resume.
/// Same flow as Tauri side: engine → fire/suppress/reroute → log → display.
class NotificationDispatcher {
  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationScheduler _scheduler;
  final NotificationDecisionEngine _engine;
  final NotificationLogRepository _logRepo;
  final SessionRepository _sessionRepo;
  final SettingsRepository _settingsRepo;
  final NotificationSettingsRepository _notifSettingsRepo;
  final GoalRepository _goalRepository;
  final AiChallengeService _aiChallengeService;
  final AiChallengeRepository _aiChallengeRepo;
  final AiChallengeHistoryRepository _aiChallengeHistoryRepo;
  final AiFeatureSettingsRepository _aiFeatureSettingsRepo;

  NotificationDispatcher({
    required FlutterLocalNotificationsPlugin plugin,
    required NotificationScheduler scheduler,
    required NotificationDecisionEngine engine,
    required NotificationLogRepository logRepo,
    required SessionRepository sessionRepo,
    required SettingsRepository settingsRepo,
    required NotificationSettingsRepository notifSettingsRepo,
    required GoalRepository goalRepository,
    required AiChallengeService aiChallengeService,
    required AiChallengeRepository aiChallengeRepo,
    required AiChallengeHistoryRepository aiChallengeHistoryRepo,
    required AiFeatureSettingsRepository aiFeatureSettingsRepo,
  })  : _plugin = plugin,
        _scheduler = scheduler,
        _engine = engine,
        _logRepo = logRepo,
        _sessionRepo = sessionRepo,
        _settingsRepo = settingsRepo,
        _notifSettingsRepo = notifSettingsRepo,
        _goalRepository = goalRepository,
        _aiChallengeService = aiChallengeService,
        _aiChallengeRepo = aiChallengeRepo,
        _aiChallengeHistoryRepo = aiChallengeHistoryRepo,
        _aiFeatureSettingsRepo = aiFeatureSettingsRepo;

  /// Dispatch a notification based on type and current state.
  Future<void> dispatch({
    required NotificationId id,
    required String title,
    required String body,
    String? payload,
    bool enabled = true,
  }) async {
    NotificationDecision decision;
    final now = DateTime.now();
    String resolvedTitle = title;
    String resolvedBody = body;

    switch (id) {
      case NotificationId.preStudy:
        final l10n = await _loadLocalization();
        final subject = await _sessionRepo.getMostStudiedSubjectLast7Days();
        resolvedTitle = l10n.appTitle;
        resolvedBody = _preStudyBody(
          l10n,
          subject ?? l10n.studySubject,
          now,
        );
        decision = _engine.shouldFirePreStudy(
          profileId: await _settingsRepo.getCurrentProfileId(),
          now: now,
          enabled: enabled,
        );
        break;
      case NotificationId.streak:
        final l10n = await _loadLocalization();
        final streak = await _sessionRepo.getCurrentStreak(now: now);
        final hasSessionToday = await _hasSessionToday(now);
        resolvedTitle = l10n.appTitle;
        resolvedBody = l10n.notifStreakBody(streak);
        decision = _engine.shouldFireStreak(
          profileId: await _settingsRepo.getCurrentProfileId(),
          now: now,
          enabled: enabled,
          currentStreak: streak,
          hasSessionToday: hasSessionToday,
        );
        break;
      case NotificationId.weekly:
        final l10n = await _loadLocalization();
        final summary = await _sessionRepo.getSummaryLast7Days();
        final subject = await _sessionRepo.getMostStudiedSubjectLast7Days();
        final since = now.subtract(const Duration(days: 7));
        final alreadyFired = await _logRepo.wasFiredSince(id.value, since);
        resolvedTitle = l10n.appTitle;
        resolvedBody = _weeklyBody(
          l10n,
          summary.totalSessions,
          summary.totalMinutes,
          subject ?? l10n.studySubject,
        );
        decision = _engine.shouldFireWeekly(
          profileId: await _settingsRepo.getCurrentProfileId(),
          now: now,
          enabled: enabled,
          alreadyFired: alreadyFired,
        );
        break;
      case NotificationId.goal:
        final l10n = await _loadLocalization();
        final goal = await _getActiveGoal();
        final minutesThisWeek = await _sessionRepo.getTotalMinutesThisWeek();
        final elapsedDays = _sessionRepo.getElapsedDaysThisWeek();
        final since = now.subtract(const Duration(days: 7));
        final alreadyFired = await _logRepo.wasFiredSince(id.value, since);
        
        resolvedTitle = l10n.appTitle;
        if (goal != null) {
          final targetWeekly = goal['targetMinutes'] as int? ?? 0;
          final deficitMinutes = ((targetWeekly * elapsedDays / 7).round() - minutesThisWeek).clamp(0, double.infinity).toInt();
          final hoursBehind = (deficitMinutes / 60).ceil();
          final daysLeft = 7 - elapsedDays;
          resolvedBody = l10n.notifGoalBehind(hoursBehind, daysLeft, goal['name'] as String? ?? '');
        } else {
          resolvedBody = l10n.notifGoalBehind(0, 0, '');
        }
        
        decision = _engine.shouldFireGoalProgress(
          profileId: await _settingsRepo.getCurrentProfileId(),
          now: now,
          enabled: enabled,
          targetMinutesPerWeek: goal?['targetMinutes'] as int? ?? 0,
          minutesSoFarThisWeek: minutesThisWeek,
          elapsedDays: elapsedDays,
          alreadyFired: alreadyFired,
        );
        break;
      case NotificationId.reengage3:
      case NotificationId.reengage7:
        final l10n = await _loadLocalization();
        final lastSessionDate = await _sessionRepo.getLastSessionDate();
        final variant = id == NotificationId.reengage3 ? 3 : 7;
        final silenceDays = lastSessionDate != null 
          ? _calculateSilenceDays(lastSessionDate, now)
          : 999; // No session ever → treat as very old
        final alreadyFired = await _logRepo.wasFiredSince(id.value, lastSessionDate ?? DateTime(2000));
        
        resolvedTitle = l10n.appTitle;
        if (silenceDays >= 7) {
          resolvedBody = l10n.notifReengageLong;
        } else {
          resolvedBody = l10n.notifReengageShort(silenceDays);
        }
        
        decision = _engine.shouldFireReengagement(
          profileId: await _settingsRepo.getCurrentProfileId(),
          now: now,
          enabled: enabled,
          variant: variant,
          silenceDays: silenceDays,
          alreadyFired: alreadyFired,
        );
        break;
      
      // T6: Surprise mission check — internal tick that fires every N hours
      // Gating: only if AI enabled + API key present. Silently skip otherwise.
      case NotificationId.surpriseMissionCheck:
        // Gating logic: if AI disabled or no API key, skip silently (no toast, no notification).
        final aiSettings = await _aiFeatureSettingsRepo.getSettings();
        final aiEnabled = aiSettings?['smart_challenges_enabled'] as bool? ?? false;
        final settingsAll = await _settingsRepo.getAll();
        final hasApiKey = (settingsAll['groqApiKey']?.trim().isNotEmpty) ?? false;
        
        if (!aiEnabled || !hasApiKey) {
          // Gating: AI off or no API key → no-op. Don't fire a notification, just log as suppressed.
          await _logRepo.log(id.value, 'suppressed', 'AI disabled or no API key');
          
          // Reschedule the next interval check since this one didn't fire
          final intervalHours = _parsePayloadInt(payload, 'intervalHours', 3);
          await _scheduler.scheduleRecurringInterval(
            id: id,
            intervalHours: intervalHours,
            title: 'Surprise Mission Check',
            body: 'Check for new surprise mission',
            payload: payload,
          );
          return;
        }
        
        // Core T6 logic: check surprise mission, refresh if needed, fire user notification if successful
        await _handleSurpriseCheckTick(id, payload);
        return;
      
      case NotificationId.surpriseMissionAvailable:
        // User-facing notification fired internally by tick handler; no external scheduling needed
        return;
    }

    await _logRepo.log(id.value, decision.fire ? 'fired' : 'suppressed', decision.reason);

    if (decision.fire) {
      await _showNotification(id, resolvedTitle, resolvedBody, payload);
    } else if (decision.rerouteTo != null) {
      // Reschedule for reroute time
      await _scheduler.scheduleAt(
        id: id,
        when: tz.TZDateTime.from(decision.rerouteTo!, tz.local),
        title: resolvedTitle,
        body: resolvedBody,
        payload: payload,
      );
    }
  }

  /// BEHAVIOR-N6/N7: Reschedule all enabled notifications based on current settings.
  /// Called after any setting change (toggle, time picker, quiet hours change).
  /// Flow: cancel all → read settings → query live data → schedule with real body.
  ///
  /// IMPORTANT: flutter_local_notifications bakes the body string into the OS alarm at schedule
  /// time. There is no runtime callback that re-evaluates the body before the notification fires.
  /// Therefore, all data-driven bodies must be computed HERE, before scheduleXxx() is called.
  Future<void> rescheduleAll(int profileId) async {
    // Step 1: Cancel all existing schedules to avoid duplicates
    await _scheduler.cancelAll();

    // Step 2: Read notification settings from the repository
    final settingsMap = await _notifSettingsRepo.getSettings();
    if (settingsMap == null) {
      // No settings yet, nothing to schedule
      return;
    }

    final settings = settingsMap;
    final l10n = await _loadLocalization();
    final now = DateTime.now();

    String? getStringSetting(String key) => _notifMapString(settings[key]);
    bool getBoolSetting(String key) => _notifMapBool(settings[key]);
    int getIntSetting(String key, int fallback) {
      final v = settings[key];
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    // Step 3: Schedule each notification type if enabled

    // Pre-Study (1001) - daily at preStudyTime
    if (getBoolSetting('pre_study_enabled')) {
      final time = getStringSetting('pre_study_time') ?? '14:00';
      // Body rotates by day-of-year; use a neutral subject since it varies daily
      final subject = await _sessionRepo.getMostStudiedSubjectLast7Days() ?? l10n.studySubject;
      await _scheduler.schedulePreStudyDaily(
        hhmm: time,
        title: l10n.appTitle,
        body: _preStudyBody(l10n, subject, now),
      );
    }

    // Streak (1002) - daily at 22:00
    // Query actual streak so the body is meaningful, not a hardcoded "1".
    if (getBoolSetting('streak_enabled')) {
      final currentStreak = await _sessionRepo.getCurrentStreak(now: now);
      final streakBody = currentStreak > 0
          ? l10n.notifStreakBody(currentStreak)
          : l10n.notifStreakBody(1); // fallback if no streak yet
      await _scheduler.scheduleStreakDaily(
        title: l10n.appTitle,
        body: streakBody,
      );
    }

    // Weekly Summary (1003) - configurable day/time (default Sunday 19:00)
    // Query real session data from the past 7 days so the body is not zeros.
    if (getBoolSetting('weekly_enabled')) {
      final time = getStringSetting('weekly_summary_time') ?? '19:00';
      final dow = getIntSetting('weekly_summary_dow', 7);
      final summary = await _sessionRepo.getSummaryLast7Days();
      final subject = await _sessionRepo.getMostStudiedSubjectLast7Days() ?? l10n.studySubject;
      final weeklyBody = _weeklyBody(
        l10n,
        summary.totalSessions,
        summary.totalMinutes,
        subject,
      );
      await _scheduler.scheduleWeeklySummary(
        hhmm: time,
        weekday: dow,
        title: l10n.appTitle,
        body: weeklyBody,
      );
    }

    // Goal Progress (1004) - configurable day/time (default Wednesday 19:00)
    if (getBoolSetting('goal_enabled')) {
      final time = getStringSetting('goal_time') ?? '19:00';
      final dow = getIntSetting('goal_dow', 3);
      final goal = await _getActiveGoal();
      final minutesThisWeek = await _sessionRepo.getTotalMinutesThisWeek();
      final elapsedDays = _sessionRepo.getElapsedDaysThisWeek();
      String goalBody;
      if (goal != null) {
        final targetWeekly = goal['targetMinutes'] as int? ?? 0;
        final deficitMinutes = ((targetWeekly * elapsedDays / 7).round() - minutesThisWeek)
            .clamp(0, double.infinity)
            .toInt();
        final hoursBehind = (deficitMinutes / 60).ceil();
        final daysLeft = 7 - elapsedDays;
        goalBody = l10n.notifGoalBehind(hoursBehind, daysLeft, goal['name'] as String? ?? '');
      } else {
        goalBody = l10n.notifGoalBehind(0, 0, '');
      }
      await _scheduler.scheduleGoalProgressWeekly(
        hhmm: time,
        weekday: dow,
        title: l10n.appTitle,
        body: goalBody,
      );
    }

    // Re-engagement (1005, 1006) - daily at reengageTime (default 14:00)
    final reengage3Enabled = getBoolSetting('reengage_3_enabled');
    final reengage7Enabled = getBoolSetting('reengage_7_enabled');
    if (reengage3Enabled || reengage7Enabled) {
      final time = getStringSetting('reengage_time') ?? '14:00';
      final lastSessionDate = await _sessionRepo.getLastSessionDate();
      final silenceDays = lastSessionDate != null
          ? _calculateSilenceDays(lastSessionDate, now)
          : 999;
      final reengageBody = silenceDays >= 7 ? l10n.notifReengageLong : l10n.notifReengageShort(silenceDays);
      await _scheduler.scheduleReengagementDaily(
        hhmm: time,
        title: l10n.appTitle,
        body: reengageBody,
      );
    }

    // T6: Surprise mission check (1007) - interval-based recurring schedule
    final aiSettings = await _aiFeatureSettingsRepo.getSettings();
    final surpriseEnabled = _notifMapBool(aiSettings?['surprise_notifications_enabled']);
    final intervalHours = getIntSetting('surprise_check_interval_hours', 3);
    if (surpriseEnabled && intervalHours > 0) {
      await _scheduler.scheduleRecurringInterval(
        id: NotificationId.surpriseMissionCheck,
        intervalHours: intervalHours,
        title: l10n.appTitle,
        body: 'Checking for new surprise mission...',
        payload: jsonEncode({'intervalHours': intervalHours}),
      );
    }
  }

  Future<AppLocalizations> _loadLocalization() async {
    final code = await _settingsRepo.get('languageCode') ?? 'en';
    final locale = AppLocalizations.supportedLocales.firstWhere(
      (supported) => supported.languageCode == code,
      orElse: () => const Locale('en'),
    );
    return AppLocalizations.delegate.load(locale);
  }

  String _preStudyBody(AppLocalizations l10n, String subject, DateTime now) {
    final variant = now.day % 3;
    switch (variant) {
      case 0:
        return l10n.notifPrestudyV1(subject);
      case 1:
        return l10n.notifPrestudyV2(subject);
      default:
        return l10n.notifPrestudyV3(subject);
    }
  }

  String _weeklyBody(
    AppLocalizations l10n,
    int sessionCount,
    int totalMinutes,
    String subject,
  ) {
    if (sessionCount == 0) return l10n.notifWeeklyEmpty;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return l10n.notifWeeklyFull(hours, minutes, sessionCount, subject);
  }

  Future<DateTime> _resolveLastSessionToday(DateTime now) async {
    final recent = await _sessionRepo.getRecent(1);
    if (recent.isEmpty) return DateTime(2000);
    final last = recent.first.startAt;
    final isToday = last.year == now.year && last.month == now.month && last.day == now.day;
    return isToday ? last : DateTime(2000);
  }

  Future<bool> _hasSessionToday(DateTime now) async {
    final last = await _resolveLastSessionToday(now);
    return last.year == now.year && last.month == now.month && last.day == now.day;
  }

  /// Fetch the active goal for the current profile.
  /// Returns a Map with 'id', 'name', 'targetMinutes', or null if none active.
  Future<Map<String, dynamic>?> _getActiveGoal() async {
    final profileId = await _settingsRepo.getCurrentProfileId();
    return _goalRepository.getActiveGoal(profileId);
  }

  /// Calculate full calendar days of silence since last session.
  /// silenceDays = 0 if last session was today
  /// silenceDays = 1 if last session was yesterday
  /// silenceDays = N if last session was N days ago
  int _calculateSilenceDays(DateTime lastSessionDate, DateTime now) {
    final lastDay = DateTime(lastSessionDate.year, lastSessionDate.month, lastSessionDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(lastDay).inDays;
  }

  Future<void> _showNotification(
    NotificationId id,
    String title,
    String body,
    String? payload,
  ) async {
    await _plugin.show(
      id.value,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_tracker_notifications',
          'Study Tracker Notifications',
          channelDescription: 'Notifications for study tracking',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  /// T6: Parse interval hours from payload (defaults to 3).
  int _parsePayloadInt(String? payload, String key, int fallback) {
    if (payload == null || payload.isEmpty) return fallback;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>?;
      if (map == null) return fallback;
      final v = map[key];
      if (v is int) return v > 0 ? v : fallback;
      if (v is String) {
        final n = int.tryParse(v);
        return (n != null && n > 0) ? n : fallback;
      }
    } catch (e) {
      // Ignore parse errors, return fallback
    }
    return fallback;
  }

  /// T6: Handle the surprise mission check tick.
  /// Flow: check current surprise → if expired, snapshot to history → call API to refresh
  ///       → fire user notification "New surprise mission available" on success
  ///       → silent on failure (error visible inside app on tab open).
  /// Then reschedule the next interval check.
  Future<void> _handleSurpriseCheckTick(NotificationId id, String? payload) async {
    final profileId = await _settingsRepo.getCurrentProfileId();
    final l10n = await _loadLocalization();
    final intervalHours = _parsePayloadInt(payload, 'intervalHours', 3);

    try {
      // 1. Get current active surprise mission (if any)
      final currentSurprise = await _aiChallengeRepo.getActiveByTier(AiChallengeTier.surprise);
      
      // 2. If no mission or expired: snapshot to history (if expired) and refresh
      if (currentSurprise == null) {
        // No active mission: just call API to create one
        final result = await _aiChallengeService.refreshTierNow(AiChallengeTier.surprise);
        if (result is AiChallengeSuccess) {
          // Success: fire user-visible notification "New surprise mission available"
          await _showNotification(
            NotificationId.surpriseMissionAvailable,
            l10n.appTitle,
            'New surprise mission available! Check it out now.',
            null,
          );
        }
        // Failure: silent (error will be visible in app on next tab open)
      } else if (currentSurprise.expiresAt.isBefore(DateTime.now())) {
        // Surprise mission is expired: snapshot it to history, then refresh
        final progress = await _aiChallengeService.calculateProgress(currentSurprise);
        await _aiChallengeHistoryRepo.create(
          NewAiChallengeHistoryEntry(
            profileId: profileId,
            tier: AiChallengeTier.surprise,
            title: currentSurprise.title,
            description: currentSurprise.description,
            metric: currentSurprise.metric,
            target: currentSurprise.target,
            progressAtClose: progress.current,
            closeReason: AiChallengeCloseReason.expired,
            closedAt: DateTime.now().toIso8601String(),
            originalCreatedAt: (currentSurprise.createdAt ?? DateTime.now()).toIso8601String(),
            originalExpiresAt: currentSurprise.expiresAt.toIso8601String(),
            subTargets: currentSurprise.subTargets,
            unitMinMinutes: currentSurprise.unitMinMinutes,
          ),
        );
        
        // Try to refresh with API
        final result = await _aiChallengeService.refreshTierNow(AiChallengeTier.surprise);
        if (result is AiChallengeSuccess) {
          // Success: fire user notification
          await _showNotification(
            NotificationId.surpriseMissionAvailable,
            l10n.appTitle,
            'New surprise mission available! Check it out now.',
            null,
          );
        }
        // Failure: silent (error visible in app)
      }
      // If mission exists and not expired: do nothing, just reschedule next check

      await _logRepo.log(id.value, 'fired', 'surprise check completed');
    } catch (e) {
      // Unexpected error: log as suppressed and silently reschedule
      await _logRepo.log(id.value, 'suppressed', 'surprise check error: $e');
    }

    // Always reschedule the next interval check (even if this one had an error)
    await _scheduler.scheduleRecurringInterval(
      id: id,
      intervalHours: intervalHours,
      title: 'Surprise Mission Check',
      body: 'Check for new surprise mission',
      payload: payload,
    );
  }
}