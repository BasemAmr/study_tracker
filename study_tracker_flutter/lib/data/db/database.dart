import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'tables.dart';

part 'database.g.dart';

// ─── UUID generator for clientDefault sync IDs ───────────────────────────────
const Uuid _uuid = Uuid();

/// The single Drift database for StudyTracker.
///
/// All tables and DAOs are defined here. Code generation produces
/// the `database.g.dart` companion file via `build_runner`.
@DriftDatabase(tables: [
  Profiles,
  StudySessions,
  SessionTasks,
  Subjects,
  SubjectGroups,
  AppSettings,
  Goals,
  MoodLogs,
  AiChallenges,
  AiChallengeHistory,
  SyncState,
  SyncHistory,
  NotificationSettings,
  NotificationLog,
  AiFeatureSettings,
  AiCache,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  static const String _dbFileName = 'study_tracker.sqlite';

  /// Bump this when adding new tables or columns.
  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _ensureCoreSeedData();
      },
      beforeOpen: (_) async {
        await _repairDateTimeStorage();
        await _ensureCoreSeedData();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(profiles);
          await customStatement(
            "INSERT INTO profiles (id, sync_id, name, academic_level, created_at, updated_at) "
            "VALUES (1, lower(hex(randomblob(16))), 'Default Profile', 'Undergraduate', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
          );

          const tablesToPatch = <String>[
            'study_sessions',
            'session_tasks',
            'subjects',
            'subject_groups',
            'goals',
            'mood_logs',
            'ai_challenges',
          ];

          for (final table in tablesToPatch) {
            await customStatement(
              'ALTER TABLE $table ADD COLUMN profile_id INTEGER NOT NULL DEFAULT 1',
            );
          }

          await customStatement(
            "INSERT OR REPLACE INTO app_settings (key, value, updated_at) "
            "VALUES ('currentProfileId', '1', CURRENT_TIMESTAMP)",
          );
        }

        if (from < 3) {
          await customStatement('DROP INDEX IF EXISTS subjects_name;');
          await customStatement('DROP INDEX IF EXISTS subjects_name_unique;');
          await customStatement('DROP INDEX IF EXISTS subject_groups_name;');
          await customStatement('DROP INDEX IF EXISTS subject_groups_name_unique;');

          // Normalize per-profile duplicate names before creating unique indexes.
          await customStatement('''
            WITH ranked AS (
              SELECT id,
                     ROW_NUMBER() OVER (PARTITION BY profile_id, name ORDER BY id) AS rn
              FROM subjects
            )
            UPDATE subjects
            SET name = name || ' (' || id || ')'
            WHERE id IN (SELECT id FROM ranked WHERE rn > 1)
          ''');

          await customStatement('''
            WITH ranked AS (
              SELECT id,
                     ROW_NUMBER() OVER (PARTITION BY profile_id, name ORDER BY id) AS rn
              FROM subject_groups
            )
            UPDATE subject_groups
            SET name = name || ' (' || id || ')'
            WHERE id IN (SELECT id FROM ranked WHERE rn > 1)
          ''');

          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS subjects_profile_id_name_unique '
            'ON subjects(profile_id, name)',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS subject_groups_profile_id_name_unique '
            'ON subject_groups(profile_id, name)',
          );
        }

        if (from < 4) {
          await customStatement('ALTER TABLE profiles ADD COLUMN sync_id TEXT;');
          await customStatement(
            "UPDATE profiles SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = ''",
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS profiles_sync_id_unique ON profiles(sync_id)',
          );

          await customStatement('ALTER TABLE study_sessions ADD COLUMN sync_id TEXT;');
          await customStatement(
            "UPDATE study_sessions SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = ''",
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS study_sessions_sync_id_unique ON study_sessions(sync_id)',
          );

          await customStatement('ALTER TABLE session_tasks ADD COLUMN sync_id TEXT;');
          await customStatement('ALTER TABLE session_tasks ADD COLUMN updated_at TEXT;');
          await customStatement(
            "UPDATE session_tasks SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = ''",
          );
          await customStatement(
            'UPDATE session_tasks SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS session_tasks_sync_id_unique ON session_tasks(sync_id)',
          );

          await customStatement('ALTER TABLE subjects ADD COLUMN sync_id TEXT;');
          await customStatement('ALTER TABLE subjects ADD COLUMN updated_at TEXT;');
          await customStatement(
            "UPDATE subjects SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = ''",
          );
          await customStatement(
            'UPDATE subjects SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS subjects_sync_id_unique ON subjects(sync_id)',
          );

          await customStatement('ALTER TABLE subject_groups ADD COLUMN sync_id TEXT;');
          await customStatement('ALTER TABLE subject_groups ADD COLUMN updated_at TEXT;');
          await customStatement(
            "UPDATE subject_groups SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = ''",
          );
          await customStatement(
            'UPDATE subject_groups SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS subject_groups_sync_id_unique ON subject_groups(sync_id)',
          );

          await customStatement('ALTER TABLE goals ADD COLUMN sync_id TEXT;');
          await customStatement(
            "UPDATE goals SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = ''",
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS goals_sync_id_unique ON goals(sync_id)',
          );

          await customStatement('ALTER TABLE mood_logs ADD COLUMN sync_id TEXT;');
          await customStatement('ALTER TABLE mood_logs ADD COLUMN updated_at TEXT;');
          await customStatement(
            "UPDATE mood_logs SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = ''",
          );
          await customStatement(
            'UPDATE mood_logs SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS mood_logs_sync_id_unique ON mood_logs(sync_id)',
          );
        }
        if (from < 5) {
          await m.createTable(syncState);
          await m.createTable(syncHistory);
          // Seed sync device identity and settings
          await customStatement(
            "INSERT OR IGNORE INTO app_settings (key, value, updated_at) "
            "VALUES ('syncDeviceId', lower(hex(randomblob(16))), CURRENT_TIMESTAMP)",
          );
          await customStatement(
            "INSERT OR IGNORE INTO app_settings (key, value, updated_at) "
            "VALUES ('syncDeviceName', 'My Android Device', CURRENT_TIMESTAMP)",
          );
          await customStatement(
            "INSERT OR IGNORE INTO app_settings (key, value, updated_at) "
            "VALUES ('syncPassphrase', '', CURRENT_TIMESTAMP)",
          );
          await customStatement(
            // Opt-in default: indicator + auto-sync stay off until the user enables.
            "INSERT OR IGNORE INTO app_settings (key, value, updated_at) "
            "VALUES ('wifiSyncEnabled', 'false', CURRENT_TIMESTAMP)",
          );
          await customStatement(
            "INSERT OR IGNORE INTO app_settings (key, value, updated_at) "
            "VALUES ('wifiSyncPort', '47821', CURRENT_TIMESTAMP)",
          );
          await customStatement(
            "INSERT OR IGNORE INTO app_settings (key, value, updated_at) "
            "VALUES ('wifiSyncPairingCode', '', CURRENT_TIMESTAMP)",
          );
          await customStatement(
            "INSERT OR IGNORE INTO app_settings (key, value, updated_at) "
            "VALUES ('cloudSyncEnabled', 'false', CURRENT_TIMESTAMP)",
          );
          await customStatement(
            "INSERT OR IGNORE INTO app_settings (key, value, updated_at) "
            "VALUES ('cloudSyncProvider', 'supabase', CURRENT_TIMESTAMP)",
          );
          await customStatement(
            "INSERT OR IGNORE INTO app_settings (key, value, updated_at) "
            "VALUES ('cloudSyncUrl', '', CURRENT_TIMESTAMP)",
          );
          await customStatement(
            "INSERT OR IGNORE INTO app_settings (key, value, updated_at) "
            "VALUES ('cloudSyncAnonKey', '', CURRENT_TIMESTAMP)",
          );
        }
        if (from < 6) {
          const tablesWithDeletedAt = <String>[
            'profiles',
            'study_sessions',
            'session_tasks',
            'subjects',
            'subject_groups',
            'goals',
            'mood_logs',
          ];
          for (final table in tablesWithDeletedAt) {
            await customStatement(
              'ALTER TABLE $table ADD COLUMN deleted_at TEXT;',
            );
          }
        }

        if (from < 7) {
          // Migration version 7 might have been missed or handled elsewhere, 
          // but we ensure version 8 is applied correctly.
        }

        if (from < 8) {
          await customStatement(
            'ALTER TABLE profiles ADD COLUMN owner_device_id TEXT NOT NULL DEFAULT "";',
          );
          // Standardize default profile sync_id
          await customStatement(
            "UPDATE profiles SET sync_id = 'profile-default' WHERE id = 1",
          );
        }
        if (from < 9) {
          await customStatement(
            "UPDATE profiles SET owner_device_id = 'shared' WHERE sync_id = 'profile-default'",
          );
        }
        if (from < 10) {
          // Device-local tables for notifications and AI feature/cache.
          await m.createTable(notificationSettings);
          await m.createTable(notificationLog);
          await m.createTable(aiFeatureSettings);
          await m.createTable(aiCache);

          // Seed a default notification_settings row for profile 1.
          // NOTE: slot_b_time was removed from the Drift schema; use explicit named columns only.
          await customStatement(
            "INSERT OR IGNORE INTO notification_settings ("
            "profile_id, pre_study_enabled, streak_enabled, weekly_enabled, goal_enabled, "
            "reengage_3_enabled, reengage_7_enabled, slot_a_time, "
            "pre_study_time, weekly_summary_time, reengage_time, "
            "quiet_hours_start, quiet_hours_end, reengage_interval_days, reengage_hour, "
            "weekly_summary_dow, goal_dow, goal_time, updated_at) "
            "VALUES (1, 0, 0, 0, 0, 0, 0, '14:00', '14:00', '19:00', '14:00', '22:00', '08:00', 3, 14, 7, 3, '19:00', CURRENT_TIMESTAMP)",
          );

          // Seed ai_feature_settings for profile 1 (defaults are all disabled)
          await customStatement(
            "INSERT OR IGNORE INTO ai_feature_settings (profile_id, updated_at) VALUES (1, CURRENT_TIMESTAMP)",
          );
        }

        if (from < 11) {
          // notification_settings.updated_at + ai_feature_settings.updated_at are TextColumn (ISO-8601).
          // On-disk values are already textual; Drift mapping change only — no data migration.
        }

        if (from < 12) {
          await customStatement('ALTER TABLE notification_settings ADD COLUMN weekly_summary_dow INTEGER NOT NULL DEFAULT 7;');
          await customStatement('ALTER TABLE notification_settings ADD COLUMN goal_dow INTEGER NOT NULL DEFAULT 3;');
          await customStatement("ALTER TABLE notification_settings ADD COLUMN goal_time TEXT NOT NULL DEFAULT '19:00';");
          
          final hasKey = await customSelect("SELECT 1 FROM app_settings WHERE key = 'groqApiKey' AND value != ''").getSingleOrNull();
          if (hasKey != null) {
            await customStatement("UPDATE ai_feature_settings SET debrief_enabled = 1 WHERE profile_id IN (SELECT id FROM profiles)");
          }
        }

        if (from < 13) {
          await customStatement('ALTER TABLE ai_challenges ADD COLUMN sub_targets_json TEXT;');
          await customStatement('ALTER TABLE ai_challenges ADD COLUMN unit_min_minutes INTEGER;');
          await customStatement(
            "ALTER TABLE ai_challenges ADD COLUMN status TEXT NOT NULL DEFAULT 'active' "
            "CHECK(status IN ('active', 'completed', 'expired', 'replaced'));",
          );

          await customStatement('''
CREATE TABLE IF NOT EXISTS ai_challenge_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  tier TEXT NOT NULL CHECK(tier IN ('daily', 'weekly', 'monthly', 'surprise')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  metric TEXT NOT NULL,
  target INTEGER NOT NULL,
  progress_at_close INTEGER NOT NULL,
  close_reason TEXT NOT NULL CHECK(close_reason IN ('replaced', 'expired', 'completed')),
  closed_at TEXT NOT NULL,
  original_created_at TEXT NOT NULL,
  original_expires_at TEXT NOT NULL,
  sub_targets_json TEXT,
  unit_min_minutes INTEGER
);
''');
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_ai_challenge_history_profile_tier_closed '
            'ON ai_challenge_history(profile_id, tier, closed_at DESC);',
          );

          await customStatement(
            'ALTER TABLE ai_feature_settings ADD COLUMN surprise_notifications_enabled INTEGER NOT NULL DEFAULT 0;',
          );
          await customStatement(
            'ALTER TABLE ai_feature_settings ADD COLUMN surprise_check_interval_hours INTEGER NOT NULL DEFAULT 3 '
            'CHECK(surprise_check_interval_hours > 0);',
          );
        }
      },
    );
  }

  Future<File> databaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, _dbFileName));
  }

  Future<int> databaseSizeBytes() async {
    final file = await databaseFile();
    var total = 0;

    if (await file.exists()) {
      total += await file.length();
    }

    final wal = File('${file.path}-wal');
    if (await wal.exists()) {
      total += await wal.length();
    }

    final shm = File('${file.path}-shm');
    if (await shm.exists()) {
      total += await shm.length();
    }

    return total;
  }

  Future<void> ensureCoreSeedData() => _ensureCoreSeedData();

  Future<void> _ensureCoreSeedData() async {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      '''
      INSERT OR IGNORE INTO profiles (id, sync_id, name, academic_level, owner_device_id, created_at, updated_at)
      VALUES (1, 'profile-default', 'Default Profile', 'Undergraduate', 'shared', ?, ?)
      ''',
      [nowMillis, nowMillis],
    );
    await customStatement(
      '''
      UPDATE profiles SET sync_id = 'profile-default', owner_device_id = 'shared' WHERE id = 1
      ''',
    );
    await customStatement(
      '''
      UPDATE profiles SET owner_device_id = 'shared' WHERE sync_id = 'profile-default'
      ''',
    );

    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES ('currentProfileId', '1', ?)
      ''',
      [nowMillis],
    );
    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES (?, ?, ?)
      ''',
      ['syncDeviceId', _uuid.v4(), nowMillis],
    );
    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES ('syncDeviceName', 'My Device', ?)
      ''',
      [nowMillis],
    );
    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES ('syncPassphrase', '', ?)
      ''',
      [nowMillis],
    );
    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES ('wifiSyncEnabled', 'false', ?)
      ''',
      [nowMillis],
    );
    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES ('wifiSyncPort', '47821', ?)
      ''',
      [nowMillis],
    );
    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES ('wifiSyncPairingCode', '', ?)
      ''',
      [nowMillis],
    );
    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES ('cloudSyncEnabled', 'false', ?)
      ''',
      [nowMillis],
    );
    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES ('cloudSyncProvider', 'supabase', ?)
      ''',
      [nowMillis],
    );
    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES ('cloudSyncUrl', '', ?)
      ''',
      [nowMillis],
    );
    await customStatement(
      '''
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
      VALUES ('cloudSyncAnonKey', '', ?)
      ''',
      [nowMillis],
    );

    // Ensure profile-scoped device-local tables have a row for profile 1.
    // These are inserted by the v10 upgrade path but also needed on fresh onCreate.
    await customStatement(
      "INSERT OR IGNORE INTO notification_settings ("
      "profile_id, pre_study_enabled, streak_enabled, weekly_enabled, goal_enabled, "
      "reengage_3_enabled, reengage_7_enabled, slot_a_time, "
      "pre_study_time, weekly_summary_time, reengage_time, "
      "quiet_hours_start, quiet_hours_end, reengage_interval_days, reengage_hour, "
      "weekly_summary_dow, goal_dow, goal_time, updated_at) "
      "VALUES (1, 0, 0, 0, 0, 0, 0, '14:00', '14:00', '19:00', '14:00', '22:00', '08:00', 3, 14, 7, 3, '19:00', CURRENT_TIMESTAMP)",
    );
    await customStatement(
      "INSERT OR IGNORE INTO ai_feature_settings (profile_id, updated_at) VALUES (1, CURRENT_TIMESTAMP)",
    );
  }

  Future<void> _repairDateTimeStorage() async {
    const dateTextToMillis = "CAST(strftime('%s', {column}) AS INTEGER) * 1000";
    const repairs = <String, List<String>>{
      'profiles': ['created_at', 'updated_at'],
      'study_sessions': ['created_at', 'updated_at'],
      'session_tasks': ['created_at', 'updated_at'],
      'subjects': ['created_at', 'updated_at'],
      'subject_groups': ['created_at', 'updated_at'],
      'app_settings': ['updated_at'],
      'goals': ['created_at', 'updated_at'],
      'mood_logs': ['created_at', 'updated_at'],
      'ai_challenges': ['created_at', 'updated_at'],
      'sync_history': ['synced_at'],
    };

    for (final entry in repairs.entries) {
      for (final column in entry.value) {
        await customStatement(
          '''
          UPDATE ${entry.key}
          SET $column = ${dateTextToMillis.replaceAll('{column}', column)}
          WHERE typeof($column) = 'text' AND $column LIKE '____-__-__%'
          ''',
        );
      }
    }
  }

  Future<DatabaseCompactResult> compactDatabase() async {
    final before = await databaseSizeBytes();
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    await customStatement('VACUUM;');
    final after = await databaseSizeBytes();
    return DatabaseCompactResult(
      beforeBytes: before,
      afterBytes: after,
    );
  }

  Future<void> wipeDatabase() async {
    await transaction(() async {
      final tableNames = [
        'session_tasks',
        'study_sessions',
        'subjects',
        'subject_groups',
        'goals',
        'mood_logs',
        'ai_challenge_history',
        'ai_challenges',
        'app_settings',
        'profiles',
        'sync_state',
        'sync_history'
      ];

      for (final table in tableNames) {
        await customStatement('DELETE FROM $table;');
      }

      await _ensureCoreSeedData();
    });
  }
}

class DatabaseCompactResult {
  final int beforeBytes;
  final int afterBytes;

  const DatabaseCompactResult({
    required this.beforeBytes,
    required this.afterBytes,
  });

  int get reclaimedBytes => beforeBytes - afterBytes;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppDatabase._dbFileName));
    return NativeDatabase.createInBackground(file);
  });
}
