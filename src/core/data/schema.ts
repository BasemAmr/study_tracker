export const migrations = [
  {
    version: 1,
    description: 'initial local persistence schema',
    sql: `
      CREATE TABLE IF NOT EXISTS _migrations (
        version INTEGER PRIMARY KEY,
        description TEXT NOT NULL,
        applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_at TEXT NOT NULL,
        end_at TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL CHECK(duration_minutes > 0),
        subject_id INTEGER,
        subject_name TEXT,
        topic TEXT,
        chapter_tag TEXT,
        mood TEXT,
        notes TEXT,
        mode TEXT NOT NULL CHECK(mode IN ('pomodoro', 'long_session', 'manual')),
        break_minutes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE SET NULL
      );

      CREATE TABLE IF NOT EXISTS session_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(session_id) REFERENCES study_sessions(id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_minutes INTEGER NOT NULL CHECK(target_minutes > 0),
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS mood_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        mood TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(session_id) REFERENCES study_sessions(id) ON DELETE SET NULL
      );

      CREATE INDEX IF NOT EXISTS idx_study_sessions_start_at ON study_sessions(start_at);
      CREATE INDEX IF NOT EXISTS idx_study_sessions_subject_id ON study_sessions(subject_id);
      CREATE INDEX IF NOT EXISTS idx_study_sessions_mode ON study_sessions(mode);
      CREATE INDEX IF NOT EXISTS idx_session_tasks_session_id ON session_tasks(session_id);
      CREATE INDEX IF NOT EXISTS idx_mood_logs_session_id ON mood_logs(session_id);
    `
  },
  {
    version: 2,
    description: 'subject groups and session backgrounds',
    sql: `
      CREATE TABLE IF NOT EXISTS subject_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      ALTER TABLE subjects ADD COLUMN group_id INTEGER REFERENCES subject_groups(id) ON DELETE SET NULL;

      ALTER TABLE study_sessions ADD COLUMN background_image TEXT;
    `
  },
  {
    version: 3,
    description: 'ai dynamic challenges',
    sql: `
      CREATE TABLE IF NOT EXISTS ai_challenges (
        id TEXT PRIMARY KEY,
        tier TEXT NOT NULL CHECK(tier IN ('daily', 'weekly', 'monthly', 'surprise')),
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        icon TEXT NOT NULL,
        metric TEXT NOT NULL,
        target INTEGER NOT NULL,
        expires_at TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        reward_badge_name TEXT NOT NULL,
        reward_badge_icon TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        raw_response TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_ai_challenges_tier ON ai_challenges(tier);
      CREATE INDEX IF NOT EXISTS idx_ai_challenges_completed ON ai_challenges(completed);
      CREATE INDEX IF NOT EXISTS idx_ai_challenges_expires_at ON ai_challenges(expires_at);
    `
  },
  {
    version: 4,
    description: 'sync foundation columns for user data tables',
    sql: `
      ALTER TABLE subjects ADD COLUMN sync_id TEXT;
      ALTER TABLE subjects ADD COLUMN updated_at TEXT;
      UPDATE subjects SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = '';
      UPDATE subjects SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
      CREATE UNIQUE INDEX IF NOT EXISTS idx_subjects_sync_id_unique ON subjects(sync_id);

      ALTER TABLE study_sessions ADD COLUMN sync_id TEXT;
      UPDATE study_sessions SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = '';
      CREATE UNIQUE INDEX IF NOT EXISTS idx_study_sessions_sync_id_unique ON study_sessions(sync_id);

      ALTER TABLE session_tasks ADD COLUMN sync_id TEXT;
      ALTER TABLE session_tasks ADD COLUMN updated_at TEXT;
      UPDATE session_tasks SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = '';
      UPDATE session_tasks SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
      CREATE UNIQUE INDEX IF NOT EXISTS idx_session_tasks_sync_id_unique ON session_tasks(sync_id);

      ALTER TABLE goals ADD COLUMN sync_id TEXT;
      UPDATE goals SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = '';
      CREATE UNIQUE INDEX IF NOT EXISTS idx_goals_sync_id_unique ON goals(sync_id);

      ALTER TABLE mood_logs ADD COLUMN sync_id TEXT;
      ALTER TABLE mood_logs ADD COLUMN updated_at TEXT;
      UPDATE mood_logs SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = '';
      UPDATE mood_logs SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
      CREATE UNIQUE INDEX IF NOT EXISTS idx_mood_logs_sync_id_unique ON mood_logs(sync_id);

      ALTER TABLE subject_groups ADD COLUMN sync_id TEXT;
      ALTER TABLE subject_groups ADD COLUMN updated_at TEXT;
      UPDATE subject_groups SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = '';
      UPDATE subject_groups SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
      CREATE UNIQUE INDEX IF NOT EXISTS idx_subject_groups_sync_id_unique ON subject_groups(sync_id);
    `
  },
  {
    version: 5,
    description: 'local scholar profiles and per-profile data partitioning',
    sql: `
      CREATE TABLE IF NOT EXISTS profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT,
        name TEXT NOT NULL,
        academic_level TEXT NOT NULL DEFAULT 'Undergraduate',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      UPDATE profiles SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL OR sync_id = '';
      CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_sync_id_unique ON profiles(sync_id);

      INSERT OR IGNORE INTO profiles (id, sync_id, name, academic_level, created_at, updated_at)
      VALUES (1, lower(hex(randomblob(16))), 'Default Profile', 'Undergraduate', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

      ALTER TABLE study_sessions ADD COLUMN profile_id INTEGER NOT NULL DEFAULT 1;
      ALTER TABLE session_tasks ADD COLUMN profile_id INTEGER NOT NULL DEFAULT 1;
      ALTER TABLE subjects ADD COLUMN profile_id INTEGER NOT NULL DEFAULT 1;
      ALTER TABLE subject_groups ADD COLUMN profile_id INTEGER NOT NULL DEFAULT 1;
      ALTER TABLE goals ADD COLUMN profile_id INTEGER NOT NULL DEFAULT 1;
      ALTER TABLE mood_logs ADD COLUMN profile_id INTEGER NOT NULL DEFAULT 1;
      ALTER TABLE ai_challenges ADD COLUMN profile_id INTEGER NOT NULL DEFAULT 1;

      CREATE INDEX IF NOT EXISTS idx_study_sessions_profile_id ON study_sessions(profile_id);
      CREATE INDEX IF NOT EXISTS idx_session_tasks_profile_id ON session_tasks(profile_id);
      CREATE INDEX IF NOT EXISTS idx_subjects_profile_id ON subjects(profile_id);
      CREATE INDEX IF NOT EXISTS idx_subject_groups_profile_id ON subject_groups(profile_id);
      CREATE INDEX IF NOT EXISTS idx_goals_profile_id ON goals(profile_id);
      CREATE INDEX IF NOT EXISTS idx_mood_logs_profile_id ON mood_logs(profile_id);
      CREATE INDEX IF NOT EXISTS idx_ai_challenges_profile_id ON ai_challenges(profile_id);

      INSERT INTO app_settings (key, value, updated_at)
      VALUES ('currentProfileId', '1', CURRENT_TIMESTAMP)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP;
    `
  },
  {
    version: 6,
    description: 'progressive sync state — device identity, peer tracking, transport toggles',
    sql: `
      CREATE TABLE IF NOT EXISTS sync_state (
        peer_device_id TEXT NOT NULL,
        transport TEXT NOT NULL,
        last_synced_at TEXT,
        last_sync_direction TEXT,
        last_row_count INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (peer_device_id, transport)
      );

      CREATE TABLE IF NOT EXISTS sync_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        peer_device_id TEXT,
        peer_device_name TEXT,
        transport TEXT NOT NULL,
        direction TEXT NOT NULL,
        rows_sent INTEGER NOT NULL DEFAULT 0,
        rows_received INTEGER NOT NULL DEFAULT 0,
        success INTEGER NOT NULL DEFAULT 1,
        error_message TEXT,
        synced_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
        VALUES ('syncDeviceId', lower(hex(randomblob(16))), CURRENT_TIMESTAMP);
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
        VALUES ('syncDeviceName', 'My Device', CURRENT_TIMESTAMP);
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
        VALUES ('syncPassphrase', '', CURRENT_TIMESTAMP);
      -- Sync is opt-in: users must explicitly turn it on from the Sync tab.
      -- This also ensures the persistent status indicator stays hidden by default.
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
        VALUES ('wifiSyncEnabled', 'false', CURRENT_TIMESTAMP);
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
        VALUES ('wifiSyncPort', '47821', CURRENT_TIMESTAMP);
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
        VALUES ('wifiSyncPairingCode', '', CURRENT_TIMESTAMP);
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
        VALUES ('cloudSyncEnabled', 'false', CURRENT_TIMESTAMP);
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
        VALUES ('cloudSyncProvider', 'supabase', CURRENT_TIMESTAMP);
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
        VALUES ('cloudSyncUrl', '', CURRENT_TIMESTAMP);
      INSERT OR IGNORE INTO app_settings (key, value, updated_at)
        VALUES ('cloudSyncAnonKey', '', CURRENT_TIMESTAMP);
    `
  },
  {
    version: 7,
    description: 'soft-delete tombstones',
    sql: `
      ALTER TABLE profiles ADD COLUMN deleted_at TEXT;
      ALTER TABLE study_sessions ADD COLUMN deleted_at TEXT;
      ALTER TABLE session_tasks ADD COLUMN deleted_at TEXT;
      ALTER TABLE subjects ADD COLUMN deleted_at TEXT;
      ALTER TABLE subject_groups ADD COLUMN deleted_at TEXT;
      ALTER TABLE goals ADD COLUMN deleted_at TEXT;
      ALTER TABLE mood_logs ADD COLUMN deleted_at TEXT;
    `
  },
  {
    version: 8,
    description: 'profile ownership and standardization',
    sql: `
      ALTER TABLE profiles ADD COLUMN owner_device_id TEXT NOT NULL DEFAULT '';
      
      -- Standardize default profile sync_id
      UPDATE profiles SET sync_id = 'profile-default' WHERE id = 1 AND (sync_id IS NULL OR sync_id = '');
      
      -- If profile 1 already had a sync_id, we might want to force it to 'profile-default' 
      -- to ensure all devices align on the same default container.
      UPDATE profiles SET sync_id = 'profile-default' WHERE id = 1;
    `
  },
  {
    version: 9,
    description: "default profile ownership sentinel 'shared' for multi-device default profile",
    sql: `
      UPDATE profiles SET owner_device_id = 'shared' WHERE sync_id = 'profile-default';
    `
  },
  {
    version: 10,
    description: 'subjects: drop global UNIQUE(name); add per-profile partial unique (matches mobile + sync)',
    sql: `
      PRAGMA foreign_keys=OFF;

      CREATE TABLE subjects_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT,
        group_id INTEGER,
        sync_id TEXT,
        updated_at TEXT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        deleted_at TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(group_id) REFERENCES subject_groups(id) ON DELETE SET NULL
      );

      INSERT INTO subjects_new (id, name, color, group_id, sync_id, updated_at, profile_id, deleted_at, created_at)
      SELECT id, name, color, group_id, sync_id, updated_at, profile_id, deleted_at, created_at FROM subjects;

      DROP TABLE subjects;
      ALTER TABLE subjects_new RENAME TO subjects;

      DELETE FROM subjects
      WHERE deleted_at IS NULL
        AND id NOT IN (
          SELECT MIN(id) FROM subjects WHERE deleted_at IS NULL GROUP BY profile_id, name
        );

      CREATE UNIQUE INDEX IF NOT EXISTS idx_subjects_sync_id_unique ON subjects(sync_id);
      CREATE INDEX IF NOT EXISTS idx_subjects_profile_id ON subjects(profile_id);
      CREATE UNIQUE INDEX IF NOT EXISTS idx_subjects_profile_name_active
        ON subjects(profile_id, name) WHERE deleted_at IS NULL;

      PRAGMA foreign_keys=ON;
    `
  },
  {
    version: 11,
    description: 'device-local notification + AI feature settings/cache (no sync)',
    sql: `
      CREATE TABLE IF NOT EXISTS notification_settings (
        profile_id INTEGER PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
        pre_study_enabled INTEGER NOT NULL DEFAULT 0,
        streak_enabled INTEGER NOT NULL DEFAULT 0,
        weekly_enabled INTEGER NOT NULL DEFAULT 0,
        goal_enabled INTEGER NOT NULL DEFAULT 0,
        reengage_3_enabled INTEGER NOT NULL DEFAULT 0,
        reengage_7_enabled INTEGER NOT NULL DEFAULT 0,
        slot_a_time TEXT NOT NULL DEFAULT '14:00',
        slot_b_time TEXT NOT NULL DEFAULT '19:00',
        quiet_hours_start TEXT NOT NULL DEFAULT '22:00',
        quiet_hours_end TEXT NOT NULL DEFAULT '08:00',
        reengage_interval_days INTEGER NOT NULL DEFAULT 3 CHECK(reengage_interval_days > 0),
        reengage_hour INTEGER NOT NULL DEFAULT 14 CHECK(reengage_hour >= 0 AND reengage_hour <= 23),
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS notification_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        notification_id INTEGER NOT NULL,
        outcome TEXT NOT NULL CHECK(outcome IN ('fired', 'suppressed')),
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_notification_log_profile_id_created ON notification_log(profile_id, notification_id, created_at);

      CREATE TABLE IF NOT EXISTS ai_feature_settings (
        profile_id INTEGER PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
        feat_challenge_ai INTEGER NOT NULL DEFAULT 0,
        feat_session_insights INTEGER NOT NULL DEFAULT 0,
        feat_study_planner INTEGER NOT NULL DEFAULT 0,
        feat_motivation INTEGER NOT NULL DEFAULT 0,
        feat_weekly_review INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS ai_cache (
        profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        feature TEXT NOT NULL,
        cache_key TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (profile_id, feature, cache_key)
      );

      CREATE INDEX IF NOT EXISTS idx_ai_cache_profile_updated ON ai_cache(profile_id, updated_at);

      INSERT OR IGNORE INTO notification_settings (
        profile_id,
        pre_study_enabled,
        streak_enabled,
        weekly_enabled,
        goal_enabled,
        reengage_3_enabled,
        reengage_7_enabled,
        slot_a_time,
        slot_b_time,
        quiet_hours_start,
        quiet_hours_end,
        reengage_interval_days,
        reengage_hour,
        updated_at
      )
      VALUES (
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        '14:00',
        '19:00',
        '22:00',
        '08:00',
        3,
        14,
        CURRENT_TIMESTAMP
      );

      INSERT OR IGNORE INTO ai_feature_settings (profile_id, updated_at) VALUES (1, CURRENT_TIMESTAMP);
    `
  },
  {
    version: 12,
    description: 'notification_settings: explicit times for pre-study, weekly summary, re-engage (HH:mm)',
    sql: `
      ALTER TABLE notification_settings ADD COLUMN pre_study_time TEXT NOT NULL DEFAULT '14:00';
      ALTER TABLE notification_settings ADD COLUMN weekly_summary_time TEXT NOT NULL DEFAULT '19:00';
      ALTER TABLE notification_settings ADD COLUMN reengage_time TEXT NOT NULL DEFAULT '14:00';
      UPDATE notification_settings SET pre_study_time = slot_a_time;
      UPDATE notification_settings SET weekly_summary_time = slot_b_time;
      UPDATE notification_settings SET reengage_time = printf('%02d:00', reengage_hour);
    `
  },
  {
    version: 13,
    description: 'ai_feature_settings: coach/smart/debrief/weekly narrative/subject-difficulty toggles',
    sql: `
      ALTER TABLE ai_feature_settings ADD COLUMN coach_enabled INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE ai_feature_settings ADD COLUMN smart_challenges_enabled INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE ai_feature_settings ADD COLUMN debrief_enabled INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE ai_feature_settings ADD COLUMN weekly_narrative_enabled INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE ai_feature_settings ADD COLUMN subject_difficulty_enabled INTEGER NOT NULL DEFAULT 0;

      UPDATE ai_feature_settings SET
        coach_enabled = feat_motivation,
        smart_challenges_enabled = feat_challenge_ai,
        debrief_enabled = feat_session_insights,
        weekly_narrative_enabled = feat_weekly_review,
        subject_difficulty_enabled = feat_study_planner;
    `
  },
  {
    version: 14,
    description: 'Add difficulty_level to subjects and DOW/time to notification_settings',
    sql: `
      ALTER TABLE subjects ADD COLUMN difficulty_level INTEGER DEFAULT 3;
      ALTER TABLE notification_settings ADD COLUMN weekly_summary_dow INTEGER NOT NULL DEFAULT 7;
      ALTER TABLE notification_settings ADD COLUMN goal_dow INTEGER NOT NULL DEFAULT 3;
      ALTER TABLE notification_settings ADD COLUMN goal_time TEXT NOT NULL DEFAULT '19:00';
    `
  },
  {
    version: 15,
    description:
      'AI missions: challenge sub-targets/status, local history, surprise notification prefs, active mission pointer',
    sql: `
      ALTER TABLE ai_challenges ADD COLUMN sub_targets_json TEXT;
      ALTER TABLE ai_challenges ADD COLUMN unit_min_minutes INTEGER;
      ALTER TABLE ai_challenges ADD COLUMN status TEXT NOT NULL DEFAULT 'active'
        CHECK(status IN ('active', 'completed', 'expired', 'replaced'));

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

      CREATE INDEX IF NOT EXISTS idx_ai_challenge_history_profile_tier_closed
        ON ai_challenge_history(profile_id, tier, closed_at DESC);

      ALTER TABLE ai_feature_settings ADD COLUMN surprise_notifications_enabled INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE ai_feature_settings ADD COLUMN surprise_check_interval_hours INTEGER NOT NULL DEFAULT 3
        CHECK(surprise_check_interval_hours > 0);
    `
  }
] as const;

