/** Sentinel `owner_device_id` for `profile-default` — not a real device UUID (LAN sync spec). */
export const PROFILE_OWNER_SHARED_SENTINEL = 'shared';

/** Ownership is display-only. It must not gate profile edits or deletes. */
export function getProfileOwnershipBadge(
  ownerDeviceId: string | undefined | null,
  myDeviceId: string,
  syncId?: string | null,
): 'SHARED' | 'MY DEVICE' | 'SYNCED' {
  if (syncId === 'profile-default') return 'SHARED';
  const od = (ownerDeviceId ?? '').trim();
  if (od === PROFILE_OWNER_SHARED_SENTINEL) return 'SHARED';
  if (!od || od === myDeviceId) return 'MY DEVICE';
  return 'SYNCED';
}
