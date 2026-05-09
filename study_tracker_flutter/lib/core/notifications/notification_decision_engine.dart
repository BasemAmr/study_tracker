import 'package:timezone/timezone.dart' as tz;

/// Decision result from the notification engine.
typedef NotificationDecision = ({bool fire, String reason, DateTime? rerouteTo});

/// Notification decision engine — Dart twin of the TS engine.
/// Same rule names, same return type.
/// Each rule comments its BEHAVIOR-Nx assertion ID.
class NotificationDecisionEngine {
  final String quietHoursStart;
  final String quietHoursEnd;

  NotificationDecisionEngine({
    required this.quietHoursStart,
    required this.quietHoursEnd,
  });

  /// Evaluate whether to fire a pre-study notification.
  /// BEHAVIOR-N4: Quiet-hours window check.
  NotificationDecision evaluatePreStudy({
    required bool enabled,
    required DateTime now,
  }) {
    if (!enabled) return (fire: false, reason: 'disabled', rerouteTo: null);

    // BEHAVIOR-N4: Quiet-hours window check
    if (_isQuietHour(now)) {
      final nextAvailable = _nextNonQuietTime(now);
      return (fire: false, reason: 'quiet_hours', rerouteTo: nextAvailable);
    }

    // Removed: session_already_today — pre-study is a time-of-day prompt,
    // not gated on whether the user already studied. They may want a second session.
    return (fire: true, reason: 'ok', rerouteTo: null);
  }

  /// BEHAVIOR-N2: pre-study reminder gate, scoped to profile and time.
  NotificationDecision shouldFirePreStudy({
    required int profileId,
    required DateTime now,
    required bool enabled,
  }) {
    // profileId is reserved for future per-profile predicates.
    return evaluatePreStudy(
      enabled: enabled,
      now: now,
    );
  }

  /// Evaluate whether to fire a streak notification.
  NotificationDecision evaluateStreak({
    required bool enabled,
    required int currentStreak,
    required bool hasSessionToday,
  }) {
    if (!enabled) return (fire: false, reason: 'disabled', rerouteTo: null);
    if (currentStreak <= 0) return (fire: false, reason: 'no_streak', rerouteTo: null);
    if (hasSessionToday) return (fire: false, reason: 'session_already_today', rerouteTo: null);
    return (fire: true, reason: 'ok', rerouteTo: null);
  }

  /// Evaluate whether to fire a weekly summary notification.
  NotificationDecision evaluateWeekly({
    required bool enabled,
    required bool alreadyFired,
  }) {
    if (!enabled) return (fire: false, reason: 'disabled', rerouteTo: null);
    if (alreadyFired) return (fire: false, reason: 'dedup', rerouteTo: null);
    return (fire: true, reason: 'ok', rerouteTo: null);
  }

  /// BEHAVIOR-N2: streak protection reminder gate.
  NotificationDecision shouldFireStreak({
    required int profileId,
    required DateTime now,
    required bool enabled,
    required int currentStreak,
    required bool hasSessionToday,
  }) {
    // profileId + now reserved for future per-profile predicates.
    return evaluateStreak(
      enabled: enabled,
      currentStreak: currentStreak,
      hasSessionToday: hasSessionToday,
    );
  }

  /// BEHAVIOR-N2: weekly summary reminder gate.
  NotificationDecision shouldFireWeekly({
    required int profileId,
    required DateTime now,
    required bool enabled,
    required bool alreadyFired,
  }) {
    // profileId + now reserved for future per-profile predicates.
    return evaluateWeekly(
      enabled: enabled,
      alreadyFired: alreadyFired,
    );
  }

  /// Evaluate whether to fire a goal notification (Wednesday evening).
  /// BEHAVIOR-N4: Quiet-hours + pace check.
  /// Inputs:
  ///   - enabled: goal notification setting
  ///   - targetMinutesPerWeek: the goal's weekly target (e.g., 600 min)
  ///   - minutesSoFarThisWeek: sum of session minutes Mon 00:00 → now
  ///   - elapsedDays: number of days elapsed in week including today (Mon=1, Sun=7)
  ///   - alreadyFired: has notification fired once this week already?
  NotificationDecision evaluateGoal({
    required bool enabled,
    required int targetMinutesPerWeek,
    required int minutesSoFarThisWeek,
    required int elapsedDays,
    required bool alreadyFired,
    required DateTime now,
  }) {
    if (!enabled) return (fire: false, reason: 'disabled', rerouteTo: null);
    
    // BEHAVIOR-N4: Quiet-hours window check
    if (_isQuietHour(now)) {
      final nextAvailable = _nextNonQuietTime(now);
      return (fire: false, reason: 'quiet_hours', rerouteTo: nextAvailable);
    }
    
    // Dedup: only fire once per week
    if (alreadyFired) return (fire: false, reason: 'dedup', rerouteTo: null);
    
    // Calculate pace deficit: expected by now vs. actual
    // expectedByNow = targetWeekly * (elapsedDays / 7)
    final expectedByNow = ((targetMinutesPerWeek * elapsedDays) / 7).round();
    final deficitMinutes = (expectedByNow - minutesSoFarThisWeek).clamp(0, double.infinity).toInt();
    
    // Only fire if actually behind (don't celebrate on track)
    if (deficitMinutes <= 0) return (fire: false, reason: 'on_track', rerouteTo: null);
    
    return (fire: true, reason: 'ok', rerouteTo: null);
  }

