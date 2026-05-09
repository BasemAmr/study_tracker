import { getDatabase } from '../database';
import type {
  AiChallengeCloseReason,
  AiChallengeHistoryEntry,
  AiChallengeMetric,
  AiChallengeTier,
  AiMissionSubTargets,
  NewAiChallengeHistoryEntry
} from '../../domain';
import { getCurrentProfileId } from './profileRepository';

export const aiChallengeHistoryRepository = {
  async create(entry: NewAiChallengeHistoryEntry): Promise<void> {
    const database = await getDatabase();
    const profileId = await getCurrentProfileId();
    if (entry.profileId !== profileId) {
      throw new Error('History entry profile_id does not match active profile.');
    }

    const subJson = entry.subTargets != null ? JSON.stringify(entry.subTargets) : null;
    const unitMin =
      entry.unitMinMinutes !== undefined && entry.unitMinMinutes !== null
        ? entry.unitMinMinutes
        : null;

    await database.execute(
      `INSERT INTO ai_challenge_history (
        profile_id, tier, title, description, metric, target, progress_at_close,
        close_reason, closed_at, original_created_at, original_expires_at,
        sub_targets_json, unit_min_minutes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        entry.profileId,
        entry.tier,
        entry.title,
        entry.description,
        entry.metric,
        entry.target,
        entry.progressAtClose,
        entry.closeReason,
        entry.closedAt,
        entry.originalCreatedAt,
        entry.originalExpiresAt,
        subJson,
        unitMin
      ]
    );
  },

  async getRecent(tier: AiChallengeTier, limit = 50): Promise<AiChallengeHistoryEntry[]> {
    const database = await getDatabase();
    const profileId = await getCurrentProfileId();
    const rows = await database.select<any[]>(
      `SELECT * FROM ai_challenge_history
       WHERE profile_id = ? AND tier = ?
       ORDER BY closed_at DESC
       LIMIT ?`,
      [profileId, tier, limit]
    );
    return rows.map(mapHistoryRow);
  },

  async pruneOldestBeyondLimit(tier: AiChallengeTier, limit = 50): Promise<void> {
    const database = await getDatabase();
    const profileId = await getCurrentProfileId();
    await database.execute(
      `DELETE FROM ai_challenge_history
       WHERE id IN (
         SELECT id FROM (
           SELECT id,
                  ROW_NUMBER() OVER (
                    PARTITION BY profile_id, tier
                    ORDER BY closed_at DESC
                  ) AS rn
           FROM ai_challenge_history
           WHERE profile_id = ? AND tier = ?
         ) AS ranked
         WHERE rn > ?
       )`,
      [profileId, tier, limit]
    );
  }
};

function mapHistoryRow(row: any): AiChallengeHistoryEntry {
  const closeRaw = row.close_reason as string;
  const closeReason: AiChallengeCloseReason =
    closeRaw === 'replaced' || closeRaw === 'expired' || closeRaw === 'completed'
      ? closeRaw
      : 'completed';

  let subTargets: AiMissionSubTargets | null | undefined;
  const st = row.sub_targets_json;
  if (typeof st === 'string' && st.trim().length > 0) {
    try {
      const parsed = JSON.parse(st) as AiMissionSubTargets;
      if (parsed && typeof parsed.mode === 'string' && typeof parsed.count === 'number') {
        subTargets = parsed;
      }
    } catch {
      subTargets = null;
    }
  }

  return {
    id: Number(row.id),
    profileId: Number(row.profile_id),
    tier: row.tier as AiChallengeTier,
    title: row.title,
    description: row.description,
    metric: row.metric as AiChallengeMetric,
    target: Number(row.target),
    progressAtClose: Number(row.progress_at_close),
    closeReason,
    closedAt: row.closed_at,
    originalCreatedAt: row.original_created_at,
    originalExpiresAt: row.original_expires_at,
    subTargets: subTargets ?? null,
    unitMinMinutes: row.unit_min_minutes != null ? Number(row.unit_min_minutes) : null
  };
}
