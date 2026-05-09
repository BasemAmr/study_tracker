import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Notification IDs: stable across app restarts.
/// BEHAVIOR-N6: ID allocation for notifications.
enum NotificationId {
  preStudy(1001),
  streak(1002),
  weekly(1003),
  goal(1004),
  reengage3(1005),
  reengage7(1006),
  surpriseMissionCheck(1007),    // Internal: triggers the tick to check/renew surprise mission
  surpriseMissionAvailable(1008); // User-facing: "New surprise mission available"

  const NotificationId(this.value);
  final int value;
}

/// Wrapper API for scheduling notifications.
/// Always uses tz.TZDateTime (NEVER plain DateTime — comment cites why per spec).
/// Always uses AndroidScheduleMode.exactAllowWhileIdle.
class NotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin;

  NotificationScheduler(this._plugin);

  /// Schedule a one-time notification at the given zoned time.
  Future<void> scheduleAt({
    required NotificationId id,
    required tz.TZDateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id.value,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_tracker_notifications',
          'Study Tracker Notifications',
          channelDescription: 'Notifications for study tracking',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Schedule a daily recurring notification.
  Future<void> scheduleDaily({
    required NotificationId id,
    required tz.TZDateTime time,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id.value,
      title,
      body,
      _nextInstance(time),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_tracker_notifications',
          'Study Tracker Notifications',
          channelDescription: 'Notifications for study tracking',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// Schedule the daily pre-study reminder at HH:mm local time.
  Future<void> schedulePreStudyDaily({
    required String hhmm,
    required String title,
    required String body,
    String? payload,
  }) async {
    final time = _nextDailyTime(hhmm);
    await scheduleDaily(
      id: NotificationId.preStudy,
      time: time,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Schedule a weekly recurring notification.
  Future<void> scheduleWeekly({
    required NotificationId id,
    required tz.TZDateTime time,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id.value,
      title,
      body,
      _nextInstance(time),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_tracker_notifications',
          'Study Tracker Notifications',
          channelDescription: 'Notifications for study tracking',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  /// Schedule the daily streak reminder at 22:00 local time.
  Future<void> scheduleStreakDaily({
    required String title,
    required String body,
    String? payload,
  }) async {
    final time = _nextDailyTime('22:00');
    await scheduleDaily(
      id: NotificationId.streak,
      time: time,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Schedule the weekly summary reminder at HH:mm local time on a specific weekday.
  Future<void> scheduleWeeklySummary({
    required String hhmm,
    required int weekday,
    required String title,
    required String body,
    String? payload,
  }) async {
    final time = _nextWeeklyTime(hhmm, weekday);
    await scheduleWeekly(
      id: NotificationId.weekly,
      time: time,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Schedule the weekly goal progress reminder at HH:mm local time on a specific weekday.
  Future<void> scheduleGoalProgressWeekly({
    required String hhmm,
    required int weekday,
    required String title,
    required String body,
    String? payload,
  }) async {
    final time = _nextWeeklyTime(hhmm, weekday);
    await scheduleWeekly(
      id: NotificationId.goal,
      time: time,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Schedule daily re-engagement reminders at HH:mm local time (both variants share schedule).
  /// Dispatcher decision engine will determine which variant fires (3-day vs 7-day).
  Future<void> scheduleReengagementDaily({
    required String hhmm,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Schedule both 3-day and 7-day variants at the same daily time.
    // The decision engine will route based on silence period.
    final time = _nextDailyTime(hhmm);
    
    // Schedule 3-day variant (ID 1005)
    await _plugin.zonedSchedule(
      NotificationId.reengage3.value,
      title,
      body,
      time,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_tracker_notifications',
          'Study Tracker Notifications',
          channelDescription: 'Notifications for study tracking',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
    
    // Schedule 7-day variant (ID 1006)
    await _plugin.zonedSchedule(
      NotificationId.reengage7.value,
      title,
      body,
      time,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_tracker_notifications',
          'Study Tracker Notifications',
          channelDescription: 'Notifications for study tracking',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// Schedule a recurring notification at a fixed interval (e.g., every 3 hours).
  /// T6 requirement: Used for surprise mission check recurring at intervalHours.
  /// Dispatcher will reschedule the next occurrence when this fires.
  /// intervalHours: must be > 0 (e.g., 3, 6, 12, 24).
  /// Payload should include 'intervalHours' so dispatcher knows to reschedule.
  Future<void> scheduleRecurringInterval({
    required NotificationId id,
    required int intervalHours,
    required String title,
    required String body,
    String? payload,
  }) async {
    assert(intervalHours > 0, 'intervalHours must be positive');
    
    final now = tz.TZDateTime.now(tz.local);
    final nextFire = now.add(Duration(hours: intervalHours));
    
    // Store intervalHours in payload so dispatcher knows to reschedule after fire
    final fullPayload = {...?_payloadToMap(payload), 'intervalHours': intervalHours.toString()};
    
    await _plugin.zonedSchedule(
      id.value,
      title,
      body,
      nextFire,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_tracker_notifications',
          'Study Tracker Notifications',
          channelDescription: 'Notifications for study tracking',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: _mapToPayloadString(fullPayload),
    );
  }

  /// Helper: parse payload string (or null) into a map.
  static Map<String, dynamic> _payloadToMap(String? payload) {
    if (payload == null || payload.isEmpty) return {};
    try {
      return (jsonDecode(payload) as Map<String, dynamic>?) ?? {};
    } catch (e) {
      return {};
    }
  }

  /// Helper: serialize map back to payload string.
  static String _mapToPayloadString(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  /// Cancel a specific notification.
  Future<void> cancel(NotificationId id) async {
    await _plugin.cancel(id.value);
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Set the action callback for when a notification is tapped.
  void onAction(Function(String? payload) callback) {
    // This will be wired in the dispatcher
  }

  /// Reschedule all enabled notifications (BEHAVIOR-N7).
  /// Placeholder — will be implemented on NotificationDispatcher.
  Future<void> rescheduleAll() async {
    // This is implemented on NotificationDispatcher, not here.
    // Scheduler stays dumb (no DB reads).
  }

  /// Get the next instance of a time, ensuring it's in the future.
  tz.TZDateTime _nextInstance(tz.TZDateTime time) {
    final now = tz.TZDateTime.now(tz.local);
    if (time.isAfter(now)) return time;
    return time.add(const Duration(days: 1));
  }

  tz.TZDateTime _nextDailyTime(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    return _nextInstance(scheduled);
  }

  tz.TZDateTime _nextWeeklyTime(String hhmm, int weekday) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return _nextInstance(scheduled);
  }
}