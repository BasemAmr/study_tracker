import { getDatabase } from '../data/database';
import { getSettingByKey, setSettingByKey } from '../data/repositories/appSettingsRepository';

let _cachedDeviceId: string | null = null;

function _generateDeviceId(): string {
  // RFC4122-ish v4 UUID for stable local device identity.
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

export async function getDeviceId(): Promise<string> {
  if (_cachedDeviceId) return _cachedDeviceId;
  const row = await getSettingByKey('syncDeviceId');

  const existing = row?.value?.trim();
  if (existing && existing.toLowerCase() !== 'unknown') {
    _cachedDeviceId = existing;
    return _cachedDeviceId;
  }

  const generated = _generateDeviceId();
  await setSettingByKey('syncDeviceId', generated);
  _cachedDeviceId = generated;
  console.log(`SYNC: [Identity] Generated missing syncDeviceId: ${generated}`);
  return _cachedDeviceId;
}

export async function getDeviceName(): Promise<string> {
  const row = await getSettingByKey('syncDeviceName');
  return row?.value ?? 'My Device';
}

export async function setDeviceName(name: string): Promise<void> {
  await setSettingByKey('syncDeviceName', name.trim() || 'My Device');
}

export async function savePeerPairingCode(peerDeviceId: string, pairingCode: string): Promise<void> {
  if (pairingCode) {
    await setSettingByKey(`peer_code_${peerDeviceId}`, pairingCode);
  }
}

export async function getPeerPairingCode(peerDeviceId: string): Promise<string | null> {
  const row = await getSettingByKey(`peer_code_${peerDeviceId}`);
  return row?.value ?? null;
}

export async function initializeOwnership(): Promise<void> {
  const database = await getDatabase();
  const deviceId = await getDeviceId();

  // Only add column if missing (migration v8 normally adds it; avoid duplicate-column errors).
  const cols = await database.select<Array<{ name: string }>>('PRAGMA table_info(profiles)');
  const hasOwner = cols.some((c) => c.name === 'owner_device_id');
  if (!hasOwner) {
    await database.execute("ALTER TABLE profiles ADD COLUMN owner_device_id TEXT NOT NULL DEFAULT ''");
    console.log('SYNC: [Identity] Added missing owner_device_id column on profiles');
  }

  await database.execute(
    "UPDATE profiles SET owner_device_id = ? WHERE (owner_device_id = '' OR owner_device_id IS NULL) AND sync_id != 'profile-default'",
    [deviceId]
  );
  await database.execute(
    "UPDATE profiles SET owner_device_id = 'shared' WHERE sync_id = 'profile-default'"
  );
  console.log(`SYNC: [Identity] Ownership initialized for device: ${deviceId}`);
}
