import { migrations } from './schema';

type Database = {
  execute: (sql: string, values?: Array<string | number | null>) => Promise<{ lastInsertId?: number | string }>;
  select: <T>(sql: string, values?: Array<string | number | null>) => Promise<T>;
};

let databasePromise: Promise<Database> | null = null;

function isRecoverableMigrationError(error: unknown): boolean {
  const message = String(error).toLowerCase();
  return (
    message.includes('duplicate column name') ||
    message.includes('already exists') ||
    message.includes('duplicate key name')
  );
}

export async function getDatabase(): Promise<Database> {
  if (!databasePromise) {
    databasePromise = (async () => {
      const { default: TauriDatabase } = await import('@tauri-apps/plugin-sql');
      const db = await TauriDatabase.load('sqlite:studytracker.db');
      await runMigrations(db as any);
      return db as any;
    })();
  }
  return databasePromise;
}

async function runMigrations(database: Database): Promise<void> {
  await database.execute('PRAGMA foreign_keys = ON');
  // WAL allows one writer + many readers concurrently, which kills 99% of
  // "database is locked" we get from the SQL plugin opening per-call connections.
  await database.execute('PRAGMA journal_mode = WAL');
  await database.execute('PRAGMA synchronous = NORMAL');
  // Wait up to 30s for the lock — sync apply + UI reads sometimes overlap.
  await database.execute('PRAGMA busy_timeout = 30000');
  await database.execute('PRAGMA wal_autocheckpoint = 1000');

  await database.execute(
    'CREATE TABLE IF NOT EXISTS _migrations (version INTEGER PRIMARY KEY, description TEXT NOT NULL, applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)'
  );
  const applied = await database.select<{ version: number }[]>(
    'SELECT version FROM _migrations ORDER BY version ASC'
  );
  const appliedVersions = new Set(applied.map((r) => r.version));

  for (const migration of migrations) {
    if (appliedVersions.has(migration.version)) {
      continue;
    }

    const statements = migration.sql
      .split(';')
      .map((statement) => statement.trim())
      .filter((statement) => statement.length > 0);

    for (let i = 0; i < statements.length; i++) {
      const stmt = statements[i];
      try {
        await database.execute(stmt);
      } catch (error) {
        if (isRecoverableMigrationError(error)) {
          continue;
        }
        throw error;
      }
    }

    await database.execute(
      'INSERT INTO _migrations (version, description) VALUES (?, ?)',
      [migration.version, migration.description]
    );
  }
}

export async function wipeDatabase(): Promise<void> {
  const db = await getDatabase();
  await db.execute('PRAGMA foreign_keys = OFF');
  try {
    const tables = [
      'study_sessions', 'session_tasks', 'subjects', 'subject_groups',
      'goals', 'mood_logs', 'ai_challenges', 'sync_state',
      'sync_history', 'profiles', 'app_settings'
    ];
    for (const table of tables) {
      await db.execute(`DELETE FROM ${table}`);
      try { await db.execute('DELETE FROM sqlite_sequence WHERE name = ?', [table]); } catch (_) { }
    }
    await db.execute(
      "INSERT INTO profiles (id, sync_id, name, academic_level, owner_device_id, created_at, updated_at) VALUES (1, 'profile-default', 'Default Profile', 'Undergraduate', 'shared', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    );
    await db.execute("INSERT INTO app_settings (key, value, updated_at) VALUES ('currentProfileId', '1', CURRENT_TIMESTAMP)");
  } finally {
    await db.execute('PRAGMA foreign_keys = ON');
  }
}