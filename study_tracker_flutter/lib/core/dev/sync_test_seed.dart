import 'package:drift/drift.dart';

import '../../data/db/database.dart' as db;
import '../../data/repositories/settings_repository.dart';
import '../../domain/enums.dart';
import '../sync/sync_trigger.dart';

/// True when DB matches a post-reset idle state: one default profile, original name, no study rows.
Future<bool> isPristineDbForSyncSeed(db.AppDatabase database) async {
  final profileRows = await database.customSelect(
    'SELECT COUNT(*) AS c FROM profiles WHERE deleted_at IS NULL',
  ).getSingle();
  if ((profileRows.data['c'] as int) != 1) return false;

  final p = await database.customSelect(
    'SELECT sync_id, name FROM profiles WHERE deleted_at IS NULL LIMIT 1',
  ).getSingle();
  if (p.data['sync_id'] != 'profile-default') return false;
  if ((p.data['name'] as String).trim() != 'Default Profile') return false;

  const tables = [
    'study_sessions',
    'subjects',
    'subject_groups',
    'goals',
    'mood_logs',
    'session_tasks',
  ];
  for (final t in tables) {
    final r = await database.customSelect(
      'SELECT COUNT(*) AS c FROM $t WHERE deleted_at IS NULL',
    ).getSingle();
    if ((r.data['c'] as int) != 0) return false;
  }
  return true;
}

Future<void> _seedProfileBundle(db.AppDatabase database, int profileId, String label) async {
  final now = DateTime.now();
  final groupId = await database.into(database.subjectGroups).insert(
        db.SubjectGroupsCompanion.insert(
          profileId: Value(profileId),
          name: 'Dev group ($label)',
          color: const Value('#63946d'),
          updatedAt: Value(now),
        ),
      );

  final subjectId = await database.into(database.subjects).insert(
        db.SubjectsCompanion.insert(
          profileId: Value(profileId),
          name: 'Dev subject ($label)',
          color: const Value('#5a7a5a'),
          groupId: Value(groupId),
          updatedAt: Value(now),
        ),
      );

  final start = now.subtract(const Duration(hours: 1));
  final end = now.subtract(const Duration(minutes: 15));

  await database.into(database.studySessions).insert(
        db.StudySessionsCompanion.insert(
          profileId: Value(profileId),
          startAt: start.toIso8601String(),
          endAt: end.toIso8601String(),
          durationMinutes: 45,
          subjectId: Value(subjectId),
          subjectName: Value('Dev subject ($label)'),
          topic: Value('Dev session ($label)'),
          mode: StudySessionMode.manual.dbValue,
          breakMinutes: const Value(0),
          updatedAt: Value(now),
        ),
      );
}

/// [role] `phone` = Flutter app scenario; `desktop` reserved if this build runs elsewhere.
Future<void> seedSyncTestScenario({
  required db.AppDatabase database,
  required SettingsRepository settingsRepo,
  required String role,
}) async {
  final deviceId = await settingsRepo.get('syncDeviceId') ?? '';
  final defaultName = role == 'desktop' ? 'Edit First' : 'Edit Second LLW';
  final secondName = role == 'desktop' ? 'new profile from desktop' : 'new profile from phone';

  await database.transaction(() async {
    final now = DateTime.now();

    await (database.update(database.profiles)..where((t) => t.syncId.equals('profile-default'))).write(
      db.ProfilesCompanion(
        name: Value(defaultName),
        academicLevel: const Value('Postgraduate'),
        updatedAt: Value(now),
      ),
    );

    final secondId = await database.into(database.profiles).insert(
          db.ProfilesCompanion.insert(
            name: secondName,
            academicLevel: const Value('Postgraduate'),
            ownerDeviceId: Value(deviceId),
            updatedAt: Value(now),
          ),
        );

    final def = await (database.select(database.profiles)..where((t) => t.syncId.equals('profile-default')))
        .getSingle();

    await _seedProfileBundle(database, def.id, 'default');
    await _seedProfileBundle(database, secondId, 'second');

    await settingsRepo.setCurrentProfileId(def.id);
  });

  SyncTrigger.instance.notifyWrite();
}
