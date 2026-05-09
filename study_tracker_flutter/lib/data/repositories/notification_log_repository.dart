import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../db/database.dart' as db;
import '../db/database_provider.dart';

class NotificationLogRepository {
  final db.AppDatabase _db;

  NotificationLogRepository(this._db);

  Future<int> _activeProfileId() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals('currentProfileId')))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '1') ?? 1;
  }

  Future<void> log(int notificationId, String outcome, String reason) async {
    final profileId = await _activeProfileId();
    await _db.customStatement(
      'INSERT INTO notification_log (profile_id, notification_id, outcome, reason, created_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)',
      [profileId, notificationId, outcome, reason],
    );
  }

  Future<List<Map<String, dynamic>>> recent(int limit) async {
    final profileId = await _activeProfileId();
    final rows = await _db.customSelect(
      'SELECT * FROM notification_log WHERE profile_id = ? ORDER BY created_at DESC LIMIT ?',
      variables: [drift.Variable(profileId), drift.Variable(limit)],
    ).get();
    return rows.map((r) => r.data).toList();
  }

  Future<bool> wasFiredSince(int notificationId, DateTime since) async {
    final profileId = await _activeProfileId();
    final rows = await _db.customSelect(
      'SELECT id FROM notification_log '
      'WHERE profile_id = ? AND notification_id = ? AND outcome = "fired" '
      'AND created_at >= ? LIMIT 1',
      variables: [
        drift.Variable(profileId),
        drift.Variable(notificationId),
        drift.Variable(since.toIso8601String()),
      ],
    ).get();
    return rows.isNotEmpty;
  }
}

final notificationLogRepositoryProvider = Provider<NotificationLogRepository>(
  (ref) => NotificationLogRepository(ref.watch(databaseProvider)),
);
