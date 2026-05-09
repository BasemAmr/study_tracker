import type { AppSettingValue, StructuredSettings } from '../domain';
import { deleteSettingByKey, getSettingByKey, getStructuredSettings, listSettings, setSettingByKey, upsertSettings } from '../data/repositories';

export function fetchSetting(key: string) {
  return getSettingByKey(key);
}

export function saveSetting(key: string, value: AppSettingValue) {
  return setSettingByKey(key, value);
}

export function removeSetting(key: string) {
  return deleteSettingByKey(key);
}

export function fetchAllSettings() {
  return listSettings();
}

export function saveSettings(settings: Record<string, AppSettingValue>) {
  return upsertSettings(settings);
}

export function fetchStructuredSettings(): Promise<StructuredSettings> {
  return getStructuredSettings();
}
