import { aiChallengeRepository } from '../data/repositories/aiChallengeRepository';
import { aiChallengeHistoryRepository } from '../data/repositories/aiChallengeHistoryRepository';
import { listSessions } from '../data/repositories';
import { chatCompletion } from './groqClient';
import { buildThirtyDayWeakSpotSummary } from './studySignalsForAi';
import { settings as settingsStore } from '../stores/settingsStore';
import { toasts } from '../stores/toastStore';
import type {
  AiChallenge,
  AiChallengeCloseReason,
  AiChallengeTier,
  AiMissionSubTargets,
  NewAiChallengeHistoryEntry
} from '../domain';
import {
  getAiFeaturesOrDefault,
  getForProfile as getAiFeatureSettings
} from '../data/repositories/aiFeatureSettingsRepository';
import { getCurrentProfileId } from '../data/repositories/profileRepository';
import {
  getSettingByKey,
  setSettingByKey,
  deleteSettingByKey,
  profileScopedAppSettingKey,
  ACTIVE_AI_MISSION_APP_SETTING_KEY
} from '../data/repositories/appSettingsRepository';

// ─── Failure contract ────────────────────────────────────────────────────────

export type AiChallengeErrorReason =
  | 'feature-disabled'
  | 'no-key'
  | 'network'
  | 'parse'
  | `http-${number}`;

export type AiChallengeError = {
  reason: AiChallengeErrorReason;
  aiToggleEnabled: boolean;
  apiKeyPresent: boolean;
};

export type AiChallengeResult =
  | { ok: true; challenge: AiChallenge }
  | { ok: false; error: AiChallengeError };

const THREE_HOURS_MS = 3 * 60 * 60 * 1000;
const _renewalInFlight = new Set<string>();

// ─── Progress types ──────────────────────────────────────────────────────────

export type SubjectProgressEntry = {
  subjectId: number;
  subjectName?: string | null;
  minutes: number;
  completed: boolean;
};

export type ChallengeProgress = {
  current: number;
  target: number;
  percent: number;
  /** Only present for any-subjects multi-progress missions. */
  subjectBreakdown?: SubjectProgressEntry[];
};

// ─── Groq response shape ─────────────────────────────────────────────────────

interface GroqChallengePayload {
  id: string;
  tier: AiChallengeTier;
  title: string;
  description: string;
  icon: string;
  metric: string;
  target: number;
  expiresInHours: number;
  difficulty: string;
  reward: { badgeName: string; badgeIcon: string };
  subTargets?: AiMissionSubTargets | null;
  unitMinMinutes?: number | null;
}

// ─── Service ─────────────────────────────────────────────────────────────────

