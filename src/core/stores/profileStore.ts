import { writable, derived, get } from 'svelte/store';
import type { Profile } from '../domain';
import { listProfiles, getCurrentProfileId, setCurrentProfileId } from '../data/repositories/profileRepository';

const _profiles = writable<Profile[]>([]);
const _activeProfileId = writable<number>(1);

export const profiles = {
  subscribe: _profiles.subscribe,
  async refresh() {
    const list = await listProfiles();
    _profiles.set(list);
  }
};

export const activeProfileId = {
  subscribe: _activeProfileId.subscribe,
  set: _activeProfileId.set
};

export const activeProfile = derived(
  [_profiles, _activeProfileId],
  ([$profiles, $activeProfileId]) => {
    return $profiles.find(p => p.id === $activeProfileId) || null;
  }
);

export const profileStore = {
  async init() {
    await profiles.refresh();
    const currentList = get(_profiles);
    const storedId = await getCurrentProfileId();
    const previousActiveId = get(_activeProfileId);

    let nextActiveId: number | null = null;
    if (!currentList.some(p => p.id === storedId)) {
      if (currentList.length > 0) {
        nextActiveId = currentList[0].id!;
        // Persist fallback so a hard refresh doesn't go back to the dead id.
        // currentProfileId is in NEVER_SYNC_SETTINGS so this is safe.
        await setCurrentProfileId(nextActiveId);
      }
    } else {
      nextActiveId = storedId;
    }

    if (nextActiveId !== null) {
      _activeProfileId.set(nextActiveId);
      if (previousActiveId !== nextActiveId) {
        window.dispatchEvent(new CustomEvent('profile-switched', { detail: { profileId: nextActiveId } }));
      }
    }
  },

  async switchProfile(id: number) {
    await setCurrentProfileId(id);
    _activeProfileId.set(id);
    // Notify other parts of the app if needed
    window.dispatchEvent(new CustomEvent('profile-switched', { detail: { profileId: id } }));
  },

  async createNewProfile(name: string, academicLevel: string = 'Undergraduate') {
    const { createProfile } = await import('../data/repositories/profileRepository');
    const newId = await createProfile(name, academicLevel);
    await profiles.refresh();
    await this.switchProfile(newId);
    return newId;
  },

  async deleteProfile(id: number) {
    const { deleteProfile } = await import('../data/repositories/profileRepository');
    await deleteProfile(id);
    await profiles.refresh();
    await this.init(); // Refresh active profile if changed
  }
};
