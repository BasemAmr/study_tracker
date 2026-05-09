import { getDatabase } from '../database';
import type {
  AiChallenge,
  AiChallengeTier,
  AiChallengeDifficulty,
  AiChallengeMetric,
  AiChallengeStatus,
  AiMissionSubTargets
} from '../../domain';
import { getCurrentProfileId } from './profileRepository';

export const aiChallengeRepository = {
  async getAll(): Promise<AiChallenge[]> {
    const database = await getDatabase();
    await ensureTable(database);
    const profileId = await getCurrentProfileId();
    const rows = await database.select<any[]>(
      'SELECT * FROM ai_challenges WHERE profile_id = ? ORDER BY created_at DESC',
      [profileId]
    );
    return rows.map(mapRowToChallenge);
  },

  async getActiveByTier(tier: AiChallengeTier): Promise<AiChallenge | null> {
    const database = await getDatabase();
    await ensureTable(database);
    const profileId = await getCurrentProfileId();
    const rows = await database.select<any[]>(
      `SELECT * FROM ai_challenges
       WHERE profile_id = ? AND tier = ? AND completed = 0 AND status = 'active'
         AND expires_at > CURRENT_TIMESTAMP
       LIMIT 1`,
      [profileId, tier]
    );
    return rows.length > 0 ? mapRowToChallenge(rows[0]) : null;
  },

  /** Current slot mission even if `expires_at` is in the past (grace UI + manual refresh). */
  async getSlotChallengeForTier(tier: AiChallengeTier): Promise<AiChallenge | null> {
    const database = await getDatabase();
    await ensureTable(database);
    const profileId = await getCurrentProfileId();
    const rows = await database.select<any[]>(
      `SELECT * FROM ai_challenges
       WHERE profile_id = ? AND tier = ? AND completed = 0 AND status = 'active'
       ORDER BY datetime(created_at) DESC
       LIMIT 1`,
      [profileId, tier]
    );
    return rows.length > 0 ? mapRowToChallenge(rows[0]) : null;
  },

  async setChallengeStatus(id: string, status: AiChallengeStatus): Promise<void> {
    const database = await getDatabase();
    await ensureTable(database);
    const profileId = await getCurrentProfileId();
    await database.execute(
      `UPDATE ai_challenges SET status = ?, updated_at = CURRENT_TIMESTAMP
       WHERE id = ? AND profile_id = ?`,
      [status, id, profileId]
    );
  },

  async create(challenge: Partial<AiChallenge>): Promise<void> {
    const database = await getDatabase();
    await ensureTable(database);
    const profileId = await getCurrentProfileId();

    if (
      !challenge.id || !challenge.tier || !challenge.title || !challenge.description ||
      !challenge.icon || !challenge.metric || challenge.target === undefined ||
      !challenge.expiresAt || !challenge.difficulty || !challenge.rewardBadgeName ||
      !challenge.rewardBadgeIcon
    ) {
      throw new Error('Challenge payload is incomplete.');
    }

    const status: AiChallengeStatus = challenge.status ?? 'active';
    const subJson =
      challenge.subTargets != null ? JSON.stringify(challenge.subTargets) : null;
    const unitMin =
      challenge.unitMinMinutes !== undefined && challenge.unitMinMinutes !== null
        ? challenge.unitMinMinutes
        : null;

    await database.execute(
      `INSERT INTO ai_challenges (
        id, profile_id, tier, title, description, icon, metric, target,
        expires_at, difficulty, reward_badge_name, reward_badge_icon,
        raw_response, sub_targets_json, unit_min_minutes, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        challenge.id,
        profileId,
        challenge.tier,
        challenge.title,
        challenge.description,
        challenge.icon,
        challenge.metric,
        challenge.target,
        challenge.expiresAt,
        challenge.difficulty,
        challenge.rewardBadgeName,
        challenge.rewardBadgeIcon,
        challenge.rawResponse ?? null,
        subJson,
        unitMin,
        status
      ]
    );
  },

  async markCompleted(id: string): Promise<void> {
    const database = await getDatabase();
    await ensureTable(database);
    const profileId = await getCurrentProfileId();
    await database.execute(
      'UPDATE ai_challenges SET completed = 1, status = \'completed\', updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?',
      [id, profileId]
    );
  },

  async deleteActiveByTier(tier: AiChallengeTier): Promise<void> {
    const database = await getDatabase();
    await ensureTable(database);
    const profileId = await getCurrentProfileId();
    await database.execute(
      `UPDATE ai_challenges SET status = 'replaced', updated_at = CURRENT_TIMESTAMP
       WHERE profile_id = ? AND tier = ? AND status = 'active'`,
      [profileId, tier]
    );
  },

  async deleteExpired(): Promise<void> {
    const database = await getDatabase();
    await ensureTable(database);
    const profileId = await getCurrentProfileId();
    await database.execute(
      'DELETE FROM ai_challenges WHERE profile_id = ? AND expires_at <= CURRENT_TIMESTAMP AND completed = 0',
      [profileId]
    );
  }
};

async function ensureTable(database: Awaited<ReturnType<typeof getDatabase>>): Promise<void> {
  await database.execute(
    `CREATE TABLE IF NOT EXISTS ai_challenges (
      id TEXT PRIMARY KEY,
      profile_id INTEGER NOT NULL DEFAULT 1,
      tier TEXT NOT NULL CHECK(tier IN ('daily', 'weekly', 'monthly', 'surprise')),
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      icon TEXT NOT NULL,
      metric TEXT NOT NULL,
      target INTEGER NOT NULL,
      expires_at TEXT NOT NULL,
      difficulty TEXT NOT NULL,
      reward_badge_name TEXT NOT NULL,
      reward_badge_icon TEXT NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      raw_response TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )`
  );

  await database.execute('CREATE INDEX IF NOT EXISTS idx_ai_challenges_tier ON ai_challenges(tier)');
  await database.execute('CREATE INDEX IF NOT EXISTS idx_ai_challenges_profile_id ON ai_challenges(profile_id)');
  await database.execute('CREATE INDEX IF NOT EXISTS idx_ai_challenges_completed ON ai_challenges(completed)');
  await database.execute('CREATE INDEX IF NOT EXISTS idx_ai_challenges_expires_at ON ai_challenges(expires_at)');
}

function mapRowToChallenge(row: any): AiChallenge {
  const statusRaw = row.status as string | null | undefined;
  const status: AiChallengeStatus =
    statusRaw === 'completed' || statusRaw === 'expired' || statusRaw === 'replaced' || statusRaw === 'active'
      ? statusRaw
      : 'active';

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
    id: row.id,
    tier: row.tier as AiChallengeTier,
    title: row.title,
    description: row.description,
    icon: row.icon,
    metric: row.metric as AiChallengeMetric,
    target: row.target,
    expiresAt: row.expires_at,
    difficulty: row.difficulty as AiChallengeDifficulty,
    rewardBadgeName: row.reward_badge_name,
    rewardBadgeIcon: row.reward_badge_icon,
    completed: Boolean(row.completed),
    rawResponse: row.raw_response,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    subTargets: subTargets ?? null,
    unitMinMinutes: row.unit_min_minutes != null ? Number(row.unit_min_minutes) : null,
    status
  };
}