export const aiChallengeService = {
  /**
   * Orchestrates challenge fetching for all tiers based on time thresholds.
   * Auto-refresh never substitutes a mission on failure — it simply skips.
   */
  async checkAndRefreshChallenges(): Promise<void> {
    const settings = settingsStore.get();
    if (!settings.aiChallengesEnabled) return;

    const now = new Date();

    if (_shouldRefresh(settings.lastFetchDaily, now, 24)) {
      await _autoRefreshTier('daily');
      settingsStore.update({ lastFetchDaily: now.toISOString() });
    }

    if (_shouldRefresh(settings.lastFetchWeekly, now, 24 * 7)) {
      await _autoRefreshTier('weekly');
      settingsStore.update({ lastFetchWeekly: now.toISOString() });
    }

    if (_shouldRefresh(settings.lastFetchMonthly, now, 24 * 30)) {
      await _autoRefreshTier('monthly');
      settingsStore.update({ lastFetchMonthly: now.toISOString() });
    }

    const activeSurprise = await aiChallengeRepository.getActiveByTier('surprise');
    if (!activeSurprise && Math.random() < 0.15) {
      await _autoRefreshTier('surprise');
    }

    window.dispatchEvent(new CustomEvent('ai-challenges-updated'));
  },

  /**
   * User-initiated per-card refresh.
   * Destructive-replace guard: old mission stays intact until the API succeeds.
   * Returns a Result so callers can render an appropriate error toast.
   */
  async refreshTierNow(tier: AiChallengeTier): Promise<AiChallengeResult> {
    const existing = await aiChallengeRepository.getSlotChallengeForTier(tier);

    const result = await _fetchFromGroq(tier);
    if (!result.ok) {
      const profileId = await getCurrentProfileId();
      await _persistTierFailure(profileId, tier, result.error);
      return result;
    }

    const profileId = await getCurrentProfileId();
    await _clearTierFailure(profileId, tier);

    // API succeeded — snapshot the old mission before destroying it.
    if (existing) {
      const progress = await aiChallengeService.calculateProgress(existing);
      await _snapshotToHistory(existing, 'replaced', progress.current, profileId);
      await aiChallengeRepository.deleteActiveByTier(tier);
    }

    const payload = result.challenge;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + payload.expiresInHours * 3600 * 1000);

    await aiChallengeRepository.create({
      id: payload.id,
      tier: payload.tier,
      title: payload.title,
      description: payload.description,
      icon: payload.icon,
      metric: payload.metric as AiChallenge['metric'],
      target: payload.target,
      expiresAt: expiresAt.toISOString(),
      difficulty: payload.difficulty as AiChallenge['difficulty'],
      rewardBadgeName: payload.reward.badgeName,
      rewardBadgeIcon: payload.reward.badgeIcon,
      rawResponse: JSON.stringify(payload),
      subTargets: payload.subTargets ?? null,
      unitMinMinutes: payload.unitMinMinutes ?? null,
      status: 'active'
    });

    window.dispatchEvent(new CustomEvent('ai-challenges-updated'));

    const created = await aiChallengeRepository.getActiveByTier(tier);
    return { ok: true, challenge: created! };
  },

  /**
   * Progress calculation.
   *
   * Key invariant: only sessions with startAt STRICTLY AFTER challenge.createdAt
   * count. This ensures a freshly created mission begins from a clean slate even
   * if older sessions exist for the same period.
   */
  async calculateProgress(challenge: AiChallenge): Promise<ChallengeProgress> {
    if (challenge.completed) {
      return { current: challenge.target, target: challenge.target, percent: 100 };
    }

    const createdAt = challenge.createdAt ?? challenge.expiresAt; // fallback: never matches
    const sessions = await listSessions({
      startFrom: createdAt,
      startTo: challenge.expiresAt,
      limit: 10000
    });

    // Strict window: exclude sessions whose startAt equals createdAt exactly.
    const windowSessions = sessions.filter((s) => s.startAt > createdAt);

    const sub = challenge.subTargets;
    if (sub?.mode === 'any-subjects') {
      return _calcMultiSubjectProgress(windowSessions, sub, challenge.target);
    }

    const unitFloor = challenge.unitMinMinutes ?? null;
    let current = 0;

    switch (challenge.metric) {
      case 'minutes':
        current = windowSessions.reduce((sum, s) => sum + s.durationMinutes, 0);
        break;
      case 'sessions':
        // Apply unit floor for sessions metric when set.
        current = unitFloor != null
          ? windowSessions.filter((s) => s.durationMinutes >= unitFloor).length
          : windowSessions.length;
        break;
      case 'subjects':
        current = new Set(windowSessions.map((s) => s.subjectId).filter((id) => id != null)).size;
        break;
      case 'pomodoros':
        current = windowSessions.filter((s) => {
          if (s.mode !== 'pomodoro') return false;
          // Unit floor: skip pomodoros shorter than the configured minimum.
          return unitFloor == null || s.durationMinutes >= unitFloor;
        }).length;
        break;
      case 'streak':
        current = new Set(windowSessions.map((s) => s.startAt.split('T')[0])).size;
        break;
    }

    const percent = Math.min(Math.round((current / challenge.target) * 100), 100);

    if (percent >= 100 && !challenge.completed) {
      await aiChallengeRepository.markCompleted(challenge.id);
      toasts.success(`Challenge Completed: ${challenge.title}!`);
    }

    return { current, target: challenge.target, percent };
  },

  // ── Active mission pin ─────────────────────────────────────────────────────

  async getActiveAiMissionId(profileId: number): Promise<string | null> {
    const key = profileScopedAppSettingKey(profileId, ACTIVE_AI_MISSION_APP_SETTING_KEY);
    const setting = await getSettingByKey(key);
    return setting?.value ?? null;
  },

  async setActiveAiMissionId(profileId: number, missionId: string): Promise<void> {
    const key = profileScopedAppSettingKey(profileId, ACTIVE_AI_MISSION_APP_SETTING_KEY);
    await setSettingByKey(key, missionId);
  },

  async clearActiveAiMissionId(profileId: number): Promise<void> {
    const key = profileScopedAppSettingKey(profileId, ACTIVE_AI_MISSION_APP_SETTING_KEY);
    await deleteSettingByKey(key);
  },

  /**
   * Resolves the pinned active mission. If the pinned mission no longer exists,
   * is expired, or has a non-active status, the pin is auto-cleared and null is returned.
   */
  async resolveActiveMission(profileId: number): Promise<AiChallenge | null> {
    const missionId = await aiChallengeService.getActiveAiMissionId(profileId);
    if (!missionId) return null;

    const all = await aiChallengeRepository.getAll();
    const mission = all.find((c) => c.id === missionId);

    if (!mission || mission.status !== 'active') {
      await aiChallengeService.clearActiveAiMissionId(profileId);
      return null;
    }

    // Time-expired but within 3h grace (still `status=active`): keep pin until auto-renew flips status.
    const expMs = new Date(mission.expiresAt).getTime();
    const nowMs = Date.now();
    if (nowMs > expMs && nowMs - expMs > THREE_HOURS_MS) {
      await aiChallengeService.clearActiveAiMissionId(profileId);
      return null;
    }

    return mission;
  },

  /**
   * T5: scan missions on AI tab open — long-expired slots snapshot + auto-renew once.
   */
  async processExpiredMissionsOnTabOpen(): Promise<void> {
    const all = await aiChallengeRepository.getAll();
    const nowMs = Date.now();
    const profileId = await getCurrentProfileId();

    for (const c of all) {
      if (c.completed || c.status !== 'active') continue;
      const expMs = new Date(c.expiresAt).getTime();
      if (expMs >= nowMs) continue;
      const since = nowMs - expMs;
      if (since <= THREE_HOURS_MS) continue;
      if (_renewalInFlight.has(c.id)) continue;
      _renewalInFlight.add(c.id);
      try {
        const progress = await aiChallengeService.calculateProgress(c);
        await _snapshotToHistory(c, 'expired', progress.current, profileId);
        const result = await _fetchFromGroq(c.tier);
        if (result.ok) {
          await _clearTierFailure(profileId, c.tier);
          await aiChallengeRepository.setChallengeStatus(c.id, 'expired');
          const payload = result.challenge;
          const now = new Date();
          const expiresAt = new Date(now.getTime() + payload.expiresInHours * 3600 * 1000);
          await aiChallengeRepository.create({
            id: payload.id,
            tier: payload.tier,
            title: payload.title,
            description: payload.description,
            icon: payload.icon,
            metric: payload.metric as AiChallenge['metric'],
            target: payload.target,
            expiresAt: expiresAt.toISOString(),
            difficulty: payload.difficulty as AiChallenge['difficulty'],
            rewardBadgeName: payload.reward.badgeName,
            rewardBadgeIcon: payload.reward.badgeIcon,
            rawResponse: JSON.stringify(payload),
            subTargets: payload.subTargets ?? null,
            unitMinMinutes: payload.unitMinMinutes ?? null,
            status: 'active'
          });
          await _maybeClearPinForMission(profileId, c.id);
        } else {
          await _persistTierFailure(profileId, c.tier, result.error);
          await aiChallengeRepository.setChallengeStatus(c.id, 'expired');
          await _maybeClearPinForMission(profileId, c.id);
          toasts.error(formatAiChallengeErrorToast(result.error));
        }
        window.dispatchEvent(new CustomEvent('ai-challenges-updated'));
      } finally {
        _renewalInFlight.delete(c.id);
      }
    }
  },

  async getTierFailure(profileId: number, tier: AiChallengeTier): Promise<AiChallengeError | null> {
    return _readTierFailure(profileId, tier);
  }
};

