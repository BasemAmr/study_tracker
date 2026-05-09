# Database Schema Alignment Scratch Analysis (2026-04-23)

## 1) LOCATE Phase — Full Schema + Access Map

### A. Svelte/Tauri schema source
- `src/core/data/schema.ts` defines additive SQL migrations v1-v3.
- `src/core/data/database.ts` runs migrations using `_migrations` table and `PRAGMA foreign_keys = ON`.
- DB file is `sqlite:studytracker.db` via Tauri SQL plugin.

### B. Flutter/Drift schema source
- `study_tracker_flutter/lib/data/db/tables.dart` defines table models.
- `study_tracker_flutter/lib/data/db/database.dart` defines `schemaVersion = 3` and additive `onUpgrade` logic.
- DB file is `study_tracker.sqlite` in app documents directory.

---

## 2) Table-by-table map

### Svelte tables (from `schema.ts`)
1. `_migrations`
- Columns: `version INTEGER PK`, `description TEXT`, `applied_at TEXT`.
- Reads: `database.ts` (`SELECT version ...`).
- Writes: `database.ts` (`INSERT INTO _migrations ...`).

2. `subjects`
- Columns: `id INTEGER PK AUTOINCREMENT`, `name TEXT UNIQUE`, `color TEXT`, `created_at TEXT`, `group_id INTEGER NULL` (added v2).
- Reads: `subjectRepository.ts` (`getSubjectById`, `getSubjectByName`, `listSubjects`, `listSubjectsByGroupId`).
- Writes: `subjectRepository.ts` (`createSubject`, `updateSubject`, `deleteSubject`, `assignSubjectToGroup`).

3. `study_sessions`
- Columns: `id INTEGER PK AUTOINCREMENT`, `start_at`, `end_at`, `duration_minutes`, `subject_id`, `subject_name`, `topic`, `chapter_tag`, `mood`, `notes`, `mode`, `break_minutes`, `background_image` (v2), `created_at`, `updated_at`.
- Reads: `sessionRepository.ts` (`getSessionById`, `listSessions`, `getSessionSummary`).
- Writes: `sessionRepository.ts` (`createSession`, `updateSession`, `deleteSession`).

4. `session_tasks`
- Columns: `id INTEGER PK AUTOINCREMENT`, `session_id`, `title`, `completed`, `created_at`.
- Reads: `sessionTaskRepository.ts` (`listSessionTasksBySessionId`).
- Writes: `sessionTaskRepository.ts` (`createSessionTask`, `updateSessionTask`, `deleteSessionTask`, `markSessionTaskComplete`, `replaceSessionTasks`).

5. `app_settings`
- Columns: `key TEXT PK`, `value TEXT`, `updated_at TEXT`.
- Reads: `appSettingsRepository.ts` (`getSettingByKey`, `listSettings`, `getStructuredSettings`).
- Writes: `appSettingsRepository.ts` (`setSettingByKey`, `deleteSettingByKey`, `upsertSettings`).

6. `goals`
- Columns: `id INTEGER PK AUTOINCREMENT`, `name`, `target_minutes`, `active`, `created_at`, `updated_at`.
- Reads: `goalRepository.ts` (`getGoalById`, `listGoals`, `getActiveGoals`).
- Writes: `goalRepository.ts` (`createGoal`, `updateGoal`, `deleteGoal`, `setGoalActive`).

7. `mood_logs`
- Columns: `id INTEGER PK AUTOINCREMENT`, `session_id`, `mood`, `note`, `created_at`.
- Reads: `moodLogRepository.ts` (`getMoodLogById`, `listMoodLogs`, `listMoodLogsBySessionId`, `getRecentMoodLogs`).
- Writes: `moodLogRepository.ts` (`createMoodLog`, `updateMoodLog`, `deleteMoodLog`).

8. `subject_groups`
- Columns: `id INTEGER PK AUTOINCREMENT`, `name`, `color`, `created_at`.
- Reads: `subjectGroupRepository.ts` (`listSubjectGroups`, `getSubjectGroupById`).
- Writes: `subjectGroupRepository.ts` (`createSubjectGroup`, `updateSubjectGroup`, `deleteSubjectGroup`).

9. `ai_challenges`
- Columns: `id TEXT PK`, `tier`, `title`, `description`, `icon`, `metric`, `target`, `expires_at`, `difficulty`, `reward_badge_name`, `reward_badge_icon`, `completed`, `raw_response`, `created_at`, `updated_at`.
- Reads: `aiChallengeRepository.ts` (`getAll`, `getActiveByTier`).
- Writes: `aiChallengeRepository.ts` (`create`, `markCompleted`, `deleteExpired`, `ensureTable`).

### Flutter tables (from `tables.dart`)
1. `profiles`
- Columns: `id INTEGER PK AUTOINCREMENT`, `name TEXT`, `academic_level TEXT`, `created_at DATETIME`, `updated_at DATETIME`.
- Reads: `settings_repository.dart` (`listProfiles`).
- Writes: `settings_repository.dart` (`createProfile`, `updateProfile`, `deleteProfile`), migration bootstrap in `database.dart`.

2. `study_sessions`
- Columns: all Svelte session concept columns + `profile_id INTEGER`.
- Reads: `session_repository.dart` (`getById`, `list`, `watchAllSessions`, `watchRecentSessions`, summary custom SQL).
- Writes: `session_repository.dart` (`create`, `update`, `delete`).

