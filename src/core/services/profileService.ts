import type { Profile } from '../domain';
import {
  createProfile,
  deleteProfile,
  getCurrentProfileId,
  getProfileDeletionStats,
  listProfiles,
  setCurrentProfileId,
  updateProfile
} from '../data/repositories/profileRepository';

export async function saveProfile(profile: Profile): Promise<number> {
  if (profile.id) {
    await updateProfile(profile);
    return profile.id;
  }
  return createProfile(profile.name, profile.academicLevel);
}

export {
  listProfiles,
  deleteProfile,
  getCurrentProfileId,
  getProfileDeletionStats,
  setCurrentProfileId
};