export function tierFailureStorageKey(profileId: number, tier: AiChallengeTier): string {
  return profileScopedAppSettingKey(profileId, `aiMissionTierFailure.${tier}`);
}

export function formatAiChallengeErrorToast(err: AiChallengeError): string {
  const t = err.aiToggleEnabled ? 'on' : 'off';
  const k = err.apiKeyPresent ? 'present' : 'missing';
  return `Mission refresh failed (${err.reason}). AI challenges: ${t}, API key: ${k}.`;
}

async function _persistTierFailure(
  profileId: number,
  tier: AiChallengeTier,
  error: AiChallengeError
): Promise<void> {
  await setSettingByKey(tierFailureStorageKey(profileId, tier), JSON.stringify(error));
}

async function _clearTierFailure(profileId: number, tier: AiChallengeTier): Promise<void> {
  await deleteSettingByKey(tierFailureStorageKey(profileId, tier));
}

async function _readTierFailure(
  profileId: number,
  tier: AiChallengeTier
): Promise<AiChallengeError | null> {
  const row = await getSettingByKey(tierFailureStorageKey(profileId, tier));
  if (!row?.value) return null;
  try {
    const o = JSON.parse(row.value) as AiChallengeError;
    if (o && typeof o.reason === 'string') return o;
  } catch {
    /* ignore corrupt rows */
  }
  return null;
}

