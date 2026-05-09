import { getDatabase } from '../database';
import type { AppSetting, AppSettingValue, StructuredSettings, StudySessionMode, ThemeMode, Language } from '../../domain';

type AppSettingRow = { key: string; value: string; updated_at: string };

/** Base key name; store per profile as `profile.<profileId>.activeAiMissionId` (matches Flutter SettingsRepository scoping). */
export const ACTIVE_AI_MISSION_APP_SETTING_KEY = 'activeAiMissionId';

export function profileScopedAppSettingKey(profileId: number, baseKey: string): string {
  return `profile.${profileId}.${baseKey}`;
}

export async function getSettingByKey(key: string): Promise<AppSetting | null> {
  const database = await getDatabase();
  const rows = await database.select<AppSettingRow[]>('SELECT * FROM app_settings WHERE key = ? LIMIT 1;', [key]);
  return rows[0] ? mapSetting(rows[0]) : null;
}

export async function setSettingByKey(key: string, value: AppSettingValue): Promise<void> {
  const database = await getDatabase();
  const serialized = String(value);
  await database.execute(
    `INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP;`,
    [key, serialized]
  );
}

export async function deleteSettingByKey(key: string): Promise<void> {
  const database = await getDatabase();
  await database.execute('DELETE FROM app_settings WHERE key = ?;', [key]);
}

export async function listSettings(): Promise<AppSetting[]> {
  const database = await getDatabase();
  const rows = await database.select<AppSettingRow[]>('SELECT * FROM app_settings ORDER BY key ASC;');
  return rows.map(mapSetting);
}

export async function upsertSettings(settings: Record<string, AppSettingValue>): Promise<void> {
  for (const [key, value] of Object.entries(settings)) {
    await setSettingByKey(key, value);
  }
}

export async function getStructuredSettings(): Promise<StructuredSettings> {
  const [
    dailyGoalMinutes, focusMinutes, breakMinutes, themeMode,
    language, defaultSessionMode, defaultBackground, overlayOpacity,
    mediaPlaylistPath, mediaAutoplay, mediaVolume, displayName, currentProfileId,
    groqApiKey, aiChallengesEnabled
  ] = await Promise.all([
    getSettingValue('dailyGoalMinutes', '120'),
    getSettingValue('focusMinutes', '25'),
    getSettingValue('breakMinutes', '5'),
    getSettingValue('themeMode', 'light'),
    getSettingValue('language', 'en'),
    getSettingValue('defaultSessionMode', 'pomodoro'),
    getSettingValue('defaultBackground', '/backgrounds/city-twilight.png'),
    getSettingValue('overlayOpacity', '0.4'),
    getSettingValue('mediaPlaylistPath', ''),
    getSettingValue('mediaAutoplay', 'false'),
    getSettingValue('mediaVolume', '0.7'),
    getSettingValue('displayName', 'Bassem'),
    getSettingValue('currentProfileId', '1'),
    getSettingValue('groqApiKey', ''),
    getSettingValue('aiChallengesEnabled', 'false')
  ]);

  return {
    dailyGoalMinutes: Number(dailyGoalMinutes),
    focusMinutes: Number(focusMinutes),
    breakMinutes: Number(breakMinutes),
    themeMode: themeMode as ThemeMode,
    language: language as Language,
    defaultSessionMode: defaultSessionMode as StudySessionMode,
    defaultBackground,
    overlayOpacity: Number(overlayOpacity),
    mediaPlaylistPath,
    mediaAutoplay: mediaAutoplay === 'true',
    mediaVolume: Number(mediaVolume),
    displayName,
    currentProfileId: Number(currentProfileId),
    groqApiKey,
    aiChallengesEnabled: aiChallengesEnabled === 'true'
  };
}

async function getSettingValue(key: string, fallback: string): Promise<string> {
  const setting = await getSettingByKey(key);
  return setting?.value ?? fallback;
}

function mapSetting(row: AppSettingRow): AppSetting {
  return { key: row.key, value: row.value, updatedAt: row.updated_at };
}