  /// BEHAVIOR-N2: goal progress reminder gate.
  NotificationDecision shouldFireGoalProgress({
    required int profileId,
    required DateTime now,
    required bool enabled,
    required int targetMinutesPerWeek,
    required int minutesSoFarThisWeek,
    required int elapsedDays,
    required bool alreadyFired,
  }) {
    // profileId reserved for future per-profile predicates.
    return evaluateGoal(
      enabled: enabled,
      targetMinutesPerWeek: targetMinutesPerWeek,
      minutesSoFarThisWeek: minutesSoFarThisWeek,
      elapsedDays: elapsedDays,
      alreadyFired: alreadyFired,
      now: now,
    );
  }

  /// Evaluate whether to fire a re-engagement notification.
  /// BEHAVIOR-N5: Silence-period check + variant-scoped dedup.
  /// Inputs:
  ///   - enabled: re-engagement notification setting
  ///   - variant: 3 or 7 (days)
  ///   - silenceDays: number of full calendar days since last session
  ///   - alreadyFired: has this variant fired since the last session?
  NotificationDecision evaluateReengage({
    required bool enabled,
    required int variant, // 3 or 7
    required int silenceDays,
    required bool alreadyFired,
  }) {
    if (!enabled) return (fire: false, reason: 'disabled', rerouteTo: null);
    
    // Variant routing: 3-day fires in [3..6], 7-day fires in [7+]
    if (variant == 3) {
      if (silenceDays < 3 || silenceDays >= 7) {
        return (fire: false, reason: 'outside_window', rerouteTo: null);
      }
    } else if (variant == 7) {
      if (silenceDays < 7) {
        return (fire: false, reason: 'outside_window', rerouteTo: null);
      }
    }
    
    // Dedup: only fire once per silence period (variant-scoped)
    if (alreadyFired) return (fire: false, reason: 'dedup', rerouteTo: null);
    
    return (fire: true, reason: 'ok', rerouteTo: null);
  }

  /// BEHAVIOR-N2: re-engagement reminder gate.
  NotificationDecision shouldFireReengagement({
    required int profileId,
    required DateTime now,
    required bool enabled,
    required int variant, // 3 or 7
    required int silenceDays,
    required bool alreadyFired,
  }) {
    // profileId + now reserved for future per-profile predicates.
    return evaluateReengage(
      enabled: enabled,
      variant: variant,
      silenceDays: silenceDays,
      alreadyFired: alreadyFired,
    );
  }

  bool _isQuietHour(DateTime now) {
    final localNow = tz.TZDateTime.from(now, tz.local);
    final start = _parseTime(quietHoursStart);
    final end = _parseTime(quietHoursEnd);
    final nowTime = TimeOfDay(hour: localNow.hour, minute: localNow.minute);

    if (start.isBefore(end)) {
      return nowTime.isAfter(start) && nowTime.isBefore(end);
    } else {
      // Overnight quiet hours
      return nowTime.isAfter(start) || nowTime.isBefore(end);
    }
  }

  DateTime _nextNonQuietTime(DateTime now) {
    final localNow = tz.TZDateTime.from(now, tz.local);
    final end = _parseTime(quietHoursEnd);
    final nextEnd = localNow.copyWith(hour: end.hour, minute: end.minute);
    if (nextEnd.isAfter(localNow)) return nextEnd;
    return nextEnd.add(const Duration(days: 1));
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  bool isAfter(TimeOfDay other) {
    return hour > other.hour || (hour == other.hour && minute > other.minute);
  }

  bool isBefore(TimeOfDay other) {
    return hour < other.hour || (hour == other.hour && minute < other.minute);
  }
}