async function _maybeClearPinForMission(profileId: number, missionId: string): Promise<void> {
  const pinned = await aiChallengeService.getActiveAiMissionId(profileId);
  if (pinned === missionId) await aiChallengeService.clearActiveAiMissionId(profileId);
}

// ─── Snapshot helper ──────────────────────────────────────────────────────────

/**
 * Records a closed challenge into ai_challenge_history and prunes oldest
 * beyond the per-tier 50-entry cap. Called on refresh (replaced) and
 * expiry/completion paths (T5/T6 will wire those).
 */
async function _snapshotToHistory(
  challenge: AiChallenge,
  reason: AiChallengeCloseReason,
  progressAtClose: number,
  profileId: number
): Promise<void> {
  const entry: NewAiChallengeHistoryEntry = {
    profileId,
    tier: challenge.tier,
    title: challenge.title,
    description: challenge.description,
    metric: challenge.metric,
    target: challenge.target,
    progressAtClose,
    closeReason: reason,
    closedAt: new Date().toISOString(),
    originalCreatedAt: challenge.createdAt ?? new Date().toISOString(),
    originalExpiresAt: challenge.expiresAt,
    subTargets: challenge.subTargets ?? null,
    unitMinMinutes: challenge.unitMinMinutes ?? null
  };
  await aiChallengeHistoryRepository.create(entry);
  await aiChallengeHistoryRepository.pruneOldestBeyondLimit(challenge.tier, 50);
}

// ─── Multi-subject progress ───────────────────────────────────────────────────

function _calcMultiSubjectProgress(
  sessions: Awaited<ReturnType<typeof listSessions>>,
  sub: AiMissionSubTargets,
  overallTarget: number
): ChallengeProgress {
  const minutesPerSubject = sub.minutesPerSubject ?? 1;
  const requiredCount = sub.count;

  // Accumulate minutes per subject.
  const bySubject = new Map<number, { name: string | null | undefined; minutes: number }>();
  for (const s of sessions) {
    if (s.subjectId == null) continue;
    const existing = bySubject.get(s.subjectId);
    if (existing) {
      existing.minutes += s.durationMinutes;
    } else {
      bySubject.set(s.subjectId, { name: s.subjectName, minutes: s.durationMinutes });
    }
  }

  // Sort descending by minutes, take top N.
  const sorted = [...bySubject.entries()].sort((a, b) => b[1].minutes - a[1].minutes);
  const top = sorted.slice(0, requiredCount);

  const breakdown: SubjectProgressEntry[] = top.map(([id, data]) => ({
    subjectId: id,
    subjectName: data.name,
    minutes: data.minutes,
    completed: data.minutes >= minutesPerSubject
  }));

  const completedCount = breakdown.filter((e) => e.completed).length;
  const percent = Math.min(Math.round((completedCount / requiredCount) * 100), 100);

  return {
    current: completedCount,
    target: overallTarget,
    percent,
    subjectBreakdown: breakdown
  };
}