3. `session_tasks`
- Columns: Svelte-like + `profile_id INTEGER`, `completed BOOLEAN`.
- Reads: `session_repository.dart` (`_getTasksForSession`).
- Writes: `session_repository.dart` (`create` inserts tasks).

4. `subjects`
- Columns: Svelte-like + `profile_id INTEGER`, unique key `(profile_id, name)`.
- Reads: `subject_repository.dart` (`listAll`, `getById`), `session_repository.dart` (group filter lookup).
- Writes: `subject_repository.dart` (`createSubject`, `updateSubject`, `deleteSubject`).

5. `subject_groups`
- Columns: Svelte-like + `profile_id INTEGER`, unique key `(profile_id, name)`.
- Reads: `subject_repository.dart` (`listGroups`).
- Writes: `subject_repository.dart` (`createGroup`, `updateGroup`, `deleteGroup`).

6. `app_settings`
- Columns: `key TEXT PK`, `value TEXT`, `updated_at DATETIME`.
- Reads: `settings_repository.dart`, plus active profile lookup in `session_repository.dart`, `subject_repository.dart`, `ai_challenge_repository.dart`.
- Writes: `settings_repository.dart`.

7. `goals`
- Columns: Svelte-like + `profile_id INTEGER`, `active BOOLEAN`.
- Reads/Writes: no dedicated repository currently (table exists, not actively used in current Flutter repositories).

8. `mood_logs`
- Columns: Svelte-like + `profile_id INTEGER`.
- Reads/Writes: no dedicated repository currently (table exists, not actively used in current Flutter repositories).

9. `ai_challenges`
- Columns: Svelte-like + `profile_id INTEGER`, `completed BOOLEAN`.
- Reads/Writes: `ai_challenge_repository.dart` (`getAll`, `watchAll`, `getById`, `getActiveByTier`, `create`, `markCompleted`, `deleteActiveByTier`).

---

## 3) Naming/type alignment notes

### Same concept, different naming/type
- `profile_id` exists in Flutter user-data tables, missing in Svelte. (multi-profile partitioning)
- Boolean storage differs:
  - Svelte SQLite schema stores booleans as `INTEGER` (`0/1`) in several tables.
  - Flutter Drift uses typed `BOOL` columns mapped to sqlite integer underneath.
- Timestamp type declaration differs:
  - Svelte uses `TEXT` timestamps.
  - Flutter declares `DateTimeColumn` (stored as sqlite text/integer via Drift mapping).
- Settings key naming differs in value space (not table schema), e.g. `language` vs `languageCode` defaults.

### Tables present in one app but not the other
- Flutter only: `profiles` table.
- Svelte only: `_migrations` table (Flutter uses Drift migration strategy metadata, not this table).

---

## 4) DIFF Phase classification

### SAFE
1. Flutter `profiles` + `profile_id` partitioning (Flutter evolved to multi-profile). Safe for now; not required for Svelte unless product adds profiles there.
2. Migration bookkeeping implementation difference (`_migrations` table vs Drift strategy internals).

### DRIFT (must resolve)
1. Sync-readiness drift: most user-generated tables in both apps rely on autoincrement integer primary key only (no stable cross-device row identifier).
2. Sync-readiness drift: some user-generated tables lack explicit last-modified timestamp.

### MISSING (must add)
1. Stable row identifier column for user-generated tables lacking one.
2. Last-modified timestamp column for user-generated tables lacking one.

---

## 5) IMPACT Phase (blast radius for DRIFT/MISSING)

### Svelte affected tables and callsites
- `subjects`: `subjectRepository.ts`, `subjectService.ts`, settings/session UI via service calls.
- `study_sessions`: `sessionRepository.ts`, `sessionService.ts`, dashboard/analytics/achievements/session UI via service calls.
- `session_tasks`: `sessionTaskRepository.ts` (called by session flows).
- `goals`: `goalRepository.ts`, `goalService.ts`, settings/dashboard goal views.
- `mood_logs`: `moodLogRepository.ts`, `moodLogService.ts`.
- `subject_groups`: `subjectGroupRepository.ts`, `subjectService.ts`, settings grouped subjects UI.
- `ai_challenges`: `aiChallengeRepository.ts`, `aiChallengeService.ts`.

### Flutter affected tables and callsites
- `profiles`: `settings_repository.dart` profile CRUD, profile selection logic in settings/app_settings.
- `study_sessions` + `session_tasks`: `session_repository.dart` all CRUD/list/watch/summary/task insert paths.
- `subjects` + `subject_groups`: `subject_repository.dart` + session group filtering.
- `app_settings`: `settings_repository.dart` and active profile lookups in repositories.
- `goals` + `mood_logs`: schema currently present with minimal direct callsites.
- `ai_challenges`: `ai_challenge_repository.dart` all CRUD/watch paths.

---

## 6) Migration safety pre-check
- Svelte migration engine is additive and versioned; no create-or-replace behavior found.
- Flutter Drift migration uses `onUpgrade` additive SQL/custom statements; no DB reset path found.
- Existing data preservation requirement can be met by additive `ALTER TABLE ... ADD COLUMN` with backfill/defaults.

## 7) Planned edit order (low to high blast radius)
1. Add sync columns for least-used tables first (`goals`, `mood_logs`, `subject_groups`, `session_tasks`).
2. Add sync columns for high-traffic tables (`subjects`, `study_sessions`).
3. Align `ai_challenges` and `profiles` where needed.
4. Update repository writes for `updated_at` mutation behavior where table now supports it.
5. Run static analysis (`svelte-check`, flutter analyze) and fix all touched-file errors.
