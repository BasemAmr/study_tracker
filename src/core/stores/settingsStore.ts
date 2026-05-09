/** App settings store — persists to SQLite */

import { writable, get } from 'svelte/store';
import type { StructuredSettings } from '../domain';
import { fetchStructuredSettings, saveSettings } from '../services/settingsService';

const defaults: StructuredSettings = {
  dailyGoalMinutes: 120,
  focusMinutes: 25,
  breakMinutes: 5,
  themeMode: 'light',
  language: 'en',
  defaultSessionMode: 'pomodoro',
  currentProfileId: 1
};

const _settings = writable<StructuredSettings>({ ...defaults });
let loaded = false;

export const settings = {
  subscribe: _settings.subscribe,

  async load(): Promise<void> {
    if (loaded) return;
    try {
      const s = await fetchStructuredSettings();
      _settings.set(s);
      loaded = true;
    } catch (error) {
      console.error('[StudyTracker] Failed to load settings:', error);
      _settings.set({ ...defaults });
    }
  },

  async update(partial: Partial<StructuredSettings>): Promise<void> {
    const current = get(_settings);
    const updated = { ...current, ...partial };
    _settings.set(updated);

    const record: Record<string, string | number | boolean> = {};
    for (const [key, value] of Object.entries(partial)) {
      record[key] = value as string | number | boolean;
    }
    await saveSettings(record);
  },

  get(): StructuredSettings {
    return get(_settings);
  }
};