// ─── Auto-refresh (silent, no user-facing error) ──────────────────────────────

async function _autoRefreshTier(tier: AiChallengeTier): Promise<void> {
  const existing = await aiChallengeRepository.getActiveByTier(tier);
  if (existing) return;

  const result = await _fetchFromGroq(tier);
  if (!result.ok) return; // silent skip on failure — no toast

  const payload = result.challenge;
  const now = new Date();
  const expiresAt = new Date(now.getTime() + payload.expiresInHours * 3600 * 1000);

  await aiChallengeRepository.create({
    id: payload.id,
    tier: payload.tier,
    title: payload.title,
    description: payload.description,
    icon: payload.icon,
    metric: payload.metric as AiChallenge['metric'],
    target: payload.target,
    expiresAt: expiresAt.toISOString(),
    difficulty: payload.difficulty as AiChallenge['difficulty'],
    rewardBadgeName: payload.reward.badgeName,
    rewardBadgeIcon: payload.reward.badgeIcon,
    rawResponse: JSON.stringify(payload),
    subTargets: payload.subTargets ?? null,
    unitMinMinutes: payload.unitMinMinutes ?? null,
    status: 'active'
  });
}

// ─── Groq fetch with failure contract ────────────────────────────────────────

async function _fetchFromGroq(tier: AiChallengeTier): Promise<
  | { ok: true; challenge: GroqChallengePayload & { expiresInHours: number } }
  | { ok: false; error: AiChallengeError }
> {
  const settings = settingsStore.get();
  const aiToggleEnabled = settings.aiChallengesEnabled ?? false;

  const profileId = await getCurrentProfileId();
  const featsRow = await getAiFeatureSettings(profileId);
  const feats = getAiFeaturesOrDefault(profileId, featsRow);
  const smartEnabled = feats.smartChallengesEnabled;

  if (!aiToggleEnabled || !smartEnabled) {
    return {
      ok: false,
      error: { reason: 'feature-disabled', aiToggleEnabled, apiKeyPresent: false }
    };
  }

  const apiKey = settings.groqApiKey?.trim();
  const apiKeyPresent = Boolean(
    apiKey && apiKey.length > 0 && !apiKey.startsWith('sk-xxxx')
  );

  if (!apiKeyPresent) {
    return {
      ok: false,
      error: { reason: 'no-key', aiToggleEnabled, apiKeyPresent: false }
    };
  }

  const blob = await buildThirtyDayWeakSpotSummary(profileId);
  const systemPrompt = _buildSystemPrompt(tier, blob);

  let content: string | null = null;
  try {
    content = await chatCompletion({
      systemPrompt,
      prompt: `Emit the JSON now for tier=${tier}.`,
      jsonMode: true,
      timeoutMs: 5000
    });
  } catch {
    return { ok: false, error: { reason: 'network', aiToggleEnabled, apiKeyPresent } };
  }

  if (!content) {
    return { ok: false, error: { reason: 'network', aiToggleEnabled, apiKeyPresent } };
  }

  const parsed = _parsePayload(content, tier);
  if (!parsed) {
    // One retry on parse failure.
    let retry: string | null = null;
    try {
      retry = await chatCompletion({
        systemPrompt: `${systemPrompt}\nYour previous reply was not valid JSON — respond with VALID JSON ONLY.`,
        prompt: `Regenerate tier=${tier} JSON.`,
        jsonMode: true,
        timeoutMs: 5000
      });
    } catch {
      return { ok: false, error: { reason: 'parse', aiToggleEnabled, apiKeyPresent } };
    }
    const retryParsed = retry ? _parsePayload(retry, tier) : null;
    if (!retryParsed) {
      return { ok: false, error: { reason: 'parse', aiToggleEnabled, apiKeyPresent } };
    }
    return { ok: true, challenge: retryParsed };
  }

  return { ok: true, challenge: parsed };
}

// ─── Prompt ───────────────────────────────────────────────────────────────────

