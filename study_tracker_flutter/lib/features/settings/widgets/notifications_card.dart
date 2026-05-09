import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/notification_settings_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/settings_widgets.dart';
import '../../../l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationsSection extends ConsumerStatefulWidget {
  const NotificationsSection({super.key});

  @override
  ConsumerState<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<NotificationsSection> {
  Map<String, dynamic>? _prefs;
  bool _loading = true;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadPrefs();
  }

  Future<void> _checkPermission() async {
    try {
      final status = await Permission.notification.status;
      if (mounted) {
        setState(() => _permissionGranted = status.isGranted);
      }
    } catch (_) {
      // Plugin not available on this platform/build; treat as granted
      // so the settings UI is still shown.
      if (mounted) {
        setState(() => _permissionGranted = true);
      }
    }
  }

  Future<void> _requestPermission() async {
    try {
      final status = await Permission.notification.request();
      if (mounted) {
        setState(() => _permissionGranted = status.isGranted);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _permissionGranted = true);
      }
    }
  }

  Future<void> _loadPrefs() async {
    final data = await ref.read(notificationSettingsRepositoryProvider).getSettings();
    if (mounted) {
      setState(() {
        _prefs = data;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(String key, bool val) async {
    final updated = Map<String, dynamic>.from(_prefs ?? {});
    updated[key] = val;
    if (mounted) setState(() => _prefs = updated);
    await ref.read(notificationSettingsRepositoryProvider).upsertSettings({key: val});
  }

  Future<void> _setTime(String key, String time) async {
    final updated = Map<String, dynamic>.from(_prefs ?? {});
    updated[key] = time;
    if (mounted) setState(() => _prefs = updated);
    await ref.read(notificationSettingsRepositoryProvider).upsertSettings({key: time});
  }

  Future<void> _pickTime(BuildContext context, String key, String initialTime) async {
    final parts = initialTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null && mounted) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await _setTime(key, formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));

    if (!_permissionGranted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsHeader(title: l10n.notif_settings_title),
          SettingsGroup(
            children: [
              SettingsRow(
                label: l10n.notif_permission_enable,
                description: l10n.notif_denied_hint,
                onTap: _requestPermission,
                control: const Icon(Icons.notifications_off_outlined, color: AppColors.error),
              ),
            ],
          ),
        ],
      );
    }

    final p = _prefs ?? {};
    final preStudy = _notifMapBool(p, 'pre_study_enabled');
    final preStudyTime = p['pre_study_time']?.toString() ?? '14:00';
    
    final quietStart = p['quiet_hours_start']?.toString() ?? '22:00';
    final quietEnd = p['quiet_hours_end']?.toString() ?? '08:00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeader(title: l10n.notif_settings_title),
        SettingsGroup(
          children: [
            SettingsToggleRow(
              label: l10n.notif_settings_prestudy,
              description: l10n.notif_settings_prestudy_desc(preStudyTime),
              value: preStudy,
              onChanged: (v) => _toggle('pre_study_enabled', v),
            ),
            if (preStudy)
              SettingsRow(
                label: l10n.notif_time_fire_at,
                control: Text(preStudyTime, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                onTap: () => _pickTime(context, 'pre_study_time', preStudyTime),
              ),
            SettingsToggleRow(
              label: l10n.notif_settings_streak,
              description: l10n.notif_settings_streak_desc,
              value: _notifMapBool(p, 'streak_enabled'),
              onChanged: (v) => _toggle('streak_enabled', v),
            ),
            SettingsToggleRow(
              label: l10n.notif_settings_weekly,
              description: l10n.notif_settings_weekly_desc(_getDayName(p['weekly_summary_dow'] ?? 7, context), p['weekly_summary_time']?.toString() ?? '19:00'),
              value: _notifMapBool(p, 'weekly_enabled'),
              onChanged: (v) => _toggle('weekly_enabled', v),
            ),
            if (_notifMapBool(p, 'weekly_enabled')) ...[
              SettingsRow(
                label: l10n.notif_day_fire_at,
                control: Text(_getDayName(p['weekly_summary_dow'] ?? 7, context), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                onTap: () => _pickDay(context, 'weekly_summary_dow', p['weekly_summary_dow'] ?? 7),
              ),
              SettingsRow(
                label: l10n.notif_time_fire_at,
                control: Text(p['weekly_summary_time']?.toString() ?? '19:00', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                onTap: () => _pickTime(context, 'weekly_summary_time', p['weekly_summary_time']?.toString() ?? '19:00'),
              ),
            ],
            SettingsToggleRow(
              label: l10n.notif_settings_goal,
              description: l10n.notif_settings_goal_desc,
              value: _notifMapBool(p, 'goal_enabled'),
              onChanged: (v) => _toggle('goal_enabled', v),
            ),
            SettingsToggleRow(
              label: l10n.notif_settings_reengage,
              description: l10n.notif_settings_reengage_desc(p['reengage_time']?.toString() ?? '14:00'),
              value: _notifMapBool(p, 'reengage_3_enabled') || _notifMapBool(p, 'reengage_7_enabled'),
              onChanged: (v) {
                _toggle('reengage_3_enabled', v);
                _toggle('reengage_7_enabled', v);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsHeader(title: l10n.notif_settings_quiet_title),
        SettingsGroup(
          children: [
            SettingsRow(
              label: l10n.notif_settings_quiet_start,
              description: l10n.notif_settings_quiet_start_desc,
              control: Text(quietStart, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
              onTap: () => _pickTime(context, 'quiet_hours_start', quietStart),
            ),
            SettingsRow(
              label: l10n.notif_settings_quiet_end,
              description: l10n.notif_settings_quiet_end_desc,
              control: Text(quietEnd, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
              onTap: () => _pickTime(context, 'quiet_hours_end', quietEnd),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDay(BuildContext context, String key, int currentDow) async {
    final l10n = AppLocalizations.of(context)!;
    final days = [
      {'name': l10n.monday, 'value': 1},
      {'name': l10n.tuesday, 'value': 2},
      {'name': l10n.wednesday, 'value': 3},
      {'name': l10n.thursday, 'value': 4},
      {'name': l10n.friday, 'value': 5},
      {'name': l10n.saturday, 'value': 6},
      {'name': l10n.sunday, 'value': 7},
    ];

    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.notif_day_fire_at),
        children: days.map((d) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, d['value'] as int),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(d['name'] as String, style: TextStyle(
              fontWeight: (d['value'] as int) == currentDow ? FontWeight.bold : FontWeight.normal,
              color: (d['value'] as int) == currentDow ? AppColors.primary : null,
            )),
          ),
        )).toList(),
      ),
    );

    if (picked != null && mounted) {
      final updated = Map<String, dynamic>.from(_prefs ?? {});
      updated[key] = picked;
      setState(() => _prefs = updated);
      await ref.read(notificationSettingsRepositoryProvider).upsertSettings({key: picked});
    }
  }

  String _getDayName(int dow, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (dow) {
      case 1: return l10n.monday;
      case 2: return l10n.tuesday;
      case 3: return l10n.wednesday;
      case 4: return l10n.thursday;
      case 5: return l10n.friday;
      case 6: return l10n.saturday;
      case 7: return l10n.sunday;
      default: return l10n.sunday;
    }
  }

  bool _notifMapBool(Map<String, dynamic>? row, String snakeKey) {
    final v = row?[snakeKey];
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }
}
