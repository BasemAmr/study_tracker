import { chatCompletion, logGroqError } from './groqClient';
import { buildThirtyDayWeakSpotSummary } from './studySignalsForAi';
import type {
  AiChallengeDifficulty,
  AiChallengeMetric,
  AiChallengeTier,
} from '../domain';

export interface GroqChallengeResponse {
  id: string;
  tier: AiChallengeTier;
  title: string;
  description: string;
  icon: string;
  metric: AiChallengeMetric;
  target: number;
  expiresInHours: number;
  difficulty: AiChallengeDifficulty;
  reward: {
    badgeName: string;
    badgeIcon: string;
  };
}

function stringifyError(error: unknown): string {
  if (error instanceof Error) {
    return `${error.name}: ${error.message}\n${error.stack ?? ''}`.trim();
  }
  return String(error);
}


function coerceChallenge(parsed: Record<string, unknown>, tier: AiChallengeTier): GroqChallengeResponse {
  const reward = parsed.reward as Record<string, unknown> | undefined;
  const out: GroqChallengeResponse = {
    id: String(parsed.id ?? `ai-${tier}-${Date.now()}`),
    tier: (parsed.tier as AiChallengeTier) ?? tier,
    title: String(parsed.title ?? ''),
    description: String(parsed.description ?? ''),
    icon: String(parsed.icon ?? 'Target'),
    metric: parsed.metric as AiChallengeMetric,
    target: Number(parsed.target),
    expiresInHours: Number(parsed.expiresInHours ?? 24),
    difficulty: (parsed.difficulty as AiChallengeDifficulty) ?? 'medium',
    reward: {
      badgeName: String(reward?.badgeName ?? 'Badge'),
      badgeIcon: String(reward?.badgeIcon ?? 'Trophy'),
    },
  };

  const metrics: AiChallengeMetric[] = ['sessions', 'minutes', 'streak', 'subjects', 'pomodoros'];
  if (!metrics.includes(out.metric)) out.metric = 'minutes';
  if (!Number.isFinite(out.target) || out.target <= 0) out.target = 30;

  const diffs: AiChallengeDifficulty[] = ['easy', 'medium', 'hard', 'extreme'];
  if (!diffs.includes(out.difficulty)) out.difficulty = 'medium';

  if (!out.expiresInHours || out.expiresInHours <= 0) {
    out.expiresInHours = tier === 'surprise' ? 8 : tier === 'monthly' ? 720 : tier === 'weekly' ? 168 : 24;
  }

  return out;
}

function parseChallengePayload(content: string, tier: AiChallengeTier): GroqChallengeResponse | null {
  try {
    const parsed = JSON.parse(content) as Record<string, unknown>;
    return coerceChallenge(parsed, tier);
  } catch (e) {
    void logGroqError('Groq AI challenge JSON parse failed', {
      tier,
      contentSnippet: content.slice(0, 2400),
      error: stringifyError(e),
    });
    return null;
  }
}

/**
 * Thin legacy Groq path — preserves previous short-summary wording for callers/tests.
 * Returns null so callers can substitute static payloads when absent.
 */
export async function fetchAiChallenge(
  tier: AiChallengeTier,
  sessionSummary: string,
): Promise<GroqChallengeResponse | null> {
  const systemPrompt = `
You are a high-performance productivity coach for StudyTracker students.
Recent activity snapshot:
${sessionSummary}

Produce a ${tier} challenge matching the JSON schema the user echoes.
`;

  const content = await chatCompletion({
    systemPrompt,
    prompt: `Return only JSON for a ${tier} challenge.`,
    jsonMode: true,
    timeoutMs: 3000,
  });
  if (!content) return null;
  return parseChallengePayload(content, tier);
}

function buildSmartChallengeSystemPrompt(tier: AiChallengeTier, thirtyDayBlob: string): string {
  return `
You are StudyTracker's adaptive challenge designer. Use the behavioural signals literally — tailor titles that mention concrete subjects or habits when useful.

Student 30-day signal block:
${thirtyDayBlob}

Design ONE ${tier} challenge JSON object (schema below). Stretch the user thoughtfully using patterns like Night Owl shifts, branching to under-used subjects, deep-work length, or aligning with recurring moods — phrase uniquely, avoid copying labels verbatim.

Respond ONLY as JSON:
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
  "reward": { "badgeName": "string", "badgeIcon": "lucide name" }
}
Rules:
• Numbers must reflect tier scale (daily < weekly < monthly).
• No prose outside JSON.
`;
}

/**
 * Smart challenges (Groq): parse fail → retry one extra completion, then callers fall back hard-coded.
 */
export async function fetchSmartAiChallengeGroq(
  tier: AiChallengeTier,
  profileId: number,
): Promise<GroqChallengeResponse | null> {
  try {
    const blob = await buildThirtyDayWeakSpotSummary(profileId);
    const systemPrompt = buildSmartChallengeSystemPrompt(tier, blob);
    let content = await chatCompletion({
      systemPrompt,
      prompt: `Emit the JSON now for tier=${tier}.`,
      jsonMode: true,
      timeoutMs: 3000,
    });
    if (!content) return null;
    let parsed = parseChallengePayload(content, tier);
    if (parsed) return parsed;

    content = await chatCompletion({
      systemPrompt: `${systemPrompt}\nYour previous reply was invalid JSON — respond again with VALID JSON ONLY.`,
      prompt: `Regenerate tier=${tier} JSON.`,
      jsonMode: true,
      timeoutMs: 3000,
    });
    if (!content) return null;
    parsed = parseChallengePayload(content, tier);
    return parsed;
  } catch (err) {
    await logGroqError('fetchSmartAiChallengeGroq crashed', stringifyError(err));
    return null;
  }
}