function _buildSystemPrompt(tier: AiChallengeTier, thirtyDayBlob: string): string {
  // Tier-specific constraints (ENFORCED)
  const tierRules: Record<AiChallengeTier, { expiresInHours: number; targetMin: number; targetMax: number; example: string }> = {
    daily: {
      expiresInHours: 24,
      targetMin: 1,
      targetMax: 5,
      example: 'Daily: 1-5 targets achievable within one day. Examples: 30-60 min focus, 1-2 sessions, 1-2 subjects.'
    },
    weekly: {
      expiresInHours: 168,
      targetMin: 5,
      targetMax: 20,
      example: 'Weekly: 5-20 targets span 7 days. Examples: 300-450 min focus, 5-10 sessions, 3-5 subjects.'
    },
    monthly: {
      expiresInHours: 720,
      targetMin: 20,
      targetMax: 100,
      example: 'Monthly: 20-100 targets span 30 days. Examples: 1500-2500 min focus, 20-40 sessions, 8+ subjects.'
    },
    surprise: {
      expiresInHours: 8,
      targetMin: 1,
      targetMax: 3,
      example: 'Surprise: 1-3 tiny targets, 8hr expiry. Quick wins. Examples: 1 session, 15 min, 1 subject.'
    }
  };

  const rules = tierRules[tier];

  return `
You are StudyTracker's adaptive challenge designer. Use the behavioural signals literally.

Student 30-day signal block:
${thirtyDayBlob}

Design ONE ${tier} challenge. Respond ONLY as valid JSON:
{
  "id": "unique_slug",
  "tier": "${tier}",
  "title": "Short enticing title",
  "description": "One imperative sentence tying to data",
  "icon": "lucide PascalCase name",
  "metric": "sessions | minutes | streak | subjects | pomodoros",
  "target": number,
  "expiresInHours": number,
  "difficulty": "easy | medium | hard | extreme",
  "reward": { "badgeName": "string", "badgeIcon": "lucide name" },
  "subTargets": { "mode": "any-subjects", "count": number, "minutesPerSubject": number } | null,
  "unitMinMinutes": number | null
}

═══════════════════════════════════════════════════════════════════════════════
TIER CONSTRAINTS (${tier.toUpperCase()} - MUST FOLLOW):
• expiresInHours: MUST be exactly ${rules.expiresInHours}
• target: MUST be in range ${rules.targetMin}-${rules.targetMax} (not outside this range)
• difficulty: Scale to tier: daily→easy/medium, weekly→medium/hard, monthly→hard/extreme, surprise→easy
• ${rules.example}

═══════════════════════════════════════════════════════════════════════════════
METRIC CHOICE (CRITICAL - ALWAYS SET):
• MUST use exactly ONE from: sessions, minutes, streak, subjects, or pomodoros
• Do NOT invent metric names. Do NOT omit metric.
• Examples:
  - "Complete 3 pomodoros": metric = "pomodoros"
  - "Study for 90 minutes": metric = "minutes"
  - "Complete 5 study sessions": metric = "sessions"
  - "Study 7 different days": metric = "streak"
  - "Study exactly 3 topics": metric = "subjects"

MULTI-SUBJECT (subTargets) RULE:
• IF description says "study N DIFFERENT SUBJECTS for M MINUTES each":
  - subTargets = { "mode": "any-subjects", "count": N, "minutesPerSubject": M }
  - metric = "minutes" or "sessions" (NOT "subjects")
  - target = N * M (or nearest tier-appropriate value)
  - EXAMPLE: "Study 3 subjects for 30 min each" → metric: "minutes", target: 90, subTargets: {...}

• IF description says "study X different topics/subjects" (no per-subject duration):
  - metric = "subjects"
  - subTargets = null
  - target = number of subjects (scaled to tier)
  - EXAMPLE: "Explore 5 topics" → metric: "subjects", target: 5, subTargets: null

UNIT MINIMUM RULE:
• IF metric is "pomodoros" or "sessions" AND each must minimum duration:
  - unitMinMinutes = duration floor (e.g., 25)
  - description must say it: "Complete 3 pomodoros of at least 25 minutes each"

═══════════════════════════════════════════════════════════════════════════════
DIFFICULTY ALIGNMENT:
• easy: achievable by most, 30-60% of top performers, low friction
• medium: moderate challenge, requires ~1-2 focused efforts, good engagement
• hard: significant push, requires planning/consistency, high satisfaction
• extreme: ambitious goal, requires peak effort/multiple sessions, high reward

FINAL VALIDATION:
✓ expiresInHours = ${rules.expiresInHours}
✓ target in range ${rules.targetMin}-${rules.targetMax}
✓ metric is one of: sessions, minutes, streak, subjects, pomodoros
✓ If subTargets exists, metric is NOT "subjects"
✓ difficulty aligns with target difficulty
✓ Pure JSON only. No markdown. No explanation text.
`.trim();
}

// ─── Parse & coerce ───────────────────────────────────────────────────────────

function _parsePayload(
  content: string,
  tier: AiChallengeTier
): (GroqChallengePayload & { expiresInHours: number }) | null {
  let raw: Record<string, unknown>;
  try {
    raw = JSON.parse(content) as Record<string, unknown>;
  } catch {
    const match = /\{[\s\S]*\}/.exec(content);
    if (!match) return null;
    try {
      raw = JSON.parse(match[0]) as Record<string, unknown>;
    } catch {
      return null;
    }
  }

  const metrics = ['sessions', 'minutes', 'streak', 'subjects', 'pomodoros'];
  const diffs = ['easy', 'medium', 'hard', 'extreme'];
  const tiers = ['daily', 'weekly', 'monthly', 'surprise'];

  // CRITICAL: metric MUST be valid. Log and fail if missing or invalid.
  const metric = metrics.includes(raw.metric as string)
    ? (raw.metric as string)
    : (() => {
        console.warn(
          `[AI Challenge] Groq did not provide a valid metric. Got: ${JSON.stringify(raw.metric)}. ` +
          `Valid options: ${metrics.join(', ')}. Defaulting to 'minutes' as fallback.`
        );
        return 'minutes';
      })();
  const difficulty = diffs.includes(raw.difficulty as string)
    ? (raw.difficulty as string)
    : 'medium';
  const parsedTier = tiers.includes(raw.tier as string) ? (raw.tier as AiChallengeTier) : tier;

  let target = Number(raw.target);
  if (!Number.isFinite(target) || target <= 0) target = 30;

  let expiresInHours = Number(raw.expiresInHours);
  if (!Number.isFinite(expiresInHours) || expiresInHours <= 0) {
    expiresInHours =
      tier === 'surprise' ? 8 : tier === 'monthly' ? 720 : tier === 'weekly' ? 168 : 24;
  }

  const reward = raw.reward as Record<string, unknown> | undefined;

  // Parse optional sub-targets.
  let subTargets: AiMissionSubTargets | null = null;
  const rawSub = raw.subTargets as Record<string, unknown> | null | undefined;
  if (rawSub && typeof rawSub.mode === 'string' && typeof rawSub.count === 'number') {
    subTargets = {
      mode: rawSub.mode,
      count: rawSub.count,
      minutesPerSubject:
        typeof rawSub.minutesPerSubject === 'number' ? rawSub.minutesPerSubject : undefined
    };
  }

  const unitMinMinutes =
    typeof raw.unitMinMinutes === 'number' && raw.unitMinMinutes > 0
      ? raw.unitMinMinutes
      : null;

  return {
    id: String(raw.id ?? `ai-${tier}-${Date.now()}`),
    tier: parsedTier,
    title: String(raw.title ?? ''),
    description: String(raw.description ?? ''),
    icon: String(raw.icon ?? 'Target'),
    metric,
    target,
    expiresInHours,
    difficulty,
    reward: {
      badgeName: String(reward?.badgeName ?? 'Badge'),
      badgeIcon: String(reward?.badgeIcon ?? 'Trophy')
    },
    subTargets,
    unitMinMinutes
  };
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function _shouldRefresh(
  lastFetch: string | undefined,
  now: Date,
  hoursThreshold: number
): boolean {
  if (!lastFetch) return true;
  const last = new Date(lastFetch);
  return (now.getTime() - last.getTime()) / (1000 * 60 * 60) >= hoursThreshold;
}
